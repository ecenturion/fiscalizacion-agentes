# L04 — Login, bloqueos, cambio de clave, logout y recuperación del admin

**Arquitecto:** claude-code · **Implementa:** CODEX sombrero B · **Audita:** claude-code (mutaciones)
**Fuente:** `docs/diseno.md` §3.3, §3.4, §3.7, §9.8–§9.12, §10.3–§10.4 y §11.2. La sección más alta manda.
**Base:** L03 (`8376871`): `auth.ts` (guard), `ip.ts`, `auditoria.ts`, `csrf.ts`, `errores.ts` y `config.ts`.

## Alcance de archivos

### Servicios (`src/server/`)
1. **`clave.ts`**:
   - `hashear(clave)` y `verificar(hash, clave)` con `@node-rs/argon2` (argon2id, parámetros fijos y documentados);
   - `HASH_SENUELO`, generado **una vez** por proceso con los mismos parámetros (§9.12);
   - `validarNuevaClave(clave)`: 10 caracteres como mínimo y, como máximo, 256.
2. **`login.ts`**, servicio sin Next:
   - `iniciarSesion(db, { usuario, clave, ip, ahora? })` → `{ ok: true, token, debeCambiarClave } | { ok: false }`;
   - el orden es **exactamente** el de §9.11, §9.12 y §10.4:
     1. si la IP es `null` → registra `ip_invalida` y devuelve `{ ok: false }`;
     2. **reserva por IP**: un `INSERT … ON CONFLICT DO UPDATE` atómico sobre `limite_ip` que reinicia la ventana
        si venció (15 min) y si no suma 1. Devuelve `intentos` y `ventana_inicio`. Con más de 20 → registra
        `limite_ip` y `{ ok: false }`, **sin verificar**;
     3. busca el usuario (`lower(usuario)`);
     4. **siempre** corre argon2: contra el hash real o contra `HASH_SENUELO`;
     5. evalúa, en este orden, y cada caso registra su resultado y devuelve `{ ok: false }`:
        - inexistente → `usuario_inexistente`;
        - inactivo → `inactivo`;
        - `bloqueado_hasta > now()` → `bloqueado`;
        - IP fuera de su lista → `ip_rechazada`;
        - clave incorrecta → `clave_incorrecta`. Antes hace el `UPDATE` atómico del contador de cuenta de §9.11:
          si el bloqueo venció, reinicia y suma, y a los 5 bloquea 15 min;
     6. si todo da bien:
        - pone `intentos_fallidos = 0` y `bloqueado_hasta = null` con `WHERE bloqueado_hasta IS NULL OR
          bloqueado_hasta < now()`;
        - **devuelve la reserva** con `UPDATE limite_ip SET intentos = intentos - 1 WHERE ip = $1 AND
          ventana_inicio = $reservada AND intentos > 0` (§11.2);
        - crea la sesión con un token de 32 bytes `randomBytes` en base64url, `token_hash` SHA-256 y la IP;
        - registra `ok`.
   - `cambiarClave(db, ctx, { actual, nueva })`:
     - verifica `actual` y valida `nueva`;
     - actualiza `hash` y `debe_cambiar_clave = false`;
     - **cierra todas las sesiones** del usuario (`motivo_cierre = 'cambio_clave'`);
     - crea y devuelve una sesión nueva;
     - audita con `accion 'cambio'`, `entidad 'usuario'` y **sin el hash** en antes ni después.
   - `cerrarSesion(db, ctx)` cierra la sesión actual (`motivo_cierre = 'logout'`).
3. **`cookie.ts`**: `opcionesCookie()` → `httpOnly`, `sameSite: 'lax'`, `path: '/'` y `secure` si
   `APP_ORIGIN` es https, **obligatorio en producción** (falla si no). Nombre: `legajos_sesion`.

### Rutas (Next)
4. **`src/app/(auth)/login/acciones.ts`**, Server Action `entrar(formData)`:
   - `verificarOrigen` sobre `headers()`;
   - IP con `ipDeHeaders`;
   - `iniciarSesion`, cookie y `redirect('/legajos')`, o `redirect('/cuenta/clave')` si `debeCambiarClave`;
   - si falla, devuelve `{ error: 'Usuario o contraseña incorrectos.' }`, **siempre el mismo texto**.
