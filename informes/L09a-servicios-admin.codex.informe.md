# Informe — L09a-servicios-admin

**Estado:** COMPLETADO
**Implementador:** CODEX, sombrero B
**Verificación final:** `pnpm verificar`, código de salida 0. Lint, typecheck, 397 pruebas de 17 suites y build completados; 17 pruebas nuevas de administración.

## Archivos

Creados, relativos a `legajos/`:

- `src/server/servicios/admin.ts`
- `test/admin.test.ts`

Modificados, relativos a `legajos/`:

- `src/server/servicios/contratos.ts`: se agregaron validadores, tipos de entrada/salida y `ServiciosAdmin`.
- `src/server/servicios/mapeo.ts`: se agregaron los mapeos administrativos.

Este informe es la única escritura realizada en `legajos-agents/`.

## Decisiones y cobertura

- Las 16 funciones comprueban primero su permiso con `exigir`. Cada operación usa una transacción y registra auditoría en ella, incluidas las vistas y los cierres de sesiones. Los tests de servicios usan Postgres real como `legajos_app`; el owner sólo prepara y restaura fixtures.
- Las claves temporales tienen 16 caracteres: 12 bytes de `randomBytes`, codificados en base64url y hasheados con `hashear`. Se devuelven solamente al crear/resetear. Todas las lecturas, retornos de UPDATE/INSERT y auditorías de usuario usan una proyección explícita sin hash. Los cierres de sesiones tampoco proyectan tokens.
- Se bloquean los admins activos con `FOR UPDATE` en orden de id antes de bloquear al destinatario. Se vuelve a consultar al actor para rechazar una petición cuyo admin fue desactivado o perdió su rol mientras esperaba. La prueba concurrente confirma un éxito, un conflicto y un admin activo.
- Las IPs se validan con el mismo criterio de `ip.ts`, se normalizan los bits de host y se convierten las formas IPv4-mapped a IPv4. Un bloqueo del usuario serializa altas/desactivaciones de IP; también se bloquean sus IPs con `FOR UPDATE`. Se prueban duplicados concurrentes y protección concurrente de la última IP.
- Desactivar una IP no cierra sesiones inmediatamente. El test comprueba que la sesión sigue abierta hasta el próximo `requerirSesion`, que devuelve 401, la cierra y escribe `sesion_ip_rechazada`.
- Los catálogos sólo actualizan columnas con grant. Los conflictos de índices únicos se traducen a `nombre_existente`. La protección del último estado también se prueba con dos desactivaciones concurrentes.
- Los visores devuelven `{ filas, total, pagina, porPagina }`, usan rangos ISO de fecha/hora con zona, límites inclusivos, orden descendente por fecha/id y una transacción repeatable read para mantener consistente el total con las filas. La auditoría devuelve `nombreUsuario`, `antes` y `despues`.
- Los casos que crean catálogos usan savepoints reales como app y rollback exterior para conservar la semilla de otras suites. El único fixture histórico de legajo, requerido para probar `verLegajo` con tipos desactivados, también queda dentro de ese rollback: no reserva años ni utiliza el contador de numeración.
- La fábrica administrativa acepta la capacidad `transaction` de la base, permitiendo usar tanto la conexión normal como una transacción real en esos tests, sin mocks de consultas ni casts inseguros.
- La búsqueda con `JSON.stringify` sobre todas las filas de auditoría comprueba ausencia de claves temporales, hashes, tokens y hashes de tokens.

## Incidencias resueltas y pendientes

El primer intento de `pnpm typecheck` terminó con:

```text
[ERROR] unable to open database file
For help, run: pnpm help run
```

Se dirigieron los directorios de pnpm/XDG a `legajos/node_modules/.cache/` para respetar el alcance de escritura. No se modificaron archivos de configuración ni dependencias.

La primera verificación completa falló por una base de tests reutilizada (correlativos de 2090/2092 ya avanzados), por el fixture histórico inicialmente ubicado en 2091 y por catálogos nuevos persistidos que interferían con la prueba de semilla exacta. Se corrigieron los fixtures usando rollback real y se recreó exclusivamente el Postgres local de `compose.test.yml`:

```sh
cd legajos
docker compose -f compose.test.yml down && docker compose -f compose.test.yml up -d --wait
```

La segunda verificación completa pasó. La salida conserva los NOTICE/WARNING de migración y la advertencia de Next sobre múltiples lockfiles.

**No quedó trabajo de implementación pendiente.** No se hizo commit, push ni auditoría del propio código. La auditoría independiente queda a cargo de AGY y el arquitecto, según la spec.

## Comando de verificación

Desde `/home/ecenturion/develop/legajos`:

