# M5 — Recuperación del admin adaptada a Docker

**Arquitecto:** claude-code · **Implementa:** CODEX sombrero B · **Audita:** arquitecto
**Rama:** `main`. **Origen:** `scripts/admin-recuperar.ts` se escribió para PM2 (§3.7 y §10.3). En producción
(§15) la app corre en Docker: el chequeo de `pm2 jlist` falla y `--sin-pm2` está prohibido en producción. El
2026-10-05 hubo que resetear la clave de `admin` a mano.

## Comportamiento nuevo
- **En el servidor** (host): `bash /srv/fiscalizacion/fiscalizacion-admin.sh recuperar <usuario> [ip]`.
  1. Toma `flock -n /var/lock/legajos-mantenimiento`. Si está tomado ("hay un backup o mantenimiento en curso"),
     sale con código 1.
  2. Ejecuta `docker compose -f /srv/fiscalizacion/compose.prod.yml exec -T app node scripts/admin-recuperar.js
     <usuario> [ip]`, con `TAG` leído de la imagen en uso. `TAG=actual` alcanza para `exec`, porque compose sólo
     necesita interpolar.
  3. Imprime la clave temporal **una vez** y nada más.
- **Dentro del contenedor**, `scripts/admin-recuperar.ts`:
  - **sin** chequeo de PM2 y **sin** `--sin-pm2`. Quitá ese flag y su código. La serialización con el backup la
    hace el lock del host;
  - la IP es **opcional**. Si viene, se normaliza como en `ip.ts` (canónica, `/32` o `/128`); si ya hay una red
    activa del usuario que la **contiene**, no se agrega otra;
  - el usuario tiene que existir y tener rol `admin`. **Si está inactivo, lo reactiva**: es un rescate. Sin IP y
    sin redes activas → error "pasá una IP: el usuario no tiene ninguna activa";
  - en **una transacción**:
    1. clave temporal (16 caracteres de `randomBytes`), con `hashear` de `clave.ts` (mismos parámetros);
    2. `debe_cambiar_clave = true`, `intentos_fallidos = 0` y `bloqueado_hasta = null`;
    3. **cierra todas** sus sesiones (`motivo_cierre = 'recuperacion'`);
    4. auditoría `login_admin` con `{ reset_clave: true, ip_agregada?, reactivado?, sesiones_cerradas }` e
       `ip = 127.0.0.1`;
  - usa `MIGRATE_DATABASE_URL` (owner), que ya está en el `.env` del contenedor.

## Alcance de archivos
1. `scripts/admin-recuperar.ts`.
2. `deploy/fiscalizacion-admin.sh` (**nuevo**): por ahora sólo con el subcomando `recuperar`. Valida
   `^[a-z0-9._-]{3,32}$` para el usuario y que la IP tenga forma de IPv4/IPv6 (la validación fuerte la hace el
   script de Node), sin `eval` y con argumentos entre comillas.
3. `scripts/deploy.sh`: copiar también `deploy/fiscalizacion-admin.sh` a `/srv/fiscalizacion/` con permisos `700`.
4. `deploy/README.md`: la sección "Recuperar el acceso del admin".
5. `test/logout-y-cli.test.ts`: adaptar los casos del CLI. Agregar:
   - recuperar sin IP con una red existente → ok;
   - una IP ya contenida en una red → no duplica;
   - un admin inactivo → se reactiva;
   - un usuario operador → error;
   - sin IP y sin redes → error;
   - la auditoría no contiene la clave ni el hash.

   Usá `LEGAJOS_LOCK` sólo si el script todavía lo necesita; si no, sacalo.

## Criterios
```
cd legajos && pnpm verificar
bash -n deploy/fiscalizacion-admin.sh && shellcheck deploy/fiscalizacion-admin.sh   # si shellcheck está instalado
```
Sin `any`, sin `console.log` (salvo el stdout de la clave en el CLI). Sin commit ni push. **No te conectes al
servidor.**
