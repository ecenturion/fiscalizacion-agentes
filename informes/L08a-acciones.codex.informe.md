# Informe — L08a-acciones

**Estado:** COMPLETADO
**Implementador:** CODEX, sombrero B
**Fecha:** 2026-10-05
**Verificación final:** `cd legajos && pnpm verificar`, código de salida **0**, 19 archivos de tests y **434 tests aprobados**, build completado.

## Archivos creados y modificados

Rutas relativas a `legajos/`.

Creados:

- `src/server/acciones/resultado.ts`
- `src/server/acciones/contexto.ts`
- `src/app/(app)/legajos/acciones.ts`
- `src/app/(app)/admin/acciones.ts`
- `test/acciones.test.ts`
- `test/guard-cobertura.test.ts`

Modificado:

- `src/app/(app)/cuenta/clave/acciones.ts` (cambios parciales).

La única escritura de esta tarea en `legajos-agents/` es este informe. Sin commit ni push; sin dependencias nuevas.

## Decisiones y motivos

- `aResultado` conserva los códigos de errores conocidos, incluye `ErrorOrigen` para CSRF, convierte validaciones a `campos` y oculta los mensajes de errores inesperados. `ErrorNoAutenticado` redirige a `/login`.
- Los servicios existentes pierden los detalles Zod al lanzar `ErrorValidacion`. Las Actions validan con los contratos originales para conservar rutas de campos anidados; los errores generales del servicio usan `_formulario`. No se modificaron servicios, contratos, guard ni base de código de datos.
- Los redirects de éxito se ejecutan fuera de `aResultado`, para no capturar la excepción de control de Next como un error interno.
- `servicios()` construye legajos, cédulas, interacciones, documentos y administración una sola vez por proceso con `dbApp()` y `ARCHIVOS_DIR`. La inyección de la conexión real en tests construye instancias independientes.
- Cada exportación async, incluidas las variantes `Con`, contiene su propio `await requerirSesion`. Las exportadas para Next delegan en `Con` sin dependencias. Esto implica dos comprobaciones de sesión en la llamada de Next y una en las llamadas directas a `Con`; permite cumplir simultáneamente la delegación y el guard literal en cada exportación, sin agregar excepciones al test de cobertura.
- Las variantes `Con(entrada, deps?)` sólo aceptan dependencias inyectadas bajo `NODE_ENV=test`: también son Server Actions exportadas y una llamada de cliente en producción no debe poder cambiar Origin, reloj o conexión. Sin deps ejecutan el guard y los servicios normales.
- Administración incluye también las cuatro lecturas de `ServiciosAdmin` (`listarUsuarios`, `listarCatalogos`, `listarAccesos`, `listarAuditoria`), con `mutacion:false`. Las claves temporales de crear/resetear sólo vuelven en el resultado; los tests comprueban el hash real, la ausencia en auditoría/listados y que no se escriben cookies.
- El formulario existente de cambio de clave exige `Promise<void>`. `cambiar` conserva esa firma, sus errores lanzados y el redirect de éxito; `cambiarCon` devuelve el error uniforme. La rotación de sesiones y la cookie mantienen la lógica existente y tienen prueba contra Postgres real.
- El test AST recorre cada exportación async de las Actions y handlers API, además de logout. Exige un guard esperado antes de cuerpos/servicios; ignora comentarios y sólo acepta imports de tipos de servicios en Actions. Impide exportaciones por arrow que escaparían al análisis. Las únicas excepciones son `entrar` del login y `POST /logout`; el GET de logout devuelve 405 sin operaciones protegidas. Incluye casos negativos para comprobar el detector.
- Los tests de Actions ejecutan guard y servicios contra Postgres real como `legajos_app`, comprobando que no hereda owner. Sólo se simulan APIs de Next; para el error interno se inyecta un fallo en la construcción de servicios.

## Entorno y límites de la verificación

- `pnpm` inicialmente no podía abrir su base de caché con las rutas predeterminadas. Se configuraron `XDG_CACHE_HOME`, `XDG_DATA_HOME` y `XDG_STATE_HOME` en `$PWD/node_modules/.cache`, dentro de `legajos/`. No se cambió la configuración del proyecto.
- La primera verificación completa contra la base compartida `legajos_test` falló: 3 tests de numeración encontraron contadores anteriores y 12 tests de cédulas colisionaron con fixtures nuevos que usaban su mismo año (2095). Los fixtures de esta tarea se corrigieron a 2088, libre en la suite actual.
- Para verificar toda la suite sin borrar datos ni modificar tests ajenos se creó la base local aislada `legajos_l08a_codex_20261005`, owner `legajos_owner`, en el Postgres de tests de localhost:55433. Se fijaron `TEST_ADMIN_URL`, `TEST_OWNER_URL` y `TEST_APP_URL` a esa base. El setup y las migraciones existentes se ejecutaron como parte de `pnpm verificar`.
- No se borraron fixtures ni bases. La base compartida mantiene los datos de corridas previas, incluidas las fixtures iniciales de esta tarea en 2095. La verificación aprobada corresponde a la base aislada. Los tests de numeración existentes requieren una base nueva para volver a esperar correlativos desde 1.
- El build informa el warning existente sobre múltiples lockfiles y la raíz inferida del workspace. No se cambió la configuración de Next fuera del alcance.
- No quedó implementación pendiente dentro del alcance. La auditoría independiente corresponde a AGY y al arquitecto, según la spec.

## Salida real

### Arranque inicial de pnpm

Comando: `pnpm typecheck && pnpm lint`. Código de salida: **1**.

```text
[ERROR] unable to open database file
For help, run: pnpm help run
```

### Primera corrida completa — base compartida

Comando: `pnpm verificar`, con las tres variables XDG bajo `legajos/node_modules/.cache`. Código de salida: **1**.

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
 ✓ test/login.test.ts (14 tests) 3720ms
   ✓ Login y cambio de clave con Postgres real como legajos_app > cinco fallos bloquean; la clave correcta no pasa hasta +16 minutos  369ms
   ✓ Login y cambio de clave con Postgres real como legajos_app > inexistente usa señuelo, con mediana de cinco muestras a menos del 30%  441ms
   ✓ Login y cambio de clave con Postgres real como legajos_app > 20 fallos por IP, el 21 no verifica ni modifica cuenta; ventana vencida reinicia  928ms
   ✓ Login y cambio de clave con Postgres real como legajos_app > 25 concurrentes desde una IP: sólo 20 verifican argon2  953ms
 ✓ test/logout-y-cli.test.ts (12 tests) 2907ms
   ✓ Logout y recuperación administrativa > CLI imprime una clave de 16 caracteres una vez, agrega IPv6 y cierra todas las sesiones  507ms
   ✓ Logout y recuperación administrativa > CLI normaliza IPv4-mapped y agrega /32  391ms
   ✓ Logout y recuperación administrativa > CLI rechaza usuario no admin, sin modificaciones ni clave en stdout  352ms
   ✓ Logout y recuperación administrativa > CLI rechaza legajos online y acepta la aplicación detenida  762ms
   ✓ Logout y recuperación administrativa > CLI falla si el lock está ocupado  343ms
 ✓ test/documentos.test.ts (43 tests) 1189ms
 ✓ test/admin.test.ts (18 tests) 1092ms
   ✓ Administración contra Postgres real como legajos_app > dos admins que se desactivan mutuamente en paralelo dejan al menos uno activo  379ms
 ✓ test/archivos-validar.test.ts (15 tests) 715ms
 ✓ test/acciones.test.ts (24 tests) 520ms
 ✓ test/rutas-documentos.test.ts (16 tests) 427ms
 ❯ test/legajos.test.ts (17 tests | 3 failed) 345ms
   ✓ Legajos contra Postgres real como legajos_app > usa el rol app sin heredar owner 1ms
   × Legajos contra Postgres real como legajos_app > dos legajos empiezan en AAAA-0001 y AAAA-0002 25ms
     → expected [ '2090-0003', '2090-0004' ] to deeply equal [ '2090-0001', '2090-0002' ]
   × Legajos contra Postgres real como legajos_app > 10 altas concurrentes reservan correlativos 1..10 sin repetidos 89ms
     → expected [ Array(10) ] to deeply equal [ 1, 2, 3, 4, 5, 6, 7, 8, 9, 10 ]
   × Legajos contra Postgres real como legajos_app > el primer legajo del año siguiente vuelve al correlativo 1 8ms
     → expected '2092-0002' to be '2092-0001' // Object.is equality
   ✓ Legajos contra Postgres real como legajos_app > usa el año de Asunción aunque el instante en UTC ya sea 2027 11ms
   ✓ Legajos contra Postgres real como legajos_app > rechaza sin cédulas y con dos originales antes de escribir 2ms
   ✓ Legajos contra Postgres real como legajos_app > audita el legajo y todas sus cédulas y devuelve UUIDv7 y fechas ISO 10ms
   ✓ Legajos contra Postgres real como legajos_app > relaciona sin duplicar y sólo por números de cédulas vivas 36ms
   ✓ Legajos contra Postgres real como legajos_app > encuentra José buscando jose, por prefijo y con filtros combinados AND 18ms
   ✓ Legajos contra Postgres real como legajos_app > trata % como literal en la búsqueda 17ms
   ✓ Legajos contra Postgres real como legajos_app > trata _ como literal en la búsqueda 16ms
   ✓ Legajos contra Postgres real como legajos_app > trata \ como literal en la búsqueda 15ms
   ✓ Legajos contra Postgres real como legajos_app > pagina con total exacto, sin duplicados y de más nuevo a más antiguo 27ms
   ✓ Legajos contra Postgres real como legajos_app > audita vistas y consultas incluso sin resultados 12ms
   ✓ Legajos contra Postgres real como legajos_app > consulta no crea ni edita; el guard entrega el contexto sin elevar permisos 5ms
   ✓ Legajos contra Postgres real como legajos_app > editarLegajo preserva estado y campos omitidos; el grant bloquea cambios de estado 11ms
   ✓ Legajos contra Postgres real como legajos_app > ver inexistente devuelve 404 y valida los UUID y el paginado 2ms
 ❯ test/cedulas.test.ts (14 tests | 12 failed) 88ms
   ✓ Cédulas contra Postgres real como legajos_app > usa legajos_app sin pertenecer a owner 1ms
   × Cédulas contra Postgres real como legajos_app > permite repetir un número en el mismo legajo y audita el alta 11ms
     → Failed query: insert into "legajos"."legajo" ("id", "anio", "correlativo", "fecha_deteccion", "observacion", "estado_id", "creado_por", "creado_en") values ($1, $2, $3, $4, $5, $6, $7, default) returning "id", "anio", "correlativo", "numero", "fecha_deteccion", "observacion", "estado_id", "creado_por", "creado_en"
