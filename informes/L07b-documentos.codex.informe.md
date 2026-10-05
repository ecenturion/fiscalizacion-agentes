# Informe — L07b-documentos

**Estado:** COMPLETADO
**Implementador:** CODEX, sombrero B
**Fecha:** 2026-10-05

## Archivos

Creados (se retomaron los archivos sin seguimiento dejados por AGY):
- `legajos/src/server/servicios/documentos.ts`
- `legajos/src/app/api/documentos/route.ts`
- `legajos/src/app/api/archivos/[id]/route.ts`
- `legajos/test/documentos.test.ts`
- `legajos/test/rutas-documentos.test.ts`

Modificados:
- `legajos/src/server/servicios/contratos.ts`: únicamente `ArchivoParaSubir`, ahora con temporal y metadatos del parser.
- `legajos/src/server/servicios/mapeo.ts`: documento, archivos y vencimiento calculado con Luxon.
- `legajos/src/server/servicios/legajos.ts`: carga de documentos en el detalle, sin el TODO de L07.

## Implementación y decisiones

- Se corrigieron parcialmente el servicio y las rutas existentes; los dos tests se reescribieron según la Corrección 2. No se agregaron dependencias ni se modificaron archivos de código fuera del alcance.
- El servicio valida todos los archivos antes de publicar; usa `rutaFinal`, publicación mediante `link`, transacción real y auditoría dentro de esa transacción. En rollback explícito retira los finales publicados. El flag de confirmación se activa al terminar el callback transaccional: un fallo al confirmar o durante la limpieza posterior conserva los finales. La transacción es inyectable para simular ese fallo, sin sustituir Postgres por un mock.
- Las solicitudes se bloquean y procesan en orden estable. La condición recibida se deriva de que el documento apuntado siga vivo. La anulación conserva el puntero de la solicitud, sus archivos y su historial; el estado vuelve a pendiente por la lógica de L06. Reemplazar bloquea el anterior, crea la versión, anula y reapunta con auditoría.
- `verArchivo` toma la ruta únicamente de la base, comprueba la contención y los symlinks, abre el archivo antes de auditar y cierra el stream si falla la operación. Permite archivos de documentos anulados. El esquema local añade `modo` y la implementación satisface `ServiciosDocumentos`, conservando intacto el contrato compartido salvo `ArchivoParaSubir`, como pide el alcance.
- POST llama al guard dentro del manejo de errores y antes de consumir el cuerpo. Devuelve JSON para los errores y limpia temporales en `finally`, ignorando sólo ENOENT. GET usa el guard, parámetros asíncronos de Next 15, streaming con contrapresión, nombre saneado y codificación RFC 5987; incluye MIME, longitud, disposición, nosniff y private/no-store.
- La inyección de sesión usa las dependencias reales de `requerirSesion`, como `auth-guard.test.ts`. En POST son propiedades opcionales del contexto de ruta; el contexto mismo es obligatorio porque el build de Next 15 rechaza un segundo argumento que pueda ser undefined.
- Se cubren 43 casos de servicios y 16 de rutas: fixtures reales, sha256, cardinalidad, archivos inválidos, rollback y fallo de confirmación, solicitudes y concurrencia, reemplazos y concurrencia, permisos, anulación, vista/descarga, traversal, symlink, faltantes retroactivos y vencimiento retroactivo con reloj inyectado. Años de fixtures: 2080, 2082 y 2084. Los servicios se ejecutan como `legajos_app` sin pertenecer a owner; owner sólo siembra y modifica fixtures.
- Los temporales propios de estos tests viven bajo `legajos/node_modules/.cache/`, con archivos recibidos en `.tmp`. Los tests no usan DELETE: conservan las filas y restauran los catálogos iniciales y la ruta adulterada. Los casos de catálogo usan los cinco tipos iniciales para no alterar la prueba existente que exige exactamente esa siembra.

## Verificación y condiciones del entorno

Comando de la spec ejecutado desde `/home/ecenturion/develop/legajos`:

```sh
pnpm sistema:check && pnpm verificar
```

**Resultado final: exit 0.** Lint, TypeScript, 16 archivos de test / 380 tests y build de Next aprobados.

Se aplicaron sólo al proceso estas variables:

```sh
export PNPM_CONFIG_PM_ON_FAIL=ignore
export PNPM_CONFIG_VERIFY_DEPS_BEFORE_RUN=false
```

El pnpm global instalado es 11.22.0; el proyecto declara 11.0.0. Sin esas variables, pnpm intenta cambiar de versión e instalar automáticamente, y falla intentando abrir su almacén SQLite fuera de las carpetas permitidas (`unable to open database file`). No se cambió `package.json`, lockfile ni configuración persistente.

La corrida final utilizó una base **temporal local limpia**, creada mediante el driver `postgres` en la misma instancia de pruebas. Se inyectaron `TEST_ADMIN_URL`, `TEST_OWNER_URL` y `TEST_APP_URL` apuntando a esa base, conservando los respectivos roles. Las migraciones se ejecutaron mediante el setup existente; al terminar se eliminó únicamente la base temporal de esa corrida. No se publican URLs ni credenciales.

