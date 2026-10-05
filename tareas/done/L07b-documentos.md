# L07b — Servicios de documentos, subida y descarga

**Arquitecto:** claude-code · **Implementa:** AGY · **Audita:** CODEX (sombrero A, obligatorio)
**Fuente:** requisitos §2.3, diseño §2.3, §3.6, §9.4, §9.5, §9.13, §9.15, §10.2, §10.5 y §14. La sección más alta manda.
**Base:** L07a (`c61bc09`):
- `src/server/archivos/{rutas,recibir,publicar,validar}.ts`;
- contratos en `src/server/servicios/contratos.ts` (`ServiciosDocumentos`, `subirDocumentoEntrada`,
  `reemplazarDocumentoEntrada`, `anularDocumentoEntrada`, `verArchivoEntrada`, `faltantesEntrada`);
- triggers de versión, solicitud y cardinalidad en la base (L02b).

**Comandos:** usá `cd legajos && …`. **No uses `git -C`.**

## Alcance de archivos
1. `src/server/servicios/documentos.ts` (**nuevo**): `crearServiciosDocumentos(db, { raiz })` implementa
   `ServiciosDocumentos`. Recibe los archivos **ya en temporales** (`{ tmp, nombreOriginal, bytes, sha256 }[]`).
   Ajustá el tipo `ArchivoParaSubir` del contrato a eso: el stream ya lo consumió `recibirMultipart`.
2. `src/server/servicios/contratos.ts`: ajustar `ArchivoParaSubir`. Ningún otro cambio.
3. `src/server/servicios/mapeo.ts`: mapeo de documento y archivo, con `vencido` y `venceEn`.
4. `src/server/servicios/legajos.ts`: **sólo** que `verLegajo` traiga `documentos`. Quitar el último `TODO`.
5. `src/app/api/documentos/route.ts` (**nuevo**), `POST`, runtime `nodejs`:
   1. `requerirSesion({ permiso: 'documento.subir', mutacion: true })` **antes de leer el cuerpo**;
   2. `recibirMultipart(request, { raiz })`;
   3. parsea los campos con zod. Si viene `documentoId`, se trata de un **reemplazo**;
   4. llama al servicio y responde `201` con el `DocumentoSalida`.

   Errores: 401, 403, 413, 422, 409, con `{ codigo, mensaje }`. Pase lo que pase, nunca deja temporales: los
   borra en `finally`, ignorando `ENOENT`.
6. `src/app/api/archivos/[id]/route.ts` (**nuevo**), `GET`, runtime `nodejs`:
   - `requerirSesion({ permiso: 'documento.ver', mutacion: false })` y después `verArchivo`;
   - responde con el stream y estos headers:
     - `Content-Type`: el MIME guardado en la base;
     - `Content-Length`;
     - `Content-Disposition`: `inline` por defecto, `attachment` con `?descargar=1`. El nombre va saneado (sin
       comillas ni control) y en `filename*=UTF-8''…`;
     - `X-Content-Type-Options: nosniff`;
     - `Cache-Control: private, no-store`.
7. `test/documentos.test.ts` (**nuevo**). **Años de test: 2080–2084.**
8. `test/rutas-documentos.test.ts` (**nuevo**): llama a los route handlers con un `Request` armado. Las deps de
   sesión son inyectables como en `auth-guard.test.ts`: agregá a los handlers la misma inyección opcional.

## Reglas del servicio

### `subirDocumento(ctx, entrada, archivos)` (permiso `documento.subir`)
1. Valida la entrada:
   - al menos 1 archivo, y como máximo 10;
   - el tipo tiene que existir y estar **activo**;
   - si el tipo no admite múltiples archivos, exactamente 1;
   - el legajo tiene que existir.
2. **Valida cada archivo** con `detectarTipo` y `validarArchivo` (L07a). Si falla → 422 y no se escribe nada.
3. **Publica antes de la base** (§9.15): `publicar(raiz, tmp, rutaFinal(...))` para cada uno.
4. Abre una transacción con:
   - `INSERT documento`;
   - `INSERT documento_archivo` por cada archivo (`orden` 1..n, `path_relativo`, `nombre_original`, `mime`,
     `bytes`, `sha256`);
   - las solicitudes, si `solicitudesIds` no está vacío. Por cada una:
     1. `SELECT … FOR UPDATE` del **documento recién creado**, en orden de id (§10.2);
     2. la solicitud tiene que ser del mismo legajo, del mismo tipo y estar **pendiente**. Si ya está recibida
        por un documento vivo → `ErrorConflicto('solicitud_recibida')`;
     3. `UPDATE solicitud_documento SET documento_recibido_id`;
   - auditoría: `alta` del documento con sus archivos, `cambio` por cada solicitud.