params: 01a10c10-f839-7c15-8677-8f718e398b59,2095,13,2026-10-01,,019b76da-a800-7000-8001-000000000001,01a10c10-f80f-7db0-bdd0-a2a2bec2a2d1
   × Cédulas contra Postgres real como legajos_app > agregar una segunda original devuelve 409 sin desmarcar ni auditar un alta 3ms
     → Failed query: insert into "legajos"."legajo" ("id", "anio", "correlativo", "fecha_deteccion", "observacion", "estado_id", "creado_por", "creado_en") values ($1, $2, $3, $4, $5, $6, $7, default) returning "id", "anio", "correlativo", "numero", "fecha_deteccion", "observacion", "estado_id", "creado_por", "creado_en"
params: 01a10c10-f841-7359-b744-5f713ef2ccd8,2095,13,2026-10-01,,019b76da-a800-7000-8001-000000000001,01a10c10-f80f-7db0-bdd0-a2a2bec2a2d1
   × Cédulas contra Postgres real como legajos_app > marcarOriginal cambia ambas filas con antes/después y dos auditorías 3ms
     → Failed query: insert into "legajos"."legajo" ("id", "anio", "correlativo", "fecha_deteccion", "observacion", "estado_id", "creado_por", "creado_en") values ($1, $2, $3, $4, $5, $6, $7, default) returning "id", "anio", "correlativo", "numero", "fecha_deteccion", "observacion", "estado_id", "creado_por", "creado_en"
params: 01a10c10-f844-7400-9230-ccc4bf862fed,2095,13,2026-10-01,,019b76da-a800-7000-8001-000000000001,01a10c10-f80f-7db0-bdd0-a2a2bec2a2d1
   × Cédulas contra Postgres real como legajos_app > dos cambios concurrentes con original inicial=true dejan exactamente una 2ms
     → Failed query: insert into "legajos"."legajo" ("id", "anio", "correlativo", "fecha_deteccion", "observacion", "estado_id", "creado_por", "creado_en") values ($1, $2, $3, $4, $5, $6, $7, default) returning "id", "anio", "correlativo", "numero", "fecha_deteccion", "observacion", "estado_id", "creado_por", "creado_en"
params: 01a10c10-f847-7eee-9938-5eaf3a25730d,2095,13,2026-10-01,,019b76da-a800-7000-8001-000000000001,01a10c10-f80f-7db0-bdd0-a2a2bec2a2d1
   × Cédulas contra Postgres real como legajos_app > dos cambios concurrentes con original inicial=false dejan exactamente una 2ms
     → Failed query: insert into "legajos"."legajo" ("id", "anio", "correlativo", "fecha_deteccion", "observacion", "estado_id", "creado_por", "creado_en") values ($1, $2, $3, $4, $5, $6, $7, default) returning "id", "anio", "correlativo", "numero", "fecha_deteccion", "observacion", "estado_id", "creado_por", "creado_en"
params: 01a10c10-f849-77f3-ad47-f7ef57e97b08,2095,13,2026-10-01,,019b76da-a800-7000-8001-000000000001,01a10c10-f80f-7db0-bdd0-a2a2bec2a2d1
   × Cédulas contra Postgres real como legajos_app > dos altas originales concurrentes tienen un éxito y un conflicto 2ms
     → Failed query: insert into "legajos"."legajo" ("id", "anio", "correlativo", "fecha_deteccion", "observacion", "estado_id", "creado_por", "creado_en") values ($1, $2, $3, $4, $5, $6, $7, default) returning "id", "anio", "correlativo", "numero", "fecha_deteccion", "observacion", "estado_id", "creado_por", "creado_en"
params: 01a10c10-f84b-7029-9b6b-e9d641ccfd2d,2095,13,2026-10-01,,019b76da-a800-7000-8001-000000000001,01a10c10-f80f-7db0-bdd0-a2a2bec2a2d1
   × Cédulas contra Postgres real como legajos_app > traduce el 23505 nativo del índice de original y revierte el alta 2ms
     → Failed query: insert into "legajos"."legajo" ("id", "anio", "correlativo", "fecha_deteccion", "observacion", "estado_id", "creado_por", "creado_en") values ($1, $2, $3, $4, $5, $6, $7, default) returning "id", "anio", "correlativo", "numero", "fecha_deteccion", "observacion", "estado_id", "creado_por", "creado_en"
params: 01a10c10-f84e-78dd-a8b1-426e7c50e125,2095,13,2026-10-01,,019b76da-a800-7000-8001-000000000001,01a10c10-f80f-7db0-bdd0-a2a2bec2a2d1
   × Cédulas contra Postgres real como legajos_app > alta y marcado concurrentes preservan una sola original 5ms
     → Failed query: insert into "legajos"."legajo" ("id", "anio", "correlativo", "fecha_deteccion", "observacion", "estado_id", "creado_por", "creado_en") values ($1, $2, $3, $4, $5, $6, $7, default) returning "id", "anio", "correlativo", "numero", "fecha_deteccion", "observacion", "estado_id", "creado_por", "creado_en"
params: 01a10c10-f853-7319-9890-c158ce87a260,2095,13,2026-10-01,,019b76da-a800-7000-8001-000000000001,01a10c10-f80f-7db0-bdd0-a2a2bec2a2d1
   × Cédulas contra Postgres real como legajos_app > editar sólo modifica los campos autorizados y preserva los opcionales omitidos 3ms
     → Failed query: insert into "legajos"."legajo" ("id", "anio", "correlativo", "fecha_deteccion", "observacion", "estado_id", "creado_por", "creado_en") values ($1, $2, $3, $4, $5, $6, $7, default) returning "id", "anio", "correlativo", "numero", "fecha_deteccion", "observacion", "estado_id", "creado_por", "creado_en"
params: 01a10c10-f855-772f-891a-8a0cc33b6d18,2095,13,2026-10-01,,019b76da-a800-7000-8001-000000000001,01a10c10-f80f-7db0-bdd0-a2a2bec2a2d1
   × Cédulas contra Postgres real como legajos_app > anular la original deja el legajo sin original viva y permite marcar otra 2ms
     → Failed query: insert into "legajos"."legajo" ("id", "anio", "correlativo", "fecha_deteccion", "observacion", "estado_id", "creado_por", "creado_en") values ($1, $2, $3, $4, $5, $6, $7, default) returning "id", "anio", "correlativo", "numero", "fecha_deteccion", "observacion", "estado_id", "creado_por", "creado_en"
