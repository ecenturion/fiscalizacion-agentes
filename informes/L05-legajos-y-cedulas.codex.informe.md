# Informe — L05-legajos-y-cedulas

**Estado:** COMPLETADO
**Implementador:** CODEX · sombrero B
**Fecha:** 2026-10-04
**Despacho:** cuarto intento

## Trabajo realizado

Se completó la implementación presente de intentos anteriores y se aplicaron las correcciones de la última spec. Los servicios usan factories con base inyectada, permisos mediante `exigir`, validación Zod y auditoría dentro de la transacción.

- Numeración mediante upsert atómico, año de Asunción con Luxon y reloj inyectable; estado inicial activo de menor orden.
- Alta conjunta de legajo y cédulas; edición del legajo limitada a fecha de detección y observación.
- Detalle con cédulas anuladas, originales primero, relacionados sin duplicados por números vivos y `TODO(L06/L07)`.
- Búsqueda con filtros AND, prefijo de cédula, unaccent, escape de caracteres LIKE, paginado y total exacto. Las lecturas utilizan repeatable read para mantener una misma instantánea.
- Mutaciones de cédulas con columnas explícitas, rechazo de anuladas y traducción del 23505 de `cedula_original_unq` a `ErrorConflicto('original_existente')`.
- Tests contra Postgres real como `legajos_app`, con contextos obtenidos por `requerirSesion` y dependencias inyectadas.

## Archivos

Archivos nuevos en el diff de L05, ya presentes al iniciar:
- `src/server/uuid.ts`
- `src/server/servicios/legajos.ts`
- `src/server/servicios/cedulas.ts`
- `src/server/servicios/mapeo.ts`
- `test/legajos.test.ts`
- `test/cedulas.test.ts`

Archivos modificados en el diff de L05:
- `src/server/login.ts`: extracción e importación de UUIDv7; reexportación para conservar los consumidores existentes.
- `src/server/servicios/contratos.ts`: entrada, tipo y firma de `editarLegajo`.
- `test/schema.test.ts`: exclusivamente el año del fixture y sus aserciones, de 2026 a 2098.

En esta ejecución se modificaron únicamente `test/legajos.test.ts`, `test/cedulas.test.ts`, `test/schema.test.ts` y este informe. Los servicios, UUID y contratos heredados se conservaron tras leerlos y verificar la tarea.

`src/server/errores.ts` ya estaba modificado por el arquitecto; no se tocó. `legajos-agents/estado.jsonl` también tenía cambios previos y se conservó.

## Decisiones

- Años asignados: 2090 para numeración secuencial, 2091 para diez altas concurrentes, 2092 para el primer legajo del año siguiente, 2094 para los demás tests de legajos, 2095 para los tests de cédulas y 2098 para schema. No se modificó triggers.
- El caso horario usa `2026-12-31T23:30-03:00` y `2027-01-01T00:30-03:00`; sólo exige los años 2026 y 2027.
- Las consultas de filas de auditoría se ordenan por `creado_en, id`.
- La prueba del 23505 usa una conexión real como app que marca una cédula original sin confirmar y omite el bloqueo del legajo del servicio. El alta no ve esa original en su SELECT, pero su INSERT espera el índice único. Se comprueba la espera con `pg_blocking_pids`, se confirma la escritura competidora y se verifica el error traducido, sin nueva cédula ni auditoría. No hay mocks de la base.
- Se conserva el bloqueo adicional del legajo en las mutaciones de cédulas: serializa altas y cambios de original incluso cuando todavía no existe una original viva.

## Verificación

Comando: `cd legajos && pnpm verificar`.

**Código de salida: 0.** Lint, typecheck, los **275 tests en 11 archivos** y build finalizaron correctamente.

Salida real completa del comando:

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
 ✓ test/legajos.test.ts (17 tests) 291ms
