# M2b — servicios restantes y acciones

**Estado:** COMPLETADO (rama `modelo-v2`) · CODEX sombrero B en el primer intento; revisó el arquitecto.

Verificación: `pnpm test` → 498 tests, 2 corridas. `typecheck` sólo falla en las pantallas, que son de M3.

Mutaciones en rojo:
- subir sin el candado del trámite → 2, incluida la barrera contra desvincular;
- sin el chequeo de vínculo en el servicio → 2.
