# L03 — Base compartida: Contexto, permisos, IP, CSRF, auditoría y contratos

**Arquitecto:** claude-code · **Implementa:** CODEX sombrero B · **Audita:** claude-code (mutaciones)
**Fuente:** `docs/diseno.md` §3.1, §3.2, §3.5, §9.8–§9.10 y §9.19. La sección más alta manda.
**Base:** L02b (`a855d7d`).

## Alcance de archivos

### `src/server/` (nuevos)
1. **`ip.ts`**:
   - `ipDeHeaders(h: Headers): string | null` lee **sólo** `x-real-ip` y lo normaliza con `ipaddr.process`
     (IPv4-mapped → IPv4). Si falta o es inválido → `null`.
   - `ipPermitida(ip: string, redes: readonly string[]): boolean` usa `ipaddr.parseCIDR` + `match`, con familias
     compatibles (una IPv4 contra una red IPv6 → false). **Nunca compara texto.**
   - Nada de `x-forwarded-for`.
2. **`permisos.ts`**:
   - `type Permiso`, una unión literal: `legajo.ver`, `legajo.crear`, `legajo.editar`, `cedula.crear`,
     `cedula.editar`, `cedula.anular`, `documento.ver`, `documento.subir`, `documento.anular`,
     `interaccion.crear`, `interaccion.anular`, `admin.usuarios`, `admin.catalogos`, `admin.accesos`,
     `cuenta.cambiar_clave`.
   - `MATRIZ: Record<Rol, ReadonlySet<Permiso>>`:
     - **admin:** todos;
     - **operador:** todos menos `*.anular` y `admin.*`;
     - **consulta:** `legajo.ver`, `documento.ver` y `cuenta.cambiar_clave`.
   - `puede(rol, permiso): boolean`.
3. **`contexto.ts`**:
   - el tipo `Contexto` es **branded** (`unique symbol`), con `{ usuarioId, usuario, rol, ip, sesionId,
     debeCambiarClave }`;
   - `crearContexto(...)`, exportada **sólo** para `auth.ts`: el tipo marcado impide armarlo a mano;
   - `exigir(ctx, permiso)` lanza `ErrorPermiso` → 403.
4. **`errores.ts`**: `ErrorNoAutenticado` (401), `ErrorPermiso` (403), `ErrorOrigen` (403), `ErrorConflicto` (409),
   `ErrorValidacion` (422) y `ErrorMantenimiento` (503), con `status` y un `codigo` estable.
5. **`csrf.ts`**: `verificarOrigen(h: Headers, appOrigin: string): void`. Exige `origin` **exactamente igual** a
   `appOrigin`. Si falta o es `null` → `ErrorOrigen`.
6. **`auth.ts`**: `requerirSesion({ permiso, mutacion }, deps?)`, que hace en orden:
   1. lee la cookie `legajos_sesion`;
   2. calcula el SHA-256 del token;
   3. valida la sesión con el **UPDATE atómico de §9.9** y su `RETURNING`;
   4. carga el usuario: activo y no bloqueado;
   5. la IP sale de `ipDeHeaders`. Si es `null` → registra `ip_invalida` y lanza 401. Si no está en
      `usuario_ip` activa → **cierra la sesión** (`motivo_cierre = 'ip'`), registra `sesion_ip_rechazada` y lanza
      401;
   6. si `debe_cambiar_clave`, sólo admite `cuenta.cambiar_clave` (si no, `ErrorPermiso` con el código
      `debe_cambiar_clave`);
   7. comprueba el permiso;
   8. si es una mutación, `verificarOrigen`.

   Sin sesión válida → `ErrorNoAutenticado`. Una falta de permiso **no** cierra la sesión (§9.8). Todo
   `UPDATE … set({...})` con columnas explícitas.

   Las dependencias (`cookies`, `headers`, `db`, `appOrigin`, `ahora`) se inyectan para testear. Por defecto usa
   `next/headers` y la configuración.
7. **`auditoria.ts`**: `registrar(tx, ctx, { entidad, entidadId, accion, antes?, despues? })` inserta en
   `auditoria` dentro de la transacción recibida, con `ctx.ip` y `ctx.usuarioId`. `registrarAcceso(db,
   { usuarioId?, usuarioIntentado, ip, resultado, ruta })` inserta en `acceso_log`.
8. **`config.ts`**: lee y valida con zod `DATABASE_URL`, `APP_ORIGIN`, `ARCHIVOS_DIR` y `TRUST_PROXY`, que tiene
   que ser `'1'` en producción; si no, falla al arrancar.
9. **`servicios/contratos.ts`**: **sólo tipos**, las entradas y salidas de L05, L06 y L07. Todas las funciones
   reciben `(ctx: Contexto, ...)`:
   - legajos: `crearLegajo`, `buscarLegajos`, `verLegajo`, `relacionadosPorCedula`;
   - cédulas: `agregarCedula`, `editarCedula`, `anularCedula`, `marcarOriginal`;
   - interacciones: `registrarInteraccion` (tipo, nota, cambio de estado opcional, tipos solicitados),
     `anularInteraccion`;
   - documentos: `subirDocumento`, `reemplazarDocumento`, `anularDocumento`, `verArchivo` y `faltantes`.

   Con zod para las entradas y TS para las salidas.

### `deploy/` y tests
10. **`deploy/nginx.conf.example`**, borrador de §3.1 y §9.13:
    - `listen 443 ssl`;
    - `proxy_pass http://127.0.0.1:3000`;
    - `proxy_set_header X-Real-IP $remote_addr`;
    - `proxy_set_header X-Forwarded-For ""`;
    - `proxy_set_header Host $host`;
    - `location /api/documentos` con `proxy_request_buffering off` y `client_max_body_size 205m`;
    - el resto con `client_max_body_size 1m`.
11. **`test/ip.test.ts`**:
    - IPv4 en una /24;
    - IPv4-mapped (`::ffff:192.168.1.5`) contra `192.168.1.0/24` → true;
    - una IPv6 en /64;
    - `192.168.1.50` contra `192.168.1.5/32` → false (no hay prefijo de texto);
    - un header con `x-forwarded-for` y sin `x-real-ip` → null;
    - IPs inválidas y vacías → null.
12. **`test/auth-guard.test.ts`**, contra la base real como `legajos_app` (siembra como owner), con deps
    inyectadas. Cubre:
    - sin cookie → 401;
    - token desconocido → 401;
    - sesión vencida por inactividad (8 h) y por edad absoluta (12 h) → 401;
    - usuario inactivo → 401;
    - IP fuera de la lista → 401, la sesión queda **cerrada** y hay una fila `sesion_ip_rechazada` en `acceso_log`;
    - `x-real-ip` ausente → 401 + `ip_invalida`;
    - usuario sin ninguna IP → 401;
    - rol `consulta` pidiendo `cedula.crear` → 403 y la sesión **sigue viva**;
    - `debe_cambiar_clave` → sólo `cuenta.cambiar_clave` pasa;
    - mutación con `origin` ajeno o ausente → 403;
    - caso feliz → un `Contexto` con los datos correctos y `ultimo_uso` actualizado.
13. **`test/permisos.unit.test.ts`**: la matriz completa, rol por permiso, contra una tabla escrita en el test.

### Dependencias
`ipaddr.js` (versión exacta 2.5.0). Ya están `zod` y `postgres`.

## Criterios
```
cd legajos && pnpm verificar
```
Sin `any`, sin `console.log`, todo `.set()` con columnas explícitas. Sin commit ni push.
