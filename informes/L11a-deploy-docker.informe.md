# L11a — deploy con Docker

**Estado:** COMPLETADO · CODEX sombrero B en el primer intento; revisó el arquitecto.

Verificación:
- `pnpm verificar` exit 0 · 434 tests;
- no quedan enlaces crudos sin `conBase`;
- `docker build` ok (821 MB);
- en la imagen: qpdf 11.3.0, vips 8.14.1, util-linux 2.38.1, uid 10001;
- `validar-imagen.sh`: 3 válidos y 7 rechazados bajo `prlimit --as=512MiB` (§13 cumplido en la imagen real).
