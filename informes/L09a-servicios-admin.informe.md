# L09a — servicios de administración

**Estado:** COMPLETADO.
- CODEX sombrero B implementó en el primer intento.
- Auditó AGY: RECHAZADO por 1 hallazgo real, que se podía reactivar un usuario sin IPs activas. El arquitecto lo
  corrigió: `activarUsuario` exige al menos una IP activa, con `FOR UPDATE` sobre sus IPs, y hay un test nuevo.
- El arquitecto también volvió determinista el test de desactivación mutua de admins: usa una barrera, una
  transacción owner que retiene las filas. Antes, la mutación "admins sin FOR UPDATE" sobrevivía porque las
  transacciones no llegaban a superponerse.

Verificación: `pnpm verificar` exit 0 · 398 tests.

Mutaciones en rojo:
- admins sin FOR UPDATE → 2 de 2 corridas;
- sin protección de la última IP → 2.
