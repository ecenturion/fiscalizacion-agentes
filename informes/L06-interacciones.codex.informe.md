# Informe — L06-interacciones

**Estado:** COMPLETADO
**Implementador:** CODEX · sombrero B
**Fecha:** 2026-10-04

## Archivos creados

- `src/server/servicios/interacciones.ts`
- `test/interacciones.test.ts`

## Archivos modificados

- `src/server/servicios/contratos.ts`: firma de `listarInteracciones`.
- `src/server/servicios/mapeo.ts`: mapeos de interacción y solicitud; el mapeo de catálogo acepta las columnas comunes id/nombre/activo.
- `src/server/servicios/legajos.ts`: carga real de interacciones en el detalle, reutilizando la transacción; queda sólo el TODO de documentos para L07.
- Este informe, única escritura en `legajos-agents/`. Se conservó la modificación previa de `estado.jsonl`.

## Implementación y decisiones

- Los servicios reciben Contexto, exigen el permiso correspondiente antes de validar o consultar y usan los contratos Zod existentes.
- Registro, solicitudes y auditorías se escriben en una misma transacción. UUIDv7 en la app; fecha de interacción con `now()` de PostgreSQL.
- El estado lo valida y cambia exclusivamente el trigger. Se traduce sólo P0001 con mensaje `estado_desactualizado`, incluido el error del driver envuelto en `cause`, a ErrorConflicto con código 409 y el mensaje exacto solicitado.
- El registro bloquea el legajo antes del INSERT para serializar las escrituras y evitar la promoción concurrente de locks de FK a FOR UPDATE. No compara ni actualiza el estado desde el servicio.
- Anulación con FOR UPDATE sobre la interacción y columnas explícitas; no modifica legajo ni solicitudes. Auditoría con antes/después.
- La carga interna consulta interacciones/tipos, estados y solicitudes/tipos/documentos por lotes. Agrupa con Map; el estado de solicitud se calcula en SQL según el documento vinculado vivo. Mantiene anuladas y nombres de catálogos desactivados, ordenando por fecha e id descendentes.
- `listarInteracciones` usa repeatable read y audita la vista en la misma transacción. `verLegajo` usa la carga interna dentro de su transacción y conserva su auditoría de vista.
- Los 12 tests nuevos usan Postgres real como legajos_app, sin heredar owner, y Contexto obtenido mediante requerirSesion. Owner sólo prepara fixtures, simula recepción/anulación de documentos y desactiva/restaura catálogos. Las recepciones simuladas bloquean primero el documento destino y comprueban que esté vivo.
- Año fijo 2085 al crear legajos. Los tests comprueban los nueve criterios, además de entradas inválidas, IDs inexistentes, solicitudes duplicadas, catálogo histórico desactivado, auditoría de lecturas y una única consulta SELECT por tabla al listar varias interacciones con solicitudes. El conteo usa el logger de Drizzle sobre consultas reales, sin mocks.
- La versión final de los tests restaura los valores originales de los catálogos en finally y no añade catálogos persistentes. La primera versión añadió catálogos de fixture y provocó el fallo del test existente que exige el seed exacto; se corrigió dentro del alcance.

## Verificación final

Comando exigido: `cd legajos && pnpm verificar`.

**Código de salida: 0.** Lint, TypeScript, **287 tests en 12 archivos**, incluidos los **12 tests de L06**, y build finalizaron correctamente.

Para respetar el sandbox sin escribir cachés fuera del repositorio se dirigieron XDG_CACHE_HOME, XDG_STATE_HOME y XDG_DATA_HOME a `legajos/node_modules/.cache`. Sin ese ajuste, pnpm fallaba antes de ejecutar scripts con `unable to open database file`.

La base compartida ya tenía contadores de L05 usados y los intentos iniciales dejaron fixtures de L06. Se creó una base nueva en el Postgres local de pruebas para verificar la suite completa sin borrar datos ni modificar tests fuera del alcance:

```text
Base local legajos_l06_20261004_1709 creada para verificación aislada.
```

