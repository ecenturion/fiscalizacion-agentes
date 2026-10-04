# Informe — L02b-grants-y-triggers

**Estado:** FALLÓ
**Implementador:** CODEX, sombrero B
**Fecha:** 2026-10-04

La implementación del alcance está escrita. La verificación completa devuelve código 1: 105 pruebas aprobadas y una fallida en un archivo fuera del alcance. Las 50 pruebas nuevas pasan (29 de permisos y 21 de triggers). Lint y typecheck pasan dentro de `pnpm verificar`; el build ejecutado por separado devuelve código 0. `pnpm db:generate` devuelve «No schema changes».

## Archivos

Creados en `legajos/`:

- `drizzle/0002_grants_y_triggers.sql`.
- `drizzle/meta/0002_snapshot.json`, generado por drizzle-kit.
- `test/permisos.test.ts`.
- `test/triggers.test.ts`.

Modificado en `legajos/`:

- `drizzle/meta/_journal.json`, actualizado por drizzle-kit.

Única escritura en `legajos-agents/`: este informe. No se modificaron 0000, 0001, los roles ni archivos fuera del alcance. Sin commit ni push.

## Decisiones

- Migración custom generada con drizzle-kit; no se cambió el schema TypeScript.
- SELECT e INSERT en las 16 tablas; UPDATE exclusivamente sobre las columnas enumeradas por la spec. Los tests comparan el inventario completo de tablas y todas sus columnas contra esa fuente.
- Cuatro funciones en `legajos`, con propietario `legajos_owner`, referencias calificadas y `search_path = legajos, pg_temp`. Sólo el cambio de estado es SECURITY DEFINER. Se revoca EXECUTE a PUBLIC y a la app en cada función de trigger.
- El cambio de estado toma FOR UPDATE y rechaza estados anteriores desactualizados con P0001 y el mensaje requerido. Las versiones bloquean el documento anterior; la cardinalidad también bloquea el documento para serializarse con su anulación.
- Las solicitudes validan legajo y tipo al insertar y al actualizar el documento recibido. El control de documento vivo queda para el servicio, como exige la tarea.
- Catálogos con UUIDv7 fijos, activos, vigencias nulas y sólo Nota con múltiples archivos.
- Todas las operaciones probadas se ejecutan con conexiones app. La siembra compartida usa owner en beforeAll. Las pruebas ordinarias revierten su transacción; la prueba concurrente usa dos conexiones app y comprueba un bloqueo real mediante pg_stat_activity desde otra conexión app antes de confirmar la primera.
- Los fixtures compartidos tienen UUIDv7 con sufijo aleatorio y numeración obtenida de un contador de prueba para permitir repetir los tests sin reiniciar la base. No se usa DELETE para limpiar.
- Para observar que una interacción sin estados no actualiza el legajo se compara también ctid, que cambia con un UPDATE incluso dentro de la misma transacción.

## Pendientes y límites

1. **`test/schema.test.ts:220`**, fuera del alcance: el test existente renombra su fixture a «Nota» antes de probar la colisión con «nota». La nueva siembra obligatoria ya contiene «Nota», por lo que ese UPDATE falla con 23505 antes de llegar a su aserción. Corregirlo exige modificar ese test (por ejemplo, usar un nombre de fixture que no pertenezca al catálogo). Se dejó intacto.
2. **`drizzle/0002_grants_y_triggers.sql:4`**: se ejecuta exactamente el REVOKE global pedido, pero PostgreSQL emite avisos 01006 para funciones de las extensiones. Sus funciones internas pertenecen a `postgres`, aunque las extensiones fueron creadas desde la migración owner. `legajos_owner` no puede revocar esos permisos: la consulta de diagnóstico confirma que ambas sobrecargas de unaccent conservan EXECUTE de PUBLIC. Los permisos de tablas y funciones de trigger sí están comprobados. La revocación efectiva de todas las funciones del esquema requiere resolver la administración de las funciones de extensión; además hay que conservar la ejecución interna necesaria para f_unaccent. No se escaló el rol ni se modificaron migraciones previas o el bootstrap fuera de alcance.
3. El pnpm instalado es **11.22.0** y el proyecto declara 11.0.0. Sin ajustes, pnpm intenta abrir su store externo y falla antes de ejecutar la tarea. Se usaron sólo variables de entorno en los comandos: `pnpm_config_pm_on_fail=ignore` y `pnpm_config_verify_deps_before_run=false`. Evitan el cambio automático de versión y la reinstalación automática; no se cambiaron dependencias ni configuración.
4. Next.js avisa que detectó otro lockfile y dedujo una raíz fuera del repo. El build termina correctamente; no se modificó su configuración, que queda fuera del alcance.

## Salida real — generación custom

Comando ejecutado desde `legajos/`:

