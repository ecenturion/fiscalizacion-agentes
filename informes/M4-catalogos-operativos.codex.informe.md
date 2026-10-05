# Informe — M4-catalogos-operativos

**Estado:** COMPLETADO
**Implementador:** CODEX, sombrero B
**Fecha:** 2026-10-05
**Verificación final:** código de salida 0; lint, typecheck, 506 tests en 21 archivos y build completados.

## Archivos

Creados:
- `src/server/servicios/catalogos.ts`
- `test/catalogos.test.ts`

Modificados:
- `src/server/acciones/contexto.ts`
- `src/server/servicios/contratos.ts`
- `src/server/servicios/mapeo.ts`
- `src/server/servicios/legajos.ts`
- `src/server/servicios/tramites.ts`
- `src/server/servicios/interacciones.ts`
- `src/app/(app)/tramites/acciones.ts`
- `src/app/(app)/tramites/nuevo/page.tsx`
- `src/app/(app)/tramites/page.tsx`
- `src/app/(app)/tramites/[id]/page.tsx`
- `src/app/(app)/legajos/page.tsx`
- `test/tramites.test.ts`
- `test/legajos.test.ts`
- `test/interacciones.test.ts`
- `test/acciones.test.ts`

Borrado, como indica la spec:
- `src/app/(app)/tramites/catalogos.ts`

Único archivo escrito en `legajos-agents/`: este informe. No hubo commit, push ni despliegue.

## Implementación y decisiones

- `catalogosOperativos(ctx)` exige `tramite.ver`, lee únicamente catálogos activos en una transacción repeatable read y no audita vistas. Tipos de trámite, estados e interacciones se ordenan por orden y nombre; tipos de documento por nombre, porque su tabla no tiene columna orden. Estos últimos incluyen vigenciaDias y multiplesArchivos.
- Las tres páginas de trámites consumen ese servicio. Nuevo trámite dispone del tipo sembrado “Múltiple cedulación” aunque no existan trámites.
- Los resúmenes incorporan cantidadTramites y cedulas mediante subconsultas correlacionadas dentro de la consulta SQL principal: no hay una consulta adicional por fila ni por vínculo. El conteo y las cédulas excluyen vínculos anulados. También se completan los resúmenes de legajos relacionados y de trámites en el detalle del legajo.
- nombreUsuario viene de un JOIN a usuario.nombre; los autores inactivos siguen apareciendo en el historial.
- obligatorios y faltantes derivan de la misma lectura. Se conserva la regla vigente: un documento vivo de un legajo vinculado cumple aunque esté vencido o tenga otra procedencia. Se distingue ausencia de obligatorios de cumplimiento de todos ellos.
- Los documentos del trámite se cargan con una sola consulta por tramite_id, incluyendo sus archivos por LEFT JOIN y agrupación en memoria. Se conservan documentos anulados y de vínculos anulados. El mapeo mantiene vencimiento, metadatos y orden de archivos. La UI usa tramite.documentos y deja de consultar/auditar los documentos de cada legajo.
- registrarInteraccionAccion, su variante Con, el servicio y la visibilidad del formulario exigen interaccion.crear. Se comprobó que la matriz ya lo incluye para admin y operador; no fue necesario editar permisos.ts.
- Los tests usan Postgres real como legajos_app, con fixtures de catálogos aisladas mediante rollback. Cubren consulta, sesión inválida (401 en el guard), catálogos inactivos, orden, tipo sin trámites, cédulas/original, conteo vivo, nombre del autor, documentos y obligatorios. El logger de Drizzle compara verTramite y buscarTramites con uno y cinco vínculos: las consultas no crecen; se comprueba una sola consulta de documentos y una sola auditoría por vista.
- La primera prueba focalizada dio 82 éxitos y 3 fallos. Drizzle eliminaba la calificación de legajo.id en la subconsulta de una selección de tabla única, dando conteo cero; se corrigió usando la referencia SQL completamente calificada. El otro fallo era un filtro del logger que contaba también el EXISTS de obligatorios; se ajustó para identificar el JOIN a documento_archivo. La corrida final pasó todos esos casos.