```sh
export PNPM_HOME=/home/ecenturion/develop/legajos/node_modules/.cache/pnpm
export XDG_DATA_HOME=/home/ecenturion/develop/legajos/node_modules/.cache/data
export XDG_CACHE_HOME=/home/ecenturion/develop/legajos/node_modules/.cache
export XDG_STATE_HOME=/home/ecenturion/develop/legajos/node_modules/.cache/state
pnpm verificar
```

## Salida real — primera verificación (exit 1)

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
 ✓ test/login.test.ts (14 tests) 3622ms
   ✓ Login y cambio de clave con Postgres real como legajos_app > cinco fallos bloquean; la clave correcta no pasa hasta +16 minutos  376ms
   ✓ Login y cambio de clave con Postgres real como legajos_app > inexistente usa señuelo, con mediana de cinco muestras a menos del 30%  443ms
   ✓ Login y cambio de clave con Postgres real como legajos_app > 20 fallos por IP, el 21 no verifica ni modifica cuenta; ventana vencida reinicia  930ms
   ✓ Login y cambio de clave con Postgres real como legajos_app > 25 concurrentes desde una IP: sólo 20 verifican argon2  886ms
 ✓ test/logout-y-cli.test.ts (12 tests) 2812ms
   ✓ Logout y recuperación administrativa > CLI imprime una clave de 16 caracteres una vez, agrega IPv6 y cierra todas las sesiones  483ms
   ✓ Logout y recuperación administrativa > CLI normaliza IPv4-mapped y agrega /32  347ms
   ✓ Logout y recuperación administrativa > CLI rechaza usuario no admin, sin modificaciones ni clave en stdout  344ms
   ✓ Logout y recuperación administrativa > CLI rechaza legajos online y acepta la aplicación detenida  749ms
   ✓ Logout y recuperación administrativa > CLI falla si el lock está ocupado  343ms
 ✓ test/documentos.test.ts (43 tests) 1174ms
 ✓ test/admin.test.ts (17 tests) 715ms
 ✓ test/archivos-validar.test.ts (15 tests) 701ms
 ✓ test/rutas-documentos.test.ts (16 tests) 431ms
 ❯ test/legajos.test.ts (17 tests | 3 failed) 293ms
   ✓ Legajos contra Postgres real como legajos_app > usa el rol app sin heredar owner 1ms
   × Legajos contra Postgres real como legajos_app > dos legajos empiezan en AAAA-0001 y AAAA-0002 24ms
     → expected [ '2090-0003', '2090-0004' ] to deeply equal [ '2090-0001', '2090-0002' ]
   × Legajos contra Postgres real como legajos_app > 10 altas concurrentes reservan correlativos 1..10 sin repetidos 12ms
     → Failed query: insert into "legajos"."legajo" ("id", "anio", "correlativo", "fecha_deteccion", "observacion", "estado_id", "creado_por", "creado_en") values ($1, $2, $3, $4, $5, $6, $7, default) returning "id", "anio", "correlativo", "numero", "fecha_deteccion", "observacion", "estado_id", "creado_por", "creado_en"