5. **Si la transacción falla de forma explícita** (error antes del COMMIT): `descartarFinal` de los finales
   recién publicados. **Si el error es en el COMMIT mismo o ambiguo:** no se borra nada (§9.15). Distinguilos
   con un flag que se pone justo antes del commit.
6. Tras el COMMIT, borra los temporales.

### `reemplazarDocumento(ctx, { documentoId, fechaEmision, observacion }, archivos)` (permiso `documento.subir`)
Es igual que subir, pero dentro de la transacción y en este orden:
1. `SELECT … FOR UPDATE` del documento anterior: tiene que estar vivo → si no, 409;
2. `INSERT` del nuevo con `version_de = anterior`, mismo legajo y mismo tipo. El trigger lo valida;
3. anula el anterior con el motivo `reemplazado por <id>`;
4. **reapunta** a la versión nueva las solicitudes que apuntaban al anterior, bloqueando antes las dos filas de
   documento en orden de id;
5. audita el alta, la anulación y los cambios de solicitudes.

Los archivos del anterior **se conservan**.

### `anularDocumento` (permiso `documento.anular`, sólo admin)
- Motivo obligatorio y sólo sobre documentos vivos.
- Las solicitudes que apuntaban a él vuelven solas a pendiente: el estado es derivado (L06).
- Los archivos en disco no se tocan.

### `verArchivo(ctx, { archivoId })` (permiso `documento.ver`)
1. Busca el archivo por id. La ruta **sale de la base**: el cliente sólo manda el id. Si el documento está
   anulado, igual se puede ver (historial).
2. `resolverSeguro(raiz, path_relativo)` y abre el stream.
3. Audita `vista` o `descarga` en la misma operación, antes de devolver el stream: `verArchivo` recibe
   `{ modo: 'vista' | 'descarga' }`.

### `faltantes(ctx, { legajoId })` (permiso `legajo.ver`)
Los tipos **obligatorios y activos** que no tienen ningún documento vivo en el legajo.

### Vencimiento (en el mapeo)
Si el tipo **actual** tiene `vigencia_dias`:
- `venceEn = fecha_emision + vigencia_dias`;
- `vencido = venceEn < hoy` en America/Asuncion, con Luxon y `now` inyectable.

Si el tipo no tiene vigencia: `venceEn = null` y `vencido = false`.

## Criterios
```
cd legajos && pnpm sistema:check && pnpm verificar
```

`test/documentos.test.ts`, con Postgres real como `legajos_app` y `ARCHIVOS_DIR` en un directorio temporal del test:
1. Subir un PDF válido:
   - queda la fila y el archivo en `<legajo>/<doc>/<uuid>.pdf`, con el sha256 correcto;
   - no queda ningún temporal;
   - hay auditoría de alta.
2. Tipo sin múltiples archivos y 2 archivos → 422, sin filas y **sin finales en disco**. Nota (con múltiples) y 3
   archivos → `orden` 1, 2 y 3.
3. Un archivo inválido (`falso.pdf`, `truncado.jpg`) → 422, sin filas ni finales.
4. Un error de base inyectado después de publicar, antes del commit → se borran los finales. Un error simulado
   **en** el commit → los finales quedan. Basta un test con una función de commit inyectable.
5. Solicitudes:
   - subir con una solicitud pendiente del mismo tipo → queda `recibida`;
   - otra solicitud del mismo tipo que ya está recibida → 409;
   - una de otro tipo → 409 o 422, sin filas;
   - **concurrencia:** dos subidas que apuntan a la misma solicitud → una sola la satisface.
6. Reemplazo:
   - versión nueva con `version_de`, anterior anulada "reemplazado por…", solicitud reapuntada y archivos viejos
     en disco;
   - reemplazar uno anulado → 409;
   - dos reemplazos concurrentes del mismo documento → uno sale bien y el otro da 409.
