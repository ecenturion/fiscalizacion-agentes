# Informe — P1-padron-y-consulta

**Estado:** BLOQUEADO
**Implementador:** CODEX, sombrero B
**Fecha:** 2026-10-07
**Rama:** main, sin commit ni push.

Implementación terminada dentro del alcance. La verificación completa sale con código 1:
537 tests pasan y uno falla en `test/migracion-0003.test.ts:132`, que aplica todas las
migraciones pero espera exactamente cuatro. P1 incorpora la quinta, como exige la spec.
Este archivo no está autorizado por el alcance de P1, por lo que no lo modifiqué.

Los 18 tests nuevos del padrón pasan (14 del servicio y 4 de la copia), junto con
los tests de permisos. Lint y typecheck pasan. Como `pnpm verificar` se interrumpe
en tests, ejecuté el build por separado: código 0. Drizzle informa que no hay
cambios pendientes y `bash -n` termina con código 0.

## Archivos creados

Rutas relativas a `legajos/`:

- `drizzle/0004_harsh_talkback.sql`
- `drizzle/meta/0004_snapshot.json`
- `deploy/padron-sync.sh` (ejecutable)
- `deploy/fiscalizacion-padron.cron`
- `src/server/servicios/padron.ts`
- `test/padron-sync.test.ts`
- `test/padron.test.ts`

## Archivos modificados

- `drizzle/meta/_journal.json`
- `src/server/db/schema.ts`
- `scripts/deploy.sh`
- `src/server/permisos.ts`
- `test/permisos.unit.test.ts`
- `src/server/acciones/contexto.ts`
- `src/server/servicios/contratos.ts`
- `deploy/README.md`

En `legajos-agents/` sólo se creó este informe.

## Decisiones y motivos

- Migración generada con Drizzle y completada con SQL custom para propietario,
  revocaciones y grants. Las cuatro tablas quedan en `padron`, de
  `legajos_owner`; la app recibe únicamente USAGE y SELECT, incluidos los
  privilegios por defecto necesarios para futuros swaps.
- Se conservan las cédulas de origen y se agregan sus valores normalizados. Los
  valores de texto/numeric que deben conservarse sin pérdida se copian a text;
  identificadores de origen permanecen numeric, y fechas permanecen date.
- Carga con `LIKE INCLUDING ALL EXCLUDING INDEXES`: los índices se crean después
  de importar y normalizar. Se retira temporalmente el NOT NULL de
  `persona_carga.cedula_norm` porque COPY todavía no trae esa columna calculada.
- Los duplicados normalizados de persona se resuelven en otra tabla de staging
  mediante DISTINCT ON, conservando la cédula más larga. No se usa DELETE.
  También se descartan las cédulas cuyo valor normalizado es NULL; ambos conteos
  quedan separados en el detalle de la sincronización.
- Swap, re-grant, ANALYZE y registro ok comparten una transacción. Un error en el
  cierre revierte incluso el DROP de las tablas anteriores. Se agregó una prueba
  que fuerza ese error mediante una restricción local y comprueba la recuperación.
- El trap ERR se propaga a las funciones con `set -E`. Ante errores se eliminan
  las tablas de staging y se registra la etapa y el código, sin volcar mensajes
  que puedan contener credenciales o datos personales.
- La clave de origen sólo se entrega como PGPASSWORD al proceso psql de origen.
  El README usa `read -s` y `printf %q` para crear el archivo Bash de credenciales
  con modo 600. El deploy sólo instala el script con modo 700; el cron se instala
  manualmente y la credencial nunca se monta en la aplicación.
- El servicio exige `consulta.cedula` y usa una transacción repeatable read con
  auditoría vista. Ejecuta una consulta agrupada por fuente; las subconsultas
  indexadas permiten encontrar la habilitante en ambas fuentes. Consulta personas,
  legajos y sincronización en lotes, sin N+1. La prueba usa el logger real de
  Drizzle para comprobar cinco lecturas y una inserción de auditoría, tanto con
  tres como con veintiuna duplicadas.