## Verificación final — salida real completa

pnpm inicialmente falló con `unable to open database file` al intentar usar su caché fuera del área escribible. Se ejecutó con XDG_CACHE_HOME y XDG_DATA_HOME dentro de `legajos/node_modules/.cache`, sin tocar directorios externos. El comando funcional de la spec se mantuvo:

```sh
cd legajos && docker compose -f compose.test.yml down && docker compose -f compose.test.yml up -d --wait && XDG_CACHE_HOME=$PWD/node_modules/.cache XDG_DATA_HOME=$PWD/node_modules/.cache pnpm verificar
```

La salida de Docker se recibió directamente; stdout/stderr de pnpm se capturó en `node_modules/.cache/M4-verificar.log`. Código de salida del comando completo: **0**.

```text
 Container legajos-postgres-1 Stopping 
 Container legajos-postgres-1 Stopped 
 Container legajos-postgres-1 Removing 
 Container legajos-postgres-1 Removed 
 Network legajos_default Removing 
 Network legajos_default Removed 
 Network legajos_default Creating 
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
 ✓ test/acciones.test.ts (31 tests) 655ms
 ✓ test/tramites.test.ts (22 tests) 639ms
 ✓ test/legajos.test.ts (16 tests) 206ms
 ✓ test/login.test.ts (14 tests) 3676ms
   ✓ Login y cambio de clave con Postgres real como legajos_app > cinco fallos bloquean; la clave correcta no pasa hasta +16 minutos  367ms
   ✓ Login y cambio de clave con Postgres real como legajos_app > inexistente usa señuelo, con mediana de cinco muestras a menos del 30%  451ms
   ✓ Login y cambio de clave con Postgres real como legajos_app > 20 fallos por IP, el 21 no verifica ni modifica cuenta; ventana vencida reinicia  937ms
   ✓ Login y cambio de clave con Postgres real como legajos_app > 25 concurrentes desde una IP: sólo 20 verifican argon2  892ms
 ✓ test/logout-y-cli.test.ts (12 tests) 2843ms
   ✓ Logout y recuperación administrativa > CLI imprime una clave de 16 caracteres una vez, agrega IPv6 y cierra todas las sesiones  489ms
   ✓ Logout y recuperación administrativa > CLI normaliza IPv4-mapped y agrega /32  349ms
   ✓ Logout y recuperación administrativa > CLI rechaza usuario no admin, sin modificaciones ni clave en stdout  348ms
   ✓ Logout y recuperación administrativa > CLI rechaza legajos online y acepta la aplicación detenida  754ms
   ✓ Logout y recuperación administrativa > CLI falla si el lock está ocupado  348ms
 ✓ test/documentos.test.ts (45 tests) 1919ms
 ✓ test/admin.test.ts (19 tests) 1142ms
   ✓ Administración contra Postgres real como legajos_app > dos admins que se desactivan mutuamente en paralelo dejan al menos uno activo  373ms
 ✓ test/archivos-validar.test.ts (15 tests) 718ms
 ✓ test/rutas-documentos.test.ts (17 tests) 521ms
 ✓ test/migracion-0003.test.ts (4 tests) 410ms
 ✓ test/interacciones.test.ts (13 tests) 351ms
 ✓ test/triggers.test.ts (44 tests) 202ms
 ✓ test/auth-guard.test.ts (40 tests) 161ms
 ✓ test/schema.test.ts (60 tests) 171ms
 ✓ test/archivos-almacen.test.ts (19 tests) 155ms
 ✓ test/catalogos.test.ts (3 tests) 55ms
 ✓ test/permisos.test.ts (36 tests) 44ms
 ✓ test/guard-cobertura.test.ts (12 tests) 46ms
 ✓ test/humo.test.ts (3 tests) 22ms
 ✓ test/ip.test.ts (24 tests) 7ms
 ✓ test/permisos.unit.test.ts (57 tests) 4ms

 Test Files  21 passed (21)
      Tests  506 passed (506)
   Start at  17:16:20
   Duration  23.24s (transform 380ms, setup 0ms, collect 4.42s, tests 13.95s, environment 3ms, prepare 798ms)

$ next build
 ⚠ Warning: Next.js inferred your workspace root, but it may not be correct.
 We detected multiple lockfiles and selected the directory of /home/ecenturion/pnpm-lock.yaml as the root directory.
 To silence this warning, set `outputFileTracingRoot` in your Next.js config, or consider removing one of the lockfiles if it's not needed.
   See https://nextjs.org/docs/app/api-reference/config/next-config-js/output#caveats for more information.
 Detected additional lockfiles: 
   * /home/ecenturion/develop/legajos/pnpm-lock.yaml

   ▲ Next.js 15.5.27

   Creating an optimized production build ...
 ✓ Compiled successfully in 2.7s
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

## Corrida focalizada previa — salida real completa (fallos corregidos)

```sh
cd legajos && XDG_CACHE_HOME=$PWD/node_modules/.cache XDG_DATA_HOME=$PWD/node_modules/.cache pnpm exec vitest run test/catalogos.test.ts test/tramites.test.ts test/legajos.test.ts test/interacciones.test.ts test/acciones.test.ts
```

Salida capturada en `node_modules/.cache/M4-pruebas.log`:

```text

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
 ❯ test/acciones.test.ts (31 tests | 1 failed) 664ms
   ✓ Actions con sesión y servicios reales conectados como legajos_app > sin sesión redirige a login antes de validar o escribir 18ms
   ✓ Actions con sesión y servicios reales conectados como legajos_app > consulta creando un legajo recibe permiso_denegado sin cerrar su sesión 10ms
   ✓ Actions con sesión y servicios reales conectados como legajos_app > Origin ajeno recibe origen_invalido antes de escribir 5ms
   ✓ Actions con sesión y servicios reales conectados como legajos_app > entrada inválida devuelve campos, incluyendo legajos anidados 8ms
   × Actions con sesión y servicios reales conectados como legajos_app > editar devuelve ok:true, persiste y revalida las rutas afectadas 15ms
     → expected { ok: true, datos: { …(10) } } to match object { ok: true, datos: { …(3) } }
