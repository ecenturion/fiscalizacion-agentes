# P1 — padrón y consulta de cédula

**Estado:** COMPLETADO · CODEX sombrero B. Quedó bloqueado sólo por un test de M1 fuera de su alcance (contaba 4
migraciones fijas); el arquitecto lo corrigió para que cuente las del journal.

Correcciones del arquitecto al revisar:
- **Bug que habría roto la copia en producción:** el origen real usa `apellido` (singular) en `personas` y
  `cedulas_dupl`; el script y el fixture del test usaban `apellidos`. Ahora el script separa las expresiones del
  `SELECT` de origen de las columnas de destino, y el fixture usa los nombres reales (verificados contra
  `information_schema` del servidor).
- `cedula_norm` del padrón se calcula en el origen: evita un `UPDATE` de 8,7 M filas.

Verificación: `pnpm verificar` exit 0 · 538 tests (18 del padrón).

Mutación: sin re-`GRANT` después del swap → 3 tests en rojo.
