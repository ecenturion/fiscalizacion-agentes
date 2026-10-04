# L06 — interacciones

**Estado:** COMPLETADO · CODEX sombrero B en el primer intento; revisó el arquitecto.

Verificación: `pnpm verificar` exit 0 · 287 tests, 2 corridas desde base limpia.

Mutaciones en rojo:
- la solicitud cuenta como recibida aunque el documento esté anulado → 1;
- sin traducir el P0001 → 2 (incluida la concurrencia);
- se acepta un tipo inactivo → 1.
