# M3 — pantallas del modelo v2

**Estado:** COMPLETADO CON BLOQUEOS DE SERVIDOR
**Rol:** OPENCODE (superficie)
**Rama:** `modelo-v2` (base `a67a7b0`, M2b)

## Verificación

`cd legajos && pnpm verificar` → **exit 0**.

```
$ pnpm lint && pnpm typecheck && pnpm test && pnpm build
$ eslint .
$ tsc --noEmit
$ vitest run

 Test Files  20 passed (20)
      Tests  498 passed (498)
   Duration  27.01s (transform 388ms, setup 0ms, collect 4.42s, tests 17.61s, environment 3ms, prepare 832ms)

$ next build
 ✓ Compiled successfully in 2.4s
 ✓ Generating static pages (7/7)
```

Rutas generadas (las de trámites y legajos son dinámicas, como antes):

```
┌ ○ /                                      133 B    ┌ ƒ /legajos/[id]                        1.72 kB
├ ○ /_not-found                            996 B    ├ ƒ /legajos/[id]/documentos/[docId]       177 B
├ ƒ /admin                                 177 B    ├ ƒ /legajos/nuevo                       1.99 kB
├ ƒ /admin/accesos                         177 B    ├ ○ /login                               826 B
├ ƒ /admin/catalogos                     3.23 kB    ├ ƒ /logout                                133 B
├ ƒ /admin/usuarios                      4.24 kB    ├ ƒ /tramites                              177 B
├ ƒ /api/archivos/[id]                     133 B    ├ ƒ /tramites/[id]                       3.44 kB
├ ƒ /api/documentos                        133 B    └ ƒ /tramites/nuevo                      2.48 kB
├ ƒ /cuenta/clave                          177 B
```

### La base de pruebas no es idempotente (preexistente, no de esta tarea)

`pnpm test` **no se puede correr dos veces seguidas**: los tests de servidor insertan filas
reales en `legajos_test` (puerto 55433) y su `afterAll` sólo cierra sesiones. La segunda
corrida sobre la misma base falla por contadores ya gastados:

```
Test Files  2 failed | 18 passed (20)
      Tests  5 failed | 493 passed (498)

FAIL  test/legajos.test.ts > escapa porcentajes, guiones bajos y barras de la búsqueda
FAIL  test/legajos.test.ts > quita formato y ceros; reutiliza sin sobrescribir datos
FAIL  test/tramites.test.ts > 10 altas concurrentes reservan los correlativos 1..10        (recibió 21..30)
FAIL  test/tramites.test.ts > numera 2090-0001 y 2090-0002 con estado inicial y auditoría   (recibió 2090-0005/0006)
FAIL  test/tramites.test.ts > usa el año de Asunción UTC−3 y reinicia la numeración        (recibió 2092-0004)
```

Los cinco son de `test/` (servidor), ningún archivo de esta tarea los toca. Se comprobó que
son preexistentes: con los cambios de M3 en `git stash` (árbol limpio en `a67a7b0`) los mismos
tests de `test/tramites.test.ts` fallan igual. Es el mismo problema que ya estava reportado en
`L08b-pantallas-operacion.opencode.informe.md`.

Para obtener la corrida verde **se truncaron las tablas transaccionales de `legajos_test`**
(`legajo`, `tramite`, `documento`, `interaccion`, `solicitud_documento`, `contador_tramite`,
`usuario`, `usuario_ip`, `sesion`, `acceso_log`, `auditoria`, con `CASCADE`), conservando los
seeds de catálogos (`estado_legajo` 5, `tipo_documento` 5, `tipo_interaccion` 4, `tipo_tramite` 1).
No se tocó ninguna base fuera de `legajos_test` ni se modificó código de servidor ni de test.

**Propuesta para el servidor:** que el `beforeAll` de `test/legajos.test.ts` y
`test/tramites.test.ts` trunque sus propias tablas con el rol owner, o que usen años
aleatorios, para que `pnpm verificar` sea repetible.

## Qué se hizo

**Chrome y navegación**