- Los datos de persona tienen prioridad sobre cedulas_dupl. Se conservan ambas
  cancelaciones, incluida DEVUELTA, y las duplicadas se deduplican por cédula.
  Si no existe ficha de la habilitante, la sugerencia contiene sólo la consultada
  y la advertencia sin_habilitante; los datos ausentes quedan en NULL para permitir
  su carga manual posterior. Con más de 20 duplicadas se devuelve la advertencia
  sin recortar la lista.
- Las pruebas del servicio conectan como legajos_app y obtienen Contexto del guard.
  Las pruebas del script crean verificacion_test y un destino aislado como owner;
  comprueban datos, normalización, índices, grants, repetición del swap,
  recuperación a mitad y después del DROP, y ausencia de la clave en stdout/stderr.
  Las bases y archivos temporales propios se limpian al terminar.
- Para ejecutar pnpm se antepuso `legajos/node_modules/.bin` al PATH: el pnpm
  global falla con “unable to open database file” en este entorno. Se utilizó
  el pnpm 11.0.0 ya disponible, sin instalar dependencias.

## Pendiente y límite de alcance

No se pudo dejar `pnpm verificar` en verde sin modificar
`test/migracion-0003.test.ts`, que está fuera del alcance. CODEX.md, flujo B,
establece “Implementá sólo los archivos de ‘Alcance de archivos’”; AGENTS.md
prohíbe editar archivos fuera de esa lista.

El arquitecto debe ampliar el alcance o corregir esa prueba para limitarla a
0000–0003 (por ejemplo, usando el dialecto y
`readMigrationFiles(config).slice(0, 4)`, como ya hace la prueba para v1).
Actualmente llama a `migrate` sobre toda la carpeta y luego espera cuatro filas,
por lo que cualquier quinta migración válida provoca el fallo.

No se conectó al servidor, no se desplegó, no se editó la UI ni se movió la tarea.
La copia se probó con PostgreSQL 16 local y el cliente psql instalado, versión
17.11; no se ejecutó con el cliente 13 ni con los 8,7 millones de filas de producción.
No se realizó una auditoría de sombrero A sobre este código.

## Verificación completa — salida real

Comando ejecutado desde `/home/ecenturion/develop/legajos`:

```sh
docker compose -f compose.test.yml down && docker compose -f compose.test.yml up -d --wait && PATH="$PWD/node_modules/.bin:$PATH" pnpm verificar
```

Código de salida: **1**. Salida íntegra de la última corrida:

```text
 Container legajos-postgres-1 Stopping 
 Container legajos-postgres-1 Stopped 
 Container legajos-postgres-1 Removing 
 Container legajos-postgres-1 Removed 
 Network legajos_default Removing 
 Network legajos_default Removed 
 Network legajos_default Creating 
 Network legajos_default Creating 
 Network legajos_default Created 
 Network legajos_default Created 
 Container legajos-postgres-1 Creating 
 Container legajos-postgres-1 Created 
 Container legajos-postgres-1 Starting 
 Container legajos-postgres-1 Started 
 Container legajos-postgres-1 Waiting 
 Container legajos-postgres-1 Healthy 
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
 ✓ test/padron-sync.test.ts (4 tests) 489ms
 ❯ test/migracion-0003.test.ts (4 tests | 1 failed) 410ms
   ✓ Migración 0003 en bases aisladas (legajos_owner) > rechaza un legajo v1 y conserva datos, schema, triggers, grants y journal íntegros 131ms
   ✓ Migración 0003 en bases aisladas (legajos_owner) > la red de seguridad también rechaza contador sin cambios 97ms
   ✓ Migración 0003 en bases aisladas (legajos_owner) > la red de seguridad también rechaza obligatorio sin cambios 92ms
   × Migración 0003 en bases aisladas (legajos_owner) > aplica 0000–0003 en una base limpia y registra las cuatro migraciones 85ms
     → expected [ { id: 1 }, { id: 2 }, …(3) ] to have a length of 4 but got 5
 ✓ test/logout-y-cli.test.ts (23 tests) 6079ms
   ✓ Logout y recuperación administrativa > CLI imprime una clave de 16 caracteres una vez, agrega IPv6 y cierra todas las sesiones  485ms
   ✓ Logout y recuperación administrativa > CLI normaliza IPv4-mapped y agrega /32  351ms
   ✓ Logout y recuperación administrativa > CLI recupera sin IP con una red existente y conserva sesiones ya cerradas  462ms
   ✓ Logout y recuperación administrativa > CLI no duplica la red activa 192.0.2.0/24 que contiene ::ffff:192.0.2.42  354ms
   ✓ Logout y recuperación administrativa > CLI no duplica la red activa 2001:db8::/64 que contiene 2001:0db8:0000:0000:0000:0000:0000:0042  349ms
   ✓ Logout y recuperación administrativa > CLI no duplica la red activa 192.0.2.17/32 que contiene 192.0.2.17  347ms
   ✓ Logout y recuperación administrativa > CLI reactiva un admin inactivo  365ms
   ✓ Logout y recuperación administrativa > CLI rechaza un operador, sin modificaciones ni clave en stdout  349ms
   ✓ Logout y recuperación administrativa > CLI sin IP y sin redes activas pide una IP y no hace cambios  325ms
   ✓ Logout y recuperación administrativa > CLI agrega una IP aunque esté contenida en una red inactiva  349ms
   ✓ Logout y recuperación administrativa > CLI no guarda la clave temporal ni el hash en ningún campo de auditoría  348ms
 ✓ test/login.test.ts (14 tests) 3643ms
   ✓ Login y cambio de clave con Postgres real como legajos_app > cinco fallos bloquean; la clave correcta no pasa hasta +16 minutos  371ms
   ✓ Login y cambio de clave con Postgres real como legajos_app > inexistente usa señuelo, con mediana de cinco muestras a menos del 30%  448ms
   ✓ Login y cambio de clave con Postgres real como legajos_app > 20 fallos por IP, el 21 no verifica ni modifica cuenta; ventana vencida reinicia  927ms
   ✓ Login y cambio de clave con Postgres real como legajos_app > 25 concurrentes desde una IP: sólo 20 verifican argon2  890ms
 ✓ test/documentos.test.ts (45 tests) 1892ms
 ✓ test/admin.test.ts (19 tests) 1111ms
   ✓ Administración contra Postgres real como legajos_app > dos admins que se desactivan mutuamente en paralelo dejan al menos uno activo  372ms
 ✓ test/archivos-validar.test.ts (15 tests) 717ms
 ✓ test/acciones.test.ts (31 tests) 639ms
 ✓ test/tramites.test.ts (22 tests) 626ms
 ✓ test/rutas-documentos.test.ts (17 tests) 471ms
 ✓ test/interacciones.test.ts (13 tests) 363ms
 ✓ test/legajos.test.ts (16 tests) 211ms
 ✓ test/triggers.test.ts (44 tests) 192ms
 ✓ test/schema.test.ts (60 tests) 160ms
 ✓ test/auth-guard.test.ts (40 tests) 159ms
 ✓ test/archivos-almacen.test.ts (19 tests) 163ms
 ✓ test/padron.test.ts (14 tests) 110ms
 ✓ test/catalogos.test.ts (3 tests) 57ms
 ✓ test/permisos.test.ts (36 tests) 45ms
 ✓ test/guard-cobertura.test.ts (12 tests) 46ms
 ✓ test/humo.test.ts (3 tests) 22ms
 ✓ test/ip.test.ts (24 tests) 7ms
 ✓ test/permisos.unit.test.ts (60 tests) 5ms

⎯⎯⎯⎯⎯⎯⎯ Failed Tests 1 ⎯⎯⎯⎯⎯⎯⎯

 FAIL  test/migracion-0003.test.ts > Migración 0003 en bases aisladas (legajos_owner) > aplica 0000–0003 en una base limpia y registra las cuatro migraciones
AssertionError: expected [ { id: 1 }, { id: 2 }, …(3) ] to have a length of 4 but got 5

- Expected
+ Received

- 4
+ 5

 ❯ test/migracion-0003.test.ts:132:75
    130|     await enBaseNueva(async (conexion) => {
    131|       await migrate(drizzle(conexion), config);
    132|       expect(await conexion`SELECT id FROM drizzle.__drizzle_migration…
       |                                                                           ^
    133|       const tablas = await conexion`
    134|         SELECT table_name FROM information_schema.tables WHERE table_s…
 ❯ enBaseNueva test/migracion-0003.test.ts:30:7
 ❯ test/migracion-0003.test.ts:130:5

⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯[1/1]⎯


 Test Files  1 failed | 22 passed (23)
      Tests  1 failed | 537 passed (538)
   Start at  08:30:58
   Duration  27.80s (transform 398ms, setup 0ms, collect 4.94s, tests 17.62s, environment 3ms, prepare 877ms)

 ELIFECYCLE  Test failed. See above for more details.
 ELIFECYCLE  Command failed with exit code 1.

```

