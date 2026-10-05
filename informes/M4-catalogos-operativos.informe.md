# M4 — catálogos operativos

**Estado:** COMPLETADO y desplegado · CODEX sombrero B; revisó el arquitecto.

**Origen:** bloqueos de servidor que OPENCODE reportó en el informe de M3 y que el arquitecto no leyó antes de desplegar. En producción no se podía crear el primer trámite ni registrar la primera interacción.

Verificación: `pnpm verificar` exit 0 · 506 tests, 2 corridas. Mutación: catálogos con inactivos → 1 test en rojo.

**Lección:** leer completa la sección de bloqueos del informe del implementador antes de cerrar una tarea.
