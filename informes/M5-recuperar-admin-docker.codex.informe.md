# Informe — M5-recuperar-admin-docker

**Estado:** COMPLETADO
**Implementador:** CODEX · sombrero B
**Fecha:** 2026-10-05

## Archivos

Creado en `legajos/`:

- `deploy/fiscalizacion-admin.sh`.

Modificados en `legajos/`:

- `scripts/admin-recuperar.ts`.
- `scripts/deploy.sh`.
- `deploy/README.md`.
- `test/logout-y-cli.test.ts`.

Única escritura en `legajos-agents/`: este informe. No se modificaron roles, specs ni `estado.jsonl` (ya estaba modificado). Sin commit, push, deploy ni conexión al servidor.

## Implementación y decisiones

- El host valida el subcomando, el usuario y la forma de la IP; conserva los argumentos entre comillas y mantiene `flock -n` sobre el descriptor 9 durante todo el CLI. Si el lock está ocupado, escribe el error en stderr y sale con código 1.
- Se usa `TAG=actual`, permitido por la spec para interpolar Compose al ejecutar sobre el contenedor existente. El deploy copia el wrapper y aplica permisos `700`.
- Se quitaron PM2, `--sin-pm2`, el lock interno y `LEGAJOS_LOCK`. La IP es opcional; se usan `ipDeHeaders` e `ipPermitida` para normalizar IPv4/IPv6, convertir IPv4-mapped y comprobar contención sólo en redes activas.
- Se bloquea la fila del usuario con `FOR UPDATE`. Dentro de una transacción se valida el admin, se genera la clave de 16 caracteres con `randomBytes(12).toString('base64url')`, se aplica `hashear`, se reactiva, se restablecen intentos/bloqueo y se cierran todas sus sesiones abiertas con motivo `recuperacion`. Las sesiones ya cerradas conservan su motivo.
- La auditoría `login_admin` usa IP `127.0.0.1` y contiene `reset_clave`, la red canónica en `ip_agregada` cuando se agrega, `reactivado` sólo cuando corresponde y el número de sesiones que se cerraron. No incluye clave ni hash. stdout sólo recibe la clave tras confirmar la transacción; los errores inesperados se ocultan para no revelar parámetros de Postgres.
- Los 23 casos de logout/CLI usan Postgres real. El CLI se ejecuta con `NODE_ENV=production`, como owner; los servicios y consultas de aserción usan `legajos_app`. Se cubren los seis casos solicitados, además de IPv4-mapped, IPv6 expandida, redes inactivas, conservación de sesiones cerradas, desbloqueo, IP inválida y usuario inexistente.

## Verificación y límites

La primera corrida de `pnpm verificar` pasó lint, typecheck y los 23 tests del archivo de esta tarea, pero falló en cinco tests fuera del alcance: dos de legajos y tres de trámites. La base local reutilizada tenía fixtures y contadores persistidos de corridas anteriores. No se editaron esos tests ni se limpiaron sus datos.

Se creó una base local nueva `legajos_m5_codex_20261005` en el mismo Postgres de tests y se repitió `pnpm verificar` con `TEST_ADMIN_URL`, `TEST_OWNER_URL` y `TEST_APP_URL` apuntando a ella. La corrida final pasó lint, typecheck, 517 tests en 21 archivos y build, con código 0. Al terminar se eliminó exclusivamente esa base creada para esta verificación.

Hubo dos intentos intermedios que fallaron antes de ejecutar los checks por `unable to open database file` de pnpm. Se usó el pnpm instalado (11.22.0), desactivando temporalmente el cambio automático a la versión declarada y la instalación automática con `pnpm_config_pm_on_fail=ignore` y `pnpm_config_verify_deps_before_run=false`. No se modificaron manifests, lockfiles ni configuración del proyecto.

`bash -n` pasó para el wrapper y el script de deploy. Se comprobó que seis combinaciones de argumentos inválidos del wrapper salen con código 1 y stdout vacío. `shellcheck` no está instalado; su comprobación condicional se omitió. No se verificó el wrapper contra Docker de producción ni un lock real del host: la tarea prohíbe conectarse al servidor.

El build emitió una advertencia por múltiples lockfiles, y las migraciones de la base nueva emitieron advertencias sobre permisos de funciones de extensiones. Se conservan en la salida real; ambos pasos terminaron correctamente.

## Salida real — primera verificación