Comando final exacto, ejecutado desde `/home/ecenturion/develop/legajos`:

```sh
XDG_CACHE_HOME=/home/ecenturion/develop/legajos/node_modules/.cache XDG_STATE_HOME=/home/ecenturion/develop/legajos/node_modules/.cache XDG_DATA_HOME=/home/ecenturion/develop/legajos/node_modules/.cache TEST_ADMIN_URL=postgres://postgres:postgres@localhost:55433/legajos_l06_20261004_1709 TEST_OWNER_URL=postgres://legajos_owner@localhost:55433/legajos_l06_20261004_1709 TEST_APP_URL=postgres://legajos_app@localhost:55433/legajos_l06_20261004_1709 pnpm verificar
```

Salida real completa:

```text
$ pnpm lint && pnpm typecheck && pnpm test && pnpm build
$ eslint .
$ tsc --noEmit
$ vitest run

 RUN  v3.2.7 /home/ecenturion/develop/legajos

$ tsx src/server/db/migrar.ts
Aplicando migraciones...
{
  severity_local: 'NOTICE',
  severity: 'NOTICE',
  code: '42P06',
  message: 'schema "legajos" already exists, skipping',
  file: 'schemacmds.c',
  line: '132',
  routine: 'CreateSchemaCommand'
}
{
  severity_local: 'WARNING',
  severity: 'WARNING',
  code: '01006',
  message: 'no privileges could be revoked for "set_limit"',
  file: 'aclchk.c',
  line: '356',
  routine: 'restrict_and_check_grant'
}
{
  severity_local: 'WARNING',
  severity: 'WARNING',
  code: '01006',
  message: 'no privileges could be revoked for "show_limit"',
  file: 'aclchk.c',
  line: '356',
  routine: 'restrict_and_check_grant'
}
{
  severity_local: 'WARNING',
  severity: 'WARNING',
  code: '01006',
  message: 'no privileges could be revoked for "show_trgm"',
  file: 'aclchk.c',
  line: '356',
  routine: 'restrict_and_check_grant'
}
{
  severity_local: 'WARNING',
  severity: 'WARNING',
  code: '01006',
  message: 'no privileges could be revoked for "similarity"',
  file: 'aclchk.c',
  line: '356',
  routine: 'restrict_and_check_grant'
}
{
  severity_local: 'WARNING',
  severity: 'WARNING',
  code: '01006',
  message: 'no privileges could be revoked for "similarity_op"',
  file: 'aclchk.c',
  line: '356',
  routine: 'restrict_and_check_grant'
}
{
  severity_local: 'WARNING',
  severity: 'WARNING',
  code: '01006',
  message: 'no privileges could be revoked for "word_similarity"',
  file: 'aclchk.c',
  line: '356',
  routine: 'restrict_and_check_grant'
}
{
  severity_local: 'WARNING',
  severity: 'WARNING',
  code: '01006',
  message: 'no privileges could be revoked for "word_similarity_op"',
  file: 'aclchk.c',
  line: '356',
  routine: 'restrict_and_check_grant'
}
{
  severity_local: 'WARNING',
  severity: 'WARNING',
  code: '01006',
  message: 'no privileges could be revoked for "word_similarity_commutator_op"',
  file: 'aclchk.c',
  line: '356',
  routine: 'restrict_and_check_grant'
}
{
  severity_local: 'WARNING',
  severity: 'WARNING',
  code: '01006',
  message: 'no privileges could be revoked for "similarity_dist"',
  file: 'aclchk.c',
  line: '356',
  routine: 'restrict_and_check_grant'
}
{
  severity_local: 'WARNING',
  severity: 'WARNING',
  code: '01006',
  message: 'no privileges could be revoked for "word_similarity_dist_op"',
  file: 'aclchk.c',
  line: '356',
  routine: 'restrict_and_check_grant'
}
{
  severity_local: 'WARNING',
  severity: 'WARNING',
  code: '01006',
  message: 'no privileges could be revoked for "word_similarity_dist_commutator_op"',
  file: 'aclchk.c',
  line: '356',
  routine: 'restrict_and_check_grant'
}
{
  severity_local: 'WARNING',
  severity: 'WARNING',
  code: '01006',
  message: 'no privileges could be revoked for "gtrgm_in"',
  file: 'aclchk.c',
  line: '356',
  routine: 'restrict_and_check_grant'
}
{
  severity_local: 'WARNING',
  severity: 'WARNING',
  code: '01006',
  message: 'no privileges could be revoked for "gtrgm_out"',
  file: 'aclchk.c',
  line: '356',
  routine: 'restrict_and_check_grant'
}
{
  severity_local: 'WARNING',
  severity: 'WARNING',
  code: '01006',
  message: 'no privileges could be revoked for "gtrgm_consistent"',
  file: 'aclchk.c',
  line: '356',
  routine: 'restrict_and_check_grant'
}
{
  severity_local: 'WARNING',
  severity: 'WARNING',
  code: '01006',
  message: 'no privileges could be revoked for "gtrgm_distance"',
  file: 'aclchk.c',
  line: '356',
  routine: 'restrict_and_check_grant'
}
{
  severity_local: 'WARNING',
  severity: 'WARNING',
  code: '01006',
  message: 'no privileges could be revoked for "gtrgm_compress"',
  file: 'aclchk.c',
  line: '356',
  routine: 'restrict_and_check_grant'
}
{
  severity_local: 'WARNING',
  severity: 'WARNING',
  code: '01006',
  message: 'no privileges could be revoked for "gtrgm_decompress"',
  file: 'aclchk.c',
  line: '356',
  routine: 'restrict_and_check_grant'
}
{
  severity_local: 'WARNING',
  severity: 'WARNING',
  code: '01006',
  message: 'no privileges could be revoked for "gtrgm_penalty"',
  file: 'aclchk.c',
  line: '356',
  routine: 'restrict_and_check_grant'
}
{
  severity_local: 'WARNING',
  severity: 'WARNING',
  code: '01006',
  message: 'no privileges could be revoked for "gtrgm_picksplit"',
  file: 'aclchk.c',
  line: '356',
  routine: 'restrict_and_check_grant'
}
{
  severity_local: 'WARNING',
  severity: 'WARNING',
  code: '01006',
  message: 'no privileges could be revoked for "gtrgm_union"',
  file: 'aclchk.c',
  line: '356',
  routine: 'restrict_and_check_grant'
}
{
  severity_local: 'WARNING',
  severity: 'WARNING',
  code: '01006',
  message: 'no privileges could be revoked for "gtrgm_same"',
  file: 'aclchk.c',
  line: '356',
  routine: 'restrict_and_check_grant'
}
{
  severity_local: 'WARNING',
  severity: 'WARNING',
  code: '01006',
  message: 'no privileges could be revoked for "gin_extract_value_trgm"',
  file: 'aclchk.c',
  line: '356',
  routine: 'restrict_and_check_grant'
}
{
  severity_local: 'WARNING',
  severity: 'WARNING',
  code: '01006',
  message: 'no privileges could be revoked for "gin_extract_query_trgm"',
  file: 'aclchk.c',
  line: '356',
  routine: 'restrict_and_check_grant'
}
{
  severity_local: 'WARNING',
  severity: 'WARNING',
  code: '01006',
  message: 'no privileges could be revoked for "gin_trgm_consistent"',
  file: 'aclchk.c',
  line: '356',
  routine: 'restrict_and_check_grant'
}
{
  severity_local: 'WARNING',
  severity: 'WARNING',
  code: '01006',
  message: 'no privileges could be revoked for "gin_trgm_triconsistent"',
  file: 'aclchk.c',
  line: '356',
  routine: 'restrict_and_check_grant'
}
{
  severity_local: 'WARNING',
  severity: 'WARNING',
  code: '01006',
  message: 'no privileges could be revoked for "strict_word_similarity"',
  file: 'aclchk.c',
  line: '356',
  routine: 'restrict_and_check_grant'
}
{
  severity_local: 'WARNING',
  severity: 'WARNING',
  code: '01006',
  message: 'no privileges could be revoked for "strict_word_similarity_op"',
  file: 'aclchk.c',
  line: '356',
  routine: 'restrict_and_check_grant'
}
{
  severity_local: 'WARNING',
  severity: 'WARNING',
  code: '01006',
  message: 'no privileges could be revoked for "strict_word_similarity_commutator_op"',
  file: 'aclchk.c',
  line: '356',
  routine: 'restrict_and_check_grant'
}
{
  severity_local: 'WARNING',
  severity: 'WARNING',
  code: '01006',
  message: 'no privileges could be revoked for "strict_word_similarity_dist_op"',
  file: 'aclchk.c',
  line: '356',
  routine: 'restrict_and_check_grant'
}
{
  severity_local: 'WARNING',
  severity: 'WARNING',
  code: '01006',
  message: 'no privileges could be revoked for "strict_word_similarity_dist_commutator_op"',
  file: 'aclchk.c',
  line: '356',
  routine: 'restrict_and_check_grant'
}
{
  severity_local: 'WARNING',
  severity: 'WARNING',
  code: '01006',
  message: 'no privileges could be revoked for "gtrgm_options"',
  file: 'aclchk.c',
  line: '356',
  routine: 'restrict_and_check_grant'
}
{
  severity_local: 'WARNING',
  severity: 'WARNING',
  code: '01006',
  message: 'no privileges could be revoked for "unaccent"',
  file: 'aclchk.c',
  line: '356',
  routine: 'restrict_and_check_grant'
}
{
  severity_local: 'WARNING',
  severity: 'WARNING',
  code: '01006',
  message: 'no privileges could be revoked for "unaccent"',
  file: 'aclchk.c',
  line: '356',
  routine: 'restrict_and_check_grant'
}
{
  severity_local: 'WARNING',
  severity: 'WARNING',
  code: '01006',
  message: 'no privileges could be revoked for "unaccent_init"',
  file: 'aclchk.c',
  line: '356',
  routine: 'restrict_and_check_grant'
}
{
  severity_local: 'WARNING',
  severity: 'WARNING',
  code: '01006',
  message: 'no privileges could be revoked for "unaccent_lexize"',
  file: 'aclchk.c',
  line: '356',
  routine: 'restrict_and_check_grant'
}
Migraciones aplicadas
 ✓ test/legajos.test.ts (17 tests) 320ms
 ✓ test/triggers.test.ts (21 tests) 111ms
 ✓ test/login.test.ts (14 tests) 3628ms
   ✓ Login y cambio de clave con Postgres real como legajos_app > cinco fallos bloquean; la clave correcta no pasa hasta +16 minutos  373ms
   ✓ Login y cambio de clave con Postgres real como legajos_app > inexistente usa señuelo, con mediana de cinco muestras a menos del 30%  446ms
   ✓ Login y cambio de clave con Postgres real como legajos_app > 20 fallos por IP, el 21 no verifica ni modifica cuenta; ventana vencida reinicia  933ms
   ✓ Login y cambio de clave con Postgres real como legajos_app > 25 concurrentes desde una IP: sólo 20 verifican argon2  888ms
 ✓ test/logout-y-cli.test.ts (12 tests) 2808ms
   ✓ Logout y recuperación administrativa > CLI imprime una clave de 16 caracteres una vez, agrega IPv6 y cierra todas las sesiones  480ms
   ✓ Logout y recuperación administrativa > CLI normaliza IPv4-mapped y agrega /32  348ms
   ✓ Logout y recuperación administrativa > CLI rechaza usuario no admin, sin modificaciones ni clave en stdout  349ms
   ✓ Logout y recuperación administrativa > CLI rechaza legajos online y acepta la aplicación detenida  746ms
   ✓ Logout y recuperación administrativa > CLI falla si el lock está ocupado  340ms
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

 ✓ test/cedulas.test.ts (14 tests) 239ms
 ✓ test/interacciones.test.ts (12 tests) 222ms
 ✓ test/auth-guard.test.ts (40 tests) 155ms
 ✓ test/schema.test.ts (53 tests) 134ms
 ✓ test/permisos.test.ts (29 tests) 42ms
 ✓ test/humo.test.ts (3 tests) 22ms
 ✓ test/ip.test.ts (24 tests) 7ms
 ✓ test/permisos.unit.test.ts (48 tests) 4ms

 Test Files  12 passed (12)
      Tests  287 passed (287)
   Start at  17:08:29
   Duration  12.80s (transform 204ms, setup 0ms, collect 2.04s, tests 7.69s, environment 2ms, prepare 457ms)

$ next build
 ⚠ Warning: Next.js inferred your workspace root, but it may not be correct.
 We detected multiple lockfiles and selected the directory of /home/ecenturion/pnpm-lock.yaml as the root directory.
 To silence this warning, set `outputFileTracingRoot` in your Next.js config, or consider removing one of the lockfiles if it's not needed.
   See https://nextjs.org/docs/app/api-reference/config/next-config-js/output#caveats for more information.
 Detected additional lockfiles: 
   * /home/ecenturion/develop/legajos/pnpm-lock.yaml

   ▲ Next.js 15.5.27

   Creating an optimized production build ...
 ✓ Compiled successfully in 1390ms
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

## Primer intento de verificación completa

Antes de corregir la persistencia de catálogos en los tests nuevos se ejecutó, desde `legajos/`:

```sh
XDG_CACHE_HOME=/home/ecenturion/develop/legajos/node_modules/.cache XDG_STATE_HOME=/home/ecenturion/develop/legajos/node_modules/.cache XDG_DATA_HOME=/home/ecenturion/develop/legajos/node_modules/.cache pnpm verificar
```

**Código de salida: 1.** Tres fallos de numeración de L05 por contadores ya usados en la base compartida y un fallo del test de seed exacto por los catálogos añadidos por los fixtures iniciales de L06. Build no se ejecutó en este intento porque test falló.

Salida real completa:

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

 ✓ test/cedulas.test.ts (14 tests) 235ms
 ✓ test/login.test.ts (14 tests) 3650ms
   ✓ Login y cambio de clave con Postgres real como legajos_app > cinco fallos bloquean; la clave correcta no pasa hasta +16 minutos  369ms
   ✓ Login y cambio de clave con Postgres real como legajos_app > inexistente usa señuelo, con mediana de cinco muestras a menos del 30%  459ms
   ✓ Login y cambio de clave con Postgres real como legajos_app > 20 fallos por IP, el 21 no verifica ni modifica cuenta; ventana vencida reinicia  938ms
   ✓ Login y cambio de clave con Postgres real como legajos_app > 25 concurrentes desde una IP: sólo 20 verifican argon2  894ms
 ✓ test/logout-y-cli.test.ts (12 tests) 2811ms
   ✓ Logout y recuperación administrativa > CLI imprime una clave de 16 caracteres una vez, agrega IPv6 y cierra todas las sesiones  485ms
   ✓ Logout y recuperación administrativa > CLI normaliza IPv4-mapped y agrega /32  344ms
   ✓ Logout y recuperación administrativa > CLI rechaza usuario no admin, sin modificaciones ni clave en stdout  343ms
   ✓ Logout y recuperación administrativa > CLI rechaza legajos online y acepta la aplicación detenida  746ms
   ✓ Logout y recuperación administrativa > CLI falla si el lock está ocupado  346ms
 ❯ test/legajos.test.ts (17 tests | 3 failed) 320ms
   ✓ Legajos contra Postgres real como legajos_app > usa el rol app sin heredar owner 1ms
   × Legajos contra Postgres real como legajos_app > dos legajos empiezan en AAAA-0001 y AAAA-0002 23ms
     → expected [ '2090-0003', '2090-0004' ] to deeply equal [ '2090-0001', '2090-0002' ]
   × Legajos contra Postgres real como legajos_app > 10 altas concurrentes reservan correlativos 1..10 sin repetidos 77ms
     → expected [ Array(10) ] to deeply equal [ 1, 2, 3, 4, 5, 6, 7, 8, 9, 10 ]
   × Legajos contra Postgres real como legajos_app > el primer legajo del año siguiente vuelve al correlativo 1 6ms
     → expected '2092-0002' to be '2092-0001' // Object.is equality
   ✓ Legajos contra Postgres real como legajos_app > usa el año de Asunción aunque el instante en UTC ya sea 2027 10ms
   ✓ Legajos contra Postgres real como legajos_app > rechaza sin cédulas y con dos originales antes de escribir 3ms
   ✓ Legajos contra Postgres real como legajos_app > audita el legajo y todas sus cédulas y devuelve UUIDv7 y fechas ISO 9ms
   ✓ Legajos contra Postgres real como legajos_app > relaciona sin duplicar y sólo por números de cédulas vivas 35ms
   ✓ Legajos contra Postgres real como legajos_app > encuentra José buscando jose, por prefijo y con filtros combinados AND 17ms
   ✓ Legajos contra Postgres real como legajos_app > trata % como literal en la búsqueda 17ms
   ✓ Legajos contra Postgres real como legajos_app > trata _ como literal en la búsqueda 18ms
   ✓ Legajos contra Postgres real como legajos_app > trata \ como literal en la búsqueda 15ms
   ✓ Legajos contra Postgres real como legajos_app > pagina con total exacto, sin duplicados y de más nuevo a más antiguo 24ms
   ✓ Legajos contra Postgres real como legajos_app > audita vistas y consultas incluso sin resultados 11ms
   ✓ Legajos contra Postgres real como legajos_app > consulta no crea ni edita; el guard entrega el contexto sin elevar permisos 5ms
   ✓ Legajos contra Postgres real como legajos_app > editarLegajo preserva estado y campos omitidos; el grant bloquea cambios de estado 11ms
   ✓ Legajos contra Postgres real como legajos_app > ver inexistente devuelve 404 y valida los UUID y el paginado 2ms
 ✓ test/interacciones.test.ts (12 tests) 219ms
 ✓ test/auth-guard.test.ts (40 tests) 150ms
 ✓ test/schema.test.ts (53 tests) 128ms
 ❯ test/triggers.test.ts (21 tests | 1 failed) 118ms
   ✓ Triggers y catálogos (operaciones como legajos_app) > conecta como legajos_app 10ms
   ✓ Triggers y catálogos (operaciones como legajos_app) > cambia el estado y rechaza un anterior desactualizado sin alterar el legajo 9ms
   ✓ Triggers y catálogos (operaciones como legajos_app) > una interacción sin cambio de estado no escribe en el legajo 2ms
   ✓ Triggers y catálogos (operaciones como legajos_app) > anular una interacción conserva el estado alcanzado 3ms
   ✓ Triggers y catálogos (operaciones como legajos_app) > serializa dos cambios con el mismo estado anterior y el segundo falla tras esperar 23ms
   ✓ Triggers y catálogos (operaciones como legajos_app) > acepta una versión de un documento vivo del mismo legajo y tipo 4ms
   ✓ Triggers y catálogos (operaciones como legajos_app) > rechaza versión con anterior inexistente 4ms
   ✓ Triggers y catálogos (operaciones como legajos_app) > rechaza versión con anterior anulado 3ms
   ✓ Triggers y catálogos (operaciones como legajos_app) > rechaza versión con anterior otro legajo 2ms
   ✓ Triggers y catálogos (operaciones como legajos_app) > rechaza versión con anterior otro tipo 2ms
   ✓ Triggers y catálogos (operaciones como legajos_app) > acepta solicitudes pendientes y documentos del legajo y tipo correctos 3ms
   ✓ Triggers y catálogos (operaciones como legajos_app) > rechaza solicitudes de otro legajo que su interacción 2ms
   ✓ Triggers y catálogos (operaciones como legajos_app) > rechaza INSERT de solicitud con documento de otro tipo 2ms
   ✓ Triggers y catálogos (operaciones como legajos_app) > rechaza INSERT de solicitud con documento de otro legajo 3ms
   ✓ Triggers y catálogos (operaciones como legajos_app) > rechaza UPDATE de solicitud con documento de otro tipo 3ms
   ✓ Triggers y catálogos (operaciones como legajos_app) > rechaza UPDATE de solicitud con documento de otro legajo 3ms
   ✓ Triggers y catálogos (operaciones como legajos_app) > la coherencia de solicitudes permite documentos anulados (el servicio controla su vigencia) 2ms
   ✓ Triggers y catálogos (operaciones como legajos_app) > rechaza orden 2 en tipos sin múltiples archivos 3ms
   ✓ Triggers y catálogos (operaciones como legajos_app) > acepta orden 1 en tipos simples y varios archivos en Nota 3ms
   ✓ Triggers y catálogos (operaciones como legajos_app) > rechaza archivos sobre documentos anulados 2ms
   × Triggers y catálogos (operaciones como legajos_app) > siembra los cinco estados, cuatro interacciones y cinco documentos con UUIDs fijos 6ms
     → expected [ { …(4) }, { …(4) }, { …(4) }, …(6) ] to deeply equal [ { …(4) }, { …(4) }, { …(4) }, …(2) ]
 ✓ test/permisos.test.ts (29 tests) 40ms
 ✓ test/humo.test.ts (3 tests) 21ms
 ✓ test/ip.test.ts (24 tests) 7ms
 ✓ test/permisos.unit.test.ts (48 tests) 4ms

⎯⎯⎯⎯⎯⎯⎯ Failed Tests 4 ⎯⎯⎯⎯⎯⎯⎯

 FAIL  test/legajos.test.ts > Legajos contra Postgres real como legajos_app > dos legajos empiezan en AAAA-0001 y AAAA-0002
AssertionError: expected [ '2090-0003', '2090-0004' ] to deeply equal [ '2090-0001', '2090-0002' ]

- Expected
+ Received

  [
-   "2090-0001",
-   "2090-0002",
+   "2090-0003",
+   "2090-0004",
  ]

 ❯ test/legajos.test.ts:79:46
     77|     const primero = await servicio.crearLegajo(admin, entrada());
     78|     const segundo = await servicio.crearLegajo(admin, entrada());
     79|     expect([primero.numero, segundo.numero]).toEqual([`${anio}-0001`, …
       |                                              ^
     80|     expect(primero.estado.nombre).toBe('Detectado');
     81|   });

⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯[1/4]⎯

 FAIL  test/legajos.test.ts > Legajos contra Postgres real como legajos_app > 10 altas concurrentes reservan correlativos 1..10 sin repetidos
AssertionError: expected [ Array(10) ] to deeply equal [ 1, 2, 3, 4, 5, 6, 7, 8, 9, 10 ]

- Expected
+ Received

  [
-   1,
-   2,
-   3,
-   4,
-   5,
-   6,
-   7,
-   8,
-   9,
-   10,
+   11,
+   12,
+   13,
+   14,
+   15,
+   16,
+   17,
+   18,
+   19,
+   20,
  ]

 ❯ test/legajos.test.ts:86:72
     84|     const servicio = conAnio(anio + 1);
     85|     const resultados = await Promise.all(Array.from({ length: 10 }, ()…
     86|     expect(resultados.map((l) => l.correlativo).sort((a, b) => a - b))…
       |                                                                        ^
     87|     expect(new Set(resultados.map((l) => l.numero)).size).toBe(10);
     88|   });

⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯[2/4]⎯

 FAIL  test/legajos.test.ts > Legajos contra Postgres real como legajos_app > el primer legajo del año siguiente vuelve al correlativo 1
AssertionError: expected '2092-0002' to be '2092-0001' // Object.is equality

Expected: "2092-0001"
Received: "2092-0002"

 ❯ test/legajos.test.ts:92:27
     90|   it('el primer legajo del año siguiente vuelve al correlativo 1', asy…
     91|     const salida = await conAnio(anio + 2).crearLegajo(admin, entrada(…
     92|     expect(salida.numero).toBe(`${anio + 2}-0001`);
       |                           ^
     93|   });
     94| 

⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯[3/4]⎯

 FAIL  test/triggers.test.ts > Triggers y catálogos (operaciones como legajos_app) > siembra los cinco estados, cuatro interacciones y cinco documentos con UUIDs fijos
AssertionError: expected [ { …(4) }, { …(4) }, { …(4) }, …(6) ] to deeply equal [ { …(4) }, { …(4) }, { …(4) }, …(2) ]

- Expected
+ Received

@@ -27,6 +27,30 @@
      "activo": true,
      "id": "019b76da-a800-7000-8001-000000000005",
      "nombre": "Archivado",
      "orden": 5,
    },
+   {
+     "activo": false,
+     "id": "01a10885-c138-7160-9d98-c57182c4c303",
+     "nombre": "L06-01a10885-c138-7160-9d98-c57182c4c303",
+     "orden": 100,
+   },
+   {
+     "activo": false,
+     "id": "01a10885-c182-7a6b-8f6a-cd8b6017517c",
+     "nombre": "L06-01a10885-c182-7a6b-8f6a-cd8b6017517c",
+     "orden": 100,
+   },
+   {
+     "activo": false,
+     "id": "01a10886-429b-7e38-bad8-18bd0bd988be",
+     "nombre": "L06-01a10886-429b-7e38-bad8-18bd0bd988be",
+     "orden": 100,
+   },
+   {
+     "activo": false,
+     "id": "01a10886-42e3-7752-9426-fd36d7c82080",
+     "nombre": "L06-01a10886-42e3-7752-9426-fd36d7c82080",
+     "orden": 100,
+   },
  ]

 ❯ test/triggers.test.ts:261:26
    259|   it('siembra los cinco estados, cuatro interacciones y cinco document…
    260|     const estados = await tx`SELECT id, nombre, orden, activo FROM leg…
    261|     expect([...estados]).toEqual(['Detectado', 'Notificado', 'En trámi…
       |                          ^
    262|       .map((nombre, i) => ({ id: `019b76da-a800-7000-8001-00000000000$…
    263|     const interacciones = await tx`SELECT id, nombre, orden, activo FR…

⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯[4/4]⎯


 Test Files  2 failed | 10 passed (12)
      Tests  4 failed | 283 passed (287)
   Start at  17:06:08
   Duration  12.72s (transform 202ms, setup 0ms, collect 2.02s, tests 7.70s, environment 2ms, prepare 455ms)

 ELIFECYCLE  Test failed. See above for more details.
 ELIFECYCLE  Command failed with exit code 1.
```

## Comprobación del alcance

`git diff --check && git status --short`, desde `legajos/`, código de salida 0:

```text
 M src/server/servicios/contratos.ts
 M src/server/servicios/legajos.ts
 M src/server/servicios/mapeo.ts
?? src/server/servicios/interacciones.ts
?? test/interacciones.test.ts
```

## Pendientes y límites

- Implementación y verificación de L06 completas. La auditoría de las mutaciones corresponde al arquitecto; no se emitió auditoría del código propio.
- La base compartida `legajos_test` conserva fixtures de los intentos iniciales, incluidos catálogos inactivos añadidos por la primera versión de los tests. No se borraron datos. La verificación completa exitosa usó `legajos_l06_20261004_1709`, que también conserva sus fixtures de prueba.
- Los tests existentes de numeración de L05 necesitan contadores inicialmente vacíos para los años que tienen asignados; repetir toda la suite en una base usada produce sus tres fallos conocidos. No se modificaron esos tests porque están fuera del alcance.
- La salida final conserva los avisos de permisos de las migraciones y el aviso de Next.js sobre múltiples lockfiles; ninguno impidió la verificación.
- Asignar o reapuntar documentos en servicios sigue reservado a L07. Sin dependencias nuevas, commit, push ni despliegue.