(7 matching properties omitted from actual)
   ✓ Actions con sesión y servicios reales conectados como legajos_app > obtenerOCrear devuelve el legajo y lo reutiliza sin redirigir 16ms
   ✓ Actions con sesión y servicios reales conectados como legajos_app > crearTramite confirma y revalida antes de redirigir fuera de aResultado 22ms
   ✓ Actions con sesión y servicios reales conectados como legajos_app > un error interno inyectado se oculta y no revalida 4ms
   ✓ Actions con sesión y servicios reales conectados como legajos_app > buscarPorCedula es lectura, admite consulta sin Origin y audita sin revalidar 6ms
   ✓ Actions con sesión y servicios reales conectados como legajos_app > corregirCedula normaliza, exige motivo y devuelve el legajo persistido 7ms
   ✓ Actions con sesión y servicios reales conectados como legajos_app > editarTramite, vincular, marcar original y desvincular usan los servicios reales 27ms
   ✓ Actions con sesión y servicios reales conectados como legajos_app > registrar y anular interacción devuelven el resultado persistido 13ms
   ✓ Actions con sesión y servicios reales conectados como legajos_app > registrarInteraccion exige interaccion.crear para admin y operador y rechaza consulta 15ms
   ✓ Actions con sesión y servicios reales conectados como legajos_app > anular documento devuelve la anulación y revalida el legajo 8ms
   ✓ Actions con sesión y servicios reales conectados como legajos_app > crearTipoTramite y definirDocumentosObligatorios persisten y revalidan catálogos y trámites 10ms
   ✓ Actions con sesión y servicios reales conectados como legajos_app > cada mutación nueva exige permiso y Origin antes de validar o ejecutar servicios 34ms
   ✓ Actions con sesión y servicios reales conectados como legajos_app > las acciones nuevas entregan campos inválidos sin escribir ni revalidar 21ms
   ✓ Actions con sesión y servicios reales conectados como legajos_app > cada acción nueva oculta fallos internos sin revalidar ni redirigir 20ms
   ✓ Actions con sesión y servicios reales conectados como legajos_app > crearUsuario y resetearClave exponen la clave sólo en el resultado de su llamada 191ms
   ✓ Actions con sesión y servicios reales conectados como legajos_app > la versión para Next usa el mismo guard y los servicios del proceso 12ms
   ✓ Actions con sesión y servicios reales conectados como legajos_app > las variantes Con rechazan dependencias inyectadas fuera de tests 2ms
   ✓ Actions con sesión y servicios reales conectados como legajos_app > cambiarCon conserva la rotación de sesión, la cookie y el redirect 131ms
   ✓ Actions con sesión y servicios reales conectados como legajos_app > cambiarCon entrega campos y el formulario cambiar conserva su firma void/error 8ms
   ✓ Resultado y contexto de página > traduce la excepción conocida Error: La operación entra en conflicto con los datos actuales. 0ms
   ✓ Resultado y contexto de página > traduce la excepción conocida Error: Operación no permitida. 0ms
   ✓ Resultado y contexto de página > traduce la excepción conocida Error: No encontrado. 0ms
   ✓ Resultado y contexto de página > traduce la excepción conocida Error: La carga supera los límites permitidos. 0ms
   ✓ Resultado y contexto de página > traduce la excepción conocida Error: Origen no permitido. 0ms
   ✓ Resultado y contexto de página > ErrorValidacion y ZodError producen campos, incluso errores generales 0ms
   ✓ Resultado y contexto de página > ctxPagina redirige sólo para sesión inválida o cambio obligatorio; el permiso se oculta 1ms
   ✓ Resultado y contexto de página > ctxPagina propaga fallos inesperados y servicios mantiene una sola instancia del proceso 1ms
 ❯ test/tramites.test.ts (22 tests | 1 failed) 632ms
   ✓ Trámites v2 contra Postgres real como legajos_app > usa legajos_app sin heredar owner 1ms
   ✓ Trámites v2 contra Postgres real como legajos_app > numera 2090-0001 y 2090-0002 con estado inicial y auditoría de todas las altas 28ms
   ✓ Trámites v2 contra Postgres real como legajos_app > 10 altas concurrentes reservan los correlativos 1..10 120ms
   ✓ Trámites v2 contra Postgres real como legajos_app > usa el año de Asunción UTC−3 y reinicia la numeración al cambiar de año 17ms
   ✓ Trámites v2 contra Postgres real como legajos_app > combina un legajo existente con otro presentado como nuevo que reutiliza su número 16ms
   ✓ Trámites v2 contra Postgres real como legajos_app > rechaza tipo inactivo con 422 y revierte el contador 14ms
   ✓ Trámites v2 contra Postgres real como legajos_app > rechaza legajos repetidos incluso por cédula normalizada y revierte todas las altas 13ms
   ✓ Trámites v2 contra Postgres real como legajos_app > dos marcas concurrentes preservan una única original; inicial=undefined 29ms
   ✓ Trámites v2 contra Postgres real como legajos_app > dos marcas concurrentes preservan una única original; inicial=0 29ms
   ✓ Trámites v2 contra Postgres real como legajos_app > marcarOriginal(null) deja la original sin determinar y audita el cambio 21ms
   ✓ Trámites v2 contra Postgres real como legajos_app > vincula nuevos y existentes, rechaza duplicados y revincula con una fila nueva 28ms
   ✓ Trámites v2 contra Postgres real como legajos_app > dos vinculaciones concurrentes del mismo legajo tienen un éxito y un 422 14ms
   ✓ Trámites v2 contra Postgres real como legajos_app > desvincular el último devuelve 409 sin cambiar ni auditar 9ms
   ✓ Trámites v2 contra Postgres real como legajos_app > dos desvinculaciones concurrentes con dos vínculos dejan exactamente uno 15ms
   ✓ Trámites v2 contra Postgres real como legajos_app > desvincular la original devuelve a pendiente sólo las solicitudes de ese trámite y legajo 33ms
   ✓ Trámites v2 contra Postgres real como legajos_app > faltantes acepta documento vencido sin procedencia o de otro trámite; anulado o desvinculado falta 57ms
   ✓ Trámites v2 contra Postgres real como legajos_app > busca por número, tipo, estado y cédula normalizada; excluye vínculos anulados 21ms
   × Trámites v2 contra Postgres real como legajos_app > verTramite y buscarTramites mantienen las consultas con 1 y 5 vínculos y auditan una sola vista 38ms
     → expected [ …(2) ] to have a length of 1 but got 2
   ✓ Trámites v2 contra Postgres real como legajos_app > el detalle incluye documentos del trámite con archivos ordenados y conserva los de vínculos anulados 29ms
   ✓ Trámites v2 contra Postgres real como legajos_app > editar preserva estado y numeración; audita antes/después 14ms
   ✓ Trámites v2 contra Postgres real como legajos_app > consulta ve pero no muta; operador no desvincula 15ms
   ✓ Trámites v2 contra Postgres real como legajos_app > valida entradas, motivos y pertenencia al trámite 27ms
 ✓ test/interacciones.test.ts (13 tests) 356ms
 ❯ test/legajos.test.ts (16 tests | 1 failed) 192ms
   ✓ Legajos v2 contra Postgres real como legajos_app > usa el rol app sin heredar owner 1ms
   ✓ Legajos v2 contra Postgres real como legajos_app > rechaza la cédula inválida 000 3ms
   ✓ Legajos v2 contra Postgres real como legajos_app > rechaza la cédula inválida  1ms
   ✓ Legajos v2 contra Postgres real como legajos_app > rechaza la cédula inválida 12a 1ms
   ✓ Legajos v2 contra Postgres real como legajos_app > rechaza la cédula inválida 1/2 1ms
   ✓ Legajos v2 contra Postgres real como legajos_app > rechaza la cédula inválida １２３ 1ms
   ✓ Legajos v2 contra Postgres real como legajos_app > quita formato y ceros; reutiliza sin sobrescribir datos 10ms
   ✓ Legajos v2 contra Postgres real como legajos_app > dos altas concurrentes del mismo número crean exactamente un legajo 9ms
   ✓ Legajos v2 contra Postgres real como legajos_app > busca prefijo normalizado, nombres sin acentos y pagina con total 11ms
   × Legajos v2 contra Postgres real como legajos_app > cantidadTramites cuenta vínculos vivos en todos los resúmenes y excluye anulaciones 35ms
     → expected +0 to be 2 // Object.is equality
   ✓ Legajos v2 contra Postgres real como legajos_app > escapa porcentajes, guiones bajos y barras de la búsqueda 5ms
   ✓ Legajos v2 contra Postgres real como legajos_app > editar preserva campos omitidos, permite limpiar opcionales y audita antes/después 7ms
   ✓ Legajos v2 contra Postgres real como legajos_app > corregir cédula exige admin y motivo, traduce choques y audita usuario e IP 9ms
   ✓ Legajos v2 contra Postgres real como legajos_app > traduce 42501 de SQL aunque el Contexto anterior sea de admin 6ms
   ✓ Legajos v2 contra Postgres real como legajos_app > relacionados usa vínculos vivos de ambos lados y conserva historial de trámites 51ms
   ✓ Legajos v2 contra Postgres real como legajos_app > valida entradas y devuelve 404 sin mutaciones para IDs ausentes 3ms
 ✓ test/catalogos.test.ts (3 tests) 57ms

