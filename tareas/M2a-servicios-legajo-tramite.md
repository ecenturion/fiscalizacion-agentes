# M2a — Servicios v2: contratos, permisos, legajos y trámites

**Arquitecto:** claude-code · **Implementa:** CODEX sombrero B · **Audita:** AGY (lectura) + arquitecto (mutaciones)
**Rama:** `modelo-v2` (cd legajos && git branch --show-current → `modelo-v2`). Base: M1 (`0df1984`).
**Fuente:** requisitos §7, diseño §16 (§16.4 manda) y lo vigente de §3 (guard, permisos) y §9.7 (`.set` explícito).

**Al terminar esta tarea, `typecheck` puede seguir fallando** en interacciones, documentos, admin, acciones y UI:
son de M2b y M3. Lo que entra en esta tarea tiene que compilar, y sus tests pasar.

## Alcance de archivos
1. **`src/server/permisos.ts`**: agregá a la unión y a la matriz:
   - `tramite.ver`, `tramite.crear`, `tramite.editar`, `tramite.vincular` → admin, operador (`ver` también
     consulta);
   - `tramite.desvincular` → sólo admin;
   - `legajo.corregir_cedula` → sólo admin.

   Quitá `cedula.*`: la cédula ya no es una entidad aparte. Actualizá `test/permisos.unit.test.ts`.
2. **`src/server/cedula.ts`** (**nuevo**): `normalizarCedula(texto)`:
   - saca puntos, espacios y guiones de formato;
   - exige sólo dígitos;
   - quita los ceros a la izquierda;
   - todo ceros o vacío → `ErrorValidacion`.

   Ejemplos: `0001.234.567` → `1234567`; `000` → error; `12a` → error.
3. **`src/server/servicios/contratos.ts`**: reescribí para v2. Quitá lo de cédula como entidad, `crearLegajo` del
   caso, etc. Mantené documentos, interacciones y admin compilables **si podés**; si no, dejalos para M2b.
   - **Legajos:**
     - `buscarLegajos({ cedula?, nombreApellido?, pagina, porPagina })`;
     - `verLegajo({ legajoId })` → `{ datos, documentos[], tramites[] (número, tipo, estado, esOriginal|null, vinculoAnulado), relacionados[] }`;
     - `obtenerOCrearLegajo({ cedula, nombres, apellidos, fechaNacimiento?, fechaEmision?, observacion? })` →
       `{ legajo, creado: boolean }`;
     - `editarLegajo({ legajoId, nombres?, apellidos?, fechaNacimiento?, fechaEmision?, observacion? })`;
     - `corregirCedula({ legajoId, nueva, motivo })`;
     - `buscarPorCedula({ cedula })` → `LegajoResumen | null`, para el aviso en el alta.
   - **Trámites:**
     - `crearTramite({ tipoId, fechaDeteccion, observacion?, legajos: ({ legajoId } | { nuevo: datosLegajo })[] min 1, originalIndice? })`;
     - `verTramite({ tramiteId })` → `{ datos, estado, tipo, vinculos[] (legajo resumen, esOriginal, anulado…), interacciones: [] (TODO M2b), solicitudes: [] (TODO M2b), faltantes[] }`;
     - `buscarTramites({ numero?, tipoId?, estadoId?, cedula?, pagina, porPagina })`;
     - `editarTramite({ tramiteId, fechaDeteccion?, observacion? })`;
     - `vincularLegajo({ tramiteId, legajoId | nuevo })`;
     - `desvincularLegajo({ tramiteId, vinculoId, motivo })`;
     - `marcarOriginal({ tramiteId, vinculoId | null })`, donde `null` = "sin determinar";
     - `faltantes({ tramiteId })`.