params: 01a10c10-f858-7ead-ab4e-c58bd87245f9,2095,13,2026-10-01,,019b76da-a800-7000-8001-000000000001,01a10c10-f80f-7db0-bdd0-a2a2bec2a2d1
   × Cédulas contra Postgres real como legajos_app > anular exige motivo y rechaza editar, marcar o anular una cédula ya anulada 2ms
     → Failed query: insert into "legajos"."legajo" ("id", "anio", "correlativo", "fecha_deteccion", "observacion", "estado_id", "creado_por", "creado_en") values ($1, $2, $3, $4, $5, $6, $7, default) returning "id", "anio", "correlativo", "numero", "fecha_deteccion", "observacion", "estado_id", "creado_por", "creado_en"
params: 01a10c10-f859-7306-ae74-498a1a298a06,2095,13,2026-10-01,,019b76da-a800-7000-8001-000000000001,01a10c10-f80f-7db0-bdd0-a2a2bec2a2d1
   × Cédulas contra Postgres real como legajos_app > consulta no crea ni edita ni marca; operador no anula 2ms
     → Failed query: insert into "legajos"."legajo" ("id", "anio", "correlativo", "fecha_deteccion", "observacion", "estado_id", "creado_por", "creado_en") values ($1, $2, $3, $4, $5, $6, $7, default) returning "id", "anio", "correlativo", "numero", "fecha_deteccion", "observacion", "estado_id", "creado_por", "creado_en"
params: 01a10c10-f85b-752c-80ad-e5dbbe2d3396,2095,13,2026-10-01,,019b76da-a800-7000-8001-000000000001,01a10c10-f80f-7db0-bdd0-a2a2bec2a2d1
   ✓ Cédulas contra Postgres real como legajos_app > valida cada entrada y devuelve 404 para IDs inexistentes 6ms
 ✓ test/interacciones.test.ts (12 tests) 236ms
 ✓ test/archivos-almacen.test.ts (19 tests) 156ms
 ✓ test/auth-guard.test.ts (40 tests) 159ms
 ✓ test/schema.test.ts (53 tests) 131ms
 ✓ test/triggers.test.ts (21 tests) 115ms
 ✓ test/guard-cobertura.test.ts (12 tests) 40ms
 ✓ test/permisos.test.ts (29 tests) 39ms
 ✓ test/humo.test.ts (3 tests) 22ms
 ✓ test/ip.test.ts (24 tests) 7ms
 ✓ test/permisos.unit.test.ts (48 tests) 4ms

⎯⎯⎯⎯⎯⎯ Failed Tests 15 ⎯⎯⎯⎯⎯⎯⎯

 FAIL  test/cedulas.test.ts > Cédulas contra Postgres real como legajos_app > permite repetir un número en el mismo legajo y audita el alta