5. **`src/app/(auth)/login/page.tsx`**: un formulario mínimo (usuario, contraseña, botón) que usa `entrar`. Sin
   estilos: la UI la hace L08.
6. **`src/app/(app)/cuenta/clave/acciones.ts` y `page.tsx`**: formulario mínimo. Primero `requerirSesion({
   permiso: 'cuenta.cambiar_clave', mutacion: true })`, después `cambiarClave`, se reemplaza la cookie y
   `redirect('/legajos')`.
7. **`src/app/logout/route.ts`**: **sólo `POST`**. Pasos:
   1. `verificarOrigen`;
   2. si hay sesión válida, `cerrarSesion`. Si no, sigue igual;
   3. borra la cookie;
   4. `303` a `/login`.

   `GET` → 405.
8. **`src/app/(app)/legajos/page.tsx`**: un placeholder que llama `requerirSesion({ permiso: 'legajo.ver',
   mutacion: false })`. Si recibe `ErrorNoAutenticado`, hace `redirect('/login')`. Muestra "Legajos — usuario X".
   La UI real es de L08.
9. **`src/middleware.ts`**: si no está la cookie `legajos_sesion` y la ruta no es `/login`, `/_next/*` ni
   `/favicon.ico`, redirige a `/login`. **No valida nada más** (§9.17).

### CLI y tests
10. **`scripts/admin-recuperar.ts`**: `pnpm admin:recuperar <usuario> <ip>`, con `MIGRATE_DATABASE_URL` (owner).
    Pasos:
    1. `flock` en `/var/lock/legajos-mantenimiento` o en `LEGAJOS_LOCK` (para tests);
    2. se niega a correr si `pm2 jlist` muestra `legajos` online, salvo con `--sin-pm2`, que existe sólo para
       desarrollo y tests;
    3. genera una clave temporal de 16 caracteres, hashea y pone `debe_cambiar_clave`;
    4. agrega la IP (`/32` o `/128`) a `usuario_ip`;
    5. cierra todas las sesiones;
    6. audita `login_admin`;
    7. imprime la clave **una sola vez** por stdout.

    El usuario tiene que existir y ser admin. Script en `package.json`.
11. **`test/login.test.ts`**, contra Postgres real como `legajos_app`:
    - feliz: devuelve un token, hay una sesión creada y un `ok` en el log, y el contador de cuenta queda en 0;
    - clave incorrecta ×5 → la 5ª bloquea, la 6ª con la clave **correcta** → `bloqueado`. Con `ahora` a +16 min
      → entra, y antes el contador se reinició;
    - usuario inexistente → `usuario_inexistente`. **Tiempo:** la mediana de 5 corridas de inexistente contra
      clave incorrecta de un existente difiere en menos del 30%;
    - IP fuera de la lista con la clave correcta → `ip_rechazada` y **no** crea sesión;
    - límite por IP: 20 fallos → el 21º devuelve `limite_ip` sin tocar `usuario.intentos_fallidos`. Un login
      correcto devuelve la reserva (`intentos` baja en 1). Con la ventana vencida, se reinicia;
    - **concurrencia:** 25 logins fallidos en paralelo desde la misma IP → como máximo 20 verifican (los demás
      son `limite_ip`);
    - `cambiarClave`: cierra las otras sesiones, la nueva funciona, la vieja da 401 en el guard, la auditoría no
      contiene el hash y una clave nueva de 9 caracteres → `ErrorValidacion`.
12. **`test/logout-y-cli.test.ts`**:
    - el route handler de logout con POST y origin correcto → la sesión queda cerrada y la cookie vencida; GET →
      405; origin ajeno → 403;
    - CLI con `--sin-pm2` y `LEGAJOS_LOCK` temporal → la salida tiene la clave; hay `debe_cambiar_clave`, la IP
      agregada, las sesiones cerradas y la auditoría `login_admin`. Con un usuario que no es admin → sale con
      código distinto de 0.

### Dependencias
`@node-rs/argon2@2.2.1`, versión exacta.

## Criterios
```
cd legajos && pnpm verificar
```
Sin `any`, sin `console.log` (salvo el stdout del CLI), `.set()` con columnas explícitas. Nunca se loguean ni
auditan contraseñas, hashes ni tokens. Sin commit ni push.