## Drizzle — salida real

```sh
PATH="$PWD/node_modules/.bin:$PATH" pnpm db:generate
```

Código de salida: **0**.

```text
$ drizzle-kit generate
No config path provided, using default 'drizzle.config.ts'
Reading config file '/home/ecenturion/develop/legajos/drizzle.config.ts'
23 tables
acceso_log 7 columns 1 indexes 1 fks
auditoria 9 columns 0 indexes 1 fks
contador_tramite 2 columns 0 indexes 0 fks
documento 12 columns 1 indexes 6 fks
documento_archivo 8 columns 0 indexes 1 fks
estado_legajo 4 columns 1 indexes 0 fks
interaccion 12 columns 1 indexes 6 fks
legajo 9 columns 1 indexes 1 fks
limite_ip 3 columns 0 indexes 0 fks
cancelacion 11 columns 2 indexes 0 fks
cedula_dupl 19 columns 2 indexes 0 fks
persona 14 columns 0 indexes 0 fks
sincronizacion 8 columns 0 indexes 0 fks
sesion 8 columns 0 indexes 1 fks
solicitud_documento 5 columns 0 indexes 4 fks
tipo_documento 5 columns 1 indexes 0 fks
tipo_interaccion 4 columns 1 indexes 0 fks
tipo_tramite 4 columns 1 indexes 0 fks
tipo_tramite_documento 3 columns 0 indexes 2 fks
tramite 10 columns 0 indexes 3 fks
tramite_legajo 9 columns 2 indexes 4 fks
usuario 10 columns 0 indexes 0 fks
usuario_ip 7 columns 0 indexes 2 fks

No schema changes, nothing to migrate 😴

```

## Sintaxis Bash

```sh
bash -n deploy/padron-sync.sh
```

Código de salida: **0**. stdout/stderr vacíos.

## Build separado — salida real

```sh
PATH="$PWD/node_modules/.bin:$PATH" pnpm build
```

Código de salida: **0**.

```text
$ next build
 ⚠ Warning: Next.js inferred your workspace root, but it may not be correct.
 We detected multiple lockfiles and selected the directory of /home/ecenturion/pnpm-lock.yaml as the root directory.
 To silence this warning, set `outputFileTracingRoot` in your Next.js config, or consider removing one of the lockfiles if it's not needed.
   See https://nextjs.org/docs/app/api-reference/config/next-config-js/output#caveats for more information.
 Detected additional lockfiles: 
   * /home/ecenturion/develop/legajos/pnpm-lock.yaml

   ▲ Next.js 15.5.27

   Creating an optimized production build ...
 ✓ Compiled successfully in 2.8s
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

## Espacios del diff

```sh
git diff --check
```

Código de salida: **0**. stdout/stderr vacíos.

