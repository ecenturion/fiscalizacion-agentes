# Informe — L04-login

**Estado:** COMPLETADO
**Implementador:** codex — sombrero B
**Verificación:** `cd legajos && pnpm verificar` — código de salida 0.
**Resultado:** lint, typecheck, 244 tests en 9 archivos y build completos.

## Archivos creados

Rutas relativas a `legajos/`:

- `src/server/clave.ts`
- `src/server/login.ts`
- `src/server/cookie.ts`
- `src/app/(auth)/login/acciones.ts`
- `src/app/(auth)/login/page.tsx`
- `src/app/(app)/cuenta/clave/acciones.ts`
- `src/app/(app)/cuenta/clave/page.tsx`
- `src/app/(app)/legajos/page.tsx`
- `src/app/logout/route.ts`
- `src/middleware.ts`
- `scripts/admin-recuperar.ts`
- `test/login.test.ts`
- `test/logout-y-cli.test.ts`

## Archivos modificados

- `package.json`: dependencia exacta `@node-rs/argon2@2.2.1` y comando `admin:recuperar`.
- `pnpm-lock.yaml`: resolución de la dependencia solicitada y sus binarios opcionales. pnpm también normalizó referencias de peers existentes de ESLint, sin cambiar sus versiones.

## Implementación y decisiones

- Argon2id v19 con 64 MiB, tres iteraciones, un hilo y salida de 32 bytes. El señuelo se genera una vez al cargar el módulo. La validación de nueva clave cuenta caracteres Unicode y admite de 10 a 256.
- Login sin Next, con reserva por IP mediante UPSERT, verificación Argon2 antes de evaluar usuario/inactividad/bloqueo/IP/clave, contador de cuenta atómico, tokens de 32 bytes y almacenamiento exclusivo de SHA-256.
- La reserva, los cambios de cuenta, la sesión y el log se confirman en la misma transacción. La fila del usuario se bloquea para serializar login y cambio de clave y evitar emitir una sesión con una contraseña reemplazada.
- La ventana reservada se devuelve como texto de timestamp y se compara mediante cast a timestamptz: conserva los microsegundos de Postgres. La primera corrida detectó que usar Date impedía devolver algunas reservas creadas con now(); quedó corregido y cubierto por el login feliz con reloj real.
- Cambio de clave cierra todas las sesiones abiertas, emite una nueva y audita sólo el indicador debe_cambiar_clave. Logout cierra la sesión y registra su cambio dentro de la misma transacción.
- Las Actions usan guard/Origin según la spec. La página GET de cambio de clave usa mutacion:false porque sólo presenta el formulario; la Action exige mutacion:true antes de cambiar la clave. Logout usa cuenta.cambiar_clave para admitir también el cambio obligatorio, sin modificar el guard L03.
- Cookie HttpOnly, SameSite=Lax, Path=/ y Secure para HTTPS; rechaza HTTP en producción. Middleware comprueba únicamente la presencia de la cookie.
- CLI con flock no bloqueante sobre descriptor compartido, retenido por el proceso padre hasta cerrar el descriptor. Comprueba pm2 jlist bajo el lock; --sin-pm2 se rechaza en producción. Valida administrador e IP, genera clave temporal de 16 caracteres, agrega /32 o /128, cierra sesiones, reinicia el bloqueo de cuenta y audita login_admin en una transacción. La clave sólo se imprime después del commit y una sola vez.
- Los servicios y el guard en tests usan Postgres real autenticado como legajos_app; owner se usa para fixtures y para el CLI. Los tests de logout sustituyen sólo headers/cookies de Next. Los espías de Argon2 ejecutan la implementación real. pm2 se simula con un ejecutable temporal dentro de node_modules para probar online/stopped sin tocar procesos de la aplicación.
- Se agregaron 26 tests: login/bloqueos/límite/concurrencia/medianas, cambio de clave, logout, recuperación, lock ocupado, restricciones de pm2, IPv4-mapped/IPv6 y cookie de producción.

## Entorno y limitaciones

- El Postgres local de compose.test.yml ya estaba activo y saludable; no se desplegó ni se modificaron servidores.
- pnpm inicialmente falló con `[ERROR] unable to open database file` al intentar usar su store habitual. Se configuraron store y caché dentro de `legajos/node_modules`, mediante variables de entorno para esta corrida, sin modificar configuración del proyecto.
- La verificación usó configuración sintética local, sin leer ni exponer archivos .env. Next emitió una advertencia por detectar otro lockfile en /home/ecenturion; no se modificaron ese archivo ni next.config.ts, que quedan fuera del alcance.
- No quedó trabajo funcional pendiente de la spec. No se ejecutó auditoría del código propio, commit, push ni movimiento de la tarea a done.

## Comando de verificación y salida real

Ejecutado desde `/home/ecenturion/develop/legajos`:

```sh
export pnpm_config_cache_dir=/home/ecenturion/develop/legajos/node_modules/.cache/pnpm
export pnpm_config_store_dir=/home/ecenturion/develop/legajos/node_modules/.pnpm-store
export DATABASE_URL=postgres://legajos_app@localhost:55433/legajos_test
export APP_ORIGIN=https://legajos.test
export ARCHIVOS_DIR=/home/ecenturion/develop/legajos/archivos-test
export TRUST_PROXY=1
pnpm verificar
```

