# Informe — M2a-servicios-legajo-tramite

**Estado:** COMPLETADO
**Implementador:** CODEX, sombrero B
**Rama:** modelo-v2
**Verificación de la spec:** código de salida 0; lint y 232 pruebas aprobadas en 6 suites.
**Typecheck del alcance:** código de salida 0, sin diagnósticos.

## Archivos creados

- `src/server/cedula.ts`
- `src/server/servicios/tramites.ts`
- `test/tramites.test.ts`

## Archivos modificados

- `src/server/permisos.ts`
- `src/server/servicios/contratos.ts`
- `src/server/servicios/legajos.ts`
- `src/server/servicios/mapeo.ts`
- `test/legajos.test.ts`
- `test/permisos.unit.test.ts`

## Archivo eliminado

- `test/cedulas.test.ts`, reemplazado por la suite de trámites según la spec.

Todas las rutas anteriores son relativas a `legajos/`.

## Implementación y decisiones

- Normalización común de cédulas al guardar, corregir y buscar. Las altas concurrentes usan `ON CONFLICT (cedula) DO NOTHING RETURNING` y luego consultan el existente; no sobrescriben datos.
- El helper `obtenerOCrearLegajoTx` comparte la transacción del trámite; audita el alta o la consulta del legajo reutilizado.
- Corrección administrativa mediante `legajos.corregir_cedula`, con usuario, motivo, IP y UUIDv7 de auditoría. Traducciones de 23505 a 409, 42501 a 403 y P0002 a 404.
- Numeración atómica por año de Asunción con Luxon. Alta de trámite, legajos, vínculos y auditorías en una transacción; rechazo de IDs repetidos, incluso cuando dos entradas nuevas normalizan al mismo número.
- Vincular, desvincular y marcar original comienzan sus consultas con el candado `FOR UPDATE` del trámite. Revincular crea otra fila; el historial permanece.
- Desvincular conserva al menos un vínculo vivo, desmarca la original y devuelve a pendiente sólo las solicitudes del trámite satisfechas por documentos del legajo desvinculado. Candados de documentos y solicitudes ordenados por ID; auditoría del vínculo y las solicitudes con motivo.
- Faltantes toma las relaciones de documentos obligatorios activas del tipo; acepta documentos vivos de cualquier procedencia y también vencidos.
- Vista del legajo con documentos y procedencia, vínculos históricos a trámites y relacionados con vínculos vivos de ambos lados. La marca original es null cuando el trámite no tiene original viva.
- Contratos y mapeos de documentos/interacciones adaptados a las columnas v2; quitada la entidad cédula y el atributo `obligatorio` del catálogo de documentos.
- Pruebas de concurrencia con el pool real conectado como `legajos_app`. Fixtures de solicitudes sembrados como owner. Dos pruebas que agregan catálogos usan una transacción externa con rollback y savepoints reales: conexión administrativa sólo para cambiar el rol local; fixtures como `legajos_owner`, servicios como `legajos_app`, comprobando `current_user` y ausencia de pertenencia a owner. Esto evita contaminar las aserciones de seeds de M1 sin borrados ni cambios de grants.
- La primera corrida señaló la representación de IP de la función SQL (`inet::text` agrega /32) y contaminación de catálogos; se corrigieron las pruebas. Se compara la IP de auditoría con `host(ip::inet)`.
- El pnpm global (11.22.0) falló con `unable to open database file`. Se priorizó en PATH el pnpm 11.0.0 ya instalado en `node_modules/.bin`, correspondiente al `packageManager` del proyecto. No se instalaron dependencias.

## Pendientes fuera del alcance

- `verTramite` devuelve interacciones y solicitudes vacías con TODO M2b, como pide la spec.
- No se adaptaron los servicios existentes de documentos, interacciones, admin ni el servicio obsoleto `servicios/cedulas.ts`; sus implementaciones y consumidores anteriores siguen pendientes de M2b/M3. El typecheck global todavía tiene incompatibilidades del modelo anterior fuera de esta tarea.
- No se ejecutó build ni la suite global: el criterio de esta tarea es el comando específico de abajo. Se ejecutó adicionalmente un typecheck estricto de todos los archivos del alcance.
- Sin commit ni push. Sin cambios en `src/app/**`, schema, migraciones o grants. No se realizó auditoría del propio código.

## Comando de verificación y salida real

Ejecutado desde `/home/ecenturion/develop/legajos`:

```sh
export PATH="$PWD/node_modules/.bin:$PATH"
pnpm lint && docker compose -f compose.test.yml down && docker compose -f compose.test.yml up -d --wait && pnpm vitest run test/legajos.test.ts test/tramites.test.ts test/permisos.unit.test.ts test/schema.test.ts test/triggers.test.ts test/permisos.test.ts
```

Salida completa (stdout y stderr), código de salida 0:

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
 ✓ test/tramites.test.ts (20 tests) 509ms
 ✓ test/triggers.test.ts (44 tests) 200ms
 ✓ test/schema.test.ts (60 tests) 165ms
 ✓ test/legajos.test.ts (15 tests) 166ms
 ✓ test/permisos.test.ts (36 tests) 47ms
 ✓ test/permisos.unit.test.ts (57 tests) 4ms

 Test Files  6 passed (6)
      Tests  232 passed (232)
   Start at  15:55:58
   Duration  3.95s (transform 134ms, setup 0ms, collect 817ms, tests 1.09s, environment 1ms, prepare 241ms)

```

## Typecheck del alcance

Ejecutado desde `/home/ecenturion/develop/legajos`:

```sh
export PATH="$PWD/node_modules/.bin:$PATH"
pnpm exec tsc --noEmit --strict --noUncheckedIndexedAccess --skipLibCheck --target ES2022 --module ESNext --moduleResolution Bundler --esModuleInterop src/server/cedula.ts src/server/permisos.ts src/server/servicios/contratos.ts src/server/servicios/legajos.ts src/server/servicios/tramites.ts src/server/servicios/mapeo.ts test/legajos.test.ts test/tramites.test.ts test/permisos.unit.test.ts
```

Salida stdout/stderr vacía; código de salida 0.

`git -C legajos diff --check`: salida vacía, código de salida 0.

