# L05 — Servicios de legajos y cédulas

**Arquitecto:** claude-code · **Implementa:** CODEX sombrero B · **Audita:** claude-code (mutaciones) + AGY (lectura)
**Fuente:** requisitos §2.1–§2.2, diseño §2.1, §2.3 ("Relacionados", "Búsqueda"), §7 y §9.1–§9.2.
**Base:** L04 (`d303f5a`). Los contratos están en `src/server/servicios/contratos.ts`: **implementalos tal cual**. Si
uno no cierra, cambialo y explicalo en el informe.

## Alcance de archivos
1. `src/server/uuid.ts`: mové acá `uuidv7()` desde `login.ts` y que `login.ts` lo importe. Es el único cambio
   permitido en `login.ts`.
2. `src/server/servicios/contratos.ts`: **agregá** `editarLegajoEntrada` (`legajoId`, `fechaDeteccion?`,
   `observacion?`) y `editarLegajo` en `ServiciosLegajos`. Sin otros cambios.
3. `src/server/servicios/legajos.ts`: implementa `ServiciosLegajos`.
4. `src/server/servicios/cedulas.ts`: implementa `ServiciosCedulas`.
5. `src/server/servicios/mapeo.ts`: funciones puras fila → salida (`CedulaSalida`, `LegajoResumen`, …).
6. `test/legajos.test.ts` y `test/cedulas.test.ts`: **nuevos**, contra Postgres real como `legajos_app`.

## Reglas
**Toda función:**
1. `exigir(ctx, permiso)`: `legajo.ver`, `legajo.crear`, `legajo.editar`, `cedula.crear`, `cedula.editar` o
   `cedula.anular`. `marcarOriginal` usa `cedula.editar`;
2. valida la entrada con su zod;
3. abre **una** transacción;
4. hace sus `.set()` con columnas explícitas;
5. escribe la auditoría con `registrar` **en la misma transacción**, con antes y después cuando es un cambio.

Los servicios reciben `db` por un factory: `crearServiciosLegajos(db)` / `crearServiciosCedulas(db)`. No hay
variables globales.

### `crearLegajo`
1. El año sale de la fecha **actual en America/Asuncion**, con Luxon (`now` inyectable para tests).
2. El número usa el contador atómico de §2.1 (`INSERT … ON CONFLICT … RETURNING ultimo`).
3. El estado inicial es el estado **activo** de menor `orden`.
4. Inserta el legajo y **todas** las cédulas (como mínimo 1, y como máximo una original, ya validado por zod) en
   la misma transacción.
5. Audita el alta del legajo y de cada cédula.

### `verLegajo`
- Devuelve el legajo con:
  - las cédulas, incluidas las anuladas, con su marca, ordenadas: original primero, después por `creado_en`;
  - `relacionados`: los otros legajos que tienen una cédula **viva** con algún número de las cédulas **vivas**
    de este, sin repetidos;
  - `documentos: []` e `interacciones: []`, porque los llenan L06 y L07. Dejá un `TODO(L06/L07)` explícito.
- Si no existe → `ErrorValidacion` con el código `no_encontrado` (404). Agregalo a `errores.ts` como
  `ErrorNoEncontrado` si no está: es el único cambio permitido allí.

### `buscarLegajos`
Filtros combinables con AND:
- `cedula`: prefijo del número, sobre cédulas vivas;
- `nombreApellido`: `legajos.f_unaccent(nombres || ' ' || apellidos) ILIKE '%' || legajos.f_unaccent($q) || '%'`;
  escapá `%`, `_` y `\` de la entrada;
- `numero`: exacto;
- `estadoId`.

Paginado, `total` exacto, orden por `creado_en` descendente.

### `relacionadosPorCedula`
Los legajos con una cédula viva de ese número, excluyendo `excluirLegajoId`. Lo usa la UI **antes** de guardar,
para avisar (decisión §7: avisa, no bloquea).

### `agregarCedula`, `editarCedula`, `anularCedula`, `marcarOriginal`
- `agregarCedula`: si viene con `esOriginal = true` y ya hay una original viva → `ErrorConflicto`, con el código
  `original_existente`. No hay desmarcado implícito. Un número repetido en el mismo legajo **se permite**: el
  aviso lo hace la UI con `relacionadosPorCedula`.
- `editarCedula`: sólo los campos de su zod (no número ni original). No se puede editar una cédula anulada → 409.
- `anularCedula`: motivo obligatorio y sólo sobre cédulas vivas. La original anulada deja el legajo **sin
  original**. Está bien, se marca otra después.
- `marcarOriginal`, en una transacción:
  1. bloquea las cédulas vivas del legajo con `FOR UPDATE`;
  2. desmarca la original actual, si existe;
  3. marca la pedida, que tiene que estar viva.

  Audita los dos cambios.
- **Conflictos de unicidad de Postgres** (23505 en `cedula_original_unq`) → `ErrorConflicto('original_existente')`,
  nunca un 500.

### `editarLegajo`
Sólo `fecha_deteccion` y `observacion`. **No toca el estado.**

## Criterios
```
cd legajos && pnpm verificar
```
Los tests cubren:
1. **Numeración:**
   - dos legajos → `AAAA-0001` y `AAAA-0002`, con el año de Asunción. Con `now` = `2026-12-31T23:30-04:00` el año
     es 2026 aunque en UTC ya sea 2027;
   - **10 `crearLegajo` concurrentes** → correlativos 1..10 sin repetir;
   - el primero de un año nuevo empieza en 1.
2. **Crear:**
   - sin cédulas → `ErrorValidacion`;
   - con dos originales → `ErrorValidacion`;
   - estado inicial "Detectado";
   - la auditoría tiene 1 alta del legajo y N de cédulas.
3. **Relacionados:**
   - legajo A con la cédula 123 y legajo B con 123 → `verLegajo(A).relacionados` = [B];
   - si se anula la 123 de B, deja de aparecer;
   - `relacionadosPorCedula('123', excluir A)` = [B].
4. **Búsqueda:**
   - "jose" encuentra "José";
   - el prefijo de cédula funciona;
   - un `%` en la consulta no matchea todo;
   - el paginado da el total correcto.
5. **Original:**
   - `marcarOriginal` cambia la original y deja dos registros de auditoría;
   - con dos `marcarOriginal` concurrentes sobre cédulas distintas, queda exactamente una original;
   - `agregarCedula` original con una ya existente → 409.
6. **Permisos y anulación:**
   - `consulta` no puede crear ni editar (403);
   - `operador` no puede anular (403);
   - `admin` sí puede anular;
   - un motivo vacío → `ErrorValidacion`;
   - editar una anulada → 409.
7. **Inmutabilidad:** `editarLegajo` no cambia `estado_id`. Como no hay grant, cualquier intento falla.

Los `Contexto` se obtienen con `requerirSesion` y las deps inyectadas, como en `auth-guard.test.ts`. No hace
falta exportar `crearContexto`. Sin `any`, sin `console.log`. Sin commit ni push.

### Nota de despacho (2do intento)
CODEX se detuvo bien: `ErrorConflicto` tenía el código fijo. El arquitecto ya cambió `errores.ts`:
`new ErrorConflicto(codigo?, mensaje?)` y `ErrorNoEncontrado` (404). **No hace falta tocar `errores.ts`.** Usá
`ErrorNoEncontrado` en `verLegajo` en lugar de `ErrorValidacion('no_encontrado')`.