- `/` redirige a `/tramites` (antes `/legajos`): la actuación es la pantalla de arranque.
- `(app)/layout.tsx`: enlaces a Trámites, Legajos y Administración; se mantiene
  `ctxPagina('cuenta.cambiar_clave')` del layout previo, con su aviso de anti-bucle.

**Buscador de trámites** (`tramites/page.tsx`)

Filtros por número, cédula vinculada, tipo y estado, con paginación y `numero`/`tipo`/`estado`/
`cedula`/`pagina` en la URL. La cédula acepta `1.234.567` o `1234567`: la normalización es del
servicio (`src/server/cedula.ts`), no del formulario. Botón «Nuevo trámite» con `tramite.crear`.

**Alta de trámite** (`tramites/nuevo/`)

`FormTramite.tsx` es cliente y mantiene las cédulas en estado local:

- Al salir del campo llama a `buscarPorCedulaAccion`; si ya hay legajo, se usa ese
  (`{ legajoId }`) y no se piden nombres, con el aviso de que no se creará otro legajo.
- Si no hay legajo, aparecen los datos de la cédula y se manda `{ nuevo: {...} }`.
- Cédula original por radios («Sin determinar» por defecto) → `originalIndice`.
- El alta real la hace `crearTramiteAccion`, que redirige al trámite nuevo; el `FormData`
  sólo se usa para tipo, fecha y observación, el resto sale del estado del cliente.
- Si la base no tiene ningún tipo de trámite, la pantalla avisa y no renderiza el formulario.

**Detalle de trámite** (`tramites/[id]/page.tsx`)

- Datos: estado (badge activo/anulado), tipo, fecha de detección y observación.
- Cédulas vinculadas: número (enlace al legajo), «apellidos, nombres», papel y acciones.
  El papel sale del diseño §16.4: sin original marcada se muestra **«Original sin determinar»**,
  no «Original». Los vínculos anulados quedan tachados con su motivo y sin botones.
- Documentos faltantes: lista de `faltantes`, con la aclaración de que un documento cargado
  en la cédula cuenta aunque haya venido de otro trámite.
- Documentos aportados en este trámite: tipo, cédula, emisión y archivos.
- Historial: fecha/hora, tipo, nota, usuario, cambio de estado, solicitudes con su estado y
  anulación con motivo. Se respeta el orden que trae `verTramite`.
- Acciones, cada una detrás de su permiso: editar, marcar original, «dejar sin determinar»,
  desvincular (con motivo), registrar interacción y subir documento.

**Componentes nuevos de trámites** (`tramites/[id]/componentes/`)

`EditarTramite`, `MarcarOriginal` (uno por vínculo y otro para «dejar sin determinar»),
`Desvincular` (explica que el vínculo se anula con motivo y que las solicitudes vuelven a
pendiente), `VincularCedula` (misma búsqueda por cédula que el alta) y `RegistrarInteraccion`
(tipo, nota, cambio de estado y documentos que se solicitan). Todos usan el `Dialogo` del legajo
y traducen los códigos de error a mensajes: **al operador nunca se le muestra un código**.

**Reutilización**

- `SubirDocumento` y `Anular` viven en `legajos/[id]/componentes/` y ahora los usan tanto el
  legajo como el trámite. `Anular` importaba `anularInteraccionAccion` de `legajos/acciones`,
  que ya no la exporta: ahora la toma de `tramites/acciones`, que es donde vive.
- El `FormData` de la subida manda sólo campos del contrato (`legajoId`, `tramiteId`, `tipoId`,
  `fechaEmision`, `observacion`, `solicitudesIds`, `archivos`; en reemplazo, `documentoId`).

**Legajos**

- `legajos/page.tsx` y `legajos/nuevo/` reescritos sobre la cédula como identidad única.
- `legajos/[id]/page.tsx`: documentos agrupados por tipo, versión actual y `details` con las
  anteriores; trámites con su papel (original/duplicado/sin determinar); acciones con permiso.
- `legajos/[id]/documentos/[docId]/page.tsx`: corregido el enlace de procedencia, que usaba el
  `tramiteId` del documento y ahora resuelve el número del trámite desde `legajo.tramites`.
