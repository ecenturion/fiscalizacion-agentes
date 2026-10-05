# Informe — M1-base-v2

**Estado:** COMPLETADO
**Agente:** codex · sombrero B
**Fecha:** 2026-10-05

Implementado el modelo v2 y verificados los criterios de base: lint, PostgreSQL 16 reiniciado, **147 pruebas aprobadas en 5 archivos**, y generación sin cambios de schema. El chequeo TypeScript estricto de los archivos del alcance también terminó con código 0.

## Archivos modificados y creados

Rutas relativas a `legajos/`; lista respecto de HEAD.

Modificados:
- `src/server/db/schema.ts`: schema v2 del despacho anterior, conservado: legajo por cédula normalizada y única, trámites, vínculos, catálogos y procedencia nullable.
- `drizzle/meta/_journal.json`: entrada 0003 ya generada en el despacho anterior, conservada.
- `test/schema.test.ts`: modelo v2; año 2098 para trámites; nulabilidad, UUID sin defaults, cédula normalizada/duplicada, número generado, vínculos vivos, originales, anulaciones, checks, FKs e índice trigram.
- `test/triggers.test.ts`: operaciones como app; año 2099; estado concurrente, solicitudes, procedencia, versiones históricas, cardinalidad y corrección administrativa con auditoría atómica.
- `test/permisos.test.ts`: matriz exacta de grants v2 de todas las tablas, prohibiciones efectivas y permisos/propietario/search_path de funciones.
- `test/setup-roles.sql`: CREATEDB para legajos_owner exclusivamente en el clúster local de tests; permite crear y borrar las bases aisladas como owner.

Creados:
- `drizzle/0003_needy_virginia_dare.sql`: reemplazada la salida provisional del generador por la migración manual completa, ordenada según §16.4.5 y sin CASCADE.
- `drizzle/meta/0003_snapshot.json`: snapshot generado en el despacho anterior, conservado y confirmado por db:generate.
- `test/migracion-0003.test.ts`: bases aisladas creadas y borradas como owner; rollback ante legajo v1, contador y obligatoriedad configurada; aplicación limpia de 0000–0003.

El único archivo escrito en `legajos-agents/` es este informe. Las migraciones 0000–0002, servicios, app, otros tests y dependencias se conservaron. Sin commit ni push.

## Decisiones y motivos

- Se aplicó la firma autorizada de seis parámetros: `legajos.corregir_cedula(uuid, text, uuid, text, inet, uuid)`. El UUID de auditoría se recibe de la app; no hay defaults ni set_config.
- La corrección valida admin activo bajo FOR SHARE, motivo y cédula normalizada; bloquea el legajo con FOR UPDATE, cambia sólo cedula y audita antes/después y motivo. El choque conserva 23505. Se comprobó que un fallo al insertar auditoría revierte también la corrección.
- Se crean contador_tramite y las tablas nuevas según §16.4.5, que manda sobre la referencia anterior al renombre del contador. numero se elimina antes de anio/correlativo. Las dos FKs renombradas se eliminan y reemplazan explícitamente.
- La red de seguridad revisa las siete tablas indicadas y tipo_documento.obligatorio antes de cualquier cambio. Las pruebas comparan datos, tablas, columnas, constraints, índices, triggers, funciones, grants y journal antes/después del rechazo.
- Estado conserva FOR UPDATE e IS DISTINCT FROM sobre tramite. Solicitud exige interacción del mismo trámite, documento vivo y del tipo y vínculo vivo; lee el documento con FOR SHARE.
- Procedencia bloquea el trámite y exige vínculo vivo para documentos nuevos. Versión exige mismo legajo/tipo, anterior vivo e igualdad de tramite_id incluso con NULL; permite conservar la procedencia histórica luego de desvincular.
- Se conserva sin cambios el trigger de cardinalidad de 0002. Las funciones de trigger fijan search_path y no conceden EXECUTE a app ni PUBLIC. Sólo estado y corregir_cedula son SECURITY DEFINER.
- Los grants de las diez tablas nuevas/modificadas están enumerados al principio de su sección SQL. Se revocan también los grants por columna anteriores: REVOKE ALL de tabla no los elimina. El test contrasta la lista exacta de UPDATE y todos los demás privilegios en las 19 tablas.
- Seed con UUIDv7 fijo `019b76da-a800-7000-8005-000000000001`, orden 1 y ningún documento obligatorio.
- Se verificó en `node_modules/drizzle-orm/pg-core/dialect.js` que migrate envuelve todas las sentencias pendientes y sus entradas de journal en session.transaction; postgres-js usa client.begin. No se agregan BEGIN/COMMIT internos a 0003.
- Las pruebas aisladas usan el dialecto y la sesión reales de Drizzle para aplicar el subconjunto 0000–0002, y el migrador real para 0003 y para la base limpia, sin copias de migraciones ni mocks.
- Para ejecutar pnpm dentro del entorno restringido se configuraron XDG_CACHE_HOME, XDG_DATA_HOME y XDG_STATE_HOME bajo `legajos/node_modules/.cache/`; el ejecutable resultante informa 11.0.0, la versión del proyecto. No se editaron configuraciones ni dependencias.
- Los WARNING 01006 de la corrida corresponden al REVOKE de funciones de extensiones de la migración 0002 existente; están incluidos sin omitir en la salida real.