4. **`src/server/servicios/legajos.ts`**: reescribí con las reglas de §16.2 y §16.4.
   - `obtenerOCrearLegajo`: normaliza → `INSERT … ON CONFLICT (cedula) DO NOTHING RETURNING` → si no devolvió
     nada, `SELECT` del existente con `creado: false`. Si existe, **no** sobrescribe sus datos.
   - `corregirCedula`: llama `legajos.corregir_cedula(...)` con un `uuidv7()` para `p_auditoria_id`, el usuario,
     el motivo y la IP del `ctx`. El 23505 se traduce a `ErrorConflicto('cedula_existente')` y el 42501 a
     `ErrorPermiso`.
   - Búsqueda con normalización y prefijo; nombre con `f_unaccent` y el escape de §L05.
   - `relacionados`: los legajos que comparten un trámite con vínculos vivos de los dos lados.
5. **`src/server/servicios/tramites.ts`** (**nuevo**), con las reglas de §16.2 y §16.4:
   - **candado del trámite** (§16.4.1) en vincular, desvincular y marcar original: primero `FOR UPDATE` del
     trámite;
   - `crearTramite`:
     1. contador atómico por año de Asunción;
     2. tipo **activo** y estado inicial;
     3. cada legajo: existente (tiene que existir) o creado con `obtenerOCrearLegajo` dentro de la **misma
        transacción**;
     4. vínculos (nunca dos vivos del mismo legajo: si viene repetido → `ErrorValidacion`);
     5. original opcional;
     6. auditoría de todo;
   - `desvincularLegajo`, en una sola transacción:
     - nunca deja cero vínculos vivos → `ErrorConflicto('ultimo_vinculo')`;
     - pone en `documento_recibido_id = null` las solicitudes de **ese trámite** satisfechas por documentos de
       **ese legajo**;
     - si era la original, queda "sin determinar";
     - auditoría de todo, con motivo;
   - `faltantes`: los `tipo_tramite_documento` activos del tipo del trámite sin un documento **vivo** de ese tipo
     en **algún legajo vinculado vivo** (cualquier procedencia; un vencido cuenta);
   - todas las funciones: `exigir`, zod, una transacción, auditoría en la misma y `.set` explícito.
6. **`src/server/servicios/mapeo.ts`**: los mapeos nuevos.
7. **Tests** (años: **2090–2094** para trámites), con Postgres real como `legajos_app`:
   - **`test/legajos.test.ts`** (reescribir):
     - normalización (`0001234567` ↔ `1234567`, el mismo legajo);
     - **alta concurrente** del mismo número → un solo legajo, uno `creado:true` y el otro `false`;
     - búsqueda por prefijo y sin acentos;
     - `corregirCedula`: admin ok con auditoría; operador 403; choque 409;
     - `editarLegajo` audita;
     - relacionados.
   - **`test/tramites.test.ts`** (**nuevo**, reemplaza `test/cedulas.test.ts`, que se borra):
     - numeración y año de Asunción (UTC−3);
     - 10 `crearTramite` concurrentes → correlativos 1..10;
     - crear con un legajo existente más uno nuevo, donde el nuevo usa un número ya existente → reutiliza;
     - tipo inactivo → 422;
     - original única con concurrencia sobre dos vínculos;
     - `marcarOriginal(null)`;
     - desvincular el último → 409;
     - desvincular con una solicitud satisfecha → vuelve a pendiente (sembrala como owner hasta que M2b tenga
       servicios);
     - **dos desvinculaciones concurrentes** sobre un trámite con 2 vínculos → queda 1;
     - faltantes: con un obligatorio y un documento del tipo en el legajo, de cualquier trámite y vencido → no
       falta; anulado → falta; legajo desvinculado → falta;
     - permisos: consulta ve pero no crea; operador no desvincula.

## Criterios
```
cd legajos && pnpm lint && docker compose -f compose.test.yml down && docker compose -f compose.test.yml up -d --wait \
  && pnpm vitest run test/legajos.test.ts test/tramites.test.ts test/permisos.unit.test.ts test/schema.test.ts test/triggers.test.ts test/permisos.test.ts
```
Sin `any`, sin `console.log`. Sin commit ni push. No toques `src/app/**`.