⎯⎯⎯⎯⎯⎯⎯ Failed Tests 3 ⎯⎯⎯⎯⎯⎯⎯

 FAIL  test/acciones.test.ts > Actions con sesión y servicios reales conectados como legajos_app > editar devuelve ok:true, persiste y revalida las rutas afectadas
AssertionError: expected { ok: true, datos: { …(10) } } to match object { ok: true, datos: { …(3) } }
(7 matching properties omitted from actual)

- Expected
+ Received

  {
    "datos": {
-     "cantidadTramites": 1,
+     "cantidadTramites": 0,
      "id": "01a10db5-47e3-7070-9eb7-9931ca9582d0",
      "observacion": "Observación editada",
    },
    "ok": true,
  }

 ❯ test/acciones.test.ts:156:113
    154| 
    155|   it('editar devuelve ok:true, persiste y revalida las rutas afectadas…
    156|     expect(await accionesLegajos.editarLegajoAccionCon({ legajoId, obs…
       |                                                                                                                 ^
    157|       ok: true, datos: { id: legajoId, cantidadTramites: 1, observacio…
    158|     });

⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯[1/3]⎯

 FAIL  test/legajos.test.ts > Legajos v2 contra Postgres real como legajos_app > cantidadTramites cuenta vínculos vivos en todos los resúmenes y excluye anulaciones
AssertionError: expected +0 to be 2 // Object.is equality

- Expected
+ Received

- 2
+ 0

 ❯ test/legajos.test.ts:119:109
    117|       legajos: [{ legajoId: legajo.id }, { nuevo: entrada() }] });
    118|     const segundo = await servicio.crearTramite(operador, { tipoId, fe…
    119|     expect((await legajos.buscarLegajos(consulta, { cedula: legajo.ced…
       |                                                                                                             ^
    120|     expect((await legajos.verLegajo(consulta, { legajoId: legajo.id })…
    121|     expect((await legajos.buscarPorCedula(consulta, { cedula: legajo.c…

⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯[2/3]⎯

 FAIL  test/tramites.test.ts > Trámites v2 contra Postgres real como legajos_app > verTramite y buscarTramites mantienen las consultas con 1 y 5 vínculos y auditan una sola vista
AssertionError: expected [ …(2) ] to have a length of 1 but got 2

- Expected
+ Received

- 1
+ 2

 ❯ test/tramites.test.ts:356:92
    354|     expect(cinco.consultasDetalle.length).toBe(uno.consultasDetalle.le…
    355|     expect(cinco.consultasLista.length).toBe(uno.consultasLista.length…
    356|     expect(cinco.consultasDetalle.filter((q) => q.includes('from "lega…
       |                                                                                            ^
    357|     expect(await app`SELECT entidad, accion FROM legajos.auditoria WHE…
    358|       AND entidad_id = ${t.datos.id}`).toEqual([{ entidad: 'tramite', …

⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯[3/3]⎯


 Test Files  3 failed | 2 passed (5)
      Tests  3 failed | 82 passed (85)
   Start at  17:15:45
   Duration  5.47s (transform 209ms, setup 0ms, collect 1.80s, tests 1.90s, environment 1ms, prepare 189ms)

```

## Comprobación de alcance

`git -C legajos diff --check` terminó con código 0 y sin salida. Estado final de archivos:

```text
 M src/app/(app)/legajos/page.tsx
 M src/app/(app)/tramites/[id]/page.tsx
 M src/app/(app)/tramites/acciones.ts
 D src/app/(app)/tramites/catalogos.ts
 M src/app/(app)/tramites/nuevo/page.tsx
 M src/app/(app)/tramites/page.tsx
 M src/server/acciones/contexto.ts
 M src/server/servicios/contratos.ts
 M src/server/servicios/interacciones.ts
 M src/server/servicios/legajos.ts
 M src/server/servicios/mapeo.ts
 M src/server/servicios/tramites.ts
 M test/acciones.test.ts
 M test/interacciones.test.ts
 M test/legajos.test.ts
 M test/tramites.test.ts
?? src/server/servicios/catalogos.ts
?? test/catalogos.test.ts
```

## Pendientes y límites

No quedó implementación pendiente de la spec. La auditoría de este código corresponde al arquitecto, conforme al sombrero B.

La verificación emitió avisos de privilegios durante las migraciones y una advertencia de Next.js por múltiples lockfiles. Se incluyen íntegros arriba; no impidieron completar la corrida. No se modificaron migraciones, configuración de Next.js ni archivos fuera del alcance para silenciarlos.
