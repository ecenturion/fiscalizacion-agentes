# M5 — recuperación del admin en Docker

**Estado:** COMPLETADO y desplegado · CODEX sombrero B; revisó el arquitecto.

Verificación: `pnpm verificar` exit 0 · 517 tests (23 de logout/CLI).

En producción, sin resetear al admin real:
- `fiscalizacion-admin.sh` quedó instalado con permisos 700;
- un usuario inexistente → "El usuario debe existir y ser admin.";
- el usuario `a;b` → "Usuario no válido.";
- sin argumentos → mensaje de uso.