Error: Failed query: insert into "legajos"."legajo" ("id", "anio", "correlativo", "fecha_deteccion", "observacion", "estado_id", "creado_por", "creado_en") values ($1, $2, $3, $4, $5, $6, $7, default) returning "id", "anio", "correlativo", "numero", "fecha_deteccion", "observacion", "estado_id", "creado_por", "creado_en"
params: 01a10c10-f839-7c15-8677-8f718e398b59,2095,13,2026-10-01,,019b76da-a800-7000-8001-000000000001,01a10c10-f80f-7db0-bdd0-a2a2bec2a2d1
 ❯ PostgresJsPreparedQuery.queryWithCache node_modules/.pnpm/drizzle-orm@0.45.3_postgres@3.4.9/node_modules/src/pg-core/session.ts:73:11
 ❯ node_modules/.pnpm/drizzle-orm@0.45.3_postgres@3.4.9/node_modules/src/postgres-js/session.ts:58:17
 ❯ src/server/servicios/legajos.ts:77:25
     75|         if (!estado) throw new ErrorValidacion('No hay un estado inici…
     76|         if (!contador) throw new Error('No se pudo numerar el legajo.'…
     77|         const [nuevo] = await tx.insert(legajo).values({
       |                         ^
     78|           id: uuidv7(), anio, correlativo: contador.ultimo, fecha_dete…
     79|           observacion: datos.observacion ?? null, estado_id: estado.id…
 ❯ scope node_modules/.pnpm/postgres@3.4.9/node_modules/postgres/src/index.js:260:18
 ❯ Function.begin node_modules/.pnpm/postgres@3.4.9/node_modules/postgres/src/index.js:243:14
 ❯ test/cedulas.test.ts:74:20

Caused by: PostgresError: duplicate key value violates unique constraint "legajo_anio_correlativo_unq"
 ❯ ErrorResponse node_modules/.pnpm/postgres@3.4.9/node_modules/postgres/src/connection.js:815:30
 ❯ handle node_modules/.pnpm/postgres@3.4.9/node_modules/postgres/src/connection.js:489:6
 ❯ Socket.data node_modules/.pnpm/postgres@3.4.9/node_modules/postgres/src/connection.js:324:9

⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯
Serialized Error: { severity_local: 'ERROR', severity: 'ERROR', code: '23505', detail: 'Key (anio, correlativo)=(2095, 13) already exists.', schema_name: 'legajos', table_name: 'legajo', constraint_name: 'legajo_anio_correlativo_unq', file: 'nbtinsert.c', routine: '_bt_check_unique', query: 'insert into "legajos"."legajo" ("id", "anio", "correlativo", "fecha_deteccion", "observacion", "estado_id", "creado_por", "creado_en") values ($1, $2, $3, $4, $5, $6, $7, default) returning "id", "anio", "correlativo", "numero", "fecha_deteccion", "observacion", "estado_id", "creado_por", "creado_en"', parameters: [ '01a10c10-f839-7c15-8677-8f718e398b59', '2095', '13', '2026-10-01', null, '019b76da-a800-7000-8001-000000000001', '01a10c10-f80f-7db0-bdd0-a2a2bec2a2d1' ], args: [ '01a10c10-f839-7c15-8677-8f718e398b59', 2095, 13, '2026-10-01', null, '019b76da-a800-7000-8001-000000000001', '01a10c10-f80f-7db0-bdd0-a2a2bec2a2d1' ], types: [ 2950, 23, 23, 1082, 25, 2950, 2950 ] }
⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯[1/15]⎯

 FAIL  test/cedulas.test.ts > Cédulas contra Postgres real como legajos_app > agregar una segunda original devuelve 409 sin desmarcar ni auditar un alta
Error: Failed query: insert into "legajos"."legajo" ("id", "anio", "correlativo", "fecha_deteccion", "observacion", "estado_id", "creado_por", "creado_en") values ($1, $2, $3, $4, $5, $6, $7, default) returning "id", "anio", "correlativo", "numero", "fecha_deteccion", "observacion", "estado_id", "creado_por", "creado_en"
params: 01a10c10-f841-7359-b744-5f713ef2ccd8,2095,13,2026-10-01,,019b76da-a800-7000-8001-000000000001,01a10c10-f80f-7db0-bdd0-a2a2bec2a2d1
 ❯ PostgresJsPreparedQuery.queryWithCache node_modules/.pnpm/drizzle-orm@0.45.3_postgres@3.4.9/node_modules/src/pg-core/session.ts:73:11
 ❯ node_modules/.pnpm/drizzle-orm@0.45.3_postgres@3.4.9/node_modules/src/postgres-js/session.ts:58:17
 ❯ src/server/servicios/legajos.ts:77:25
     75|         if (!estado) throw new ErrorValidacion('No hay un estado inici…
     76|         if (!contador) throw new Error('No se pudo numerar el legajo.'…
     77|         const [nuevo] = await tx.insert(legajo).values({
       |                         ^
     78|           id: uuidv7(), anio, correlativo: contador.ultimo, fecha_dete…
     79|           observacion: datos.observacion ?? null, estado_id: estado.id…
 ❯ scope node_modules/.pnpm/postgres@3.4.9/node_modules/postgres/src/index.js:260:18
 ❯ Function.begin node_modules/.pnpm/postgres@3.4.9/node_modules/postgres/src/index.js:243:14
 ❯ test/cedulas.test.ts:85:20

Caused by: PostgresError: duplicate key value violates unique constraint "legajo_anio_correlativo_unq"
 ❯ ErrorResponse node_modules/.pnpm/postgres@3.4.9/node_modules/postgres/src/connection.js:815:30
 ❯ handle node_modules/.pnpm/postgres@3.4.9/node_modules/postgres/src/connection.js:489:6
 ❯ Socket.data node_modules/.pnpm/postgres@3.4.9/node_modules/postgres/src/connection.js:324:9

⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯
Serialized Error: { severity_local: 'ERROR', severity: 'ERROR', code: '23505', detail: 'Key (anio, correlativo)=(2095, 13) already exists.', schema_name: 'legajos', table_name: 'legajo', constraint_name: 'legajo_anio_correlativo_unq', file: 'nbtinsert.c', routine: '_bt_check_unique', query: 'insert into "legajos"."legajo" ("id", "anio", "correlativo", "fecha_deteccion", "observacion", "estado_id", "creado_por", "creado_en") values ($1, $2, $3, $4, $5, $6, $7, default) returning "id", "anio", "correlativo", "numero", "fecha_deteccion", "observacion", "estado_id", "creado_por", "creado_en"', parameters: [ '01a10c10-f841-7359-b744-5f713ef2ccd8', '2095', '13', '2026-10-01', null, '019b76da-a800-7000-8001-000000000001', '01a10c10-f80f-7db0-bdd0-a2a2bec2a2d1' ], args: [ '01a10c10-f841-7359-b744-5f713ef2ccd8', 2095, 13, '2026-10-01', null, '019b76da-a800-7000-8001-000000000001', '01a10c10-f80f-7db0-bdd0-a2a2bec2a2d1' ], types: [ 2950, 23, 23, 1082, 25, 2950, 2950 ] }
⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯[2/15]⎯

 FAIL  test/cedulas.test.ts > Cédulas contra Postgres real como legajos_app > marcarOriginal cambia ambas filas con antes/después y dos auditorías
Error: Failed query: insert into "legajos"."legajo" ("id", "anio", "correlativo", "fecha_deteccion", "observacion", "estado_id", "creado_por", "creado_en") values ($1, $2, $3, $4, $5, $6, $7, default) returning "id", "anio", "correlativo", "numero", "fecha_deteccion", "observacion", "estado_id", "creado_por", "creado_en"
params: 01a10c10-f844-7400-9230-ccc4bf862fed,2095,13,2026-10-01,,019b76da-a800-7000-8001-000000000001,01a10c10-f80f-7db0-bdd0-a2a2bec2a2d1
 ❯ PostgresJsPreparedQuery.queryWithCache node_modules/.pnpm/drizzle-orm@0.45.3_postgres@3.4.9/node_modules/src/pg-core/session.ts:73:11
 ❯ node_modules/.pnpm/drizzle-orm@0.45.3_postgres@3.4.9/node_modules/src/postgres-js/session.ts:58:17
 ❯ src/server/servicios/legajos.ts:77:25
     75|         if (!estado) throw new ErrorValidacion('No hay un estado inici…
     76|         if (!contador) throw new Error('No se pudo numerar el legajo.'…
     77|         const [nuevo] = await tx.insert(legajo).values({
       |                         ^
     78|           id: uuidv7(), anio, correlativo: contador.ultimo, fecha_dete…
     79|           observacion: datos.observacion ?? null, estado_id: estado.id…
 ❯ scope node_modules/.pnpm/postgres@3.4.9/node_modules/postgres/src/index.js:260:18
 ❯ Function.begin node_modules/.pnpm/postgres@3.4.9/node_modules/postgres/src/index.js:243:14
 ❯ test/cedulas.test.ts:96:20

Caused by: PostgresError: duplicate key value violates unique constraint "legajo_anio_correlativo_unq"
 ❯ ErrorResponse node_modules/.pnpm/postgres@3.4.9/node_modules/postgres/src/connection.js:815:30
 ❯ handle node_modules/.pnpm/postgres@3.4.9/node_modules/postgres/src/connection.js:489:6
 ❯ Socket.data node_modules/.pnpm/postgres@3.4.9/node_modules/postgres/src/connection.js:324:9

⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯
Serialized Error: { severity_local: 'ERROR', severity: 'ERROR', code: '23505', detail: 'Key (anio, correlativo)=(2095, 13) already exists.', schema_name: 'legajos', table_name: 'legajo', constraint_name: 'legajo_anio_correlativo_unq', file: 'nbtinsert.c', routine: '_bt_check_unique', query: 'insert into "legajos"."legajo" ("id", "anio", "correlativo", "fecha_deteccion", "observacion", "estado_id", "creado_por", "creado_en") values ($1, $2, $3, $4, $5, $6, $7, default) returning "id", "anio", "correlativo", "numero", "fecha_deteccion", "observacion", "estado_id", "creado_por", "creado_en"', parameters: [ '01a10c10-f844-7400-9230-ccc4bf862fed', '2095', '13', '2026-10-01', null, '019b76da-a800-7000-8001-000000000001', '01a10c10-f80f-7db0-bdd0-a2a2bec2a2d1' ], args: [ '01a10c10-f844-7400-9230-ccc4bf862fed', 2095, 13, '2026-10-01', null, '019b76da-a800-7000-8001-000000000001', '01a10c10-f80f-7db0-bdd0-a2a2bec2a2d1' ], types: [ 2950, 23, 23, 1082, 25, 2950, 2950 ] }
⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯[3/15]⎯

 FAIL  test/cedulas.test.ts > Cédulas contra Postgres real como legajos_app > dos cambios concurrentes con original inicial=true dejan exactamente una
Error: Failed query: insert into "legajos"."legajo" ("id", "anio", "correlativo", "fecha_deteccion", "observacion", "estado_id", "creado_por", "creado_en") values ($1, $2, $3, $4, $5, $6, $7, default) returning "id", "anio", "correlativo", "numero", "fecha_deteccion", "observacion", "estado_id", "creado_por", "creado_en"
params: 01a10c10-f847-7eee-9938-5eaf3a25730d,2095,13,2026-10-01,,019b76da-a800-7000-8001-000000000001,01a10c10-f80f-7db0-bdd0-a2a2bec2a2d1
 ❯ PostgresJsPreparedQuery.queryWithCache node_modules/.pnpm/drizzle-orm@0.45.3_postgres@3.4.9/node_modules/src/pg-core/session.ts:73:11
 ❯ node_modules/.pnpm/drizzle-orm@0.45.3_postgres@3.4.9/node_modules/src/postgres-js/session.ts:58:17
 ❯ src/server/servicios/legajos.ts:77:25
     75|         if (!estado) throw new ErrorValidacion('No hay un estado inici…
     76|         if (!contador) throw new Error('No se pudo numerar el legajo.'…
     77|         const [nuevo] = await tx.insert(legajo).values({
       |                         ^
     78|           id: uuidv7(), anio, correlativo: contador.ultimo, fecha_dete…
     79|           observacion: datos.observacion ?? null, estado_id: estado.id…
 ❯ scope node_modules/.pnpm/postgres@3.4.9/node_modules/postgres/src/index.js:260:18
 ❯ Function.begin node_modules/.pnpm/postgres@3.4.9/node_modules/postgres/src/index.js:243:14
 ❯ test/cedulas.test.ts:111:20

Caused by: PostgresError: duplicate key value violates unique constraint "legajo_anio_correlativo_unq"
 ❯ ErrorResponse node_modules/.pnpm/postgres@3.4.9/node_modules/postgres/src/connection.js:815:30
 ❯ handle node_modules/.pnpm/postgres@3.4.9/node_modules/postgres/src/connection.js:489:6
 ❯ Socket.data node_modules/.pnpm/postgres@3.4.9/node_modules/postgres/src/connection.js:324:9

⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯
Serialized Error: { severity_local: 'ERROR', severity: 'ERROR', code: '23505', detail: 'Key (anio, correlativo)=(2095, 13) already exists.', schema_name: 'legajos', table_name: 'legajo', constraint_name: 'legajo_anio_correlativo_unq', file: 'nbtinsert.c', routine: '_bt_check_unique', query: 'insert into "legajos"."legajo" ("id", "anio", "correlativo", "fecha_deteccion", "observacion", "estado_id", "creado_por", "creado_en") values ($1, $2, $3, $4, $5, $6, $7, default) returning "id", "anio", "correlativo", "numero", "fecha_deteccion", "observacion", "estado_id", "creado_por", "creado_en"', parameters: [ '01a10c10-f847-7eee-9938-5eaf3a25730d', '2095', '13', '2026-10-01', null, '019b76da-a800-7000-8001-000000000001', '01a10c10-f80f-7db0-bdd0-a2a2bec2a2d1' ], args: [ '01a10c10-f847-7eee-9938-5eaf3a25730d', 2095, 13, '2026-10-01', null, '019b76da-a800-7000-8001-000000000001', '01a10c10-f80f-7db0-bdd0-a2a2bec2a2d1' ], types: [ 2950, 23, 23, 1082, 25, 2950, 2950 ] }
⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯[4/15]⎯

 FAIL  test/cedulas.test.ts > Cédulas contra Postgres real como legajos_app > dos cambios concurrentes con original inicial=false dejan exactamente una
Error: Failed query: insert into "legajos"."legajo" ("id", "anio", "correlativo", "fecha_deteccion", "observacion", "estado_id", "creado_por", "creado_en") values ($1, $2, $3, $4, $5, $6, $7, default) returning "id", "anio", "correlativo", "numero", "fecha_deteccion", "observacion", "estado_id", "creado_por", "creado_en"
params: 01a10c10-f849-77f3-ad47-f7ef57e97b08,2095,13,2026-10-01,,019b76da-a800-7000-8001-000000000001,01a10c10-f80f-7db0-bdd0-a2a2bec2a2d1
 ❯ PostgresJsPreparedQuery.queryWithCache node_modules/.pnpm/drizzle-orm@0.45.3_postgres@3.4.9/node_modules/src/pg-core/session.ts:73:11
 ❯ node_modules/.pnpm/drizzle-orm@0.45.3_postgres@3.4.9/node_modules/src/postgres-js/session.ts:58:17
 ❯ src/server/servicios/legajos.ts:77:25
     75|         if (!estado) throw new ErrorValidacion('No hay un estado inici…
     76|         if (!contador) throw new Error('No se pudo numerar el legajo.'…
     77|         const [nuevo] = await tx.insert(legajo).values({
       |                         ^
     78|           id: uuidv7(), anio, correlativo: contador.ultimo, fecha_dete…
     79|           observacion: datos.observacion ?? null, estado_id: estado.id…
 ❯ scope node_modules/.pnpm/postgres@3.4.9/node_modules/postgres/src/index.js:260:18
 ❯ Function.begin node_modules/.pnpm/postgres@3.4.9/node_modules/postgres/src/index.js:243:14
 ❯ test/cedulas.test.ts:111:20

Caused by: PostgresError: duplicate key value violates unique constraint "legajo_anio_correlativo_unq"
 ❯ ErrorResponse node_modules/.pnpm/postgres@3.4.9/node_modules/postgres/src/connection.js:815:30
 ❯ handle node_modules/.pnpm/postgres@3.4.9/node_modules/postgres/src/connection.js:489:6
 ❯ Socket.data node_modules/.pnpm/postgres@3.4.9/node_modules/postgres/src/connection.js:324:9

⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯
Serialized Error: { severity_local: 'ERROR', severity: 'ERROR', code: '23505', detail: 'Key (anio, correlativo)=(2095, 13) already exists.', schema_name: 'legajos', table_name: 'legajo', constraint_name: 'legajo_anio_correlativo_unq', file: 'nbtinsert.c', routine: '_bt_check_unique', query: 'insert into "legajos"."legajo" ("id", "anio", "correlativo", "fecha_deteccion", "observacion", "estado_id", "creado_por", "creado_en") values ($1, $2, $3, $4, $5, $6, $7, default) returning "id", "anio", "correlativo", "numero", "fecha_deteccion", "observacion", "estado_id", "creado_por", "creado_en"', parameters: [ '01a10c10-f849-77f3-ad47-f7ef57e97b08', '2095', '13', '2026-10-01', null, '019b76da-a800-7000-8001-000000000001', '01a10c10-f80f-7db0-bdd0-a2a2bec2a2d1' ], args: [ '01a10c10-f849-77f3-ad47-f7ef57e97b08', 2095, 13, '2026-10-01', null, '019b76da-a800-7000-8001-000000000001', '01a10c10-f80f-7db0-bdd0-a2a2bec2a2d1' ], types: [ 2950, 23, 23, 1082, 25, 2950, 2950 ] }
⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯[5/15]⎯

 FAIL  test/cedulas.test.ts > Cédulas contra Postgres real como legajos_app > dos altas originales concurrentes tienen un éxito y un conflicto
Error: Failed query: insert into "legajos"."legajo" ("id", "anio", "correlativo", "fecha_deteccion", "observacion", "estado_id", "creado_por", "creado_en") values ($1, $2, $3, $4, $5, $6, $7, default) returning "id", "anio", "correlativo", "numero", "fecha_deteccion", "observacion", "estado_id", "creado_por", "creado_en"
params: 01a10c10-f84b-7029-9b6b-e9d641ccfd2d,2095,13,2026-10-01,,019b76da-a800-7000-8001-000000000001,01a10c10-f80f-7db0-bdd0-a2a2bec2a2d1
 ❯ PostgresJsPreparedQuery.queryWithCache node_modules/.pnpm/drizzle-orm@0.45.3_postgres@3.4.9/node_modules/src/pg-core/session.ts:73:11
 ❯ node_modules/.pnpm/drizzle-orm@0.45.3_postgres@3.4.9/node_modules/src/postgres-js/session.ts:58:17
 ❯ src/server/servicios/legajos.ts:77:25
     75|         if (!estado) throw new ErrorValidacion('No hay un estado inici…
     76|         if (!contador) throw new Error('No se pudo numerar el legajo.'…
     77|         const [nuevo] = await tx.insert(legajo).values({
       |                         ^
     78|           id: uuidv7(), anio, correlativo: contador.ultimo, fecha_dete…
     79|           observacion: datos.observacion ?? null, estado_id: estado.id…
 ❯ scope node_modules/.pnpm/postgres@3.4.9/node_modules/postgres/src/index.js:260:18
 ❯ Function.begin node_modules/.pnpm/postgres@3.4.9/node_modules/postgres/src/index.js:243:14
 ❯ test/cedulas.test.ts:124:20

Caused by: PostgresError: duplicate key value violates unique constraint "legajo_anio_correlativo_unq"
 ❯ ErrorResponse node_modules/.pnpm/postgres@3.4.9/node_modules/postgres/src/connection.js:815:30
 ❯ handle node_modules/.pnpm/postgres@3.4.9/node_modules/postgres/src/connection.js:489:6
 ❯ Socket.data node_modules/.pnpm/postgres@3.4.9/node_modules/postgres/src/connection.js:324:9

⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯
Serialized Error: { severity_local: 'ERROR', severity: 'ERROR', code: '23505', detail: 'Key (anio, correlativo)=(2095, 13) already exists.', schema_name: 'legajos', table_name: 'legajo', constraint_name: 'legajo_anio_correlativo_unq', file: 'nbtinsert.c', routine: '_bt_check_unique', query: 'insert into "legajos"."legajo" ("id", "anio", "correlativo", "fecha_deteccion", "observacion", "estado_id", "creado_por", "creado_en") values ($1, $2, $3, $4, $5, $6, $7, default) returning "id", "anio", "correlativo", "numero", "fecha_deteccion", "observacion", "estado_id", "creado_por", "creado_en"', parameters: [ '01a10c10-f84b-7029-9b6b-e9d641ccfd2d', '2095', '13', '2026-10-01', null, '019b76da-a800-7000-8001-000000000001', '01a10c10-f80f-7db0-bdd0-a2a2bec2a2d1' ], args: [ '01a10c10-f84b-7029-9b6b-e9d641ccfd2d', 2095, 13, '2026-10-01', null, '019b76da-a800-7000-8001-000000000001', '01a10c10-f80f-7db0-bdd0-a2a2bec2a2d1' ], types: [ 2950, 23, 23, 1082, 25, 2950, 2950 ] }
⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯[6/15]⎯

 FAIL  test/cedulas.test.ts > Cédulas contra Postgres real como legajos_app > traduce el 23505 nativo del índice de original y revierte el alta
Error: Failed query: insert into "legajos"."legajo" ("id", "anio", "correlativo", "fecha_deteccion", "observacion", "estado_id", "creado_por", "creado_en") values ($1, $2, $3, $4, $5, $6, $7, default) returning "id", "anio", "correlativo", "numero", "fecha_deteccion", "observacion", "estado_id", "creado_por", "creado_en"
params: 01a10c10-f84e-78dd-a8b1-426e7c50e125,2095,13,2026-10-01,,019b76da-a800-7000-8001-000000000001,01a10c10-f80f-7db0-bdd0-a2a2bec2a2d1
 ❯ PostgresJsPreparedQuery.queryWithCache node_modules/.pnpm/drizzle-orm@0.45.3_postgres@3.4.9/node_modules/src/pg-core/session.ts:73:11
 ❯ node_modules/.pnpm/drizzle-orm@0.45.3_postgres@3.4.9/node_modules/src/postgres-js/session.ts:58:17
 ❯ src/server/servicios/legajos.ts:77:25
     75|         if (!estado) throw new ErrorValidacion('No hay un estado inici…
     76|         if (!contador) throw new Error('No se pudo numerar el legajo.'…
     77|         const [nuevo] = await tx.insert(legajo).values({
       |                         ^
     78|           id: uuidv7(), anio, correlativo: contador.ultimo, fecha_dete…
     79|           observacion: datos.observacion ?? null, estado_id: estado.id…
 ❯ scope node_modules/.pnpm/postgres@3.4.9/node_modules/postgres/src/index.js:260:18
 ❯ Function.begin node_modules/.pnpm/postgres@3.4.9/node_modules/postgres/src/index.js:243:14
 ❯ test/cedulas.test.ts:134:20

Caused by: PostgresError: duplicate key value violates unique constraint "legajo_anio_correlativo_unq"
 ❯ ErrorResponse node_modules/.pnpm/postgres@3.4.9/node_modules/postgres/src/connection.js:815:30
 ❯ handle node_modules/.pnpm/postgres@3.4.9/node_modules/postgres/src/connection.js:489:6
 ❯ Socket.data node_modules/.pnpm/postgres@3.4.9/node_modules/postgres/src/connection.js:324:9

⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯
Serialized Error: { severity_local: 'ERROR', severity: 'ERROR', code: '23505', detail: 'Key (anio, correlativo)=(2095, 13) already exists.', schema_name: 'legajos', table_name: 'legajo', constraint_name: 'legajo_anio_correlativo_unq', file: 'nbtinsert.c', routine: '_bt_check_unique', query: 'insert into "legajos"."legajo" ("id", "anio", "correlativo", "fecha_deteccion", "observacion", "estado_id", "creado_por", "creado_en") values ($1, $2, $3, $4, $5, $6, $7, default) returning "id", "anio", "correlativo", "numero", "fecha_deteccion", "observacion", "estado_id", "creado_por", "creado_en"', parameters: [ '01a10c10-f84e-78dd-a8b1-426e7c50e125', '2095', '13', '2026-10-01', null, '019b76da-a800-7000-8001-000000000001', '01a10c10-f80f-7db0-bdd0-a2a2bec2a2d1' ], args: [ '01a10c10-f84e-78dd-a8b1-426e7c50e125', 2095, 13, '2026-10-01', null, '019b76da-a800-7000-8001-000000000001', '01a10c10-f80f-7db0-bdd0-a2a2bec2a2d1' ], types: [ 2950, 23, 23, 1082, 25, 2950, 2950 ] }
⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯[7/15]⎯

 FAIL  test/cedulas.test.ts > Cédulas contra Postgres real como legajos_app > alta y marcado concurrentes preservan una sola original
Error: Failed query: insert into "legajos"."legajo" ("id", "anio", "correlativo", "fecha_deteccion", "observacion", "estado_id", "creado_por", "creado_en") values ($1, $2, $3, $4, $5, $6, $7, default) returning "id", "anio", "correlativo", "numero", "fecha_deteccion", "observacion", "estado_id", "creado_por", "creado_en"
params: 01a10c10-f853-7319-9890-c158ce87a260,2095,13,2026-10-01,,019b76da-a800-7000-8001-000000000001,01a10c10-f80f-7db0-bdd0-a2a2bec2a2d1
 ❯ PostgresJsPreparedQuery.queryWithCache node_modules/.pnpm/drizzle-orm@0.45.3_postgres@3.4.9/node_modules/src/pg-core/session.ts:73:11
 ❯ node_modules/.pnpm/drizzle-orm@0.45.3_postgres@3.4.9/node_modules/src/postgres-js/session.ts:58:17
 ❯ src/server/servicios/legajos.ts:77:25
     75|         if (!estado) throw new ErrorValidacion('No hay un estado inici…
     76|         if (!contador) throw new Error('No se pudo numerar el legajo.'…
     77|         const [nuevo] = await tx.insert(legajo).values({
       |                         ^
     78|           id: uuidv7(), anio, correlativo: contador.ultimo, fecha_dete…
     79|           observacion: datos.observacion ?? null, estado_id: estado.id…
 ❯ scope node_modules/.pnpm/postgres@3.4.9/node_modules/postgres/src/index.js:260:18
 ❯ Function.begin node_modules/.pnpm/postgres@3.4.9/node_modules/postgres/src/index.js:243:14
 ❯ test/cedulas.test.ts:172:20

Caused by: PostgresError: duplicate key value violates unique constraint "legajo_anio_correlativo_unq"
 ❯ ErrorResponse node_modules/.pnpm/postgres@3.4.9/node_modules/postgres/src/connection.js:815:30
 ❯ handle node_modules/.pnpm/postgres@3.4.9/node_modules/postgres/src/connection.js:489:6
 ❯ Socket.data node_modules/.pnpm/postgres@3.4.9/node_modules/postgres/src/connection.js:324:9

⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯
Serialized Error: { severity_local: 'ERROR', severity: 'ERROR', code: '23505', detail: 'Key (anio, correlativo)=(2095, 13) already exists.', schema_name: 'legajos', table_name: 'legajo', constraint_name: 'legajo_anio_correlativo_unq', file: 'nbtinsert.c', routine: '_bt_check_unique', query: 'insert into "legajos"."legajo" ("id", "anio", "correlativo", "fecha_deteccion", "observacion", "estado_id", "creado_por", "creado_en") values ($1, $2, $3, $4, $5, $6, $7, default) returning "id", "anio", "correlativo", "numero", "fecha_deteccion", "observacion", "estado_id", "creado_por", "creado_en"', parameters: [ '01a10c10-f853-7319-9890-c158ce87a260', '2095', '13', '2026-10-01', null, '019b76da-a800-7000-8001-000000000001', '01a10c10-f80f-7db0-bdd0-a2a2bec2a2d1' ], args: [ '01a10c10-f853-7319-9890-c158ce87a260', 2095, 13, '2026-10-01', null, '019b76da-a800-7000-8001-000000000001', '01a10c10-f80f-7db0-bdd0-a2a2bec2a2d1' ], types: [ 2950, 23, 23, 1082, 25, 2950, 2950 ] }
⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯[8/15]⎯

 FAIL  test/cedulas.test.ts > Cédulas contra Postgres real como legajos_app > editar sólo modifica los campos autorizados y preserva los opcionales omitidos
Error: Failed query: insert into "legajos"."legajo" ("id", "anio", "correlativo", "fecha_deteccion", "observacion", "estado_id", "creado_por", "creado_en") values ($1, $2, $3, $4, $5, $6, $7, default) returning "id", "anio", "correlativo", "numero", "fecha_deteccion", "observacion", "estado_id", "creado_por", "creado_en"
params: 01a10c10-f855-772f-891a-8a0cc33b6d18,2095,13,2026-10-01,,019b76da-a800-7000-8001-000000000001,01a10c10-f80f-7db0-bdd0-a2a2bec2a2d1
 ❯ PostgresJsPreparedQuery.queryWithCache node_modules/.pnpm/drizzle-orm@0.45.3_postgres@3.4.9/node_modules/src/pg-core/session.ts:73:11
 ❯ node_modules/.pnpm/drizzle-orm@0.45.3_postgres@3.4.9/node_modules/src/postgres-js/session.ts:58:17
 ❯ src/server/servicios/legajos.ts:77:25
     75|         if (!estado) throw new ErrorValidacion('No hay un estado inici…
     76|         if (!contador) throw new Error('No se pudo numerar el legajo.'…
     77|         const [nuevo] = await tx.insert(legajo).values({
       |                         ^
     78|           id: uuidv7(), anio, correlativo: contador.ultimo, fecha_dete…
     79|           observacion: datos.observacion ?? null, estado_id: estado.id…
 ❯ scope node_modules/.pnpm/postgres@3.4.9/node_modules/postgres/src/index.js:260:18
 ❯ Function.begin node_modules/.pnpm/postgres@3.4.9/node_modules/postgres/src/index.js:243:14
 ❯ test/cedulas.test.ts:184:20

Caused by: PostgresError: duplicate key value violates unique constraint "legajo_anio_correlativo_unq"
 ❯ ErrorResponse node_modules/.pnpm/postgres@3.4.9/node_modules/postgres/src/connection.js:815:30
 ❯ handle node_modules/.pnpm/postgres@3.4.9/node_modules/postgres/src/connection.js:489:6
 ❯ Socket.data node_modules/.pnpm/postgres@3.4.9/node_modules/postgres/src/connection.js:324:9

⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯
Serialized Error: { severity_local: 'ERROR', severity: 'ERROR', code: '23505', detail: 'Key (anio, correlativo)=(2095, 13) already exists.', schema_name: 'legajos', table_name: 'legajo', constraint_name: 'legajo_anio_correlativo_unq', file: 'nbtinsert.c', routine: '_bt_check_unique', query: 'insert into "legajos"."legajo" ("id", "anio", "correlativo", "fecha_deteccion", "observacion", "estado_id", "creado_por", "creado_en") values ($1, $2, $3, $4, $5, $6, $7, default) returning "id", "anio", "correlativo", "numero", "fecha_deteccion", "observacion", "estado_id", "creado_por", "creado_en"', parameters: [ '01a10c10-f855-772f-891a-8a0cc33b6d18', '2095', '13', '2026-10-01', null, '019b76da-a800-7000-8001-000000000001', '01a10c10-f80f-7db0-bdd0-a2a2bec2a2d1' ], args: [ '01a10c10-f855-772f-891a-8a0cc33b6d18', 2095, 13, '2026-10-01', null, '019b76da-a800-7000-8001-000000000001', '01a10c10-f80f-7db0-bdd0-a2a2bec2a2d1' ], types: [ 2950, 23, 23, 1082, 25, 2950, 2950 ] }
⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯[9/15]⎯

 FAIL  test/cedulas.test.ts > Cédulas contra Postgres real como legajos_app > anular la original deja el legajo sin original viva y permite marcar otra
Error: Failed query: insert into "legajos"."legajo" ("id", "anio", "correlativo", "fecha_deteccion", "observacion", "estado_id", "creado_por", "creado_en") values ($1, $2, $3, $4, $5, $6, $7, default) returning "id", "anio", "correlativo", "numero", "fecha_deteccion", "observacion", "estado_id", "creado_por", "creado_en"
params: 01a10c10-f858-7ead-ab4e-c58bd87245f9,2095,13,2026-10-01,,019b76da-a800-7000-8001-000000000001,01a10c10-f80f-7db0-bdd0-a2a2bec2a2d1
 ❯ PostgresJsPreparedQuery.queryWithCache node_modules/.pnpm/drizzle-orm@0.45.3_postgres@3.4.9/node_modules/src/pg-core/session.ts:73:11
 ❯ node_modules/.pnpm/drizzle-orm@0.45.3_postgres@3.4.9/node_modules/src/postgres-js/session.ts:58:17
 ❯ src/server/servicios/legajos.ts:77:25
     75|         if (!estado) throw new ErrorValidacion('No hay un estado inici…
     76|         if (!contador) throw new Error('No se pudo numerar el legajo.'…
     77|         const [nuevo] = await tx.insert(legajo).values({
       |                         ^
     78|           id: uuidv7(), anio, correlativo: contador.ultimo, fecha_dete…
     79|           observacion: datos.observacion ?? null, estado_id: estado.id…
 ❯ scope node_modules/.pnpm/postgres@3.4.9/node_modules/postgres/src/index.js:260:18
 ❯ Function.begin node_modules/.pnpm/postgres@3.4.9/node_modules/postgres/src/index.js:243:14
 ❯ test/cedulas.test.ts:205:20

Caused by: PostgresError: duplicate key value violates unique constraint "legajo_anio_correlativo_unq"
 ❯ ErrorResponse node_modules/.pnpm/postgres@3.4.9/node_modules/postgres/src/connection.js:815:30
 ❯ handle node_modules/.pnpm/postgres@3.4.9/node_modules/postgres/src/connection.js:489:6
 ❯ Socket.data node_modules/.pnpm/postgres@3.4.9/node_modules/postgres/src/connection.js:324:9

⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯
Serialized Error: { severity_local: 'ERROR', severity: 'ERROR', code: '23505', detail: 'Key (anio, correlativo)=(2095, 13) already exists.', schema_name: 'legajos', table_name: 'legajo', constraint_name: 'legajo_anio_correlativo_unq', file: 'nbtinsert.c', routine: '_bt_check_unique', query: 'insert into "legajos"."legajo" ("id", "anio", "correlativo", "fecha_deteccion", "observacion", "estado_id", "creado_por", "creado_en") values ($1, $2, $3, $4, $5, $6, $7, default) returning "id", "anio", "correlativo", "numero", "fecha_deteccion", "observacion", "estado_id", "creado_por", "creado_en"', parameters: [ '01a10c10-f858-7ead-ab4e-c58bd87245f9', '2095', '13', '2026-10-01', null, '019b76da-a800-7000-8001-000000000001', '01a10c10-f80f-7db0-bdd0-a2a2bec2a2d1' ], args: [ '01a10c10-f858-7ead-ab4e-c58bd87245f9', 2095, 13, '2026-10-01', null, '019b76da-a800-7000-8001-000000000001', '01a10c10-f80f-7db0-bdd0-a2a2bec2a2d1' ], types: [ 2950, 23, 23, 1082, 25, 2950, 2950 ] }
⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯[10/15]⎯

 FAIL  test/cedulas.test.ts > Cédulas contra Postgres real como legajos_app > anular exige motivo y rechaza editar, marcar o anular una cédula ya anulada
Error: Failed query: insert into "legajos"."legajo" ("id", "anio", "correlativo", "fecha_deteccion", "observacion", "estado_id", "creado_por", "creado_en") values ($1, $2, $3, $4, $5, $6, $7, default) returning "id", "anio", "correlativo", "numero", "fecha_deteccion", "observacion", "estado_id", "creado_por", "creado_en"
params: 01a10c10-f859-7306-ae74-498a1a298a06,2095,13,2026-10-01,,019b76da-a800-7000-8001-000000000001,01a10c10-f80f-7db0-bdd0-a2a2bec2a2d1
 ❯ PostgresJsPreparedQuery.queryWithCache node_modules/.pnpm/drizzle-orm@0.45.3_postgres@3.4.9/node_modules/src/pg-core/session.ts:73:11
 ❯ node_modules/.pnpm/drizzle-orm@0.45.3_postgres@3.4.9/node_modules/src/postgres-js/session.ts:58:17
 ❯ src/server/servicios/legajos.ts:77:25
     75|         if (!estado) throw new ErrorValidacion('No hay un estado inici…
     76|         if (!contador) throw new Error('No se pudo numerar el legajo.'…
     77|         const [nuevo] = await tx.insert(legajo).values({
       |                         ^
     78|           id: uuidv7(), anio, correlativo: contador.ultimo, fecha_dete…
     79|           observacion: datos.observacion ?? null, estado_id: estado.id…
 ❯ scope node_modules/.pnpm/postgres@3.4.9/node_modules/postgres/src/index.js:260:18
 ❯ Function.begin node_modules/.pnpm/postgres@3.4.9/node_modules/postgres/src/index.js:243:14
 ❯ test/cedulas.test.ts:221:20

Caused by: PostgresError: duplicate key value violates unique constraint "legajo_anio_correlativo_unq"
 ❯ ErrorResponse node_modules/.pnpm/postgres@3.4.9/node_modules/postgres/src/connection.js:815:30
 ❯ handle node_modules/.pnpm/postgres@3.4.9/node_modules/postgres/src/connection.js:489:6
 ❯ Socket.data node_modules/.pnpm/postgres@3.4.9/node_modules/postgres/src/connection.js:324:9

⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯
Serialized Error: { severity_local: 'ERROR', severity: 'ERROR', code: '23505', detail: 'Key (anio, correlativo)=(2095, 13) already exists.', schema_name: 'legajos', table_name: 'legajo', constraint_name: 'legajo_anio_correlativo_unq', file: 'nbtinsert.c', routine: '_bt_check_unique', query: 'insert into "legajos"."legajo" ("id", "anio", "correlativo", "fecha_deteccion", "observacion", "estado_id", "creado_por", "creado_en") values ($1, $2, $3, $4, $5, $6, $7, default) returning "id", "anio", "correlativo", "numero", "fecha_deteccion", "observacion", "estado_id", "creado_por", "creado_en"', parameters: [ '01a10c10-f859-7306-ae74-498a1a298a06', '2095', '13', '2026-10-01', null, '019b76da-a800-7000-8001-000000000001', '01a10c10-f80f-7db0-bdd0-a2a2bec2a2d1' ], args: [ '01a10c10-f859-7306-ae74-498a1a298a06', 2095, 13, '2026-10-01', null, '019b76da-a800-7000-8001-000000000001', '01a10c10-f80f-7db0-bdd0-a2a2bec2a2d1' ], types: [ 2950, 23, 23, 1082, 25, 2950, 2950 ] }
⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯[11/15]⎯

 FAIL  test/cedulas.test.ts > Cédulas contra Postgres real como legajos_app > consulta no crea ni edita ni marca; operador no anula
Error: Failed query: insert into "legajos"."legajo" ("id", "anio", "correlativo", "fecha_deteccion", "observacion", "estado_id", "creado_por", "creado_en") values ($1, $2, $3, $4, $5, $6, $7, default) returning "id", "anio", "correlativo", "numero", "fecha_deteccion", "observacion", "estado_id", "creado_por", "creado_en"
params: 01a10c10-f85b-752c-80ad-e5dbbe2d3396,2095,13,2026-10-01,,019b76da-a800-7000-8001-000000000001,01a10c10-f80f-7db0-bdd0-a2a2bec2a2d1
 ❯ PostgresJsPreparedQuery.queryWithCache node_modules/.pnpm/drizzle-orm@0.45.3_postgres@3.4.9/node_modules/src/pg-core/session.ts:73:11
 ❯ node_modules/.pnpm/drizzle-orm@0.45.3_postgres@3.4.9/node_modules/src/postgres-js/session.ts:58:17
 ❯ src/server/servicios/legajos.ts:77:25
     75|         if (!estado) throw new ErrorValidacion('No hay un estado inici…
     76|         if (!contador) throw new Error('No se pudo numerar el legajo.'…
     77|         const [nuevo] = await tx.insert(legajo).values({
       |                         ^
     78|           id: uuidv7(), anio, correlativo: contador.ultimo, fecha_dete…
     79|           observacion: datos.observacion ?? null, estado_id: estado.id…
 ❯ scope node_modules/.pnpm/postgres@3.4.9/node_modules/postgres/src/index.js:260:18
 ❯ Function.begin node_modules/.pnpm/postgres@3.4.9/node_modules/postgres/src/index.js:243:14
 ❯ test/cedulas.test.ts:232:20

Caused by: PostgresError: duplicate key value violates unique constraint "legajo_anio_correlativo_unq"
 ❯ ErrorResponse node_modules/.pnpm/postgres@3.4.9/node_modules/postgres/src/connection.js:815:30
 ❯ handle node_modules/.pnpm/postgres@3.4.9/node_modules/postgres/src/connection.js:489:6
 ❯ Socket.data node_modules/.pnpm/postgres@3.4.9/node_modules/postgres/src/connection.js:324:9

⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯
Serialized Error: { severity_local: 'ERROR', severity: 'ERROR', code: '23505', detail: 'Key (anio, correlativo)=(2095, 13) already exists.', schema_name: 'legajos', table_name: 'legajo', constraint_name: 'legajo_anio_correlativo_unq', file: 'nbtinsert.c', routine: '_bt_check_unique', query: 'insert into "legajos"."legajo" ("id", "anio", "correlativo", "fecha_deteccion", "observacion", "estado_id", "creado_por", "creado_en") values ($1, $2, $3, $4, $5, $6, $7, default) returning "id", "anio", "correlativo", "numero", "fecha_deteccion", "observacion", "estado_id", "creado_por", "creado_en"', parameters: [ '01a10c10-f85b-752c-80ad-e5dbbe2d3396', '2095', '13', '2026-10-01', null, '019b76da-a800-7000-8001-000000000001', '01a10c10-f80f-7db0-bdd0-a2a2bec2a2d1' ], args: [ '01a10c10-f85b-752c-80ad-e5dbbe2d3396', 2095, 13, '2026-10-01', null, '019b76da-a800-7000-8001-000000000001', '01a10c10-f80f-7db0-bdd0-a2a2bec2a2d1' ], types: [ 2950, 23, 23, 1082, 25, 2950, 2950 ] }
⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯[12/15]⎯

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

⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯[13/15]⎯

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

⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯[14/15]⎯

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

⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯[15/15]⎯


 Test Files  2 failed | 17 passed (19)
      Tests  15 failed | 419 passed (434)
   Start at  09:36:24
   Duration  20.09s (transform 321ms, setup 0ms, collect 3.82s, tests 11.91s, environment 2ms, prepare 720ms)

 ELIFECYCLE  Test failed. See above for more details.
 ELIFECYCLE  Command failed with exit code 1.
```

### Verificación final — base aislada

Creación local (código de salida **0**):

```text
Base local aislada creada: legajos_l08a_codex_20261005
```

Comando: `pnpm verificar`, con las tres variables XDG bajo `legajos/node_modules/.cache` y las tres `TEST_*_URL` apuntando a `legajos_l08a_codex_20261005`. Código de salida: **0**.

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
 ✓ test/legajos.test.ts (17 tests) 329ms
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

 ✓ test/cedulas.test.ts (14 tests) 257ms
 ✓ test/login.test.ts (14 tests) 3633ms
   ✓ Login y cambio de clave con Postgres real como legajos_app > cinco fallos bloquean; la clave correcta no pasa hasta +16 minutos  367ms
   ✓ Login y cambio de clave con Postgres real como legajos_app > inexistente usa señuelo, con mediana de cinco muestras a menos del 30%  451ms
   ✓ Login y cambio de clave con Postgres real como legajos_app > 20 fallos por IP, el 21 no verifica ni modifica cuenta; ventana vencida reinicia  942ms
   ✓ Login y cambio de clave con Postgres real como legajos_app > 25 concurrentes desde una IP: sólo 20 verifican argon2  884ms
 ✓ test/logout-y-cli.test.ts (12 tests) 2813ms
   ✓ Logout y recuperación administrativa > CLI imprime una clave de 16 caracteres una vez, agrega IPv6 y cierra todas las sesiones  486ms
   ✓ Logout y recuperación administrativa > CLI normaliza IPv4-mapped y agrega /32  347ms
   ✓ Logout y recuperación administrativa > CLI rechaza usuario no admin, sin modificaciones ni clave en stdout  345ms
   ✓ Logout y recuperación administrativa > CLI rechaza legajos online y acepta la aplicación detenida  739ms
   ✓ Logout y recuperación administrativa > CLI falla si el lock está ocupado  345ms
 ✓ test/documentos.test.ts (43 tests) 1178ms
 ✓ test/admin.test.ts (18 tests) 1048ms
   ✓ Administración contra Postgres real como legajos_app > dos admins que se desactivan mutuamente en paralelo dejan al menos uno activo  369ms
 ✓ test/archivos-validar.test.ts (15 tests) 706ms
 ✓ test/acciones.test.ts (24 tests) 508ms
 ✓ test/rutas-documentos.test.ts (16 tests) 394ms
 ✓ test/interacciones.test.ts (12 tests) 239ms
 ✓ test/auth-guard.test.ts (40 tests) 155ms
 ✓ test/archivos-almacen.test.ts (19 tests) 154ms
 ✓ test/schema.test.ts (53 tests) 131ms
 ✓ test/triggers.test.ts (21 tests) 113ms
 ✓ test/guard-cobertura.test.ts (12 tests) 40ms
 ✓ test/permisos.test.ts (29 tests) 40ms
 ✓ test/humo.test.ts (3 tests) 22ms
 ✓ test/ip.test.ts (24 tests) 7ms
 ✓ test/permisos.unit.test.ts (48 tests) 4ms

 Test Files  19 passed (19)
      Tests  434 passed (434)
   Start at  09:38:07
   Duration  19.94s (transform 324ms, setup 0ms, collect 3.79s, tests 11.77s, environment 2ms, prepare 714ms)

$ next build
 ⚠ Warning: Next.js inferred your workspace root, but it may not be correct.
 We detected multiple lockfiles and selected the directory of /home/ecenturion/pnpm-lock.yaml as the root directory.
 To silence this warning, set `outputFileTracingRoot` in your Next.js config, or consider removing one of the lockfiles if it's not needed.
   See https://nextjs.org/docs/app/api-reference/config/next-config-js/output#caveats for more information.
 Detected additional lockfiles: 
   * /home/ecenturion/develop/legajos/pnpm-lock.yaml

   ▲ Next.js 15.5.27

   Creating an optimized production build ...
 ✓ Compiled successfully in 2.1s
   Linting and checking validity of types ...
   Collecting page data ...
   Generating static pages (0/7) ...
   Generating static pages (1/7) 
   Generating static pages (3/7) 
   Generating static pages (5/7) 
 ✓ Generating static pages (7/7)
   Finalizing page optimization ...
   Collecting build traces ...

Route (app)                                 Size  First Load JS
┌ ○ /                                      144 B         103 kB
├ ○ /_not-found                            996 B         104 kB
├ ƒ /api/archivos/[id]                     144 B         103 kB
├ ƒ /api/documentos                        144 B         103 kB
├ ƒ /cuenta/clave                          144 B         103 kB
├ ƒ /legajos                               144 B         103 kB
├ ○ /login                                 688 B         104 kB
└ ƒ /logout                                144 B         103 kB
+ First Load JS shared by all             103 kB
  ├ chunks/758-942e49721ce48ac0.js       46.5 kB
  ├ chunks/d36d6ee9-817a06892149dc1d.js  54.4 kB
  └ other shared chunks (total)          1.87 kB


ƒ Middleware                             34.1 kB

○  (Static)   prerendered as static content
ƒ  (Dynamic)  server-rendered on demand

```