Código de salida: **0**.

```text
$ pnpm lint && pnpm typecheck && pnpm test && pnpm build
$ eslint .
$ tsc --noEmit
$ vitest run

 RUN  v3.2.7 /home/ecenturion/develop/legajos

{
  severity_local: 'NOTICE',
  severity: 'NOTICE',
  code: '42P06',
  message: 'schema "legajos" already exists, skipping',
  file: 'schemacmds.c',
  line: '132',
  routine: 'CreateSchemaCommand'
}
$ tsx src/server/db/migrar.ts
Aplicando migraciones...
{
  severity_local: 'NOTICE',
  severity: 'NOTICE',
  code: '42P06',
  message: 'schema "drizzle" already exists, skipping',
  file: 'schemacmds.c',
  line: '132',
  routine: 'CreateSchemaCommand'
}
{
  severity_local: 'NOTICE',
  severity: 'NOTICE',
  code: '42P07',
  message: 'relation "__drizzle_migrations" already exists, skipping',
  file: 'parse_utilcmd.c',
  line: '207',
  routine: 'transformCreateStmt'
}
Migraciones aplicadas
 ✓ test/auth-guard.test.ts (40 tests) 149ms
 ✓ test/login.test.ts (14 tests) 3631ms
   ✓ Login y cambio de clave con Postgres real como legajos_app > cinco fallos bloquean; la clave correcta no pasa hasta +16 minutos  370ms
   ✓ Login y cambio de clave con Postgres real como legajos_app > inexistente usa señuelo, con mediana de cinco muestras a menos del 30%  454ms
   ✓ Login y cambio de clave con Postgres real como legajos_app > 20 fallos por IP, el 21 no verifica ni modifica cuenta; ventana vencida reinicia  933ms
   ✓ Login y cambio de clave con Postgres real como legajos_app > 25 concurrentes desde una IP: sólo 20 verifican argon2  889ms
 ✓ test/logout-y-cli.test.ts (12 tests) 2574ms
   ✓ Logout y recuperación administrativa > CLI imprime una clave de 16 caracteres una vez, agrega IPv6 y cierra todas las sesiones  450ms
   ✓ Logout y recuperación administrativa > CLI normaliza IPv4-mapped y agrega /32  309ms
   ✓ Logout y recuperación administrativa > CLI rechaza usuario no admin, sin modificaciones ni clave en stdout  306ms
   ✓ Logout y recuperación administrativa > CLI rechaza legajos online y acepta la aplicación detenida  682ms
   ✓ Logout y recuperación administrativa > CLI falla si el lock está ocupado  311ms
 ✓ test/schema.test.ts (53 tests) 134ms
 ✓ test/triggers.test.ts (21 tests) 108ms
 ✓ test/permisos.test.ts (29 tests) 40ms
 ✓ test/humo.test.ts (3 tests) 22ms
 ✓ test/ip.test.ts (24 tests) 7ms
 ✓ test/permisos.unit.test.ts (48 tests) 4ms

 Test Files  9 passed (9)
      Tests  244 passed (244)
   Start at  16:18:50
   Duration  10.19s (transform 158ms, setup 0ms, collect 1.09s, tests 6.67s, environment 1ms, prepare 339ms)

$ next build
 ⚠ Warning: Next.js inferred your workspace root, but it may not be correct.
 We detected multiple lockfiles and selected the directory of /home/ecenturion/pnpm-lock.yaml as the root directory.
 To silence this warning, set `outputFileTracingRoot` in your Next.js config, or consider removing one of the lockfiles if it's not needed.
   See https://nextjs.org/docs/app/api-reference/config/next-config-js/output#caveats for more information.
 Detected additional lockfiles: 
   * /home/ecenturion/develop/legajos/pnpm-lock.yaml

   ▲ Next.js 15.5.27

   Creating an optimized production build ...
 ✓ Compiled successfully in 3.5s
   Linting and checking validity of types ...
   Collecting page data ...
   Generating static pages (0/8) ...
   Generating static pages (2/8) 
   Generating static pages (4/8) 
   Generating static pages (6/8) 
 ✓ Generating static pages (8/8)
   Finalizing page optimization ...
   Collecting build traces ...

Route (app)                                 Size  First Load JS
┌ ○ /                                      137 B         103 kB
├ ○ /_not-found                            996 B         104 kB
├ ƒ /cuenta/clave                          137 B         103 kB
├ ƒ /legajos                               137 B         103 kB
├ ○ /login                                 688 B         104 kB
└ ƒ /logout                                137 B         103 kB
+ First Load JS shared by all             103 kB
  ├ chunks/758-942e49721ce48ac0.js       46.5 kB
  ├ chunks/d36d6ee9-817a06892149dc1d.js  54.4 kB
  └ other shared chunks (total)          1.87 kB


ƒ Middleware                             34.1 kB

○  (Static)   prerendered as static content
ƒ  (Dynamic)  server-rendered on demand


```

También se ejecutó `git diff --check`: código 0, sin salida.