- `CorregirCedula.tsx` nuevo (admin, con motivo). `legajo.editar` ya no toca la cédula:
  cambiarla es `corregirCedulaAccion`, que exige `legajo.corregir_cedula`.
- **Borrados** los componentes v1 sin destino en el modelo v2: `AgregarCedula`, `EditarCedula`,
  `legajos/[id]/MarcarOriginal` y `legajos/[id]/RegistrarInteraccion`. Sus equivalentes ahora
  están en la pantalla de trámite, que es donde el original y las solicitudes tienen sentido.

**Administración › Catálogos**

- Nueva sección **Tipos de trámite**: alta con orden, edición, activar/desactivar y los
  documentos obligatorios (`ObligatoriosTramite.tsx`), que en el modelo v2 son del tipo de
  trámite y no del tipo de documento.
- `Catalogo` pasó a ser `'estado' | 'interaccion' | 'documento' | 'tramite'`.
- Quitado `obligatorio` del tipo de documento en el alta, la edición y la tabla: el campo ya no
  existe en `crearTipoDocumentoEntrada` ni en `TipoDocumentoAdminSalida`. `esDocumento` ahora
  detecta por `vigenciaDias` en vez de por `obligatorio`.

**Helper de catálogos** (`tramites/catalogos.ts`)

Una sola lectura de `buscarTramites` devuelve tipos y estados para los filtros. Ver bloqueo 1.

## Bloqueos de servidor (no se tocan desde superficie)

1. **No hay lectura de catálogos para un operador.** `admin.listarCatalogos` exige
   `admin.catalogos` y `servicios()` no expone nada equivalente. Es el mismo bloqueo de L08b y
   es el que más molesta en el modelo v2, porque el tipo de trámite es obligatorio al dar de alta.
   Workaround: `tramites/catalogos.ts` deriva tipos y estados de hasta 100 trámites existentes.
   - En el **buscador** no se pierde nada: un tipo o estado sin trámites tampoco se puede filtrar.
   - En el **alta** sí importa: en una base recién sembrada hay 1 tipo de trámite y 0 trámites, así
     que la lista derivada queda vacía y **no se puede crear el primer trámite** desde la pantalla;
     hay que pedir que un administrador lo dé de alta en Catálogos. La pantalla lo avisa en vez de
     mandar un `select` vacío.
   - En el **detalle**, los tipos de interacción y los estados alternativos salen del historial del
     propio trámite: un trámite recién creado no tiene historial y no puede registrar su primera
     interacción. Los tipos de documento salen de `faltantes ∪ documentos.tipo ∪ solicitudes.tipo`.
   - **Propuesta:** `catalogosOperativos(ctx)` de sólo lectura que devuelva tipos de trámite,
     estados y tipos de interacción/documento **activos**, exigiendo `tramite.ver` (o
     `tramite.crear` para el alta). Reemplaza el helper derivado en ~15 líneas y destraba el
     primer trámite.

2. **`LegajoResumen` no trae la cantidad de trámites.** La columna pedida para el buscador de
   legajos no existe en el contrato. Se agregó en su lugar emisión y observaciones, que sí están.
   **Propuesta:** `cantidadTramites` en `LegajoResumen`, o `buscarLegajos` con `tramites: number[]`.

3. **`TramiteResumen` no trae las cédulas vinculadas.** El listado de trámites no puede mostrar la
   columna de cédulas. **Propuesta:** `cedulas: { legajoId, cedula, esOriginal }[]` en
   `TramiteResumen`, o un `TramiteConVinculos` para el listado.

4. **`InteraccionSalida` sólo trae `usuarioId`.** El historial muestra el UUID crudo, que no le
   sirve a un operador. **Propuesta:** `nombreUsuario` en la salida.

5. **`faltantes` vacío es ambiguo.** `verTramite` devuelve la lista de tipos de documento
   obligatorios que el tipo de trámite declara y que ninguna cédula tiene; si esa lista viene
   vacía no se puede distinguir «el tipo no declara obligatorios» de «todo está cumplido».
   La pantalla dice «No falta ningún documento obligatorio», que es cierto en los dos casos, y
   aclara que los obligatorios se definen en el tipo de trámite. Para distinguirlo haría falta
   `obligatorios: CatalogoResumen[]` en `TramiteSalida` y marcar los cumplidos.