La primera corrida completa sobre la base compartida encontró dos problemas de aislamiento de los tests nuevos: catálogos agregados que afectaban la comprobación exacta de siembra y una ruta adulterada que colisionaba al repetir. Se corrigieron los tests usando catálogos existentes y restaurando los valores. Las filas de esos primeros intentos permanecen en la base compartida: no se borraron. Por eso la verificación final usa una base limpia, sin destruir fixtures ajenos.

En una corrida posterior se detectó `FOR UPDATE must specify unqualified relation names`: Drizzle había calificado la tabla en el lock del JOIN de anulación. Se corrigió separando el bloqueo del documento de la consulta del tipo. La salida completa que sigue corresponde al estado final corregido.

`git diff --check` terminó con exit 0 y sin salida.

## Salida real completa de la verificación final

```text
$ bash scripts/chequear-sistema.sh
Dependencias del sistema: ok (qpdf, vips, vipsheader, prlimit).
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
 ✓ test/documentos.test.ts (43 tests) 1168ms
 ✓ test/rutas-documentos.test.ts (16 tests) 392ms
 ✓ test/login.test.ts (14 tests) 3609ms
   ✓ Login y cambio de clave con Postgres real como legajos_app > cinco fallos bloquean; la clave correcta no pasa hasta +16 minutos  368ms
   ✓ Login y cambio de clave con Postgres real como legajos_app > inexistente usa señuelo, con mediana de cinco muestras a menos del 30%  442ms
   ✓ Login y cambio de clave con Postgres real como legajos_app > 20 fallos por IP, el 21 no verifica ni modifica cuenta; ventana vencida reinicia  928ms
   ✓ Login y cambio de clave con Postgres real como legajos_app > 25 concurrentes desde una IP: sólo 20 verifican argon2  886ms
 ✓ test/logout-y-cli.test.ts (12 tests) 2819ms
   ✓ Logout y recuperación administrativa > CLI imprime una clave de 16 caracteres una vez, agrega IPv6 y cierra todas las sesiones  486ms
   ✓ Logout y recuperación administrativa > CLI normaliza IPv4-mapped y agrega /32  348ms
   ✓ Logout y recuperación administrativa > CLI rechaza usuario no admin, sin modificaciones ni clave en stdout  345ms
   ✓ Logout y recuperación administrativa > CLI rechaza legajos online y acepta la aplicación detenida  751ms
   ✓ Logout y recuperación administrativa > CLI falla si el lock está ocupado  341ms
 ✓ test/archivos-validar.test.ts (15 tests) 720ms
 ✓ test/legajos.test.ts (17 tests) 328ms
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
 ✓ test/interacciones.test.ts (12 tests) 234ms
 ✓ test/archivos-almacen.test.ts (19 tests) 174ms
 ✓ test/auth-guard.test.ts (40 tests) 147ms
 ✓ test/schema.test.ts (53 tests) 125ms
 ✓ test/triggers.test.ts (21 tests) 114ms
 ✓ test/permisos.test.ts (29 tests) 40ms
 ✓ test/humo.test.ts (3 tests) 21ms
 ✓ test/ip.test.ts (24 tests) 7ms
 ✓ test/permisos.unit.test.ts (48 tests) 4ms

 Test Files  16 passed (16)
      Tests  380 passed (380)
   Start at  08:42:59
   Duration  16.74s (transform 257ms, setup 0ms, collect 2.78s, tests 10.15s, environment 2ms, prepare 602ms)

$ next build
 ⚠ Warning: Next.js inferred your workspace root, but it may not be correct.
 We detected multiple lockfiles and selected the directory of /home/ecenturion/pnpm-lock.yaml as the root directory.
 To silence this warning, set `outputFileTracingRoot` in your Next.js config, or consider removing one of the lockfiles if it's not needed.
   See https://nextjs.org/docs/app/api-reference/config/next-config-js/output#caveats for more information.
 Detected additional lockfiles: 
   * /home/ecenturion/develop/legajos/pnpm-lock.yaml

   ▲ Next.js 15.5.27

   Creating an optimized production build ...
 ✓ Compiled successfully in 1614ms
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

Salida real del proceso que preparó y retiró la base temporal:

```text
Base temporal local creada para la verificación completa.
pnpm sistema:check && pnpm verificar: exit 0.
Base temporal de esta corrida eliminada.
```

## Limitaciones y pendiente de otro rol

- La salida conserva las advertencias reales de permisos de extensiones al migrar, la advertencia de transacción de un test existente y la detección de múltiples lockfiles de Next. No impiden exit 0; no se modificaron migraciones, esos tests ni configuración de Next por estar fuera del alcance.
- Una corrida sobre la base compartida ya poblada no equivale a la corrida final sobre base limpia; allí permanecen fixtures de intentos anteriores. Se informa esta condición para reproducir correctamente la verificación.
- No quedaron criterios de implementación sin cubrir. La auditoría independiente corresponde al arquitecto u otro auditor: como implementador B no audité mi propio código.
- No se hizo commit, push, deploy ni se movió la tarea a done.