Comando: `cd legajos && pnpm verificar`. Código de salida: 1.

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
 ✓ test/catalogos.test.ts (3 tests) 56ms
 ✓ test/login.test.ts (14 tests) 3660ms
   ✓ Login y cambio de clave con Postgres real como legajos_app > cinco fallos bloquean; la clave correcta no pasa hasta +16 minutos  370ms
   ✓ Login y cambio de clave con Postgres real como legajos_app > inexistente usa señuelo, con mediana de cinco muestras a menos del 30%  446ms
   ✓ Login y cambio de clave con Postgres real como legajos_app > 20 fallos por IP, el 21 no verifica ni modifica cuenta; ventana vencida reinicia  931ms
   ✓ Login y cambio de clave con Postgres real como legajos_app > 25 concurrentes desde una IP: sólo 20 verifican argon2  894ms
 ✓ test/logout-y-cli.test.ts (23 tests) 6155ms
   ✓ Logout y recuperación administrativa > CLI imprime una clave de 16 caracteres una vez, agrega IPv6 y cierra todas las sesiones  554ms
   ✓ Logout y recuperación administrativa > CLI normaliza IPv4-mapped y agrega /32  357ms
   ✓ Logout y recuperación administrativa > CLI recupera sin IP con una red existente y conserva sesiones ya cerradas  462ms
   ✓ Logout y recuperación administrativa > CLI no duplica la red activa 192.0.2.0/24 que contiene ::ffff:192.0.2.42  355ms
   ✓ Logout y recuperación administrativa > CLI no duplica la red activa 2001:db8::/64 que contiene 2001:0db8:0000:0000:0000:0000:0000:0042  349ms
   ✓ Logout y recuperación administrativa > CLI no duplica la red activa 192.0.2.17/32 que contiene 192.0.2.17  350ms
   ✓ Logout y recuperación administrativa > CLI reactiva un admin inactivo  367ms
   ✓ Logout y recuperación administrativa > CLI rechaza un operador, sin modificaciones ni clave en stdout  346ms
   ✓ Logout y recuperación administrativa > CLI sin IP y sin redes activas pide una IP y no hace cambios  325ms
   ✓ Logout y recuperación administrativa > CLI agrega una IP aunque esté contenida en una red inactiva  350ms
   ✓ Logout y recuperación administrativa > CLI no guarda la clave temporal ni el hash en ningún campo de auditoría  346ms
   ✓ Logout y recuperación administrativa > CLI rechaza un usuario inexistente  301ms
 ✓ test/documentos.test.ts (45 tests) 1939ms
 ✓ test/admin.test.ts (19 tests) 1161ms
   ✓ Administración contra Postgres real como legajos_app > dos admins que se desactivan mutuamente en paralelo dejan al menos uno activo  379ms
 ✓ test/archivos-validar.test.ts (15 tests) 731ms
 ✓ test/acciones.test.ts (31 tests) 648ms
 ❯ test/tramites.test.ts (22 tests | 3 failed) 647ms
   ✓ Trámites v2 contra Postgres real como legajos_app > usa legajos_app sin heredar owner 1ms
   × Trámites v2 contra Postgres real como legajos_app > numera 2090-0001 y 2090-0002 con estado inicial y auditoría de todas las altas 32ms
     → expected [ '2090-0003', '2090-0004' ] to deeply equal [ '2090-0001', '2090-0002' ]
   × Trámites v2 contra Postgres real como legajos_app > 10 altas concurrentes reservan los correlativos 1..10 124ms
     → expected [ Array(10) ] to deeply equal [ 1, 2, 3, 4, 5, 6, 7, 8, 9, 10 ]
   × Trámites v2 contra Postgres real como legajos_app > usa el año de Asunción UTC−3 y reinicia la numeración al cambiar de año 10ms
     → expected '2092-0002' to be '2092-0001' // Object.is equality
   ✓ Trámites v2 contra Postgres real como legajos_app > combina un legajo existente con otro presentado como nuevo que reutiliza su número 16ms
   ✓ Trámites v2 contra Postgres real como legajos_app > rechaza tipo inactivo con 422 y revierte el contador 13ms
   ✓ Trámites v2 contra Postgres real como legajos_app > rechaza legajos repetidos incluso por cédula normalizada y revierte todas las altas 12ms
   ✓ Trámites v2 contra Postgres real como legajos_app > dos marcas concurrentes preservan una única original; inicial=undefined 32ms
   ✓ Trámites v2 contra Postgres real como legajos_app > dos marcas concurrentes preservan una única original; inicial=0 32ms
   ✓ Trámites v2 contra Postgres real como legajos_app > marcarOriginal(null) deja la original sin determinar y audita el cambio 24ms
   ✓ Trámites v2 contra Postgres real como legajos_app > vincula nuevos y existentes, rechaza duplicados y revincula con una fila nueva 27ms
   ✓ Trámites v2 contra Postgres real como legajos_app > dos vinculaciones concurrentes del mismo legajo tienen un éxito y un 422 13ms
   ✓ Trámites v2 contra Postgres real como legajos_app > desvincular el último devuelve 409 sin cambiar ni auditar 10ms
   ✓ Trámites v2 contra Postgres real como legajos_app > dos desvinculaciones concurrentes con dos vínculos dejan exactamente uno 14ms
   ✓ Trámites v2 contra Postgres real como legajos_app > desvincular la original devuelve a pendiente sólo las solicitudes de ese trámite y legajo 35ms
   ✓ Trámites v2 contra Postgres real como legajos_app > faltantes acepta documento vencido sin procedencia o de otro trámite; anulado o desvinculado falta 61ms
   ✓ Trámites v2 contra Postgres real como legajos_app > busca por número, tipo, estado y cédula normalizada; excluye vínculos anulados 21ms
   ✓ Trámites v2 contra Postgres real como legajos_app > verTramite y buscarTramites mantienen las consultas con 1 y 5 vínculos y auditan una sola vista 35ms
   ✓ Trámites v2 contra Postgres real como legajos_app > el detalle incluye documentos del trámite con archivos ordenados y conserva los de vínculos anulados 32ms
   ✓ Trámites v2 contra Postgres real como legajos_app > editar preserva estado y numeración; audita antes/después 16ms
   ✓ Trámites v2 contra Postgres real como legajos_app > consulta ve pero no muta; operador no desvincula 15ms
   ✓ Trámites v2 contra Postgres real como legajos_app > valida entradas, motivos y pertenencia al trámite 30ms
 ✓ test/rutas-documentos.test.ts (17 tests) 470ms
 ✓ test/migracion-0003.test.ts (4 tests) 408ms
 ✓ test/interacciones.test.ts (13 tests) 376ms
 ✓ test/triggers.test.ts (44 tests) 198ms
 ❯ test/legajos.test.ts (16 tests | 2 failed) 212ms
   ✓ Legajos v2 contra Postgres real como legajos_app > usa el rol app sin heredar owner 1ms
   ✓ Legajos v2 contra Postgres real como legajos_app > rechaza la cédula inválida 000 3ms
   ✓ Legajos v2 contra Postgres real como legajos_app > rechaza la cédula inválida  1ms
   ✓ Legajos v2 contra Postgres real como legajos_app > rechaza la cédula inválida 12a 1ms
   ✓ Legajos v2 contra Postgres real como legajos_app > rechaza la cédula inválida 1/2 0ms
   ✓ Legajos v2 contra Postgres real como legajos_app > rechaza la cédula inválida １２３ 1ms
   × Legajos v2 contra Postgres real como legajos_app > quita formato y ceros; reutiliza sin sobrescribir datos 10ms
     → expected false to be true // Object.is equality
   ✓ Legajos v2 contra Postgres real como legajos_app > dos altas concurrentes del mismo número crean exactamente un legajo 9ms
   ✓ Legajos v2 contra Postgres real como legajos_app > busca prefijo normalizado, nombres sin acentos y pagina con total 10ms
   ✓ Legajos v2 contra Postgres real como legajos_app > cantidadTramites cuenta vínculos vivos en todos los resúmenes y excluye anulaciones 54ms
   × Legajos v2 contra Postgres real como legajos_app > escapa porcentajes, guiones bajos y barras de la búsqueda 7ms
     → expected [ …(2) ] to deeply equal [ Array(1) ]
   ✓ Legajos v2 contra Postgres real como legajos_app > editar preserva campos omitidos, permite limpiar opcionales y audita antes/después 6ms
   ✓ Legajos v2 contra Postgres real como legajos_app > corregir cédula exige admin y motivo, traduce choques y audita usuario e IP 9ms
   ✓ Legajos v2 contra Postgres real como legajos_app > traduce 42501 de SQL aunque el Contexto anterior sea de admin 6ms
   ✓ Legajos v2 contra Postgres real como legajos_app > relacionados usa vínculos vivos de ambos lados y conserva historial de trámites 51ms
   ✓ Legajos v2 contra Postgres real como legajos_app > valida entradas y devuelve 404 sin mutaciones para IDs ausentes 3ms
 ✓ test/archivos-almacen.test.ts (19 tests) 157ms
 ✓ test/auth-guard.test.ts (40 tests) 158ms
 ✓ test/schema.test.ts (60 tests) 163ms
 ✓ test/permisos.test.ts (36 tests) 43ms
 ✓ test/guard-cobertura.test.ts (12 tests) 44ms
 ✓ test/humo.test.ts (3 tests) 21ms
 ✓ test/ip.test.ts (24 tests) 7ms
 ✓ test/permisos.unit.test.ts (57 tests) 4ms