params: 01a10bf7-c58f-7a5b-9c29-936ebf49acd2,2091,11,2026-10-01,,019b76da-a800-7000-8001-000000000001,01a10bf7-c550-77ce-8ad0-695dd4f5bf1a
   × Legajos contra Postgres real como legajos_app > el primer legajo del año siguiente vuelve al correlativo 1 14ms
     → expected '2092-0002' to be '2092-0001' // Object.is equality
   ✓ Legajos contra Postgres real como legajos_app > usa el año de Asunción aunque el instante en UTC ya sea 2027 17ms
   ✓ Legajos contra Postgres real como legajos_app > rechaza sin cédulas y con dos originales antes de escribir 2ms
   ✓ Legajos contra Postgres real como legajos_app > audita el legajo y todas sus cédulas y devuelve UUIDv7 y fechas ISO 11ms
   ✓ Legajos contra Postgres real como legajos_app > relaciona sin duplicar y sólo por números de cédulas vivas 48ms
   ✓ Legajos contra Postgres real como legajos_app > encuentra José buscando jose, por prefijo y con filtros combinados AND 19ms
   ✓ Legajos contra Postgres real como legajos_app > trata % como literal en la búsqueda 19ms
   ✓ Legajos contra Postgres real como legajos_app > trata _ como literal en la búsqueda 15ms
   ✓ Legajos contra Postgres real como legajos_app > trata \ como literal en la búsqueda 17ms
   ✓ Legajos contra Postgres real como legajos_app > pagina con total exacto, sin duplicados y de más nuevo a más antiguo 25ms
   ✓ Legajos contra Postgres real como legajos_app > audita vistas y consultas incluso sin resultados 12ms
   ✓ Legajos contra Postgres real como legajos_app > consulta no crea ni edita; el guard entrega el contexto sin elevar permisos 5ms
   ✓ Legajos contra Postgres real como legajos_app > editarLegajo preserva estado y campos omitidos; el grant bloquea cambios de estado 11ms
   ✓ Legajos contra Postgres real como legajos_app > ver inexistente devuelve 404 y valida los UUID y el paginado 2ms
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

 ✓ test/cedulas.test.ts (14 tests) 254ms
 ✓ test/interacciones.test.ts (12 tests) 232ms
 ✓ test/archivos-almacen.test.ts (19 tests) 167ms
 ✓ test/auth-guard.test.ts (40 tests) 151ms
 ✓ test/schema.test.ts (53 tests) 127ms
 ❯ test/triggers.test.ts (21 tests | 1 failed) 117ms
   ✓ Triggers y catálogos (operaciones como legajos_app) > conecta como legajos_app 10ms
   ✓ Triggers y catálogos (operaciones como legajos_app) > cambia el estado y rechaza un anterior desactualizado sin alterar el legajo 9ms
   ✓ Triggers y catálogos (operaciones como legajos_app) > una interacción sin cambio de estado no escribe en el legajo 3ms
   ✓ Triggers y catálogos (operaciones como legajos_app) > anular una interacción conserva el estado alcanzado 2ms
   ✓ Triggers y catálogos (operaciones como legajos_app) > serializa dos cambios con el mismo estado anterior y el segundo falla tras esperar 23ms
   ✓ Triggers y catálogos (operaciones como legajos_app) > acepta una versión de un documento vivo del mismo legajo y tipo 4ms
   ✓ Triggers y catálogos (operaciones como legajos_app) > rechaza versión con anterior inexistente 3ms
   ✓ Triggers y catálogos (operaciones como legajos_app) > rechaza versión con anterior anulado 3ms
   ✓ Triggers y catálogos (operaciones como legajos_app) > rechaza versión con anterior otro legajo 2ms
   ✓ Triggers y catálogos (operaciones como legajos_app) > rechaza versión con anterior otro tipo 2ms
   ✓ Triggers y catálogos (operaciones como legajos_app) > acepta solicitudes pendientes y documentos del legajo y tipo correctos 4ms
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
     → expected [ { …(4) }, { …(4) }, { …(4) }, …(4) ] to deeply equal [ { …(4) }, { …(4) }, { …(4) }, …(2) ]
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
Error: Failed query: insert into "legajos"."legajo" ("id", "anio", "correlativo", "fecha_deteccion", "observacion", "estado_id", "creado_por", "creado_en") values ($1, $2, $3, $4, $5, $6, $7, default) returning "id", "anio", "correlativo", "numero", "fecha_deteccion", "observacion", "estado_id", "creado_por", "creado_en"
params: 01a10bf7-c58f-7a5b-9c29-936ebf49acd2,2091,11,2026-10-01,,019b76da-a800-7000-8001-000000000001,01a10bf7-c550-77ce-8ad0-695dd4f5bf1a
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
 ❯ test/legajos.test.ts:85:24

Caused by: PostgresError: duplicate key value violates unique constraint "legajo_anio_correlativo_unq"
 ❯ ErrorResponse node_modules/.pnpm/postgres@3.4.9/node_modules/postgres/src/connection.js:815:30
 ❯ handle node_modules/.pnpm/postgres@3.4.9/node_modules/postgres/src/connection.js:489:6
 ❯ Socket.data node_modules/.pnpm/postgres@3.4.9/node_modules/postgres/src/connection.js:324:9

⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯
Serialized Error: { severity_local: 'ERROR', severity: 'ERROR', code: '23505', detail: 'Key (anio, correlativo)=(2091, 11) already exists.', schema_name: 'legajos', table_name: 'legajo', constraint_name: 'legajo_anio_correlativo_unq', file: 'nbtinsert.c', routine: '_bt_check_unique', query: 'insert into "legajos"."legajo" ("id", "anio", "correlativo", "fecha_deteccion", "observacion", "estado_id", "creado_por", "creado_en") values ($1, $2, $3, $4, $5, $6, $7, default) returning "id", "anio", "correlativo", "numero", "fecha_deteccion", "observacion", "estado_id", "creado_por", "creado_en"', parameters: [ '01a10bf7-c58f-7a5b-9c29-936ebf49acd2', '2091', '11', '2026-10-01', null, '019b76da-a800-7000-8001-000000000001', '01a10bf7-c550-77ce-8ad0-695dd4f5bf1a' ], args: [ '01a10bf7-c58f-7a5b-9c29-936ebf49acd2', 2091, 11, '2026-10-01', null, '019b76da-a800-7000-8001-000000000001', '01a10bf7-c550-77ce-8ad0-695dd4f5bf1a' ], types: [ 2950, 23, 23, 1082, 25, 2950, 2950 ] }
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
AssertionError: expected [ { …(4) }, { …(4) }, { …(4) }, …(4) ] to deeply equal [ { …(4) }, { …(4) }, { …(4) }, …(2) ]