```sh
env pnpm_config_pm_on_fail=ignore pnpm_config_verify_deps_before_run=false pnpm drizzle-kit generate --custom --name grants_y_triggers
```

Código de salida: 0.

```text
No config path provided, using default 'drizzle.config.ts'
Reading config file '/home/ecenturion/develop/legajos/drizzle.config.ts'
Prepared empty file for your custom SQL migration!
[✓] Your SQL migration file ➜ drizzle/0002_grants_y_triggers.sql 🚀
```

## Salida real — verificación final con base recreada

Comando ejecutado desde `legajos/`:

```sh
export pnpm_config_pm_on_fail=ignore pnpm_config_verify_deps_before_run=false
docker compose -f compose.test.yml down && docker compose -f compose.test.yml up -d --wait && pnpm verificar
```

Código de salida: 1.

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
 ❯ test/schema.test.ts (53 tests | 1 failed) 123ms
   ✓ Tablas y constraints de legajos (legajos_owner) > conecta como legajos_owner 18ms
   ✓ Tablas y constraints de legajos (legajos_owner) > genera 2026-0001 y conserva los cinco dígitos de 2026-12345 2ms
   ✓ Tablas y constraints de legajos (legajos_owner) > rechaza un (anio, correlativo) duplicado 6ms
   ✓ Tablas y constraints de legajos (legajos_owner) > rechaza dos cédulas originales vivas del mismo legajo 4ms
   ✓ Tablas y constraints de legajos (legajos_owner) > permite otra original cuando la anterior está anulada 3ms
   ✓ Tablas y constraints de legajos (legajos_owner) > rechaza el número de cédula 12a 1ms
   ✓ Tablas y constraints de legajos (legajos_owner) > Anulación de cedula > rechaza la combinación parcial (true, false, false) 2ms
   ✓ Tablas y constraints de legajos (legajos_owner) > Anulación de cedula > rechaza la combinación parcial (false, true, false) 2ms
   ✓ Tablas y constraints de legajos (legajos_owner) > Anulación de cedula > rechaza la combinación parcial (false, false, true) 2ms
   ✓ Tablas y constraints de legajos (legajos_owner) > Anulación de cedula > rechaza la combinación parcial (true, true, false) 2ms
   ✓ Tablas y constraints de legajos (legajos_owner) > Anulación de cedula > rechaza la combinación parcial (true, false, true) 1ms
   ✓ Tablas y constraints de legajos (legajos_owner) > Anulación de cedula > rechaza la combinación parcial (false, true, true) 2ms
   ✓ Tablas y constraints de legajos (legajos_owner) > Anulación de cedula > rechaza un motivo con sólo espacios 2ms
   ✓ Tablas y constraints de legajos (legajos_owner) > Anulación de cedula > acepta las tres columnas completas 2ms
   ✓ Tablas y constraints de legajos (legajos_owner) > Anulación de documento > rechaza la combinación parcial (true, false, false) 2ms
   ✓ Tablas y constraints de legajos (legajos_owner) > Anulación de documento > rechaza la combinación parcial (false, true, false) 1ms
   ✓ Tablas y constraints de legajos (legajos_owner) > Anulación de documento > rechaza la combinación parcial (false, false, true) 1ms
   ✓ Tablas y constraints de legajos (legajos_owner) > Anulación de documento > rechaza la combinación parcial (true, true, false) 1ms
   ✓ Tablas y constraints de legajos (legajos_owner) > Anulación de documento > rechaza la combinación parcial (true, false, true) 1ms
   ✓ Tablas y constraints de legajos (legajos_owner) > Anulación de documento > rechaza la combinación parcial (false, true, true) 1ms
   ✓ Tablas y constraints de legajos (legajos_owner) > Anulación de documento > rechaza un motivo con sólo espacios 1ms
   ✓ Tablas y constraints de legajos (legajos_owner) > Anulación de documento > acepta las tres columnas completas 1ms
   ✓ Tablas y constraints de legajos (legajos_owner) > Anulación de interaccion > rechaza la combinación parcial (true, false, false) 2ms
   ✓ Tablas y constraints de legajos (legajos_owner) > Anulación de interaccion > rechaza la combinación parcial (false, true, false) 2ms
   ✓ Tablas y constraints de legajos (legajos_owner) > Anulación de interaccion > rechaza la combinación parcial (false, false, true) 2ms
   ✓ Tablas y constraints de legajos (legajos_owner) > Anulación de interaccion > rechaza la combinación parcial (true, true, false) 1ms
   ✓ Tablas y constraints de legajos (legajos_owner) > Anulación de interaccion > rechaza la combinación parcial (true, false, true) 1ms
   ✓ Tablas y constraints de legajos (legajos_owner) > Anulación de interaccion > rechaza la combinación parcial (false, true, true) 1ms
   ✓ Tablas y constraints de legajos (legajos_owner) > Anulación de interaccion > rechaza un motivo con sólo espacios 1ms
   ✓ Tablas y constraints de legajos (legajos_owner) > Anulación de interaccion > acepta las tres columnas completas 1ms
   ✓ Tablas y constraints de legajos (legajos_owner) > rechaza la nota vacía "" 2ms
   ✓ Tablas y constraints de legajos (legajos_owner) > rechaza la nota vacía "  " 1ms
   ✓ Tablas y constraints de legajos (legajos_owner) > rechaza sólo estado_nuevo_id 1ms
   ✓ Tablas y constraints de legajos (legajos_owner) > rechaza sólo estado_anterior_id 1ms
   ✓ Tablas y constraints de legajos (legajos_owner) > rechaza ambos estados iguales 1ms
   ✓ Tablas y constraints de legajos (legajos_owner) > acepta ambos estados nulos 1ms
   ✓ Tablas y constraints de legajos (legajos_owner) > acepta ambos estados distintos 2ms
   ✓ Tablas y constraints de legajos (legajos_owner) > acepta un tipo sin vigencia (requisitos §2.3: es opcional) 2ms
   ✓ Tablas y constraints de legajos (legajos_owner) > rechaza vigencia_dias = 0 1ms
   ✓ Tablas y constraints de legajos (legajos_owner) > rechaza Nota y nota en estado_legajo 2ms
   ✓ Tablas y constraints de legajos (legajos_owner) > rechaza Nota y nota en tipo_interaccion 1ms
   × Tablas y constraints de legajos (legajos_owner) > rechaza Nota y nota en tipo_documento 2ms
     → duplicate key value violates unique constraint "tipo_documento_nombre_idx"
   ✓ Tablas y constraints de legajos (legajos_owner) > rechaza archivos image/gif 2ms
   ✓ Tablas y constraints de legajos (legajos_owner) > rechaza el orden repetido en un documento 2ms
   ✓ Tablas y constraints de legajos (legajos_owner) > rechaza un path_relativo repetido aunque cambie el orden 2ms
   ✓ Tablas y constraints de legajos (legajos_owner) > acepta un archivo application/pdf 1ms
   ✓ Tablas y constraints de legajos (legajos_owner) > acepta un archivo image/jpeg 1ms
   ✓ Tablas y constraints de legajos (legajos_owner) > acepta un archivo image/png 2ms
   ✓ Tablas y constraints de legajos (legajos_owner) > rechaza dos versiones que apuntan al mismo documento 2ms
   ✓ Tablas y constraints de legajos (legajos_owner) > acepta ip nula para un acceso con resultado ip_invalida 2ms
   ✓ Tablas y constraints de legajos (legajos_owner) > todas las FK aplican ON DELETE RESTRICT 2ms
   ✓ Tablas y constraints de legajos (legajos_owner) > los UUID no tienen DEFAULT y la nulabilidad coincide con §9.1 7ms
   ✓ Tablas y constraints de legajos (legajos_owner) > las extensiones y el índice trigram usan el esquema legajos 3ms
 ✓ test/triggers.test.ts (21 tests) 110ms
 ✓ test/permisos.test.ts (29 tests) 39ms
 ✓ test/humo.test.ts (3 tests) 22ms

