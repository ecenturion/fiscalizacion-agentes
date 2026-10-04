# L02b — grants, triggers y catálogos

**Estado:** COMPLETADO · CODEX sombrero B implementó; auditó el arquitecto con mutaciones (AGY no, por sus cortes de allowlist).

Ajustes del arquitecto en `test/schema.test.ts` (L02a), ambos informados por CODEX como fuera de su alcance: el fixture de catálogos ya no usa "Nota" (choca con la siembra) y los UPDATE de anulación filtran por `legajo_id` (antes tocaban filas de otros archivos de test en la base compartida).

Verificación: `pnpm verificar` exit 0 · 106 tests (permisos 29, triggers 21), dos corridas desde base limpia; `db:generate` sin cambios.

Mutaciones en rojo: estado sin `FOR UPDATE` → test de concurrencia; `GRANT UPDATE (estado_id)` → 2 de permisos; versión sin chequeo de tipo → 1; solicitud sin chequeo de tipo → 2.