7. Anular (admin): la solicitud vuelve a pendiente. Operador → 403.
8. `verArchivo`:
   - devuelve el contenido exacto y audita `vista` o `descarga`;
   - un id inexistente → 404;
   - un `path_relativo` adulterado en la base (como owner) a `../../etc/passwd` → error y **nada** leído;
   - lo mismo con un symlink plantado en el directorio del documento.
9. `faltantes`:
   - un tipo obligatorio sin documento aparece;
   - después de subirlo, desaparece;
   - si el documento se anula, vuelve a aparecer;
   - marcar un tipo como obligatorio afecta legajos viejos (§14, aplica hacia atrás).
10. Vencimiento:
    - con vigencia de 365 días y una emisión de hace 366 → `vencido`;
    - con una de hace 10 → no;
    - si el tipo no tiene vigencia → `venceEn null`;
    - cambiar la vigencia del tipo cambia el resultado de documentos existentes.
11. `consulta` puede ver y descargar, pero no subir (403).

`test/rutas-documentos.test.ts`:
- POST sin sesión → 401 **sin consumir el cuerpo**: un body que, si se lee, lanza;
- `origin` ajeno → 403;
- más de 20 MB → 413 sin temporales;
- caso feliz → 201;
- GET de un archivo propio → 200 con los headers exactos de arriba, `?descargar=1` → `attachment`, un nombre con
  comillas sale saneado, sin sesión → 401.

Sin `any`, sin `console.log`, `.set()` explícito. Sin commit ni push.

### Corrección 1 (reintento de AGY): el primer intento se cortó con 7 tests en rojo
**Seguí desde lo que ya escribiste**, sin reescribir desde cero:
1. **`psql` no está permitido.** Para mirar la base usá un test o `node -e` con `postgres`.
2. **Los tests usan los fixtures reales** de `test/fixtures/archivos/` (`valido.pdf`, `valido.jpg`, `falso.pdf`,
   `truncado.jpg`…), copiados a un tmp dentro de `ARCHIVOS_DIR/.tmp` del test. Un "PDF" armado a mano no pasa
   `qpdf --check`: por eso hoy fallan con `archivo_invalido`.
3. El fixture de interacción tiene que incluir `fecha` (NOT NULL).
4. **Faltan casos de la spec**:
   - 4b: un error **en** el commit deja los finales;
   - 5: solicitud del mismo tipo → recibida; ya recibida → 409; **concurrencia** de dos subidas sobre la misma
     solicitud;
   - 6: reemplazo concurrente → uno sale bien y el otro da 409; reemplazar un anulado → 409; los archivos viejos
     siguen en disco; la solicitud queda reapuntada;
   - 8: `path_relativo` adulterado a `../../etc/passwd` y un symlink plantado → error sin leer nada; `vista` y
     `descarga` auditadas;
   - 9: aplicación hacia atrás de la obligatoriedad y la vigencia;
   - 10: vencido / no vencido / sin vigencia, con `now` inyectado.

   Separá el test 9+10 en casos propios.
5. **Nada de `as unknown as`**, tampoco en los tests. Para el `Request` con stream: `new Request(url, { method:
   'POST', body: Readable.toWeb(stream) as ReadableStream<Uint8Array>, duplex: 'half' } as RequestInit &
   { duplex: 'half' })`. Si no tipa, explicá por qué en el informe.
6. Verificá con `cd legajos && pnpm verificar` hasta exit 0.

### Corrección 2 (reintento final, CODEX sombrero B)
AGY se cortó dos veces. En el segundo intento un `sed` global (`tipo_id` → `tipo_documento_id`) rompió
`test/documentos.test.ts`, que hoy no parsea. Tomá como base `src/server/servicios/documentos.ts`, las rutas y
el mapeo que dejó, revisalos contra la spec y corregí lo que no cumpla. **Podés reescribir los dos archivos de
test desde cero.** Tienen que cubrir **todos** los criterios de la spec y de la Corrección 1, uno por caso.
`cargarDocumentos`, si hace falta exportarla para `verLegajo`, está bien. Verificá con
`cd legajos && pnpm verificar` hasta exit 0.
