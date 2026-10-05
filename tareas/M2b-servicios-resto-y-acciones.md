# M2b — Servicios v2: interacciones, documentos, admin y Server Actions

**Arquitecto:** claude-code · **Implementa:** CODEX sombrero B · **Audita:** AGY (lectura) + arquitecto (mutaciones)
**Rama:** `modelo-v2`. Base: M2a (`d7303c9`), con `legajos.ts`, `tramites.ts`, `cedula.ts`, contratos y permisos v2.
**Fuente:** requisitos §7, diseño §16 (§16.4 manda), §10.2, §9.7 y §9.15.

Al terminar, **sólo** pueden quedar errores de `typecheck` en las pantallas: `src/app/(app)/**/page.tsx` y
`src/app/(app)/**/componentes/**`. Son de M3 (OPENCODE). Todo `src/server/**`, los `acciones.ts`, los route
handlers y los tests compilan y pasan.

## Alcance de archivos
1. **`src/server/servicios/cedulas.ts`**: **se borra**. Su `test/cedulas.test.ts` ya no está.
2. **`src/server/servicios/interacciones.ts`**: todo pasa a `tramite_id`.
   - `registrarInteraccion({ tramiteId, … })` toma el **candado del trámite** (§16.4.1) antes de insertar. El cambio
     de estado sigue siendo por trigger, y el P0001 se traduce a `estado_desactualizado`.
   - Las solicitudes son del trámite.
   - `listarInteracciones({ tramiteId })`: el estado derivado sigue igual, `recibida` sólo con un documento vivo.
   - Permisos: `tramite.editar` para registrar; `interaccion.anular` (admin) para anular; `tramite.ver` para listar.
3. **`src/server/servicios/documentos.ts`**:
   - `subirDocumento({ legajoId, tramiteId?, tipoId, fechaEmision, observacion?, solicitudesIds[] }, archivos)`:
     - si viene `tramiteId`: toma el **candado del trámite** primero y exige un vínculo vivo `(tramite,
       legajo)` → si no, 409 `legajo_no_vinculado`. El trigger es la segunda red;
     - las solicitudes tienen que ser **de ese trámite**, del tipo y estar pendientes. Orden de locks: trámite →
       documento → solicitudes por id;
     - sin `tramiteId` el documento queda sólo en el legajo, y entonces `solicitudesIds` tiene que venir vacío;
   - `reemplazarDocumento`: **hereda** el `tramite_id` del anterior (lo valida el trigger), incluso con el vínculo
     ya anulado. Las solicitudes que apuntaban al anterior se reapuntan con los locks de §16.4.1;
   - `anularDocumento`, `verArchivo` y el vencimiento: igual que antes;
   - **`faltantes` sale de acá**: ya vive en `tramites.ts`. Quitalo del contrato `ServiciosDocumentos`;
   - `listarDocumentosLegajo({ legajoId })`, si `verLegajo` lo necesita: con su trámite de procedencia (número) y
     las versiones.
4. **`src/server/servicios/tramites.ts`**: **sólo** completar en `verTramite` las `interacciones` y
   `solicitudes`, que hoy son `TODO M2b`, usando `listarInteracciones`.
5. **`src/server/servicios/admin.ts`**:
   - quitar `obligatorio` de los tipos de documento;
   - catálogo **`tipo_tramite`**: crear, editar y activar, con el nombre único sin distinguir mayúsculas → 409;
   - **`definirDocumentosObligatorios({ tipoTramiteId, tipoDocumentoIds[] })`**: reemplaza el conjunto activando y
     desactivando filas de `tipo_tramite_documento`. **No borra**: sin grant de DELETE, lo que sale queda
     `activo = false`;
   - `listarCatalogos` agrega `tiposTramite` con sus obligatorios;
   - el chequeo "tiene que quedar un estado activo" sigue igual.
6. **`src/server/servicios/contratos.ts`** y **`mapeo.ts`**: lo necesario para lo de arriba.
7. **`src/server/acciones/contexto.ts`**: `servicios()` con `legajos`, `tramites`, `interacciones`, `documentos` y
   `admin`.
8. **Actions** (mismo patrón de L08a: guard, `aResultado`, `revalidatePath`, y `…Con(deps)` para tests):
   - **`src/app/(app)/legajos/acciones.ts`**: `obtenerOCrearLegajoAccion`, `editarLegajoAccion`,
     `corregirCedulaAccion`, `buscarPorCedulaAccion` (lectura, para el aviso en el alta) y `anularDocumentoAccion`;
   - **`src/app/(app)/tramites/acciones.ts`** (**nuevo**): `crearTramiteAccion` (si sale bien, `redirect` a
     `/tramites/[id]`), `editarTramiteAccion`, `vincularLegajoAccion`, `desvincularLegajoAccion`,
     `marcarOriginalAccion`, `registrarInteraccionAccion` y `anularInteraccionAccion`;
   - **`src/app/(app)/admin/acciones.ts`**: sumar las del catálogo de tipos de trámite y
     `definirDocumentosObligatoriosAccion`, y quitar `obligatorio` de los tipos de documento.
9. **`src/app/api/documentos/route.ts`**: acepta `tramiteId` opcional y `legajoId` **obligatorio**.
10. **Tests** (años: **2080–2089** para trámites), reescribir para v2:
    - **`test/interacciones.test.ts`**:
      - estado del trámite y su concurrencia;
      - catálogos inactivos;
      - solicitudes `pendiente` → `recibida` (con `subirDocumento` real) → anulación → `pendiente`;
      - anular la interacción no cambia el estado.
    - **`test/documentos.test.ts`**:
      - subir al legajo sin trámite;
      - subir con un trámite y el legajo vinculado → `tramite_id` puesto;
      - con el legajo **no** vinculado → 409;
      - **concurrencia** entre subir con trámite y `desvincularLegajo` del mismo legajo → nunca queda un documento
        con un vínculo anulado al momento de cargar; usá la barrera de L09a;
      - reemplazo que hereda el trámite, también después de desvincular;
      - la solicitud de otro trámite → 409;
      - lo de L07b que sigue vigente: validación, finales, path traversal, vista o descarga auditada y headers.
    - **`test/admin.test.ts`**:
      - tipos de trámite;
      - obligatorios: definir, reemplazar y desactivar, que se ve en `faltantes` del trámite sin borrar filas;
      - el resto igual.
    - **`test/acciones.test.ts`**: las acciones nuevas (permiso, origin, campos, feliz e interno oculto).
    - `test/guard-cobertura.test.ts` cubre `tramites/acciones.ts`.
    - `test/rutas-documentos.test.ts` y `test/auth-guard.test.ts`: ajustar a v2.

## Criterios
```
cd legajos && pnpm lint && docker compose -f compose.test.yml down && docker compose -f compose.test.yml up -d --wait && pnpm test
pnpm typecheck 2>&1 | grep "error TS" | grep -v "^src/app/(app)/.*\(page\.tsx\|componentes/\)"   # vacío
```
Sin `any`, sin `console.log`, `.set` explícito. Sin commit ni push. **No toques** pantallas
(`src/app/(app)/**/page.tsx`, `componentes/`), sólo los `acciones.ts`.