6. **`verTramite` no devuelve los documentos del trámite.** Para la tabla de «documentos
   aportados» se llama a `listarDocumentosLegajo` por cada vínculo vivo y se filtra por
   `tramiteId`: es N+1 (una consulta por cédula vinculada) y duplica entradas de auditoría de
   lectura. Con muchos vínculos se nota. **Propuesta:** `documentos: DocumentoSalida[]` en
   `TramiteSalida`.

7. **`interaccion.crear` no lo exige ningún Action.** `registrarInteraccionAccion` pide
   `tramite.editar`. El botón de «Registrar interacción» se muestra con `tramite.editar` para que
   la UI y el servidor coincidan. Con la matriz actual la diferencia no se nota (operador y admin
   tienen ambos permisos, consulta ninguno), pero el permiso queda sin uso.

## Desviaciones de la spec

- **Columna de cantidad de trámites en `/legajos`:** omitida (bloqueo 2).
- **Columna de cédulas vinculadas en `/tramites`:** omitida (bloqueo 3).
- **Historial:** se muestra `Usuario: {usuarioId}` en vez del nombre (bloqueo 4).
- **Tipos de trámite/estado del alta:** derivados de trámites existentes en vez del catálogo
  activo (bloqueo 1). Consecuencia visible: en una base recién sembrada no se puede crear el
  primer trámite desde la pantalla.
- **Tipos de interacción y estados del detalle:** derivados del historial del trámite (bloqueo 1).
- **`src/lib/es-py.ts`:** helper nuevo con `cedulaConPuntos`, `soloDigitos`, `fecha`, `fechaHora`
  y `hoyEnAsuncion`. Se prefirió el formateo con Luxon en cliente y servidor; el módulo es
  puramente de presentación, no toca servidor.
- **`src/app/(app)/tramites/catalogos.ts`:** helper no solicitado por nombre, necesario para los
  filtros del buscador y el alta.
- **Base de `legajos_test` truncada** antes de la verificación verde; ver la sección de
  verificación. No es un cambio de código y queda reportado para que no parezca un verde
  permanente.

## Archivos tocados

Creados:

- `src/lib/es-py.ts`
- `src/app/(app)/tramites/page.tsx`
- `src/app/(app)/tramites/catalogos.ts`
- `src/app/(app)/tramites/nuevo/page.tsx`
- `src/app/(app)/tramites/nuevo/componentes/FormTramite.tsx`
- `src/app/(app)/tramites/[id]/page.tsx`
- `src/app/(app)/tramites/[id]/componentes/{EditarTramite,MarcarOriginal,Desvincular,VincularCedula,RegistrarInteraccion}.tsx`
- `src/app/(app)/legajos/[id]/componentes/CorregirCedula.tsx`
- `src/app/(app)/admin/catalogos/componentes/ObligatoriosTramite.tsx`

Modificados:

- `src/app/page.tsx`, `src/app/(app)/layout.tsx`
- `src/app/(app)/legajos/page.tsx`, `legajos/nuevo/page.tsx`, `legajos/nuevo/componentes/FormLegajo.tsx`
- `src/app/(app)/legajos/[id]/page.tsx`, `legajos/[id]/documentos/[docId]/page.tsx`
- `src/app/(app)/legajos/[id]/componentes/{Anular,EditarLegajo,SubirDocumento}.tsx`
- `src/app/(app)/admin/catalogos/page.tsx`
- `src/app/(app)/admin/catalogos/componentes/{AltaCatalogo,EditarCatalogo,CamposCatalogo,catalogo}.ts(x)`

Borrados:

- `src/app/(app)/legajos/[id]/componentes/{AgregarCedula,EditarCedula,MarcarOriginal,RegistrarInteraccion}.tsx`

Sin tocar: `src/server/**`, `src/app/api/**`, `acciones.ts`, `package.json`, migraciones,
permisos, schemas y dependencias.