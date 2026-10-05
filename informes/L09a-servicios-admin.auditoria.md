# Auditoría — L09a-servicios-admin

**Veredicto:** RECHAZADO
**Auditor:** codex
**Diff auditado:** 4 archivos creados o modificados.

## Hallazgos

### 🔴 Críticos
- **src/server/servicios/admin.ts:187** — Elusión de la protección de última IP. La función `activarUsuario` no verifica que el usuario tenga al menos una IP activa al reactivarlo. Un administrador puede desactivar a un usuario, luego desactivar su última IP (lo cual está permitido por la lógica actual si el usuario ya está inactivo), y finalmente volver a activarlo. Esto deja al sistema con un usuario activo sin ninguna IP, eludiendo la restricción estructural de la base de datos y la regla de negocio.

### 🟢 Verificado
- Todas las 16 funciones verifican permisos correctamente con `exigir()`.
- Ningún `hash` o `claveTemporal` se filtra hacia la auditoría o hacia la salida de los servicios (se garantiza mediante la proyección `usuarioSeguro`).
- La protección contra la desactivación del último administrador o cambio de rol funciona bajo concurrencia mediante los bloqueos `FOR UPDATE` implementados en `bloquearAdmins`.
- Los cierres de sesión están garantizados y operan sobre las filas correctas durante `activarUsuario` y `resetearClave`.
- La lógica de normalización de redes y CIDR (IPv4 e IPv6) no presenta fallos, gestionando correctamente bits de host y formatos IPv4-mapped.
- Todas las sentencias `update().set()` utilizan propiedades explícitas y evitan la mutación mediante spreads de filas completas.
- Los catálogos mantienen su integridad histórica al no emplearse comandos `DELETE` (sólo se manipula la propiedad `activo`).

## Comandos que corrí

```bash
cd legajos && git status -u
cd legajos && git diff --stat
cd legajos && git diff
```