## Verificación final: comando de la spec

Las salidas se pegan completas; sólo se quitan los espacios finales emitidos por Docker Compose.

Ejecutado desde `/home/ecenturion/develop/legajos`:

```sh
export XDG_CACHE_HOME="$PWD/node_modules/.cache" XDG_DATA_HOME="$PWD/node_modules/.cache/data" XDG_STATE_HOME="$PWD/node_modules/.cache/state"
pnpm lint && docker compose -f compose.test.yml down && docker compose -f compose.test.yml up -d --wait && pnpm vitest run test/schema.test.ts test/triggers.test.ts test/permisos.test.ts test/migracion-0003.test.ts test/humo.test.ts
```

Código de salida: **0**.

```text
$ eslint .
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
 ✓ test/migracion-0003.test.ts (4 tests) 437ms
 ✓ test/triggers.test.ts (44 tests) 211ms
 ✓ test/schema.test.ts (60 tests) 159ms
 ✓ test/permisos.test.ts (36 tests) 47ms
 ✓ test/humo.test.ts (3 tests) 21ms

 Test Files  5 passed (5)
      Tests  147 passed (147)
   Start at  15:40:38
   Duration  3.06s (transform 68ms, setup 0ms, collect 346ms, tests 876ms, environment 1ms, prepare 199ms)
```

## Generación sin cambios

```sh
export XDG_CACHE_HOME="$PWD/node_modules/.cache" XDG_DATA_HOME="$PWD/node_modules/.cache/data" XDG_STATE_HOME="$PWD/node_modules/.cache/state"
pnpm db:generate
```

Código de salida: **0**.

```text
$ drizzle-kit generate
No config path provided, using default 'drizzle.config.ts'
Reading config file '/home/ecenturion/develop/legajos/drizzle.config.ts'
19 tables
acceso_log 7 columns 1 indexes 1 fks
auditoria 9 columns 0 indexes 1 fks
contador_tramite 2 columns 0 indexes 0 fks
documento 12 columns 1 indexes 6 fks
documento_archivo 8 columns 0 indexes 1 fks
estado_legajo 4 columns 1 indexes 0 fks
interaccion 12 columns 1 indexes 6 fks
legajo 9 columns 1 indexes 1 fks
limite_ip 3 columns 0 indexes 0 fks
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

## TypeScript estricto limitado al alcance

Se ejecutó adicionalmente para comprobar los tipos de schema y tests sin depender de los servicios pendientes de M2.

```sh
export XDG_CACHE_HOME="$PWD/node_modules/.cache" XDG_DATA_HOME="$PWD/node_modules/.cache/data" XDG_STATE_HOME="$PWD/node_modules/.cache/state"
pnpm exec tsc --noEmit --strict --skipLibCheck --target es2022 --module esnext --moduleResolution bundler src/server/db/schema.ts test/schema.test.ts test/triggers.test.ts test/permisos.test.ts test/migracion-0003.test.ts
```

Código de salida final: **0**. Sin salida en stdout/stderr.

## Intentos fallidos y correcciones

El primer intento del comando de la spec se detuvo en pnpm por acceso a su caché:

```text
[ERROR] unable to open database file
For help, run: pnpm help run
```

Código de salida: 1. Se resolvió con las variables XDG anteriores, dentro del repo.

La primera corrida que llegó a vitest falló en tres capturas de datos del test de migración. El helper de identificadores recibía esquema y tabla como dos argumentos y producía una referencia sólo al esquema. Se corrigió a `FROM legajos.${conexion(tabla.relname)}`. Salida real de esa corrida:

```text
$ eslint .
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
 ✓ test/schema.test.ts (60 tests) 170ms
 ✓ test/triggers.test.ts (44 tests) 206ms
 ❯ test/migracion-0003.test.ts (4 tests | 3 failed) 360ms
   × Migración 0003 en bases aisladas (legajos_owner) > rechaza un legajo v1 y conserva datos, schema, triggers, grants y journal íntegros 119ms
     → relation "legajos" does not exist
   × Migración 0003 en bases aisladas (legajos_owner) > la red de seguridad también rechaza contador sin cambios 78ms
     → relation "legajos" does not exist
   × Migración 0003 en bases aisladas (legajos_owner) > la red de seguridad también rechaza obligatorio sin cambios 76ms
     → relation "legajos" does not exist
   ✓ Migración 0003 en bases aisladas (legajos_owner) > aplica 0000–0003 en una base limpia y registra las cuatro migraciones 82ms
 ✓ test/permisos.test.ts (36 tests) 48ms
 ✓ test/humo.test.ts (3 tests) 21ms

