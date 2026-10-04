# L04 — login

**Estado:** COMPLETADO · CODEX sombrero B implementó; revisó el arquitecto.

Correcciones del arquitecto, porque el build fallaba:
- `config.ts` pasa a `leerConfig()` perezosa: `next build` la evaluaba al importar, sin el entorno.
- Un solo pool `dbApp()` en lugar de un `conectar()` a nivel módulo en cada ruta.
- `src/app/(app)/layout.tsx` con `dynamic = "force-dynamic"`, sin lógica de seguridad: el guard sigue en cada página.
- Los tests de config, adaptados.

Verificación: `pnpm verificar` exit 0 · 244 tests · build con `/cuenta/clave`, `/legajos` y `/logout` dinámicas.

Mutaciones en rojo:
- sin hash señuelo → test de tiempo;
- sin devolución de la reserva → 3;
- límite por IP a 200 → 2 (incluido el de concurrencia).

Pendiente menor: `uuidv7()` vive en `login.ts`; se moverá a `src/server/uuid.ts` en L05.