⎯⎯⎯⎯⎯⎯⎯ Failed Tests 5 ⎯⎯⎯⎯⎯⎯⎯

 FAIL  test/legajos.test.ts > Legajos v2 contra Postgres real como legajos_app > quita formato y ceros; reutiliza sin sobrescribir datos
AssertionError: expected false to be true // Object.is equality

- Expected
+ Received

- true
+ false

 ❯ test/legajos.test.ts:79:28
     77|     const primero = await legajos.obtenerOCrearLegajo(admin, entrada('…
     78|     const segundo = await legajos.obtenerOCrearLegajo(admin, { ...entr…
     79|     expect(primero.creado).toBe(true);
       |                            ^
     80|     expect(segundo).toEqual({ legajo: primero.legajo, creado: false });
     81|     expect(await legajos.buscarPorCedula(consulta, { cedula: '00012345…

⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯[1/5]⎯

 FAIL  test/legajos.test.ts > Legajos v2 contra Postgres real como legajos_app > escapa porcentajes, guiones bajos y barras de la búsqueda
AssertionError: expected [ …(2) ] to deeply equal [ Array(1) ]

- Expected
+ Received

  [
    "01a10e38-2e8c-7c78-ac41-bed659fdf228",
+   "01a10db9-1097-7864-9d82-27b731cf8c43",
  ]

 ❯ test/legajos.test.ts:135:45
    133|     await legajos.obtenerOCrearLegajo(admin, { ...entrada(), nombres: …
    134|     const salida = await legajos.buscarLegajos(admin, { nombreApellido…
    135|     expect(salida.legajos.map((l) => l.id)).toEqual([legajo.id]);
       |                                             ^
    136|   });
    137| 

⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯[2/5]⎯

 FAIL  test/tramites.test.ts > Trámites v2 contra Postgres real como legajos_app > numera 2090-0001 y 2090-0002 con estado inicial y auditoría de todas las altas
AssertionError: expected [ '2090-0003', '2090-0004' ] to deeply equal [ '2090-0001', '2090-0002' ]

- Expected
+ Received

  [
-   "2090-0001",
-   "2090-0002",
+   "2090-0003",
+   "2090-0004",
  ]

 ❯ test/tramites.test.ts:106:46
    104|     const a = await servicio.crearTramite(operador, entrada());
    105|     const b = await servicio.crearTramite(operador, entrada());
    106|     expect([a.datos.numero, b.datos.numero]).toEqual(['2090-0001', '20…
       |                                              ^
    107|     expect(a.estado.nombre).toBe('Detectado');
    108|     expect(a.tipo.id).toBe(tipoId);

⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯[3/5]⎯

 FAIL  test/tramites.test.ts > Trámites v2 contra Postgres real como legajos_app > 10 altas concurrentes reservan los correlativos 1..10
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

 ❯ test/tramites.test.ts:119:78
    117|     const servicio = conAnio(2091);
    118|     const resultados = await Promise.all(Array.from({ length: 10 }, ()…
    119|     expect(resultados.map((t) => t.datos.correlativo).sort((a, b) => a…
       |                                                                              ^
    120|     expect(new Set(resultados.map((t) => t.datos.numero)).size).toBe(1…
    121|   });

⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯[4/5]⎯

 FAIL  test/tramites.test.ts > Trámites v2 contra Postgres real como legajos_app > usa el año de Asunción UTC−3 y reinicia la numeración al cambiar de año
AssertionError: expected '2092-0002' to be '2092-0001' // Object.is equality

Expected: "2092-0001"
Received: "2092-0002"

 ❯ test/tramites.test.ts:127:28
    125|     expect(instante.setZone('America/Asuncion').offset).toBe(-180);
    126|     const a = await crearServiciosTramites(db, { now: () => instante }…
    127|     expect(a.datos.numero).toBe('2092-0001');
       |                            ^
    128|     const b = await crearServiciosTramites(db, { now: () => DateTime.f…
    129|     expect(b.datos.numero).toBe('2093-0001');

⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯[5/5]⎯


 Test Files  2 failed | 19 passed (21)
      Tests  5 failed | 512 passed (517)
   Start at  19:38:21
   Duration  26.45s (transform 361ms, setup 0ms, collect 4.42s, tests 17.26s, environment 3ms, prepare 797ms)

 ELIFECYCLE  Test failed. See above for more details.
 ELIFECYCLE  Command failed with exit code 1.

```

## Salida real — intentos intermedios

Desde `legajos/`:

```sh
TEST_ADMIN_URL=postgres://postgres:postgres@localhost:55433/legajos_m5_codex_20261005 TEST_OWNER_URL=postgres://legajos_owner@localhost:55433/legajos_m5_codex_20261005 TEST_APP_URL=postgres://legajos_app@localhost:55433/legajos_m5_codex_20261005 pnpm verificar
```

Código de salida: 1.

```text
[ERROR] unable to open database file
For help, run: pnpm help run

```

```sh
pnpm_config_pm_on_fail=ignore TEST_ADMIN_URL=postgres://postgres:postgres@localhost:55433/legajos_m5_codex_20261005 TEST_OWNER_URL=postgres://legajos_owner@localhost:55433/legajos_m5_codex_20261005 TEST_APP_URL=postgres://legajos_app@localhost:55433/legajos_m5_codex_20261005 pnpm verificar
```

Código de salida: 1.

```text
[ERR_SQLITE_ERROR] unable to open database file

pnpm: unable to open database file
    at file:///home/ecenturion/.npm-global/lib/node_modules/pnpm/dist/pnpm.mjs:102448:19
    at sqliteRetry (file:///home/ecenturion/.npm-global/lib/node_modules/pnpm/dist/pnpm.mjs:102358:14)
    at StoreIndex.openDatabase (file:///home/ecenturion/.npm-global/lib/node_modules/pnpm/dist/pnpm.mjs:102447:9)
    at new StoreIndex (file:///home/ecenturion/.npm-global/lib/node_modules/pnpm/dist/pnpm.mjs:102432:14)
    at createNewStoreController (file:///home/ecenturion/.npm-global/lib/node_modules/pnpm/dist/pnpm.mjs:182737:83)
    at async installDeps (file:///home/ecenturion/.npm-global/lib/node_modules/pnpm/dist/pnpm.mjs:219786:17)
    at async Object.handler5 (file:///home/ecenturion/.npm-global/lib/node_modules/pnpm/dist/pnpm.mjs:220893:3)
    at async file:///home/ecenturion/.npm-global/lib/node_modules/pnpm/dist/pnpm.mjs:322592:19
    at async main4 (file:///home/ecenturion/.npm-global/lib/node_modules/pnpm/dist/pnpm.mjs:322560:30)
    at async runPnpm (file:///home/ecenturion/.npm-global/lib/node_modules/pnpm/dist/pnpm.mjs:322856:5)
[ERROR] Command failed with exit code 1: pnpm install

pnpm: Command failed with exit code 1: pnpm install
    at getFinalError (file:///home/ecenturion/.npm-global/lib/node_modules/pnpm/dist/pnpm.mjs:89203:14)
    at makeError (file:///home/ecenturion/.npm-global/lib/node_modules/pnpm/dist/pnpm.mjs:91510:21)
    at getSyncResult (file:///home/ecenturion/.npm-global/lib/node_modules/pnpm/dist/pnpm.mjs:93354:10)
    at spawnSubprocessSync (file:///home/ecenturion/.npm-global/lib/node_modules/pnpm/dist/pnpm.mjs:93314:14)
    at execaCoreSync (file:///home/ecenturion/.npm-global/lib/node_modules/pnpm/dist/pnpm.mjs:93244:23)
    at callBoundExeca (file:///home/ecenturion/.npm-global/lib/node_modules/pnpm/dist/pnpm.mjs:95772:23)
    at boundExeca (file:///home/ecenturion/.npm-global/lib/node_modules/pnpm/dist/pnpm.mjs:95749:49)
    at sync2 (file:///home/ecenturion/.npm-global/lib/node_modules/pnpm/dist/pnpm.mjs:95904:14)
    at runPnpmCli (file:///home/ecenturion/.npm-global/lib/node_modules/pnpm/dist/pnpm.mjs:271525:5)
    at runDepsStatusCheck (file:///home/ecenturion/.npm-global/lib/node_modules/pnpm/dist/pnpm.mjs:273323:7)

```

## Salida real — verificación completa en base aislada

Desde `legajos/`:

```sh
pnpm_config_pm_on_fail=ignore pnpm_config_verify_deps_before_run=false TEST_ADMIN_URL=postgres://postgres:postgres@localhost:55433/legajos_m5_codex_20261005 TEST_OWNER_URL=postgres://legajos_owner@localhost:55433/legajos_m5_codex_20261005 TEST_APP_URL=postgres://legajos_app@localhost:55433/legajos_m5_codex_20261005 pnpm verificar
```

Código de salida: 0.

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
 ✓ test/tramites.test.ts (22 tests) 624ms
 ✓ test/legajos.test.ts (16 tests) 197ms
 ✓ test/logout-y-cli.test.ts (23 tests) 6072ms
   ✓ Logout y recuperación administrativa > CLI imprime una clave de 16 caracteres una vez, agrega IPv6 y cierra todas las sesiones  487ms
   ✓ Logout y recuperación administrativa > CLI normaliza IPv4-mapped y agrega /32  347ms
   ✓ Logout y recuperación administrativa > CLI recupera sin IP con una red existente y conserva sesiones ya cerradas  461ms
   ✓ Logout y recuperación administrativa > CLI no duplica la red activa 192.0.2.0/24 que contiene ::ffff:192.0.2.42  352ms
   ✓ Logout y recuperación administrativa > CLI no duplica la red activa 2001:db8::/64 que contiene 2001:0db8:0000:0000:0000:0000:0000:0042  347ms
   ✓ Logout y recuperación administrativa > CLI no duplica la red activa 192.0.2.17/32 que contiene 192.0.2.17  347ms
   ✓ Logout y recuperación administrativa > CLI reactiva un admin inactivo  368ms
   ✓ Logout y recuperación administrativa > CLI rechaza un operador, sin modificaciones ni clave en stdout  345ms
   ✓ Logout y recuperación administrativa > CLI sin IP y sin redes activas pide una IP y no hace cambios  339ms
   ✓ Logout y recuperación administrativa > CLI agrega una IP aunque esté contenida en una red inactiva  346ms
   ✓ Logout y recuperación administrativa > CLI no guarda la clave temporal ni el hash en ningún campo de auditoría  348ms
 ✓ test/login.test.ts (14 tests) 3688ms
   ✓ Login y cambio de clave con Postgres real como legajos_app > cinco fallos bloquean; la clave correcta no pasa hasta +16 minutos  367ms
   ✓ Login y cambio de clave con Postgres real como legajos_app > inexistente usa señuelo, con mediana de cinco muestras a menos del 30%  441ms
   ✓ Login y cambio de clave con Postgres real como legajos_app > 20 fallos por IP, el 21 no verifica ni modifica cuenta; ventana vencida reinicia  974ms
   ✓ Login y cambio de clave con Postgres real como legajos_app > 25 concurrentes desde una IP: sólo 20 verifican argon2  889ms
 ✓ test/documentos.test.ts (45 tests) 1903ms
 ✓ test/admin.test.ts (19 tests) 1113ms
   ✓ Administración contra Postgres real como legajos_app > dos admins que se desactivan mutuamente en paralelo dejan al menos uno activo  371ms
 ✓ test/archivos-validar.test.ts (15 tests) 721ms
 ✓ test/acciones.test.ts (31 tests) 645ms
 ✓ test/rutas-documentos.test.ts (17 tests) 505ms
 ✓ test/migracion-0003.test.ts (4 tests) 409ms
 ✓ test/interacciones.test.ts (13 tests) 358ms
 ✓ test/triggers.test.ts (44 tests) 197ms
 ✓ test/schema.test.ts (60 tests) 159ms
 ✓ test/auth-guard.test.ts (40 tests) 156ms
 ✓ test/archivos-almacen.test.ts (19 tests) 158ms
 ✓ test/catalogos.test.ts (3 tests) 58ms
 ✓ test/guard-cobertura.test.ts (12 tests) 43ms
 ✓ test/permisos.test.ts (36 tests) 45ms
 ✓ test/humo.test.ts (3 tests) 22ms
 ✓ test/ip.test.ts (24 tests) 7ms
 ✓ test/permisos.unit.test.ts (57 tests) 4ms

 Test Files  21 passed (21)
      Tests  517 passed (517)
   Start at  19:40:37
   Duration  26.27s (transform 366ms, setup 0ms, collect 4.40s, tests 17.09s, environment 3ms, prepare 792ms)

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
┌ ○ /                                      133 B         103 kB
├ ○ /_not-found                            996 B         104 kB
├ ƒ /admin                                 177 B         106 kB
├ ƒ /admin/accesos                         177 B         106 kB
├ ƒ /admin/catalogos                     3.23 kB         106 kB
├ ƒ /admin/usuarios                      4.24 kB         107 kB
├ ƒ /api/archivos/[id]                     133 B         103 kB
├ ƒ /api/documentos                        133 B         103 kB
├ ƒ /cuenta/clave                          177 B         106 kB
├ ƒ /legajos                               177 B         106 kB
├ ƒ /legajos/[id]                        1.72 kB         111 kB
├ ƒ /legajos/[id]/documentos/[docId]       177 B         106 kB
├ ƒ /legajos/nuevo                       1.99 kB         108 kB
├ ○ /login                                 826 B         104 kB
├ ƒ /logout                                133 B         103 kB
├ ƒ /tramites                              177 B         106 kB
├ ƒ /tramites/[id]                       3.44 kB         113 kB
└ ƒ /tramites/nuevo                      2.48 kB         105 kB
+ First Load JS shared by all             103 kB
  ├ chunks/758-942e49721ce48ac0.js       46.5 kB
  ├ chunks/d36d6ee9-817a06892149dc1d.js  54.4 kB
  └ other shared chunks (total)          1.92 kB


ƒ Middleware                             34.2 kB

○  (Static)   prerendered as static content
ƒ  (Dynamic)  server-rendered on demand


```

## Salida real — Bash y shellcheck condicional

Desde `legajos/`:

```sh
bash -n deploy/fiscalizacion-admin.sh && if command -v shellcheck >/dev/null 2>&1; then shellcheck deploy/fiscalizacion-admin.sh; else echo 'shellcheck no está instalado; chequeo omitido.'; fi
```

Código de salida: 0.

```text
shellcheck no está instalado; chequeo omitido.

```

También se ejecutó `bash -n scripts/deploy.sh` y se probaron las entradas inválidas con `subprocess.run(['bash', 'deploy/fiscalizacion-admin.sh', *args], capture_output=True, text=True)`, exigiendo código 1 y stdout vacío. Código de salida del chequeo: 0.

```text
Argumentos: []; código: 1; stdout: ''; stderr: 'Uso: fiscalizacion-admin.sh recuperar <usuario> [ip]\n'
Argumentos: ['estado', 'admin']; código: 1; stdout: ''; stderr: 'Uso: fiscalizacion-admin.sh recuperar <usuario> [ip]\n'
Argumentos: ['recuperar', 'ADMIN']; código: 1; stdout: ''; stderr: 'Usuario no válido.\n'
Argumentos: ['recuperar', 'ab']; código: 1; stdout: ''; stderr: 'Usuario no válido.\n'
Argumentos: ['recuperar', 'admin', '192.0.2.1;id']; código: 1; stdout: ''; stderr: 'IP no válida.\n'
Argumentos: ['recuperar', 'admin', '192.0.2.1', 'extra']; código: 1; stdout: ''; stderr: 'Uso: fiscalizacion-admin.sh recuperar <usuario> [ip]\n'

```

## Salida real — entorno aislado

Mediante `postgres` como owner local se ejecutaron `CREATE DATABASE legajos_m5_codex_20261005 OWNER legajos_owner` y, al terminar, `DROP DATABASE legajos_m5_codex_20261005`. Ambos comandos terminaron con código 0.

```text
Base local aislada creada: legajos_m5_codex_20261005
Base local aislada eliminada: legajos_m5_codex_20261005

```