stdout | test/cedulas.test.ts > Cédulas contra Postgres real como legajos_app > traduce el 23505 nativo del índice de original y revierte el alta
{
  severity_local: 'WARNING',
  severity: 'WARNING',
  code: '25P01',
  message: 'there is no transaction in progress',
  file: 'xact.c',
  line: '4131',
  routine: 'UserAbortTransactionBlock'
}

 ✓ test/cedulas.test.ts (14 tests) 220ms
 ✓ test/schema.test.ts (53 tests) 123ms
 ✓ test/login.test.ts (14 tests) 3618ms
   ✓ Login y cambio de clave con Postgres real como legajos_app > cinco fallos bloquean; la clave correcta no pasa hasta +16 minutos  366ms
   ✓ Login y cambio de clave con Postgres real como legajos_app > inexistente usa señuelo, con mediana de cinco muestras a menos del 30%  445ms
   ✓ Login y cambio de clave con Postgres real como legajos_app > 20 fallos por IP, el 21 no verifica ni modifica cuenta; ventana vencida reinicia  925ms
   ✓ Login y cambio de clave con Postgres real como legajos_app > 25 concurrentes desde una IP: sólo 20 verifican argon2  882ms
 ✓ test/logout-y-cli.test.ts (12 tests) 2805ms
   ✓ Logout y recuperación administrativa > CLI imprime una clave de 16 caracteres una vez, agrega IPv6 y cierra todas las sesiones  484ms
   ✓ Logout y recuperación administrativa > CLI normaliza IPv4-mapped y agrega /32  349ms
   ✓ Logout y recuperación administrativa > CLI rechaza usuario no admin, sin modificaciones ni clave en stdout  343ms
   ✓ Logout y recuperación administrativa > CLI rechaza legajos online y acepta la aplicación detenida  743ms
   ✓ Logout y recuperación administrativa > CLI falla si el lock está ocupado  341ms
 ✓ test/auth-guard.test.ts (40 tests) 162ms
 ✓ test/triggers.test.ts (21 tests) 107ms
 ✓ test/permisos.test.ts (29 tests) 39ms
 ✓ test/humo.test.ts (3 tests) 22ms
 ✓ test/ip.test.ts (24 tests) 7ms
 ✓ test/permisos.unit.test.ts (48 tests) 4ms

 Test Files  11 passed (11)
      Tests  275 passed (275)
   Start at  16:52:06
   Duration  11.89s (transform 183ms, setup 0ms, collect 1.70s, tests 7.40s, environment 1ms, prepare 410ms)

$ next build
 ⚠ Warning: Next.js inferred your workspace root, but it may not be correct.
 We detected multiple lockfiles and selected the directory of /home/ecenturion/pnpm-lock.yaml as the root directory.
 To silence this warning, set `outputFileTracingRoot` in your Next.js config, or consider removing one of the lockfiles if it's not needed.
   See https://nextjs.org/docs/app/api-reference/config/next-config-js/output#caveats for more information.
 Detected additional lockfiles: 
   * /home/ecenturion/develop/legajos/pnpm-lock.yaml

   ▲ Next.js 15.5.27

   Creating an optimized production build ...
 ✓ Compiled successfully in 1969ms
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

Comprobación adicional: `git diff --check` terminó con código 0 y sin salida.

## Limitaciones y pendientes

- Documentos e interacciones permanecen vacíos con el TODO solicitado para L06/L07.
- Los fixtures confirmados son append-only. Las aserciones de numeración desde 1 requieren que 2090–2092 estén libres al iniciar la suite; esta verificación se ejecutó con esa condición.
- PostgreSQL emitió un aviso no fatal porque el finally de la prueba del conflicto intenta ROLLBACK tras el COMMIT. Next.js emitió su aviso de varios lockfiles. Se incluyen ambos en la salida real; ninguno impidió la verificación.
- No quedaron criterios pendientes de L05. La auditoría y la aprobación corresponden al arquitecto y a AGY; este informe es de implementación.
- No se hizo commit, push, despliegue ni movimiento de la tarea.
