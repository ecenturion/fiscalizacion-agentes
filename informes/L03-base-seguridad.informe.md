# L03 — base de seguridad

**Estado:** COMPLETADO · CODEX sombrero B implementó; revisó el arquitecto.

Correcciones del arquitecto:
- `ip.ts` sólo acepta formas canónicas: `ipaddr.isValid` aceptaba `127.1`, `0x7f.0.0.1` y octales (`010.0.0.1` → 8.0.0.1). Hay 4 tests nuevos.
- Regla de eslint: sólo `auth.ts` puede importar `crearContexto`. Probada con un archivo temporal.

Verificación: `pnpm verificar` exit 0 · 218 tests (guard 40 contra Postgres real como `legajos_app`).

Mutaciones en rojo:
- sin vencimiento absoluto de 12 h → 2;
- sin CSRF → 4;
- no cerrar la sesión por IP → 4.