⎯⎯⎯⎯⎯⎯⎯ Failed Tests 1 ⎯⎯⎯⎯⎯⎯⎯

 FAIL  test/schema.test.ts > Tablas y constraints de legajos (legajos_owner) > rechaza Nota y nota en tipo_documento
PostgresError: duplicate key value violates unique constraint "tipo_documento_nombre_idx"
 ❯ ErrorResponse node_modules/.pnpm/postgres@3.4.9/node_modules/postgres/src/connection.js:815:30
 ❯ handle node_modules/.pnpm/postgres@3.4.9/node_modules/postgres/src/connection.js:489:6
 ❯ Socket.data node_modules/.pnpm/postgres@3.4.9/node_modules/postgres/src/connection.js:324:9
 ❯ cachedError node_modules/.pnpm/postgres@3.4.9/node_modules/postgres/src/query.js:170:23
 ❯ new Query node_modules/.pnpm/postgres@3.4.9/node_modules/postgres/src/query.js:36:24
 ❯ sql node_modules/.pnpm/postgres@3.4.9/node_modules/postgres/src/index.js:112:11
 ❯ test/schema.test.ts:220:11
    218| 
    219|   it.each(['estado_legajo', 'tipo_interaccion', 'tipo_documento'] as c…
    220|     await tx`UPDATE legajos.${tx(tabla)} SET nombre = 'Nota' WHERE id …
       |           ^
    221|       tabla === 'estado_legajo' ? base.estado : tabla === 'tipo_intera…
    222|     }`;

⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯[1/1]⎯


 Test Files  1 failed | 3 passed (4)
      Tests  1 failed | 105 passed (106)
   Start at  15:41:29
   Duration  1.86s (transform 53ms, setup 0ms, collect 80ms, tests 294ms, environment 1ms, prepare 152ms)

[ELIFECYCLE] Test failed. See above for more details.
[ELIFECYCLE] Command failed with exit code 1.
```

## Salida real — comprobación del schema

```sh
export pnpm_config_pm_on_fail=ignore pnpm_config_verify_deps_before_run=false
pnpm db:generate
```

Código de salida: 0.

```text
$ drizzle-kit generate
No config path provided, using default 'drizzle.config.ts'
Reading config file '/home/ecenturion/develop/legajos/drizzle.config.ts'
16 tables
acceso_log 7 columns 1 indexes 1 fks
auditoria 9 columns 0 indexes 1 fks
cedula 14 columns 2 indexes 3 fks
contador_legajo 2 columns 0 indexes 0 fks
documento 11 columns 1 indexes 5 fks
documento_archivo 8 columns 0 indexes 1 fks
estado_legajo 4 columns 1 indexes 0 fks
interaccion 12 columns 1 indexes 6 fks
legajo 9 columns 0 indexes 2 fks
limite_ip 3 columns 0 indexes 0 fks
sesion 8 columns 0 indexes 1 fks
solicitud_documento 5 columns 0 indexes 4 fks
tipo_documento 6 columns 1 indexes 0 fks
tipo_interaccion 4 columns 1 indexes 0 fks
usuario 10 columns 0 indexes 0 fks
usuario_ip 7 columns 0 indexes 2 fks

No schema changes, nothing to migrate 😴
```

## Salida real — build por separado

El encadenamiento de verificar se detiene al fallar los tests; se ejecutó el build por separado.

```sh
export pnpm_config_pm_on_fail=ignore pnpm_config_verify_deps_before_run=false
pnpm build
```

Código de salida: 0.

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
 ✓ Compiled successfully in 783ms
   Linting and checking validity of types ...
   Collecting page data ...
   Generating static pages (0/4) ...
   Generating static pages (1/4) 
   Generating static pages (2/4) 
   Generating static pages (3/4) 
 ✓ Generating static pages (4/4)
   Finalizing page optimization ...
   Collecting build traces ...

Route (app)                                 Size  First Load JS
┌ ○ /                                      125 B         103 kB
└ ○ /_not-found                            996 B         104 kB
+ First Load JS shared by all             103 kB
  ├ chunks/758-942e49721ce48ac0.js       46.5 kB
  ├ chunks/d36d6ee9-817a06892149dc1d.js  54.4 kB
  └ other shared chunks (total)          1.87 kB


○  (Static)  prerendered as static content

```

## Salida real — diagnóstico de funciones de extensión

Consulta desde una conexión `legajos_app`:

```sql
SELECT p.oid::regprocedure::text AS funcion,
  pg_catalog.pg_get_userbyid(p.proowner) AS propietario,
  pg_catalog.has_function_privilege(current_user, p.oid, 'EXECUTE') AS ejecutable_app,
  p.proacl::text AS acl
FROM pg_catalog.pg_proc AS p
JOIN pg_catalog.pg_namespace AS n ON n.oid = p.pronamespace
WHERE n.nspname = 'legajos' AND p.proname IN ('unaccent', 'f_unaccent')
ORDER BY funcion;
SELECT legajos.f_unaccent('José Gómez') AS normalizado;
```

Código de salida del comando Node que ejecuta ambas consultas: 0.

```text
[
  {
    "funcion": "f_unaccent(text)",
    "propietario": "legajos_owner",
    "ejecutable_app": true,
    "acl": "{legajos_owner=X/legajos_owner,legajos_app=X/legajos_owner}"
  },
  {
    "funcion": "unaccent(regdictionary,text)",
    "propietario": "postgres",
    "ejecutable_app": true,
    "acl": "{=X/postgres,postgres=X/postgres}"
  },
  {
    "funcion": "unaccent(text)",
    "propietario": "postgres",
    "ejecutable_app": true,
    "acl": "{=X/postgres,postgres=X/postgres}"
  }
]
[{"normalizado":"Jose Gomez"}]
```

## Otras comprobaciones

`git diff --check`: código 0, salida vacía. El inventario final de cambios contiene únicamente los cinco archivos del alcance enumerados arriba.

El primer intento sin ajustes de entorno (`pnpm drizzle-kit generate --custom --name grants_y_triggers`) devolvió código 1:

```text
[ERROR] unable to open database file
For help, run: pnpm help run
```