⎯⎯⎯⎯⎯⎯⎯ Failed Tests 3 ⎯⎯⎯⎯⎯⎯⎯

 FAIL  test/migracion-0003.test.ts > Migración 0003 en bases aisladas (legajos_owner) > rechaza un legajo v1 y conserva datos, schema, triggers, grants y journal íntegros
 FAIL  test/migracion-0003.test.ts > Migración 0003 en bases aisladas (legajos_owner) > la red de seguridad también rechaza contador sin cambios
 FAIL  test/migracion-0003.test.ts > Migración 0003 en bases aisladas (legajos_owner) > la red de seguridad también rechaza obligatorio sin cambios
PostgresError: relation "legajos" does not exist
 ❯ ErrorResponse node_modules/.pnpm/postgres@3.4.9/node_modules/postgres/src/connection.js:815:30
 ❯ handle node_modules/.pnpm/postgres@3.4.9/node_modules/postgres/src/connection.js:489:6
 ❯ Socket.data node_modules/.pnpm/postgres@3.4.9/node_modules/postgres/src/connection.js:324:9
 ❯ cachedError node_modules/.pnpm/postgres@3.4.9/node_modules/postgres/src/query.js:170:23
 ❯ new Query node_modules/.pnpm/postgres@3.4.9/node_modules/postgres/src/query.js:36:24
 ❯ sql node_modules/.pnpm/postgres@3.4.9/node_modules/postgres/src/index.js:112:11
 ❯ capturarBase test/migracion-0003.test.ts:76:27
     74|     const datos: Record<string, unknown> = {};
     75|     for (const tabla of tablas) {
     76|       const filas = await conexion`
       |                           ^
     77|         SELECT coalesce(jsonb_agg(to_jsonb(t) ORDER BY to_jsonb(t)::te…
     78|         FROM ${conexion('legajos', tabla.relname)} AS t

⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯[1/3]⎯


 Test Files  1 failed | 4 passed (5)
      Tests  3 failed | 144 passed (147)
   Start at  15:38:32
   Duration  2.94s (transform 66ms, setup 0ms, collect 326ms, tests 804ms, environment 1ms, prepare 198ms)
```

Código de salida: 1.

El primer chequeo estricto detectó incompatibilidad entre los parámetros genéricos de db._.session y PgDialect.migrate:

```text
test/migracion-0003.test.ts(39,75): error TS2345: Argument of type 'PgSession<PostgresJsQueryResultHKT, Record<string, never>, ExtractTablesWithRelations<Record<string, never>>>' is not assignable to parameter of type 'PgSession<PgQueryResultHKT, Record<string, never>, Record<string, never>>'.
  Type 'ExtractTablesWithRelations<Record<string, never>>' is not assignable to type 'Record<string, never>'.
    'string' index signatures are incompatible.
      Type '{ tsName: string; dbName: never; columns: never; relations: Record<string, Relation<string>>; primaryKey: AnyColumn[]; }' is not assignable to type 'never'.
```

Código de salida: 2. Se reemplazó por PostgresJsSession con parámetros explícitos para una sesión sin schema relacional; sin any, casts ni supresiones. Luego pasaron tanto el chequeo estricto como la corrida final completa pegada arriba.

## Lo que no se ejecutó / pendiente

Ningún criterio de esta tarea quedó pendiente. No se ejecutó `pnpm verificar`, typecheck global ni build: la spec limita la verificación a base y prevé que los servicios v1 se adapten en M2. Este informe es de implementación; la auditoría corresponde a AGY y al arquitecto.