- Expected
+ Received

@@ -27,6 +27,18 @@
      "activo": true,
      "id": "019b76da-a800-7000-8001-000000000005",
      "nombre": "Archivado",
      "orden": 5,
    },
+   {
+     "activo": false,
+     "id": "01a10bf6-dae2-7e37-8126-77c3bce37d90",
+     "nombre": "l09-82f822d2e860f5a9",
+     "orden": 92,
+   },
+   {
+     "activo": false,
+     "id": "01a10bf7-bbb0-7b9d-938f-6625ce700ec4",
+     "nombre": "l09-c9834c3ef7929c90",
+     "orden": 92,
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


 Test Files  2 failed | 15 passed (17)
      Tests  4 failed | 393 passed (397)
   Start at  09:08:56
   Duration  17.99s (transform 300ms, setup 0ms, collect 3.16s, tests 10.87s, environment 2ms, prepare 641ms)

 ELIFECYCLE  Test failed. See above for more details.
 ELIFECYCLE  Command failed with exit code 1.
```

## Salida real — verificación final (exit 0)

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
 ✓ test/legajos.test.ts (17 tests) 334ms
 ✓ test/triggers.test.ts (21 tests) 107ms
 ✓ test/login.test.ts (14 tests) 3622ms
   ✓ Login y cambio de clave con Postgres real como legajos_app > cinco fallos bloquean; la clave correcta no pasa hasta +16 minutos  374ms
   ✓ Login y cambio de clave con Postgres real como legajos_app > inexistente usa señuelo, con mediana de cinco muestras a menos del 30%  442ms
   ✓ Login y cambio de clave con Postgres real como legajos_app > 20 fallos por IP, el 21 no verifica ni modifica cuenta; ventana vencida reinicia  933ms
   ✓ Login y cambio de clave con Postgres real como legajos_app > 25 concurrentes desde una IP: sólo 20 verifican argon2  885ms
 ✓ test/logout-y-cli.test.ts (12 tests) 2821ms
   ✓ Logout y recuperación administrativa > CLI imprime una clave de 16 caracteres una vez, agrega IPv6 y cierra todas las sesiones  481ms
   ✓ Logout y recuperación administrativa > CLI normaliza IPv4-mapped y agrega /32  343ms
   ✓ Logout y recuperación administrativa > CLI rechaza usuario no admin, sin modificaciones ni clave en stdout  345ms
   ✓ Logout y recuperación administrativa > CLI rechaza legajos online y acepta la aplicación detenida  764ms
   ✓ Logout y recuperación administrativa > CLI falla si el lock está ocupado  341ms
 ✓ test/documentos.test.ts (43 tests) 1212ms
 ✓ test/admin.test.ts (17 tests) 749ms
 ✓ test/archivos-validar.test.ts (15 tests) 762ms
 ✓ test/rutas-documentos.test.ts (16 tests) 433ms
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

 ✓ test/cedulas.test.ts (14 tests) 251ms
 ✓ test/interacciones.test.ts (12 tests) 229ms
 ✓ test/archivos-almacen.test.ts (19 tests) 157ms
 ✓ test/auth-guard.test.ts (40 tests) 147ms
 ✓ test/schema.test.ts (53 tests) 140ms
 ✓ test/permisos.test.ts (29 tests) 39ms
 ✓ test/humo.test.ts (3 tests) 21ms
 ✓ test/ip.test.ts (24 tests) 7ms
 ✓ test/permisos.unit.test.ts (48 tests) 4ms

 Test Files  17 passed (17)
      Tests  397 passed (397)
   Start at  09:12:06
   Duration  18.23s (transform 284ms, setup 0ms, collect 3.17s, tests 11.04s, environment 2ms, prepare 646ms)

$ next build
 ⚠ Warning: Next.js inferred your workspace root, but it may not be correct.
 We detected multiple lockfiles and selected the directory of /home/ecenturion/pnpm-lock.yaml as the root directory.
 To silence this warning, set `outputFileTracingRoot` in your Next.js config, or consider removing one of the lockfiles if it's not needed.
   See https://nextjs.org/docs/app/api-reference/config/next-config-js/output#caveats for more information.
 Detected additional lockfiles: 
   * /home/ecenturion/develop/legajos/pnpm-lock.yaml

   ▲ Next.js 15.5.27

   Creating an optimized production build ...
 ✓ Compiled successfully in 1943ms
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

