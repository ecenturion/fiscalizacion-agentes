# Informe — L05-legajos-y-cedulas

**Estado:** BLOQUEADO
**Implementador:** CODEX · sombrero B
**Fecha:** 2026-10-04

## Bloqueo

La spec exige que los conflictos de original único se lancen como `ErrorConflicto`, con HTTP 409 y `codigo = 'original_existente'`.

En `src/server/errores.ts:18–21`, `ErrorConflicto` fija `readonly codigo = 'conflicto'` y su constructor sólo acepta el mensaje. Por lo tanto, `new ErrorConflicto('original_existente')` cambia el mensaje, pero conserva el código genérico `conflicto`. La UI no recibiría el código exigido.

La propia spec permite en `errores.ts` únicamente agregar `ErrorNoEncontrado`. Corregir el contrato de `ErrorConflicto` queda fuera de esa excepción. Según `AGENTS.md` §4.9 y `CODEX.md` (sombrero B), corresponde detenerse y reportar la contradicción.

**Cambio de alcance necesario:** permitir que el constructor de `ErrorConflicto` reciba un código opcional, conservando `conflicto` como valor predeterminado y el mensaje como primer argumento. Así L05 puede emitir `original_existente` sin romper sus consumidores actuales.

## Archivos creados y modificados

- Código: ninguno.
- Creado: `legajos-agents/informes/L05-legajos-y-cedulas.codex.informe.md` (este informe).
- `git -C legajos status --short` y `git -C legajos diff --stat`, después de verificar: salida vacía.

## Decisiones

- No modificar `ErrorConflicto` fuera del alcance autorizado.
- No forzar el código mediante mutación de propiedades ni trucos de tipos.
- Ejecutar el comando obligatorio sobre el estado existente. Su resultado verifica la base actual; no acredita L05, que permanece sin implementar.
- No hacer commit, push ni mover la tarea.

## Verificación

Comando solicitado: `cd legajos && pnpm verificar`.

Código de salida: **0**.

Salida real completa, concatenada de las respuestas del proceso:

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
 ✓ test/login.test.ts (14 tests) 3630ms
   ✓ Login y cambio de clave con Postgres real como legajos_app > cinco fallos bloquean; la clave correcta no pasa hasta +16 minutos  368ms
   ✓ Login y cambio de clave con Postgres real como legajos_app > inexistente usa señuelo, con mediana de cinco muestras a menos del 30%  451ms
   ✓ Login y cambio de clave con Postgres real como legajos_app > 20 fallos por IP, el 21 no verifica ni modifica cuenta; ventana vencida reinicia  920ms
   ✓ Login y cambio de clave con Postgres real como legajos_app > 25 concurrentes desde una IP: sólo 20 verifican argon2  896ms
 ✓ test/logout-y-cli.test.ts (12 tests) 2805ms
   ✓ Logout y recuperación administrativa > CLI imprime una clave de 16 caracteres una vez, agrega IPv6 y cierra todas las sesiones  482ms
   ✓ Logout y recuperación administrativa > CLI normaliza IPv4-mapped y agrega /32  345ms
   ✓ Logout y recuperación administrativa > CLI rechaza usuario no admin, sin modificaciones ni clave en stdout  338ms
   ✓ Logout y recuperación administrativa > CLI rechaza legajos online y acepta la aplicación detenida  750ms
   ✓ Logout y recuperación administrativa > CLI falla si el lock está ocupado  345ms
 ✓ test/auth-guard.test.ts (40 tests) 150ms
 ✓ test/schema.test.ts (53 tests) 133ms
 ✓ test/triggers.test.ts (21 tests) 105ms
 ✓ test/permisos.test.ts (29 tests) 41ms
 ✓ test/humo.test.ts (3 tests) 22ms
 ✓ test/ip.test.ts (24 tests) 7ms
 ✓ test/permisos.unit.test.ts (48 tests) 4ms

 Test Files  9 passed (9)
      Tests  244 passed (244)
   Start at  16:25:25
   Duration  10.41s (transform 169ms, setup 0ms, collect 1.08s, tests 6.90s, environment 1ms, prepare 339ms)

$ next build
 ⚠ Warning: Next.js inferred your workspace root, but it may not be correct.
 We detected multiple lockfiles and selected the directory of /home/ecenturion/pnpm-lock.yaml as the root directory.
 To silence this warning, set `outputFileTracingRoot` in your Next.js config, or consider removing one of the lockfiles if it's not needed.
   See https://nextjs.org/docs/app/api-reference/config/next-config-js/output#caveats for more information.
 Detected additional lockfiles: 
   * /home/ecenturion/develop/legajos/pnpm-lock.yaml

   ▲ Next.js 15.5.27

   Creating an optimized production build ...
 ✓ Compiled successfully in 1368ms
   Linting and checking validity of types ...
   Collecting page data ...
   Generating static pages (0/6) ...
   Generating static pages (1/6) 
   Generating static pages (2/6) 
   Generating static pages (4/6) 
 ✓ Generating static pages (6/6)
   Finalizing page optimization ...
   Collecting build traces ...

Route (app)                                 Size  First Load JS
┌ ○ /                                      139 B         103 kB
├ ○ /_not-found                            996 B         104 kB
├ ƒ /cuenta/clave                          139 B         103 kB
├ ƒ /legajos                               139 B         103 kB
├ ○ /login                                 688 B         104 kB
└ ƒ /logout                                139 B         103 kB
+ First Load JS shared by all             103 kB
  ├ chunks/758-942e49721ce48ac0.js       46.5 kB
  ├ chunks/d36d6ee9-817a06892149dc1d.js  54.4 kB
  └ other shared chunks (total)          1.87 kB


ƒ Middleware                             34.1 kB

○  (Static)   prerendered as static content
ƒ  (Dynamic)  server-rendered on demand


```

## Pendiente

Toda la implementación y los tests específicos de L05, a la espera de que se resuelva el alcance de `ErrorConflicto`.

