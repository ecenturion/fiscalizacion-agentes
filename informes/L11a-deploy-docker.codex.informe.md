# Informe — L11a-deploy-docker

**Estado:** COMPLETADO
**Implementador:** CODEX, sombrero B
**Fecha:** 2026-10-05

Implementados el basePath, la imagen standalone, PostgreSQL propio con dos roles, el arranque con migraciones, el primer admin, el script de deploy y la guía de Apache/backup/restauración. La verificación final pasó: 434 tests, lint, typecheck y build. Pasaron también el build con /fiscalizacion, la construcción Docker y los diez fixtures dentro de la imagen bajo 512 MiB.

## Archivos modificados (rutas relativas a legajos/)

- `.gitignore`
- `next.config.ts`
- `src/server/cookie.ts`
- `src/app/logout/route.ts`
- `src/middleware.ts`
- `src/server/config.ts`
- `src/app/(app)/layout.tsx`
- `src/app/(app)/legajos/page.tsx`
- `src/app/(app)/legajos/[id]/page.tsx`
- `src/app/(app)/legajos/[id]/componentes/SubirDocumento.tsx`
- `src/app/(app)/legajos/[id]/documentos/[docId]/page.tsx`

## Archivos creados (rutas relativas a legajos/)

- `src/lib/base.ts`
- `Dockerfile`
- `scripts/entrypoint.sh`
- `deploy/compose.prod.yml`
- `deploy/initdb/01-roles.sh`
- `deploy/.env.example`
- `deploy/apache-fiscalizacion.conf`
- `scripts/admin-crear.ts`
- `scripts/deploy.sh`
- `scripts/validar-imagen.sh`
- `deploy/README.md`

Única salida propia en legajos-agents/: `informes/L11a-deploy-docker.codex.informe.md`.

## Decisiones y motivos

- `conBase` se aplica sólo a enlaces/formularios/peticiones crudos. Los Link y redirect existentes conservan el comportamiento de Next. El visor usa img del navegador para enviar la cookie al guard y a la auditoría; sus dimensiones se ajustan dentro del archivo permitido.
- Se verificó con Next 15.5.27 instalado que pathname excluye el basePath, clone lo conserva y Next prefija el matcher al construir. Las exclusiones de _next y favicon se comprobaron con aserciones.
- La imagen compila los CLI con el TypeScript ya disponible. Completa las extensiones ESM y conserva la ubicación original del migrador para que encuentre drizzle/. Copia las dependencias de producción, sin agregar paquetes al proyecto. Las copias explícitas excluyen archivos de entorno de la imagen.
- Se reserva UID/GID 10001; el directorio .next y el volumen de archivos son accesibles al usuario de servicio. La DB no publica puertos y la app publica sólo 127.0.0.1:3000. Se validaron los límites y depends_on al resolver Compose sin cargar un .env real.
- `admin-crear` usa owner y bloquea la tabla usuario antes de consultar/crear el admin. Usuario, red y login_admin se confirman en una transacción. Dos procesos concurrentes produjeron una sola alta y una sola clave; el contenido de las claves de prueba nunca se imprimió en el informe.
- Bookworm instala vips 8.14.1. Con los fixtures reales, vips avg puede emitir un error de tile como advertencia y devolver 0 aun con fail_on=error. Se fijó G_DEBUG=fatal-warnings en el Dockerfile: la advertencia termina el hijo por señal, que el validador existente rechaza. No se modificó el validador fuera del alcance. Es una política conservadora: otras advertencias nativas también rechazan el archivo. Los tres fixtures válidos pasan y los siete inválidos se rechazan. El entrypoint desactiva core dumps; se comprobó /proc/1/limits. La semántica está documentada por [GLib](https://docs.gtk.org/glib/running.html).
- La conf Apache se incluye dentro del VirtualHost SSL existente. El redirect del 80 se entrega como directiva separada en la guía y comentada en la conf, para ubicarla en el VirtualHost correcto sin reemplazar otros sitios. El script no instala ni recarga Apache.
- La guía usa un archivo OpenSSL de extensiones compatible con CentOS 7 para el SAN, detiene/verifica el contenedor y las conexiones antes del backup e incluye comandos de restauración y comparación de archivos sin borrado. Al restaurar se omite únicamente la creación del esquema legajos ya creado por initdb.
- Las claves de producción se generan sólo en el servidor mediante openssl, con umask 077, publicación sin sobrescritura y .env modo 600. No se ejecutó esa parte del script.

## Verificación final

Comando: `cd legajos && pnpm verificar`. Se ejecutó desde legajos/ con el estado de pnpm dentro de node_modules/ y con PostgreSQL 16 efímero vacío:

```sh
XDG_CACHE_HOME="$PWD/node_modules/.cache" \
XDG_DATA_HOME="$PWD/node_modules/.pnpm-data" \
TMPDIR="$PWD/node_modules/.cache/tmp" \
TEST_ADMIN_URL=postgres://postgres:postgres@127.0.0.1:32770/legajos_test \
TEST_OWNER_URL=postgres://legajos_owner@127.0.0.1:32770/legajos_test \
TEST_APP_URL=postgres://legajos_app@127.0.0.1:32770/legajos_test \
pnpm verificar
```

Salida real del harness y del comando; código de salida 0:

```text
pnpm verificar con Postgres 16 efímero vacío; TEST_*_URL apuntan a loopback:32770
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
 ✓ test/login.test.ts (14 tests) 5990ms
   ✓ Login y cambio de clave con Postgres real como legajos_app > cinco fallos bloquean; la clave correcta no pasa hasta +16 minutos  763ms
   ✓ Login y cambio de clave con Postgres real como legajos_app > inexistente usa señuelo, con mediana de cinco muestras a menos del 30%  940ms
   ✓ Login y cambio de clave con Postgres real como legajos_app > 20 fallos por IP, el 21 no verifica ni modifica cuenta; ventana vencida reinicia  1473ms
   ✓ Login y cambio de clave con Postgres real como legajos_app > 25 concurrentes desde una IP: sólo 20 verifican argon2  1229ms
   ✓ Login y cambio de clave con Postgres real como legajos_app > cambiar clave cierra sesiones, emite otra válida y audita sin secretos  381ms
 ✓ test/logout-y-cli.test.ts (12 tests) 3064ms
   ✓ Logout y recuperación administrativa > CLI imprime una clave de 16 caracteres una vez, agrega IPv6 y cierra todas las sesiones  599ms
   ✓ Logout y recuperación administrativa > CLI normaliza IPv4-mapped y agrega /32  368ms
   ✓ Logout y recuperación administrativa > CLI rechaza usuario no admin, sin modificaciones ni clave en stdout  346ms
   ✓ Logout y recuperación administrativa > CLI rechaza legajos online y acepta la aplicación detenida  764ms
   ✓ Logout y recuperación administrativa > CLI falla si el lock está ocupado  362ms
 ✓ test/documentos.test.ts (43 tests) 1568ms
 ✓ test/admin.test.ts (18 tests) 1181ms
   ✓ Administración contra Postgres real como legajos_app > dos admins que se desactivan mutuamente en paralelo dejan al menos uno activo  368ms
 ✓ test/archivos-validar.test.ts (15 tests) 735ms
 ✓ test/acciones.test.ts (24 tests) 597ms
 ✓ test/rutas-documentos.test.ts (16 tests) 548ms
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

 ✓ test/cedulas.test.ts (14 tests) 258ms
 ✓ test/interacciones.test.ts (12 tests) 236ms
 ✓ test/auth-guard.test.ts (40 tests) 147ms
 ✓ test/archivos-almacen.test.ts (19 tests) 430ms
 ✓ test/schema.test.ts (53 tests) 125ms
 ✓ test/triggers.test.ts (21 tests) 106ms
 ✓ test/guard-cobertura.test.ts (12 tests) 41ms
 ✓ test/permisos.test.ts (29 tests) 36ms
 ✓ test/humo.test.ts (3 tests) 18ms
 ✓ test/ip.test.ts (24 tests) 7ms
 ✓ test/permisos.unit.test.ts (48 tests) 4ms

 Test Files  19 passed (19)
      Tests  434 passed (434)
   Start at  10:33:19
   Duration  25.57s (transform 335ms, setup 0ms, collect 5.66s, tests 15.42s, environment 2ms, prepare 732ms)

$ next build
 ⚠ Warning: Next.js inferred your workspace root, but it may not be correct.
 We detected multiple lockfiles and selected the directory of /home/ecenturion/pnpm-lock.yaml as the root directory.
 To silence this warning, set `outputFileTracingRoot` in your Next.js config, or consider removing one of the lockfiles if it's not needed.
   See https://nextjs.org/docs/app/api-reference/config/next-config-js/output#caveats for more information.
 Detected additional lockfiles: 
   * /home/ecenturion/develop/legajos/pnpm-lock.yaml

   ▲ Next.js 15.5.27

   Creating an optimized production build ...
 ✓ Compiled successfully in 6.0s
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
├ ƒ /api/archivos/[id]                     133 B         103 kB
├ ƒ /api/documentos                        133 B         103 kB
├ ƒ /cuenta/clave                          170 B         106 kB
├ ƒ /legajos                               170 B         106 kB
├ ƒ /legajos/[id]                        4.82 kB         111 kB
├ ƒ /legajos/[id]/documentos/[docId]       170 B         106 kB
├ ƒ /legajos/nuevo                       2.14 kB         108 kB
├ ○ /login                                 826 B         104 kB
└ ƒ /logout                                133 B         103 kB
+ First Load JS shared by all             103 kB
  ├ chunks/758-942e49721ce48ac0.js       46.5 kB
  ├ chunks/d36d6ee9-817a06892149dc1d.js  54.4 kB
  └ other shared chunks (total)          1.92 kB


ƒ Middleware                             34.2 kB

○  (Static)   prerendered as static content
ƒ  (Dynamic)  server-rendered on demand

Postgres efímero de verificación retirado.

```

## Build con basePath

Comando: `NEXT_BASE_PATH=/fiscalizacion NEXT_PUBLIC_BASE_PATH=/fiscalizacion pnpm build`, con los mismos XDG_CACHE_HOME/XDG_DATA_HOME locales. Código de salida 0:

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
 ✓ Compiled successfully in 5.5s
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
├ ƒ /api/archivos/[id]                     133 B         103 kB
├ ƒ /api/documentos                        133 B         103 kB
├ ƒ /cuenta/clave                          170 B         106 kB
├ ƒ /legajos                               170 B         106 kB
├ ƒ /legajos/[id]                        4.72 kB         111 kB
├ ƒ /legajos/[id]/documentos/[docId]       170 B         106 kB
├ ƒ /legajos/nuevo                       2.14 kB         108 kB
├ ○ /login                                 826 B         104 kB
└ ƒ /logout                                133 B         103 kB
+ First Load JS shared by all             103 kB
  ├ chunks/758-f4e03461beee14c0.js       46.6 kB
  ├ chunks/d36d6ee9-817a06892149dc1d.js  54.4 kB
  └ other shared chunks (total)          1.93 kB


ƒ Middleware                             34.2 kB

○  (Static)   prerendered as static content
ƒ  (Dynamic)  server-rendered on demand


```

## Construcción de la imagen final

Comando: `DOCKER_CONFIG="$PWD/node_modules/.cache/docker" docker build -t fiscalizacion:prueba --build-arg NEXT_BASE_PATH=/fiscalizacion .`. Código de salida 0.

Imagen final: `sha256:5333f827a8cc9c766539f11a5e5e9a96c180eb674ec58cfebe735fdceaa6c867`. Dos construcciones solapadas usaron el mismo tag durante el ajuste; se volvió a asociar fiscalizacion:prueba a este digest final antes de repetir los fixtures y la prueba runtime.

Salida real completa de la construcción final:

```text
#0 building with "default" instance using docker driver

#1 [internal] load build definition from Dockerfile
#1 transferring dockerfile: 3.64kB done
#1 DONE 0.0s

#2 resolve image config for docker-image://docker.io/docker/dockerfile:1
#2 DONE 1.0s

#3 docker-image://docker.io/docker/dockerfile:1@sha256:4edf897a3ffa55b89f906fc8cc78afdb3f1834cc9c7083565e611a8a7d5fe99e
#3 CACHED

#4 [internal] load metadata for docker.io/library/node:22-bookworm-slim
#4 DONE 0.8s

#5 [internal] load .dockerignore
#5 transferring context: 2B done
#5 DONE 0.1s

#6 [dependencies 1/5] FROM docker.io/library/node:22-bookworm-slim@sha256:43ac6c60b8f89723f746e8a92ce91abd5017e627ce1ddfe4238355d3a30b772c
#6 CACHED

#7 [runtime  2/12] RUN apt-get update     && apt-get install -y --no-install-recommends qpdf libvips-tools util-linux     && rm -rf /var/lib/apt/lists/*     && groupadd --gid 10001 fiscalizacion     && useradd --uid 10001 --gid 10001 --no-create-home fiscalizacion     && mkdir -p /datos/archivos     && chown 10001:10001 /datos/archivos
#7 0.551 Get:1 http://deb.debian.org/debian bookworm InRelease [151 kB]
#7 0.700 Get:2 http://deb.debian.org/debian bookworm-updates InRelease [55.4 kB]
#7 1.045 Get:3 http://deb.debian.org/debian-security bookworm-security InRelease [34.8 kB]
#7 1.280 Get:4 http://deb.debian.org/debian bookworm/main amd64 Packages [8790 kB]
#7 4.589 Get:5 http://deb.debian.org/debian bookworm-updates/main amd64 Packages [6924 B]
#7 5.062 Get:6 http://deb.debian.org/debian-security bookworm-security/main amd64 Packages [349 kB]
#7 5.371 Fetched 9387 kB in 5s (1826 kB/s)
#7 5.371 Reading package lists...
#7 5.659 Reading package lists...
#7 5.966 Building dependency tree...
#7 6.052 Reading state information...
#7 6.149 util-linux is already the newest version (2.38.1-5+deb12u3).
#7 6.149 util-linux set to manually installed.
#7 6.149 The following additional packages will be installed:
#7 6.149   fontconfig fontconfig-config fonts-dejavu-core imagemagick-6-common libaec0
#7 6.149   libaom3 libbrotli1 libbsd0 libcairo-gobject2 libcairo2 libcfitsio10 libcgif0
#7 6.149   libcurl3-gnutls libcurl4 libdatrie1 libdav1d6 libde265-0 libdeflate0
#7 6.149   libexif12 libexpat1 libfftw3-double3 libfontconfig1 libfreetype6 libfribidi0
#7 6.149   libgdk-pixbuf-2.0-0 libgdk-pixbuf2.0-common libglib2.0-0 libgomp1
#7 6.149   libgraphite2-3 libgsf-1-114 libgsf-1-common libgssapi-krb5-2 libharfbuzz0b
#7 6.149   libhdf5-103-1 libheif1 libhwy1 libicu72 libimagequant0 libimath-3-1-29
#7 6.149   libjbig0 libjpeg62-turbo libjxl0.7 libk5crypto3 libkeyutils1 libkrb5-3
#7 6.149   libkrb5support0 liblcms2-2 libldap-2.5-0 liblerc4 liblqr-1-0 libltdl7
#7 6.149   libmagickcore-6.q16-6 libmatio11 libncursesw6 libnghttp2-14 libnsl2 libnspr4
#7 6.149   libnss3 libnuma1 libopenexr-3-1-30 libopenjp2-7 libopenslide0 liborc-0.4-0
#7 6.149   libpango-1.0-0 libpangocairo-1.0-0 libpangoft2-1.0-0 libpixman-1-0
#7 6.149   libpng16-16 libpoppler-glib8 libpoppler126 libpsl5 libpython3-stdlib
#7 6.149   libpython3.11-minimal libpython3.11-stdlib libqpdf29 libreadline8 librsvg2-2
#7 6.149   librtmp1 libsasl2-2 libsasl2-modules-db libsqlite3-0 libssh2-1 libssl3
#7 6.149   libsz2 libthai-data libthai0 libtiff6 libtirpc-common libtirpc3 libvips42
#7 6.149   libwebp7 libwebpdemux2 libwebpmux3 libx11-6 libx11-data libx265-199 libxau6
#7 6.149   libxcb-render0 libxcb-shm0 libxcb1 libxdmcp6 libxext6 libxml2 libxrender1
#7 6.149   media-types python3 python3-minimal python3.11 python3.11-minimal
#7 6.149   readline-common shared-mime-info
#7 6.150 Suggested packages:
#7 6.150   libfftw3-bin libfftw3-dev low-memory-monitor krb5-doc krb5-user
#7 6.150   liblcms2-utils libmagickcore-6.q16-6-extra librsvg2-bin nip2 libvips-doc
#7 6.150   libvips-dev python3-doc python3-tk python3-venv python3.11-venv
#7 6.150   python3.11-doc binutils binfmt-support readline-doc
#7 6.150 Recommended packages:
#7 6.150   ca-certificates libgdk-pixbuf2.0-bin libglib2.0-data xdg-user-dirs
#7 6.150   krb5-locales libldap-common ghostscript gsfonts libgpm2 poppler-data
#7 6.150   publicsuffix librsvg2-common libsasl2-modules
#7 6.468 The following NEW packages will be installed:
#7 6.468   fontconfig fontconfig-config fonts-dejavu-core imagemagick-6-common libaec0
#7 6.468   libaom3 libbrotli1 libbsd0 libcairo-gobject2 libcairo2 libcfitsio10 libcgif0
#7 6.468   libcurl3-gnutls libcurl4 libdatrie1 libdav1d6 libde265-0 libdeflate0
#7 6.468   libexif12 libexpat1 libfftw3-double3 libfontconfig1 libfreetype6 libfribidi0
#7 6.468   libgdk-pixbuf-2.0-0 libgdk-pixbuf2.0-common libglib2.0-0 libgomp1
#7 6.468   libgraphite2-3 libgsf-1-114 libgsf-1-common libgssapi-krb5-2 libharfbuzz0b
#7 6.468   libhdf5-103-1 libheif1 libhwy1 libicu72 libimagequant0 libimath-3-1-29
#7 6.468   libjbig0 libjpeg62-turbo libjxl0.7 libk5crypto3 libkeyutils1 libkrb5-3
#7 6.468   libkrb5support0 liblcms2-2 libldap-2.5-0 liblerc4 liblqr-1-0 libltdl7
#7 6.468   libmagickcore-6.q16-6 libmatio11 libncursesw6 libnghttp2-14 libnsl2 libnspr4
#7 6.468   libnss3 libnuma1 libopenexr-3-1-30 libopenjp2-7 libopenslide0 liborc-0.4-0
#7 6.468   libpango-1.0-0 libpangocairo-1.0-0 libpangoft2-1.0-0 libpixman-1-0
#7 6.468   libpng16-16 libpoppler-glib8 libpoppler126 libpsl5 libpython3-stdlib
#7 6.468   libpython3.11-minimal libpython3.11-stdlib libqpdf29 libreadline8 librsvg2-2
#7 6.468   librtmp1 libsasl2-2 libsasl2-modules-db libsqlite3-0 libssh2-1 libssl3
#7 6.468   libsz2 libthai-data libthai0 libtiff6 libtirpc-common libtirpc3
#7 6.468   libvips-tools libvips42 libwebp7 libwebpdemux2 libwebpmux3 libx11-6
#7 6.468   libx11-data libx265-199 libxau6 libxcb-render0 libxcb-shm0 libxcb1 libxdmcp6
#7 6.469   libxext6 libxml2 libxrender1 media-types python3 python3-minimal python3.11
#7 6.469   python3.11-minimal qpdf readline-common shared-mime-info
#7 6.582 0 upgraded, 113 newly installed, 0 to remove and 3 not upgraded.
#7 6.582 Need to get 54.7 MB of archives.
#7 6.582 After this operation, 196 MB of additional disk space will be used.
#7 6.582 Get:1 http://deb.debian.org/debian bookworm/main amd64 libgomp1 amd64 12.2.0-14+deb12u1 [116 kB]
#7 6.896 Get:2 http://deb.debian.org/debian bookworm/main amd64 libfftw3-double3 amd64 3.3.10-1 [776 kB]
#7 7.829 Get:3 http://deb.debian.org/debian-security bookworm-security/main amd64 libexpat1 amd64 2.5.0-1+deb12u4 [106 kB]
#7 8.404 Get:4 http://deb.debian.org/debian bookworm/main amd64 libbrotli1 amd64 1.0.9-2+b6 [275 kB]
#7 8.789 Get:5 http://deb.debian.org/debian bookworm/main amd64 libpng16-16 amd64 1.6.39-2+deb12u5 [277 kB]
#7 9.161 Get:6 http://deb.debian.org/debian bookworm/main amd64 libfreetype6 amd64 2.12.1+dfsg-5+deb12u4 [398 kB]
#7 9.782 Get:7 http://deb.debian.org/debian bookworm/main amd64 fonts-dejavu-core all 2.37-6 [1068 kB]
#7 10.82 Get:8 http://deb.debian.org/debian bookworm/main amd64 fontconfig-config amd64 2.14.1-4 [315 kB]
#7 11.48 Get:9 http://deb.debian.org/debian bookworm/main amd64 libfontconfig1 amd64 2.14.1-4 [386 kB]
#7 12.35 Get:10 http://deb.debian.org/debian-security bookworm-security/main amd64 libaom3 amd64 3.6.0-1+deb12u3 [1851 kB]
#7 13.99 Get:11 http://deb.debian.org/debian bookworm/main amd64 libdav1d6 amd64 1.0.0-2+deb12u1 [513 kB]
#7 14.63 Get:12 http://deb.debian.org/debian-security bookworm-security/main amd64 libde265-0 amd64 1.0.11-1+deb12u3 [186 kB]
#7 15.20 Get:13 http://deb.debian.org/debian bookworm/main amd64 libnuma1 amd64 2.0.16-1 [21.0 kB]
#7 15.30 Get:14 http://deb.debian.org/debian bookworm/main amd64 libx265-199 amd64 3.5-2+b1 [1150 kB]
#7 15.91 Get:15 http://deb.debian.org/debian bookworm/main amd64 libheif1 amd64 1.15.1-1+deb12u1 [215 kB]
#7 16.51 Get:16 http://deb.debian.org/debian bookworm/main amd64 libjbig0 amd64 2.1-6.1 [31.7 kB]
#7 16.82 Get:17 http://deb.debian.org/debian bookworm/main amd64 libjpeg62-turbo amd64 1:2.1.5-2 [166 kB]
#7 17.15 Get:18 http://deb.debian.org/debian bookworm/main amd64 liblcms2-2 amd64 2.14-2+deb12u1 [154 kB]
#7 17.50 Get:19 http://deb.debian.org/debian bookworm/main amd64 libglib2.0-0 amd64 2.74.6-2+deb12u9 [1403 kB]
#7 18.40 Get:20 http://deb.debian.org/debian bookworm/main amd64 liblqr-1-0 amd64 0.4.2-2.1 [29.1 kB]
#7 18.72 Get:21 http://deb.debian.org/debian bookworm/main amd64 libltdl7 amd64 2.4.7-7~deb12u1 [393 kB]
#7 19.39 Get:22 http://deb.debian.org/debian bookworm/main amd64 libopenjp2-7 amd64 2.5.0-2+deb12u3 [189 kB]
#7 19.98 Get:23 http://deb.debian.org/debian bookworm/main amd64 libdeflate0 amd64 1.14-1 [61.4 kB]
#7 20.31 Get:24 http://deb.debian.org/debian bookworm/main amd64 liblerc4 amd64 4.0.0+ds-2 [170 kB]
#7 20.68 Get:25 http://deb.debian.org/debian bookworm/main amd64 libwebp7 amd64 1.2.4-0.2+deb12u1 [286 kB]
#7 21.07 Get:26 http://deb.debian.org/debian bookworm/main amd64 libtiff6 amd64 4.5.0-6+deb12u4 [316 kB]
#7 21.66 Get:27 http://deb.debian.org/debian bookworm/main amd64 libwebpdemux2 amd64 1.2.4-0.2+deb12u1 [99.4 kB]
#7 22.00 Get:28 http://deb.debian.org/debian bookworm/main amd64 libwebpmux3 amd64 1.2.4-0.2+deb12u1 [109 kB]
#7 22.32 Get:29 http://deb.debian.org/debian bookworm/main amd64 libxau6 amd64 1:1.0.9-1 [19.7 kB]
#7 22.63 Get:30 http://deb.debian.org/debian bookworm/main amd64 libbsd0 amd64 0.11.7-2 [117 kB]
#7 23.21 Get:31 http://deb.debian.org/debian bookworm/main amd64 libxdmcp6 amd64 1:1.1.2-3 [26.3 kB]
#7 23.30 Get:32 http://deb.debian.org/debian bookworm/main amd64 libxcb1 amd64 1.15-1 [144 kB]
#7 23.63 Get:33 http://deb.debian.org/debian bookworm/main amd64 libx11-data all 2:1.8.4-2+deb12u2 [292 kB]
#7 24.22 Get:34 http://deb.debian.org/debian bookworm/main amd64 libx11-6 amd64 2:1.8.4-2+deb12u2 [760 kB]
#7 25.90 Get:35 http://deb.debian.org/debian bookworm/main amd64 libxext6 amd64 2:1.3.4-1+b1 [52.9 kB]
#7 26.21 Get:36 http://deb.debian.org/debian bookworm/main amd64 libicu72 amd64 72.1-3+deb12u1 [9376 kB]
#7 29.92 Get:37 http://deb.debian.org/debian bookworm/main amd64 libxml2 amd64 2.9.14+dfsg-1.3~deb12u6 [689 kB]
#7 30.83 Get:38 http://deb.debian.org/debian-security bookworm-security/main amd64 imagemagick-6-common all 8:6.9.11.60+dfsg-1.6+deb12u13 [175 kB]
#7 31.18 Get:39 http://deb.debian.org/debian-security bookworm-security/main amd64 libmagickcore-6.q16-6 amd64 8:6.9.11.60+dfsg-1.6+deb12u13 [1806 kB]
#7 32.35 Get:40 http://deb.debian.org/debian-security bookworm-security/main amd64 libssl3 amd64 3.0.22-1~deb12u1 [2039 kB]
#7 33.27 Get:41 http://deb.debian.org/debian bookworm/main amd64 libpython3.11-minimal amd64 3.11.2-6+deb12u8 [818 kB]
#7 34.22 Get:42 http://deb.debian.org/debian bookworm/main amd64 python3.11-minimal amd64 3.11.2-6+deb12u8 [2065 kB]
#7 36.28 Get:43 http://deb.debian.org/debian bookworm/main amd64 python3-minimal amd64 3.11.2-1+b1 [26.3 kB]
#7 36.58 Get:44 http://deb.debian.org/debian bookworm/main amd64 media-types all 10.0.0 [26.1 kB]
#7 36.89 Get:45 http://deb.debian.org/debian bookworm/main amd64 libncursesw6 amd64 6.4-4 [134 kB]
#7 37.02 Get:46 http://deb.debian.org/debian bookworm/main amd64 libkrb5support0 amd64 1.20.1-2+deb12u5 [33.2 kB]
#7 37.33 Get:47 http://deb.debian.org/debian bookworm/main amd64 libk5crypto3 amd64 1.20.1-2+deb12u5 [79.7 kB]
#7 37.64 Get:48 http://deb.debian.org/debian bookworm/main amd64 libkeyutils1 amd64 1.6.3-2 [8808 B]
#7 37.96 Get:49 http://deb.debian.org/debian bookworm/main amd64 libkrb5-3 amd64 1.20.1-2+deb12u5 [332 kB]
#7 38.34 Get:50 http://deb.debian.org/debian bookworm/main amd64 libgssapi-krb5-2 amd64 1.20.1-2+deb12u5 [135 kB]
#7 38.69 Get:51 http://deb.debian.org/debian bookworm/main amd64 libtirpc-common all 1.3.3+ds-1 [14.0 kB]
#7 39.01 Get:52 http://deb.debian.org/debian bookworm/main amd64 libtirpc3 amd64 1.3.3+ds-1 [85.2 kB]
#7 39.58 Get:53 http://deb.debian.org/debian bookworm/main amd64 libnsl2 amd64 1.3.0-2 [39.5 kB]
#7 39.92 Get:54 http://deb.debian.org/debian bookworm/main amd64 readline-common all 8.2-1.3 [69.0 kB]
#7 40.25 Get:55 http://deb.debian.org/debian bookworm/main amd64 libreadline8 amd64 8.2-1.3 [166 kB]
#7 40.59 Get:56 http://deb.debian.org/debian bookworm/main amd64 libsqlite3-0 amd64 3.40.1-2+deb12u2 [839 kB]
#7 41.32 Get:57 http://deb.debian.org/debian bookworm/main amd64 libpython3.11-stdlib amd64 3.11.2-6+deb12u8 [1799 kB]
#7 42.21 Get:58 http://deb.debian.org/debian bookworm/main amd64 python3.11 amd64 3.11.2-6+deb12u8 [574 kB]
#7 42.86 Get:59 http://deb.debian.org/debian bookworm/main amd64 libpython3-stdlib amd64 3.11.2-1+b1 [9312 B]
#7 43.17 Get:60 http://deb.debian.org/debian bookworm/main amd64 python3 amd64 3.11.2-1+b1 [26.3 kB]
#7 43.47 Get:61 http://deb.debian.org/debian bookworm/main amd64 fontconfig amd64 2.14.1-4 [449 kB]
#7 44.32 Get:62 http://deb.debian.org/debian bookworm/main amd64 libaec0 amd64 1.0.6-1+b1 [21.1 kB]
#7 44.63 Get:63 http://deb.debian.org/debian bookworm/main amd64 libpixman-1-0 amd64 0.42.2-1 [546 kB]
#7 45.48 Get:64 http://deb.debian.org/debian bookworm/main amd64 libxcb-render0 amd64 1.15-1 [115 kB]
#7 45.81 Get:65 http://deb.debian.org/debian bookworm/main amd64 libxcb-shm0 amd64 1.15-1 [105 kB]
#7 46.13 Get:66 http://deb.debian.org/debian bookworm/main amd64 libxrender1 amd64 1:0.9.10-1.1 [33.2 kB]
#7 46.43 Get:67 http://deb.debian.org/debian bookworm/main amd64 libcairo2 amd64 1.16.0-7 [575 kB]
#7 47.08 Get:68 http://deb.debian.org/debian bookworm/main amd64 libcairo-gobject2 amd64 1.16.0-7 [112 kB]
#7 47.42 Get:69 http://deb.debian.org/debian bookworm/main amd64 libsasl2-modules-db amd64 2.1.28+dfsg-10 [20.3 kB]
#7 47.51 Get:70 http://deb.debian.org/debian bookworm/main amd64 libsasl2-2 amd64 2.1.28+dfsg-10 [59.7 kB]
#7 47.84 Get:71 http://deb.debian.org/debian bookworm/main amd64 libldap-2.5-0 amd64 2.5.13+dfsg-5 [183 kB]
#7 48.20 Get:72 http://deb.debian.org/debian bookworm/main amd64 libnghttp2-14 amd64 1.52.0-1+deb12u3 [72.4 kB]
#7 48.51 Get:73 http://deb.debian.org/debian bookworm/main amd64 libpsl5 amd64 0.21.2-1 [58.7 kB]
#7 48.83 Get:74 http://deb.debian.org/debian bookworm/main amd64 librtmp1 amd64 2.4+20151223.gitfa8646d.1-2+b2 [60.8 kB]
#7 49.17 Get:75 http://deb.debian.org/debian-security bookworm-security/main amd64 libssh2-1 amd64 1.10.0-3+deb12u1 [176 kB]
#7 49.53 Get:76 http://deb.debian.org/debian bookworm/main amd64 libcurl3-gnutls amd64 7.88.1-10+deb12u15 [386 kB]
#7 49.96 Get:77 http://deb.debian.org/debian bookworm/main amd64 libcfitsio10 amd64 4.2.0-3 [563 kB]
#7 50.59 Get:78 http://deb.debian.org/debian bookworm/main amd64 libcgif0 amd64 0.3.0-1 [9748 B]
#7 50.67 Get:79 http://deb.debian.org/debian bookworm/main amd64 libcurl4 amd64 7.88.1-10+deb12u15 [392 kB]
#7 51.07 Get:80 http://deb.debian.org/debian bookworm/main amd64 libdatrie1 amd64 0.2.13-2+b1 [43.3 kB]
#7 51.38 Get:81 http://deb.debian.org/debian bookworm/main amd64 libexif12 amd64 0.6.24-1+deb12u1 [397 kB]
#7 52.24 Get:82 http://deb.debian.org/debian bookworm/main amd64 libfribidi0 amd64 1.0.8-2.1 [65.0 kB]
#7 52.57 Get:83 http://deb.debian.org/debian bookworm/main amd64 libgdk-pixbuf2.0-common all 2.42.10+dfsg-1+deb12u4 [307 kB]
#7 53.20 Get:84 http://deb.debian.org/debian bookworm/main amd64 shared-mime-info amd64 2.2-1 [729 kB]
#7 54.17 Get:85 http://deb.debian.org/debian bookworm/main amd64 libgdk-pixbuf-2.0-0 amd64 2.42.10+dfsg-1+deb12u4 [139 kB]
#7 54.52 Get:86 http://deb.debian.org/debian bookworm/main amd64 libgraphite2-3 amd64 1.3.14-1+deb12u1 [74.6 kB]
#7 55.08 Get:87 http://deb.debian.org/debian bookworm/main amd64 libgsf-1-common all 1.14.50-1+deb12u1 [154 kB]
#7 55.42 Get:88 http://deb.debian.org/debian bookworm/main amd64 libgsf-1-114 amd64 1.14.50-1+deb12u1 [154 kB]
#7 55.78 Get:89 http://deb.debian.org/debian bookworm/main amd64 libharfbuzz0b amd64 6.0.0+dfsg-3 [1945 kB]
#7 65.18 Get:90 http://deb.debian.org/debian bookworm/main amd64 libsz2 amd64 1.0.6-1+b1 [7804 B]
#7 65.54 Get:91 http://deb.debian.org/debian bookworm/main amd64 libhdf5-103-1 amd64 1.10.8+repack1-1 [1237 kB]
#7 66.19 Get:92 http://deb.debian.org/debian bookworm/main amd64 libhwy1 amd64 1.0.3-3+deb12u1 [348 kB]
#7 ...

#8 [build 1/7] COPY next.config.ts tsconfig.json next-env.d.ts eslint.config.mjs ./
#8 CACHED

#9 [build 2/7] COPY src ./src
#9 DONE 0.1s

#10 [production-dependencies 1/1] RUN pnpm prune --prod
#10 CACHED

#11 [internal] load build context
#11 transferring context: 553.18kB done
#11 DONE 0.0s

#12 [dependencies 5/5] RUN pnpm install --frozen-lockfile
#12 CACHED

#13 [build 1/7] COPY next.config.ts tsconfig.json next-env.d.ts eslint.config.mjs ./
#13 CACHED

#14 [build 2/7] COPY src ./src
#14 CACHED

#15 [dependencies 4/5] COPY package.json pnpm-lock.yaml pnpm-workspace.yaml ./
#15 CACHED

#16 [dependencies 2/5] WORKDIR /app
#16 CACHED

#17 [dependencies 3/5] RUN corepack enable
#17 CACHED

#18 [build 3/7] COPY scripts ./scripts
#18 DONE 0.1s

#7 [runtime  2/12] RUN apt-get update     && apt-get install -y --no-install-recommends qpdf libvips-tools util-linux     && rm -rf /var/lib/apt/lists/*     && groupadd --gid 10001 fiscalizacion     && useradd --uid 10001 --gid 10001 --no-create-home fiscalizacion     && mkdir -p /datos/archivos     && chown 10001:10001 /datos/archivos
#7 67.05 Get:93 http://deb.debian.org/debian bookworm/main amd64 libimagequant0 amd64 2.17.0-1 [32.5 kB]
#7 ...

#19 [build 4/7] COPY drizzle ./drizzle
#19 DONE 0.1s

#7 [runtime  2/12] RUN apt-get update     && apt-get install -y --no-install-recommends qpdf libvips-tools util-linux     && rm -rf /var/lib/apt/lists/*     && groupadd --gid 10001 fiscalizacion     && useradd --uid 10001 --gid 10001 --no-create-home fiscalizacion     && mkdir -p /datos/archivos     && chown 10001:10001 /datos/archivos
#7 67.38 Get:94 http://deb.debian.org/debian bookworm/main amd64 libimath-3-1-29 amd64 3.1.6-1 [47.4 kB]
#7 67.69 Get:95 http://deb.debian.org/debian bookworm/main amd64 libjxl0.7 amd64 0.7.0-10+deb12u1 [1046 kB]
#7 68.65 Get:96 http://deb.debian.org/debian bookworm/main amd64 libmatio11 amd64 1.5.23-2+deb12u1 [103 kB]
#7 69.20 Get:97 http://deb.debian.org/debian bookworm/main amd64 libnspr4 amd64 2:4.35-1 [113 kB]
#7 69.54 Get:98 http://deb.debian.org/debian-security bookworm-security/main amd64 libnss3 amd64 2:3.87.1-1+deb12u4 [1331 kB]
#7 70.67 Get:99 http://deb.debian.org/debian bookworm/main amd64 libopenexr-3-1-30 amd64 3.1.5-5 [923 kB]
#7 72.09 Get:100 http://deb.debian.org/debian bookworm/main amd64 libopenslide0 amd64 3.4.1+dfsg-6+deb12u1 [86.9 kB]
#7 72.43 Get:101 http://deb.debian.org/debian bookworm/main amd64 liborc-0.4-0 amd64 1:0.4.33-2 [164 kB]
#7 73.23 Get:102 http://deb.debian.org/debian bookworm/main amd64 libthai-data all 0.1.29-1 [176 kB]
#7 73.58 Get:103 http://deb.debian.org/debian bookworm/main amd64 libthai0 amd64 0.1.29-1 [57.5 kB]
#7 73.91 Get:104 http://deb.debian.org/debian bookworm/main amd64 libpango-1.0-0 amd64 1.50.12+ds-1 [212 kB]
#7 74.28 Get:105 http://deb.debian.org/debian bookworm/main amd64 libpangoft2-1.0-0 amd64 1.50.12+ds-1 [47.4 kB]
#7 74.59 Get:106 http://deb.debian.org/debian bookworm/main amd64 libpangocairo-1.0-0 amd64 1.50.12+ds-1 [34.2 kB]
#7 74.90 Get:107 http://deb.debian.org/debian-security bookworm-security/main amd64 libpoppler126 amd64 22.12.0-2+deb12u3 [1856 kB]
#7 75.57 Get:108 http://deb.debian.org/debian-security bookworm-security/main amd64 libpoppler-glib8 amd64 22.12.0-2+deb12u3 [133 kB]
#7 76.13 Get:109 http://deb.debian.org/debian bookworm/main amd64 libqpdf29 amd64 11.3.0-1+deb12u1 [867 kB]
#7 77.03 Get:110 http://deb.debian.org/debian bookworm/main amd64 librsvg2-2 amd64 2.54.7+dfsg-1~deb12u1 [2620 kB]
#7 ...

#20 [build 5/7] RUN pnpm build
#20 0.382 $ next build
#20 0.848    ▲ Next.js 15.5.27
#20 0.848 
#20 0.861    Creating an optimized production build ...
#20 7.162  ✓ Compiled successfully in 4.9s
#20 7.164    Linting and checking validity of types ...
#20 9.996    Collecting page data ...
#20 11.44    Generating static pages (0/7) ...
#20 ...

#7 [runtime  2/12] RUN apt-get update     && apt-get install -y --no-install-recommends qpdf libvips-tools util-linux     && rm -rf /var/lib/apt/lists/*     && groupadd --gid 10001 fiscalizacion     && useradd --uid 10001 --gid 10001 --no-create-home fiscalizacion     && mkdir -p /datos/archivos     && chown 10001:10001 /datos/archivos
#7 79.00 Get:111 http://deb.debian.org/debian bookworm/main amd64 libvips42 amd64 8.14.1-3+deb12u3 [1269 kB]
#7 80.92 Get:112 http://deb.debian.org/debian bookworm/main amd64 libvips-tools amd64 8.14.1-3+deb12u3 [82.8 kB]
#7 81.23 Get:113 http://deb.debian.org/debian bookworm/main amd64 qpdf amd64 11.3.0-1+deb12u1 [131 kB]
#7 81.57 debconf: delaying package configuration, since apt-utils is not installed
#7 81.59 Fetched 54.7 MB in 1min 15s (729 kB/s)
#7 81.60 Selecting previously unselected package libgomp1:amd64.
#7 81.60 (Reading database ... (Reading database ... 5%(Reading database ... 10%(Reading database ... 15%(Reading database ... 20%(Reading database ... 25%(Reading database ... 30%(Reading database ... 35%(Reading database ... 40%(Reading database ... 45%(Reading database ... 50%(Reading database ... 55%(Reading database ... 60%(Reading database ... 65%(Reading database ... 70%(Reading database ... 75%(Reading database ... 80%(Reading database ... 85%(Reading database ... 90%(Reading database ... 95%(Reading database ... 100%(Reading database ... 6096 files and directories currently installed.)
#7 81.61 Preparing to unpack .../00-libgomp1_12.2.0-14+deb12u1_amd64.deb ...
#7 81.77 Unpacking libgomp1:amd64 (12.2.0-14+deb12u1) ...
#7 81.80 Selecting previously unselected package libfftw3-double3:amd64.
#7 81.81 Preparing to unpack .../01-libfftw3-double3_3.3.10-1_amd64.deb ...
#7 81.81 Unpacking libfftw3-double3:amd64 (3.3.10-1) ...
#7 81.86 Selecting previously unselected package libexpat1:amd64.
#7 81.86 Preparing to unpack .../02-libexpat1_2.5.0-1+deb12u4_amd64.deb ...
#7 81.87 Unpacking libexpat1:amd64 (2.5.0-1+deb12u4) ...
#7 81.89 Selecting previously unselected package libbrotli1:amd64.
#7 81.89 Preparing to unpack .../03-libbrotli1_1.0.9-2+b6_amd64.deb ...
#7 81.90 Unpacking libbrotli1:amd64 (1.0.9-2+b6) ...
#7 81.94 Selecting previously unselected package libpng16-16:amd64.
#7 81.94 Preparing to unpack .../04-libpng16-16_1.6.39-2+deb12u5_amd64.deb ...
#7 81.94 Unpacking libpng16-16:amd64 (1.6.39-2+deb12u5) ...
#7 81.97 Selecting previously unselected package libfreetype6:amd64.
#7 81.97 Preparing to unpack .../05-libfreetype6_2.12.1+dfsg-5+deb12u4_amd64.deb ...
#7 81.98 Unpacking libfreetype6:amd64 (2.12.1+dfsg-5+deb12u4) ...
#7 82.01 Selecting previously unselected package fonts-dejavu-core.
#7 82.01 Preparing to unpack .../06-fonts-dejavu-core_2.37-6_all.deb ...
#7 82.02 Unpacking fonts-dejavu-core (2.37-6) ...
#7 82.09 Selecting previously unselected package fontconfig-config.
#7 82.09 Preparing to unpack .../07-fontconfig-config_2.14.1-4_amd64.deb ...
#7 82.15 Unpacking fontconfig-config (2.14.1-4) ...
#7 82.19 Selecting previously unselected package libfontconfig1:amd64.
#7 82.19 Preparing to unpack .../08-libfontconfig1_2.14.1-4_amd64.deb ...
#7 82.19 Unpacking libfontconfig1:amd64 (2.14.1-4) ...
#7 82.22 Selecting previously unselected package libaom3:amd64.
#7 82.22 Preparing to unpack .../09-libaom3_3.6.0-1+deb12u3_amd64.deb ...
#7 82.22 Unpacking libaom3:amd64 (3.6.0-1+deb12u3) ...
#7 82.32 Selecting previously unselected package libdav1d6:amd64.
#7 82.32 Preparing to unpack .../10-libdav1d6_1.0.0-2+deb12u1_amd64.deb ...
#7 82.33 Unpacking libdav1d6:amd64 (1.0.0-2+deb12u1) ...
#7 82.38 Selecting previously unselected package libde265-0:amd64.
#7 82.38 Preparing to unpack .../11-libde265-0_1.0.11-1+deb12u3_amd64.deb ...
#7 82.38 Unpacking libde265-0:amd64 (1.0.11-1+deb12u3) ...
#7 82.42 Selecting previously unselected package libnuma1:amd64.
#7 82.43 Preparing to unpack .../12-libnuma1_2.0.16-1_amd64.deb ...
#7 82.43 Unpacking libnuma1:amd64 (2.0.16-1) ...
#7 82.48 Selecting previously unselected package libx265-199:amd64.
#7 82.48 Preparing to unpack .../13-libx265-199_3.5-2+b1_amd64.deb ...
#7 82.49 Unpacking libx265-199:amd64 (3.5-2+b1) ...
#7 82.59 Selecting previously unselected package libheif1:amd64.
#7 82.59 Preparing to unpack .../14-libheif1_1.15.1-1+deb12u1_amd64.deb ...
#7 82.59 Unpacking libheif1:amd64 (1.15.1-1+deb12u1) ...
#7 82.64 Selecting previously unselected package libjbig0:amd64.
#7 82.65 Preparing to unpack .../15-libjbig0_2.1-6.1_amd64.deb ...
#7 82.65 Unpacking libjbig0:amd64 (2.1-6.1) ...
#7 82.68 Selecting previously unselected package libjpeg62-turbo:amd64.
#7 82.68 Preparing to unpack .../16-libjpeg62-turbo_1%3a2.1.5-2_amd64.deb ...
#7 82.68 Unpacking libjpeg62-turbo:amd64 (1:2.1.5-2) ...
#7 82.71 Selecting previously unselected package liblcms2-2:amd64.
#7 82.71 Preparing to unpack .../17-liblcms2-2_2.14-2+deb12u1_amd64.deb ...
#7 82.72 Unpacking liblcms2-2:amd64 (2.14-2+deb12u1) ...
#7 82.75 Selecting previously unselected package libglib2.0-0:amd64.
#7 82.75 Preparing to unpack .../18-libglib2.0-0_2.74.6-2+deb12u9_amd64.deb ...
#7 82.75 Unpacking libglib2.0-0:amd64 (2.74.6-2+deb12u9) ...
#7 82.83 Selecting previously unselected package liblqr-1-0:amd64.
#7 82.83 Preparing to unpack .../19-liblqr-1-0_0.4.2-2.1_amd64.deb ...
#7 82.83 Unpacking liblqr-1-0:amd64 (0.4.2-2.1) ...
#7 82.86 Selecting previously unselected package libltdl7:amd64.
#7 82.86 Preparing to unpack .../20-libltdl7_2.4.7-7~deb12u1_amd64.deb ...
#7 82.86 Unpacking libltdl7:amd64 (2.4.7-7~deb12u1) ...
#7 82.89 Selecting previously unselected package libopenjp2-7:amd64.
#7 82.89 Preparing to unpack .../21-libopenjp2-7_2.5.0-2+deb12u3_amd64.deb ...
#7 82.90 Unpacking libopenjp2-7:amd64 (2.5.0-2+deb12u3) ...
#7 82.93 Selecting previously unselected package libdeflate0:amd64.
#7 82.93 Preparing to unpack .../22-libdeflate0_1.14-1_amd64.deb ...
#7 82.94 Unpacking libdeflate0:amd64 (1.14-1) ...
#7 82.96 Selecting previously unselected package liblerc4:amd64.
#7 82.96 Preparing to unpack .../23-liblerc4_4.0.0+ds-2_amd64.deb ...
#7 82.97 Unpacking liblerc4:amd64 (4.0.0+ds-2) ...
#7 83.00 Selecting previously unselected package libwebp7:amd64.
#7 83.00 Preparing to unpack .../24-libwebp7_1.2.4-0.2+deb12u1_amd64.deb ...
#7 83.00 Unpacking libwebp7:amd64 (1.2.4-0.2+deb12u1) ...
#7 83.03 Selecting previously unselected package libtiff6:amd64.
#7 83.04 Preparing to unpack .../25-libtiff6_4.5.0-6+deb12u4_amd64.deb ...
#7 83.04 Unpacking libtiff6:amd64 (4.5.0-6+deb12u4) ...
#7 83.07 Selecting previously unselected package libwebpdemux2:amd64.
#7 83.07 Preparing to unpack .../26-libwebpdemux2_1.2.4-0.2+deb12u1_amd64.deb ...
#7 83.08 Unpacking libwebpdemux2:amd64 (1.2.4-0.2+deb12u1) ...
#7 83.11 Selecting previously unselected package libwebpmux3:amd64.
#7 83.11 Preparing to unpack .../27-libwebpmux3_1.2.4-0.2+deb12u1_amd64.deb ...
#7 83.11 Unpacking libwebpmux3:amd64 (1.2.4-0.2+deb12u1) ...
#7 83.14 Selecting previously unselected package libxau6:amd64.
#7 83.14 Preparing to unpack .../28-libxau6_1%3a1.0.9-1_amd64.deb ...
#7 83.15 Unpacking libxau6:amd64 (1:1.0.9-1) ...
#7 83.17 Selecting previously unselected package libbsd0:amd64.
#7 83.17 Preparing to unpack .../29-libbsd0_0.11.7-2_amd64.deb ...
#7 83.18 Unpacking libbsd0:amd64 (0.11.7-2) ...
#7 83.20 Selecting previously unselected package libxdmcp6:amd64.
#7 83.21 Preparing to unpack .../30-libxdmcp6_1%3a1.1.2-3_amd64.deb ...
#7 83.21 Unpacking libxdmcp6:amd64 (1:1.1.2-3) ...
#7 83.23 Selecting previously unselected package libxcb1:amd64.
#7 83.24 Preparing to unpack .../31-libxcb1_1.15-1_amd64.deb ...
#7 83.24 Unpacking libxcb1:amd64 (1.15-1) ...
#7 83.26 Selecting previously unselected package libx11-data.
#7 83.26 Preparing to unpack .../32-libx11-data_2%3a1.8.4-2+deb12u2_all.deb ...
#7 83.27 Unpacking libx11-data (2:1.8.4-2+deb12u2) ...
#7 83.47 Selecting previously unselected package libx11-6:amd64.
#7 83.47 Preparing to unpack .../33-libx11-6_2%3a1.8.4-2+deb12u2_amd64.deb ...
#7 83.48 Unpacking libx11-6:amd64 (2:1.8.4-2+deb12u2) ...
#7 83.53 Selecting previously unselected package libxext6:amd64.
#7 83.53 Preparing to unpack .../34-libxext6_2%3a1.3.4-1+b1_amd64.deb ...
#7 83.55 Unpacking libxext6:amd64 (2:1.3.4-1+b1) ...
#7 83.80 Selecting previously unselected package libicu72:amd64.
#7 83.80 Preparing to unpack .../35-libicu72_72.1-3+deb12u1_amd64.deb ...
#7 83.81 Unpacking libicu72:amd64 (72.1-3+deb12u1) ...
#7 84.12 Selecting previously unselected package libxml2:amd64.
#7 84.12 Preparing to unpack .../36-libxml2_2.9.14+dfsg-1.3~deb12u6_amd64.deb ...
#7 84.12 Unpacking libxml2:amd64 (2.9.14+dfsg-1.3~deb12u6) ...
#7 84.17 Selecting previously unselected package imagemagick-6-common.
#7 84.17 Preparing to unpack .../37-imagemagick-6-common_8%3a6.9.11.60+dfsg-1.6+deb12u13_all.deb ...
#7 84.17 Unpacking imagemagick-6-common (8:6.9.11.60+dfsg-1.6+deb12u13) ...
#7 84.20 Selecting previously unselected package libmagickcore-6.q16-6:amd64.
#7 84.20 Preparing to unpack .../38-libmagickcore-6.q16-6_8%3a6.9.11.60+dfsg-1.6+deb12u13_amd64.deb ...
#7 84.21 Unpacking libmagickcore-6.q16-6:amd64 (8:6.9.11.60+dfsg-1.6+deb12u13) ...
#7 84.36 Selecting previously unselected package libssl3:amd64.
#7 84.36 Preparing to unpack .../39-libssl3_3.0.22-1~deb12u1_amd64.deb ...
#7 84.36 Unpacking libssl3:amd64 (3.0.22-1~deb12u1) ...
#7 84.46 Selecting previously unselected package libpython3.11-minimal:amd64.
#7 84.46 Preparing to unpack .../40-libpython3.11-minimal_3.11.2-6+deb12u8_amd64.deb ...
#7 84.46 Unpacking libpython3.11-minimal:amd64 (3.11.2-6+deb12u8) ...
#7 84.52 Selecting previously unselected package python3.11-minimal.
#7 84.53 Preparing to unpack .../41-python3.11-minimal_3.11.2-6+deb12u8_amd64.deb ...
#7 84.53 Unpacking python3.11-minimal (3.11.2-6+deb12u8) ...
#7 84.68 Setting up libssl3:amd64 (3.0.22-1~deb12u1) ...
#7 84.69 Setting up libpython3.11-minimal:amd64 (3.11.2-6+deb12u8) ...
#7 84.70 Setting up libexpat1:amd64 (2.5.0-1+deb12u4) ...
#7 84.70 Setting up python3.11-minimal (3.11.2-6+deb12u8) ...
#7 85.06 Selecting previously unselected package python3-minimal.
#7 85.06 (Reading database ... (Reading database ... 5%(Reading database ... 10%(Reading database ... 15%(Reading database ... 20%(Reading database ... 25%(Reading database ... 30%(Reading database ... 35%(Reading database ... 40%(Reading database ... 45%(Reading database ... 50%(Reading database ... 55%(Reading database ... 60%(Reading database ... 65%(Reading database ... 70%(Reading database ... 75%(Reading database ... 80%(Reading database ... 85%(Reading database ... 90%(Reading database ... 95%(Reading database ... 100%(Reading database ... 7331 files and directories currently installed.)
#7 85.07 Preparing to unpack .../00-python3-minimal_3.11.2-1+b1_amd64.deb ...
#7 85.07 Unpacking python3-minimal (3.11.2-1+b1) ...
#7 85.10 Selecting previously unselected package media-types.
#7 85.10 Preparing to unpack .../01-media-types_10.0.0_all.deb ...
#7 85.10 Unpacking media-types (10.0.0) ...
#7 85.13 Selecting previously unselected package libncursesw6:amd64.
#7 85.13 Preparing to unpack .../02-libncursesw6_6.4-4_amd64.deb ...
#7 85.14 Unpacking libncursesw6:amd64 (6.4-4) ...
#7 85.19 Selecting previously unselected package libkrb5support0:amd64.
#7 85.19 Preparing to unpack .../03-libkrb5support0_1.20.1-2+deb12u5_amd64.deb ...
#7 85.20 Unpacking libkrb5support0:amd64 (1.20.1-2+deb12u5) ...
#7 85.22 Selecting previously unselected package libk5crypto3:amd64.
#7 85.23 Preparing to unpack .../04-libk5crypto3_1.20.1-2+deb12u5_amd64.deb ...
#7 85.23 Unpacking libk5crypto3:amd64 (1.20.1-2+deb12u5) ...
#7 85.26 Selecting previously unselected package libkeyutils1:amd64.
#7 85.26 Preparing to unpack .../05-libkeyutils1_1.6.3-2_amd64.deb ...
#7 85.26 Unpacking libkeyutils1:amd64 (1.6.3-2) ...
#7 85.28 Selecting previously unselected package libkrb5-3:amd64.
#7 85.29 Preparing to unpack .../06-libkrb5-3_1.20.1-2+deb12u5_amd64.deb ...
#7 85.29 Unpacking libkrb5-3:amd64 (1.20.1-2+deb12u5) ...
#7 85.33 Selecting previously unselected package libgssapi-krb5-2:amd64.
#7 85.33 Preparing to unpack .../07-libgssapi-krb5-2_1.20.1-2+deb12u5_amd64.deb ...
#7 85.33 Unpacking libgssapi-krb5-2:amd64 (1.20.1-2+deb12u5) ...
#7 85.36 Selecting previously unselected package libtirpc-common.
#7 85.36 Preparing to unpack .../08-libtirpc-common_1.3.3+ds-1_all.deb ...
#7 85.36 Unpacking libtirpc-common (1.3.3+ds-1) ...
#7 85.39 Selecting previously unselected package libtirpc3:amd64.
#7 85.39 Preparing to unpack .../09-libtirpc3_1.3.3+ds-1_amd64.deb ...
#7 85.40 Unpacking libtirpc3:amd64 (1.3.3+ds-1) ...
#7 85.43 Selecting previously unselected package libnsl2:amd64.
#7 85.43 Preparing to unpack .../10-libnsl2_1.3.0-2_amd64.deb ...
#7 85.43 Unpacking libnsl2:amd64 (1.3.0-2) ...
#7 85.45 Selecting previously unselected package readline-common.
#7 85.46 Preparing to unpack .../11-readline-common_8.2-1.3_all.deb ...
#7 85.46 Unpacking readline-common (8.2-1.3) ...
#7 85.50 Selecting previously unselected package libreadline8:amd64.
#7 85.50 Preparing to unpack .../12-libreadline8_8.2-1.3_amd64.deb ...
#7 85.51 Unpacking libreadline8:amd64 (8.2-1.3) ...
#7 85.54 Selecting previously unselected package libsqlite3-0:amd64.
#7 85.54 Preparing to unpack .../13-libsqlite3-0_3.40.1-2+deb12u2_amd64.deb ...
#7 85.54 Unpacking libsqlite3-0:amd64 (3.40.1-2+deb12u2) ...
#7 85.59 Selecting previously unselected package libpython3.11-stdlib:amd64.
#7 85.60 Preparing to unpack .../14-libpython3.11-stdlib_3.11.2-6+deb12u8_amd64.deb ...
#7 85.60 Unpacking libpython3.11-stdlib:amd64 (3.11.2-6+deb12u8) ...
#7 85.72 Selecting previously unselected package python3.11.
#7 85.72 Preparing to unpack .../15-python3.11_3.11.2-6+deb12u8_amd64.deb ...
#7 85.73 Unpacking python3.11 (3.11.2-6+deb12u8) ...
#7 85.76 Selecting previously unselected package libpython3-stdlib:amd64.
#7 85.76 Preparing to unpack .../16-libpython3-stdlib_3.11.2-1+b1_amd64.deb ...
#7 85.76 Unpacking libpython3-stdlib:amd64 (3.11.2-1+b1) ...
#7 85.79 Setting up python3-minimal (3.11.2-1+b1) ...
#7 85.88 Selecting previously unselected package python3.
#7 85.88 (Reading database ... (Reading database ... 5%(Reading database ... 10%(Reading database ... 15%(Reading database ... 20%(Reading database ... 25%(Reading database ... 30%(Reading database ... 35%(Reading database ... 40%(Reading database ... 45%(Reading database ... 50%(Reading database ... 55%(Reading database ... 60%(Reading database ... 65%(Reading database ... 70%(Reading database ... 75%(Reading database ... 80%(Reading database ... 85%(Reading database ... 90%(Reading database ... 95%(Reading database ... 100%(Reading database ... 7839 files and directories currently installed.)
#7 85.89 Preparing to unpack .../00-python3_3.11.2-1+b1_amd64.deb ...
#7 85.89 Unpacking python3 (3.11.2-1+b1) ...
#7 85.92 Selecting previously unselected package fontconfig.
#7 85.92 Preparing to unpack .../01-fontconfig_2.14.1-4_amd64.deb ...
#7 85.92 Unpacking fontconfig (2.14.1-4) ...
#7 85.96 Selecting previously unselected package libaec0:amd64.
#7 85.96 Preparing to unpack .../02-libaec0_1.0.6-1+b1_amd64.deb ...
#7 85.96 Unpacking libaec0:amd64 (1.0.6-1+b1) ...
#7 85.99 Selecting previously unselected package libpixman-1-0:amd64.
#7 85.99 Preparing to unpack .../03-libpixman-1-0_0.42.2-1_amd64.deb ...
#7 85.99 Unpacking libpixman-1-0:amd64 (0.42.2-1) ...
#7 86.03 Selecting previously unselected package libxcb-render0:amd64.
#7 86.03 Preparing to unpack .../04-libxcb-render0_1.15-1_amd64.deb ...
#7 86.03 Unpacking libxcb-render0:amd64 (1.15-1) ...
#7 86.07 Selecting previously unselected package libxcb-shm0:amd64.
#7 86.07 Preparing to unpack .../05-libxcb-shm0_1.15-1_amd64.deb ...
#7 86.07 Unpacking libxcb-shm0:amd64 (1.15-1) ...
#7 86.10 Selecting previously unselected package libxrender1:amd64.
#7 86.10 Preparing to unpack .../06-libxrender1_1%3a0.9.10-1.1_amd64.deb ...
#7 86.11 Unpacking libxrender1:amd64 (1:0.9.10-1.1) ...
#7 86.13 Selecting previously unselected package libcairo2:amd64.
#7 86.13 Preparing to unpack .../07-libcairo2_1.16.0-7_amd64.deb ...
#7 86.14 Unpacking libcairo2:amd64 (1.16.0-7) ...
#7 86.20 Selecting previously unselected package libcairo-gobject2:amd64.
#7 86.20 Preparing to unpack .../08-libcairo-gobject2_1.16.0-7_amd64.deb ...
#7 86.20 Unpacking libcairo-gobject2:amd64 (1.16.0-7) ...
#7 86.23 Selecting previously unselected package libsasl2-modules-db:amd64.
#7 86.24 Preparing to unpack .../09-libsasl2-modules-db_2.1.28+dfsg-10_amd64.deb ...
#7 86.24 Unpacking libsasl2-modules-db:amd64 (2.1.28+dfsg-10) ...
#7 86.28 Selecting previously unselected package libsasl2-2:amd64.
#7 86.29 Preparing to unpack .../10-libsasl2-2_2.1.28+dfsg-10_amd64.deb ...
#7 86.29 Unpacking libsasl2-2:amd64 (2.1.28+dfsg-10) ...
#7 86.32 Selecting previously unselected package libldap-2.5-0:amd64.
#7 86.32 Preparing to unpack .../11-libldap-2.5-0_2.5.13+dfsg-5_amd64.deb ...
#7 86.32 Unpacking libldap-2.5-0:amd64 (2.5.13+dfsg-5) ...
#7 86.35 Selecting previously unselected package libnghttp2-14:amd64.
#7 86.36 Preparing to unpack .../12-libnghttp2-14_1.52.0-1+deb12u3_amd64.deb ...
#7 86.36 Unpacking libnghttp2-14:amd64 (1.52.0-1+deb12u3) ...
#7 86.38 Selecting previously unselected package libpsl5:amd64.
#7 86.39 Preparing to unpack .../13-libpsl5_0.21.2-1_amd64.deb ...
#7 86.39 Unpacking libpsl5:amd64 (0.21.2-1) ...
#7 86.42 Selecting previously unselected package librtmp1:amd64.
#7 86.42 Preparing to unpack .../14-librtmp1_2.4+20151223.gitfa8646d.1-2+b2_amd64.deb ...
#7 86.42 Unpacking librtmp1:amd64 (2.4+20151223.gitfa8646d.1-2+b2) ...
#7 86.45 Selecting previously unselected package libssh2-1:amd64.
#7 86.46 Preparing to unpack .../15-libssh2-1_1.10.0-3+deb12u1_amd64.deb ...
#7 86.46 Unpacking libssh2-1:amd64 (1.10.0-3+deb12u1) ...
#7 86.49 Selecting previously unselected package libcurl3-gnutls:amd64.
#7 86.49 Preparing to unpack .../16-libcurl3-gnutls_7.88.1-10+deb12u15_amd64.deb ...
#7 86.49 Unpacking libcurl3-gnutls:amd64 (7.88.1-10+deb12u15) ...
#7 86.53 Selecting previously unselected package libcfitsio10:amd64.
#7 86.53 Preparing to unpack .../17-libcfitsio10_4.2.0-3_amd64.deb ...
#7 86.54 Unpacking libcfitsio10:amd64 (4.2.0-3) ...
#7 86.58 Selecting previously unselected package libcgif0:amd64.
#7 86.58 Preparing to unpack .../18-libcgif0_0.3.0-1_amd64.deb ...
#7 86.58 Unpacking libcgif0:amd64 (0.3.0-1) ...
#7 86.61 Selecting previously unselected package libcurl4:amd64.
#7 86.61 Preparing to unpack .../19-libcurl4_7.88.1-10+deb12u15_amd64.deb ...
#7 86.62 Unpacking libcurl4:amd64 (7.88.1-10+deb12u15) ...
#7 86.65 Selecting previously unselected package libdatrie1:amd64.
#7 86.66 Preparing to unpack .../20-libdatrie1_0.2.13-2+b1_amd64.deb ...
#7 86.66 Unpacking libdatrie1:amd64 (0.2.13-2+b1) ...
#7 86.68 Selecting previously unselected package libexif12:amd64.
#7 86.69 Preparing to unpack .../21-libexif12_0.6.24-1+deb12u1_amd64.deb ...
#7 86.69 Unpacking libexif12:amd64 (0.6.24-1+deb12u1) ...
#7 86.74 Selecting previously unselected package libfribidi0:amd64.
#7 86.74 Preparing to unpack .../22-libfribidi0_1.0.8-2.1_amd64.deb ...
#7 86.75 Unpacking libfribidi0:amd64 (1.0.8-2.1) ...
#7 86.77 Selecting previously unselected package libgdk-pixbuf2.0-common.
#7 86.78 Preparing to unpack .../23-libgdk-pixbuf2.0-common_2.42.10+dfsg-1+deb12u4_all.deb ...
#7 86.78 Unpacking libgdk-pixbuf2.0-common (2.42.10+dfsg-1+deb12u4) ...
#7 86.82 Selecting previously unselected package shared-mime-info.
#7 86.82 Preparing to unpack .../24-shared-mime-info_2.2-1_amd64.deb ...
#7 86.82 Unpacking shared-mime-info (2.2-1) ...
#7 86.88 Selecting previously unselected package libgdk-pixbuf-2.0-0:amd64.
#7 86.88 Preparing to unpack .../25-libgdk-pixbuf-2.0-0_2.42.10+dfsg-1+deb12u4_amd64.deb ...
#7 86.89 Unpacking libgdk-pixbuf-2.0-0:amd64 (2.42.10+dfsg-1+deb12u4) ...
#7 86.92 Selecting previously unselected package libgraphite2-3:amd64.
#7 86.92 Preparing to unpack .../26-libgraphite2-3_1.3.14-1+deb12u1_amd64.deb ...
#7 86.92 Unpacking libgraphite2-3:amd64 (1.3.14-1+deb12u1) ...
#7 87.02 Selecting previously unselected package libgsf-1-common.
#7 87.02 Preparing to unpack .../27-libgsf-1-common_1.14.50-1+deb12u1_all.deb ...
#7 87.06 Unpacking libgsf-1-common (1.14.50-1+deb12u1) ...
#7 87.17 Selecting previously unselected package libgsf-1-114:amd64.
#7 87.17 Preparing to unpack .../28-libgsf-1-114_1.14.50-1+deb12u1_amd64.deb ...
#7 87.20 Unpacking libgsf-1-114:amd64 (1.14.50-1+deb12u1) ...
#7 87.29 Selecting previously unselected package libharfbuzz0b:amd64.
#7 87.29 Preparing to unpack .../29-libharfbuzz0b_6.0.0+dfsg-3_amd64.deb ...
#7 87.29 Unpacking libharfbuzz0b:amd64 (6.0.0+dfsg-3) ...
#7 87.34 Selecting previously unselected package libsz2:amd64.
#7 87.34 Preparing to unpack .../30-libsz2_1.0.6-1+b1_amd64.deb ...
#7 87.34 Unpacking libsz2:amd64 (1.0.6-1+b1) ...
#7 87.37 Selecting previously unselected package libhdf5-103-1:amd64.
#7 87.37 Preparing to unpack .../31-libhdf5-103-1_1.10.8+repack1-1_amd64.deb ...
#7 87.37 Unpacking libhdf5-103-1:amd64 (1.10.8+repack1-1) ...
#7 87.44 Selecting previously unselected package libhwy1:amd64.
#7 87.44 Preparing to unpack .../32-libhwy1_1.0.3-3+deb12u1_amd64.deb ...
#7 87.45 Unpacking libhwy1:amd64 (1.0.3-3+deb12u1) ...
#7 87.49 Selecting previously unselected package libimagequant0:amd64.
#7 87.50 Preparing to unpack .../33-libimagequant0_2.17.0-1_amd64.deb ...
#7 87.50 Unpacking libimagequant0:amd64 (2.17.0-1) ...
#7 87.52 Selecting previously unselected package libimath-3-1-29:amd64.
#7 87.53 Preparing to unpack .../34-libimath-3-1-29_3.1.6-1_amd64.deb ...
#7 87.53 Unpacking libimath-3-1-29:amd64 (3.1.6-1) ...
#7 87.56 Selecting previously unselected package libjxl0.7:amd64.
#7 87.56 Preparing to unpack .../35-libjxl0.7_0.7.0-10+deb12u1_amd64.deb ...
#7 87.56 Unpacking libjxl0.7:amd64 (0.7.0-10+deb12u1) ...
#7 87.62 Selecting previously unselected package libmatio11:amd64.
#7 87.63 Preparing to unpack .../36-libmatio11_1.5.23-2+deb12u1_amd64.deb ...
#7 87.63 Unpacking libmatio11:amd64 (1.5.23-2+deb12u1) ...
#7 87.66 Selecting previously unselected package libnspr4:amd64.
#7 87.66 Preparing to unpack .../37-libnspr4_2%3a4.35-1_amd64.deb ...
#7 87.66 Unpacking libnspr4:amd64 (2:4.35-1) ...
#7 87.69 Selecting previously unselected package libnss3:amd64.
#7 87.69 Preparing to unpack .../38-libnss3_2%3a3.87.1-1+deb12u4_amd64.deb ...
#7 87.70 Unpacking libnss3:amd64 (2:3.87.1-1+deb12u4) ...
#7 87.77 Selecting previously unselected package libopenexr-3-1-30:amd64.
#7 87.77 Preparing to unpack .../39-libopenexr-3-1-30_3.1.5-5_amd64.deb ...
#7 87.77 Unpacking libopenexr-3-1-30:amd64 (3.1.5-5) ...
#7 87.84 Selecting previously unselected package libopenslide0.
#7 87.84 Preparing to unpack .../40-libopenslide0_3.4.1+dfsg-6+deb12u1_amd64.deb ...
#7 87.85 Unpacking libopenslide0 (3.4.1+dfsg-6+deb12u1) ...
#7 87.87 Selecting previously unselected package liborc-0.4-0:amd64.
#7 87.87 Preparing to unpack .../41-liborc-0.4-0_1%3a0.4.33-2_amd64.deb ...
#7 87.88 Unpacking liborc-0.4-0:amd64 (1:0.4.33-2) ...
#7 87.91 Selecting previously unselected package libthai-data.
#7 87.91 Preparing to unpack .../42-libthai-data_0.1.29-1_all.deb ...
#7 87.91 Unpacking libthai-data (0.1.29-1) ...
#7 87.94 Selecting previously unselected package libthai0:amd64.
#7 87.95 Preparing to unpack .../43-libthai0_0.1.29-1_amd64.deb ...
#7 87.95 Unpacking libthai0:amd64 (0.1.29-1) ...
#7 87.98 Selecting previously unselected package libpango-1.0-0:amd64.
#7 87.98 Preparing to unpack .../44-libpango-1.0-0_1.50.12+ds-1_amd64.deb ...
#7 87.98 Unpacking libpango-1.0-0:amd64 (1.50.12+ds-1) ...
#7 88.01 Selecting previously unselected package libpangoft2-1.0-0:amd64.
#7 88.02 Preparing to unpack .../45-libpangoft2-1.0-0_1.50.12+ds-1_amd64.deb ...
#7 88.02 Unpacking libpangoft2-1.0-0:amd64 (1.50.12+ds-1) ...
#7 88.04 Selecting previously unselected package libpangocairo-1.0-0:amd64.
#7 88.05 Preparing to unpack .../46-libpangocairo-1.0-0_1.50.12+ds-1_amd64.deb ...
#7 88.05 Unpacking libpangocairo-1.0-0:amd64 (1.50.12+ds-1) ...
#7 88.07 Selecting previously unselected package libpoppler126:amd64.
#7 88.08 Preparing to unpack .../47-libpoppler126_22.12.0-2+deb12u3_amd64.deb ...
#7 88.08 Unpacking libpoppler126:amd64 (22.12.0-2+deb12u3) ...
#7 88.16 Selecting previously unselected package libpoppler-glib8:amd64.
#7 88.16 Preparing to unpack .../48-libpoppler-glib8_22.12.0-2+deb12u3_amd64.deb ...
#7 88.17 Unpacking libpoppler-glib8:amd64 (22.12.0-2+deb12u3) ...
#7 88.19 Selecting previously unselected package libqpdf29:amd64.
#7 88.20 Preparing to unpack .../49-libqpdf29_11.3.0-1+deb12u1_amd64.deb ...
#7 88.20 Unpacking libqpdf29:amd64 (11.3.0-1+deb12u1) ...
#7 88.26 Selecting previously unselected package librsvg2-2:amd64.
#7 88.26 Preparing to unpack .../50-librsvg2-2_2.54.7+dfsg-1~deb12u1_amd64.deb ...
#7 88.26 Unpacking librsvg2-2:amd64 (2.54.7+dfsg-1~deb12u1) ...
#7 88.39 Selecting previously unselected package libvips42:amd64.
#7 88.39 Preparing to unpack .../51-libvips42_8.14.1-3+deb12u3_amd64.deb ...
#7 88.40 Unpacking libvips42:amd64 (8.14.1-3+deb12u3) ...
#7 88.46 Selecting previously unselected package libvips-tools.
#7 88.46 Preparing to unpack .../52-libvips-tools_8.14.1-3+deb12u3_amd64.deb ...
#7 88.47 Unpacking libvips-tools (8.14.1-3+deb12u3) ...
#7 88.49 Selecting previously unselected package qpdf.
#7 88.49 Preparing to unpack .../53-qpdf_11.3.0-1+deb12u1_amd64.deb ...
#7 88.49 Unpacking qpdf (11.3.0-1+deb12u1) ...
#7 88.53 Setting up media-types (10.0.0) ...
#7 88.55 Setting up libgsf-1-common (1.14.50-1+deb12u1) ...
#7 88.55 Setting up libgraphite2-3:amd64 (1.3.14-1+deb12u1) ...
#7 88.56 Setting up liblcms2-2:amd64 (2.14-2+deb12u1) ...
#7 88.57 Setting up libpixman-1-0:amd64 (0.42.2-1) ...
#7 88.58 Setting up libaom3:amd64 (3.6.0-1+deb12u3) ...
#7 88.58 Setting up libxau6:amd64 (1:1.0.9-1) ...
#7 88.59 Setting up imagemagick-6-common (8:6.9.11.60+dfsg-1.6+deb12u13) ...
#7 88.64 Setting up libkeyutils1:amd64 (1.6.3-2) ...
#7 88.65 Setting up libpsl5:amd64 (0.21.2-1) ...
#7 88.66 Setting up libcgif0:amd64 (0.3.0-1) ...
#7 88.67 Setting up libicu72:amd64 (72.1-3+deb12u1) ...
#7 88.67 Setting up liblerc4:amd64 (4.0.0+ds-2) ...
#7 88.69 Setting up libdatrie1:amd64 (0.2.13-2+b1) ...
#7 88.70 Setting up libglib2.0-0:amd64 (2.74.6-2+deb12u9) ...
#7 88.71 No schema files found: doing nothing.
#7 88.71 Setting up libtirpc-common (1.3.3+ds-1) ...
#7 88.72 Setting up libbrotli1:amd64 (1.0.9-2+b6) ...
#7 88.73 Setting up libsqlite3-0:amd64 (3.40.1-2+deb12u2) ...
#7 88.74 Setting up libgdk-pixbuf2.0-common (2.42.10+dfsg-1+deb12u4) ...
#7 88.75 Setting up libnghttp2-14:amd64 (1.52.0-1+deb12u3) ...
#7 88.76 Setting up libdeflate0:amd64 (1.14-1) ...
#7 88.76 Setting up libhwy1:amd64 (1.0.3-3+deb12u1) ...
#7 88.77 Setting up libgomp1:amd64 (12.2.0-14+deb12u1) ...
#7 88.78 Setting up libimath-3-1-29:amd64 (3.1.6-1) ...
#7 88.79 Setting up libjbig0:amd64 (2.1-6.1) ...
#7 88.80 Setting up libaec0:amd64 (1.0.6-1+b1) ...
#7 88.80 Setting up libkrb5support0:amd64 (1.20.1-2+deb12u5) ...
#7 88.81 Setting up libsasl2-modules-db:amd64 (2.1.28+dfsg-10) ...
#7 88.82 Setting up libjpeg62-turbo:amd64 (1:2.1.5-2) ...
#7 88.83 Setting up libx11-data (2:1.8.4-2+deb12u2) ...
#7 88.84 Setting up libnspr4:amd64 (2:4.35-1) ...
#7 88.84 Setting up librtmp1:amd64 (2.4+20151223.gitfa8646d.1-2+b2) ...
#7 88.85 Setting up libopenexr-3-1-30:amd64 (3.1.5-5) ...
#7 88.86 Setting up libfribidi0:amd64 (1.0.8-2.1) ...
#7 88.87 Setting up libexif12:amd64 (0.6.24-1+deb12u1) ...
#7 88.88 Setting up libimagequant0:amd64 (2.17.0-1) ...
#7 88.88 Setting up libpng16-16:amd64 (1.6.39-2+deb12u5) ...
#7 88.89 Setting up liborc-0.4-0:amd64 (1:0.4.33-2) ...
#7 88.90 Setting up fonts-dejavu-core (2.37-6) ...
#7 88.94 Setting up libjxl0.7:amd64 (0.7.0-10+deb12u1) ...
#7 88.95 Setting up libncursesw6:amd64 (6.4-4) ...
#7 88.95 Setting up libk5crypto3:amd64 (1.20.1-2+deb12u5) ...
#7 88.97 Setting up libdav1d6:amd64 (1.0.0-2+deb12u1) ...
#7 88.97 Setting up libltdl7:amd64 (2.4.7-7~deb12u1) ...
#7 88.98 Setting up libfftw3-double3:amd64 (3.3.10-1) ...
#7 88.99 Setting up libsasl2-2:amd64 (2.1.28+dfsg-10) ...
#7 89.00 Setting up libwebp7:amd64 (1.2.4-0.2+deb12u1) ...
#7 89.01 Setting up libnuma1:amd64 (2.0.16-1) ...
#7 89.01 Setting up liblqr-1-0:amd64 (0.4.2-2.1) ...
#7 89.02 Setting up libtiff6:amd64 (4.5.0-6+deb12u4) ...
#7 89.03 Setting up libopenjp2-7:amd64 (2.5.0-2+deb12u3) ...
#7 89.04 Setting up libthai-data (0.1.29-1) ...
#7 89.04 Setting up libssh2-1:amd64 (1.10.0-3+deb12u1) ...
#7 89.05 Setting up libkrb5-3:amd64 (1.20.1-2+deb12u5) ...
#7 89.06 Setting up libde265-0:amd64 (1.0.11-1+deb12u3) ...
#7 89.07 Setting up libwebpmux3:amd64 (1.2.4-0.2+deb12u1) ...
#7 89.08 Setting up libbsd0:amd64 (0.11.7-2) ...
#7 89.08 Setting up readline-common (8.2-1.3) ...
#7 89.09 Setting up libxml2:amd64 (2.9.14+dfsg-1.3~deb12u6) ...
#7 89.10 Setting up libsz2:amd64 (1.0.6-1+b1) ...
#7 89.11 Setting up libqpdf29:amd64 (11.3.0-1+deb12u1) ...
#7 89.12 Setting up libxdmcp6:amd64 (1:1.1.2-3) ...
#7 89.13 Setting up libxcb1:amd64 (1.15-1) ...
#7 89.13 Setting up libxcb-render0:amd64 (1.15-1) ...
#7 89.14 Setting up fontconfig-config (2.14.1-4) ...
#7 89.19 debconf: unable to initialize frontend: Dialog
#7 89.19 debconf: (TERM is not set, so the dialog frontend is not usable.)
#7 89.19 debconf: falling back to frontend: Readline
#7 ...

#20 [build 5/7] RUN pnpm build
#20 11.77    Generating static pages (1/7) 
#20 11.81    Generating static pages (3/7) 
#20 11.81    Generating static pages (5/7) 
#20 11.81  ✓ Generating static pages (7/7)
#20 12.22    Finalizing page optimization ...
#20 12.22    Collecting build traces ...
#20 ...

#7 [runtime  2/12] RUN apt-get update     && apt-get install -y --no-install-recommends qpdf libvips-tools util-linux     && rm -rf /var/lib/apt/lists/*     && groupadd --gid 10001 fiscalizacion     && useradd --uid 10001 --gid 10001 --no-create-home fiscalizacion     && mkdir -p /datos/archivos     && chown 10001:10001 /datos/archivos
#7 89.19 debconf: unable to initialize frontend: Readline
#7 89.19 debconf: (Can't locate Term/ReadLine.pm in @INC (you may need to install the Term::ReadLine module) (@INC contains: /etc/perl /usr/local/lib/x86_64-linux-gnu/perl/5.36.0 /usr/local/share/perl/5.36.0 /usr/lib/x86_64-linux-gnu/perl5/5.36 /usr/share/perl5 /usr/lib/x86_64-linux-gnu/perl-base /usr/lib/x86_64-linux-gnu/perl/5.36 /usr/share/perl/5.36 /usr/local/lib/site_perl) at /usr/share/perl5/Debconf/FrontEnd/Readline.pm line 7.)
#7 89.19 debconf: falling back to frontend: Teletype
#7 89.28 Setting up libwebpdemux2:amd64 (1.2.4-0.2+deb12u1) ...
#7 89.29 Setting up libreadline8:amd64 (8.2-1.3) ...
#7 89.30 Setting up libnss3:amd64 (2:3.87.1-1+deb12u4) ...
#7 89.31 Setting up libxcb-shm0:amd64 (1.15-1) ...
#7 89.31 Setting up libldap-2.5-0:amd64 (2.5.13+dfsg-5) ...
#7 89.32 Setting up libgsf-1-114:amd64 (1.14.50-1+deb12u1) ...
#7 89.33 Setting up libthai0:amd64 (0.1.29-1) ...
#7 89.34 Setting up libfreetype6:amd64 (2.12.1+dfsg-5+deb12u4) ...
#7 89.35 Setting up qpdf (11.3.0-1+deb12u1) ...
#7 89.38 Setting up shared-mime-info (2.2-1) ...
#7 ...

#20 [build 5/7] RUN pnpm build
#20 22.89 
#20 22.89 Route (app)                                 Size  First Load JS
#20 22.89 ┌ ○ /                                      134 B         103 kB
#20 22.89 ├ ○ /_not-found                            993 B         104 kB
#20 22.89 ├ ƒ /api/archivos/[id]                     134 B         103 kB
#20 22.89 ├ ƒ /api/documentos                        134 B         103 kB
#20 22.89 ├ ƒ /cuenta/clave                          169 B         106 kB
#20 22.89 ├ ƒ /legajos                               169 B         106 kB
#20 22.89 ├ ƒ /legajos/[id]                        4.71 kB         111 kB
#20 22.89 ├ ƒ /legajos/[id]/documentos/[docId]       169 B         106 kB
#20 22.89 ├ ƒ /legajos/nuevo                       2.13 kB         108 kB
#20 22.89 ├ ○ /login                                 828 B         103 kB
#20 22.89 └ ƒ /logout                                134 B         103 kB
#20 22.89 + First Load JS shared by all             103 kB
#20 22.89   ├ chunks/758-f4e03461beee14c0.js       46.3 kB
#20 22.89   ├ chunks/d36d6ee9-817a06892149dc1d.js  54.2 kB
#20 22.89   └ other shared chunks (total)          1.94 kB
#20 22.89 
#20 22.89 
#20 22.89 ƒ Middleware                             34.1 kB
#20 22.89 
#20 22.89 ○  (Static)   prerendered as static content
#20 22.89 ƒ  (Dynamic)  server-rendered on demand
#20 22.89 
#20 DONE 23.4s

#21 [build 6/7] RUN pnpm exec tsc --noEmit false --incremental false --outDir /compiled
#21 DONE 3.2s

#7 [runtime  2/12] RUN apt-get update     && apt-get install -y --no-install-recommends qpdf libvips-tools util-linux     && rm -rf /var/lib/apt/lists/*     && groupadd --gid 10001 fiscalizacion     && useradd --uid 10001 --gid 10001 --no-create-home fiscalizacion     && mkdir -p /datos/archivos     && chown 10001:10001 /datos/archivos
#7 91.24 Setting up libgssapi-krb5-2:amd64 (1.20.1-2+deb12u5) ...
#7 91.25 Setting up libx265-199:amd64 (3.5-2+b1) ...
#7 91.26 Setting up libcurl4:amd64 (7.88.1-10+deb12u15) ...
#7 91.27 Setting up libx11-6:amd64 (2:1.8.4-2+deb12u2) ...
#7 91.28 Setting up libharfbuzz0b:amd64 (6.0.0+dfsg-3) ...
#7 91.29 Setting up libgdk-pixbuf-2.0-0:amd64 (2.42.10+dfsg-1+deb12u4) ...
#7 91.31 Setting up libfontconfig1:amd64 (2.14.1-4) ...
#7 91.32 Setting up libtirpc3:amd64 (1.3.3+ds-1) ...
#7 91.32 Setting up fontconfig (2.14.1-4) ...
#7 91.33 Regenerating fonts cache... done.
#7 93.34 Setting up libxrender1:amd64 (1:0.9.10-1.1) ...
#7 93.35 Setting up libpango-1.0-0:amd64 (1.50.12+ds-1) ...
#7 93.36 Setting up libheif1:amd64 (1.15.1-1+deb12u1) ...
#7 93.42 Setting up libxext6:amd64 (2:1.3.4-1+b1) ...
#7 93.43 Setting up libcurl3-gnutls:amd64 (7.88.1-10+deb12u15) ...
#7 93.44 Setting up libcfitsio10:amd64 (4.2.0-3) ...
#7 93.45 Setting up libcairo2:amd64 (1.16.0-7) ...
#7 93.46 Setting up libmagickcore-6.q16-6:amd64 (8:6.9.11.60+dfsg-1.6+deb12u13) ...
#7 93.46 Setting up libpoppler126:amd64 (22.12.0-2+deb12u3) ...
#7 93.47 Setting up libhdf5-103-1:amd64 (1.10.8+repack1-1) ...
#7 93.49 Setting up libnsl2:amd64 (1.3.0-2) ...
#7 93.50 Setting up libcairo-gobject2:amd64 (1.16.0-7) ...
#7 93.50 Setting up libpangoft2-1.0-0:amd64 (1.50.12+ds-1) ...
#7 93.51 Setting up libopenslide0 (3.4.1+dfsg-6+deb12u1) ...
#7 93.53 Setting up libpangocairo-1.0-0:amd64 (1.50.12+ds-1) ...
#7 93.54 Setting up libpoppler-glib8:amd64 (22.12.0-2+deb12u3) ...
#7 93.55 Setting up libpython3.11-stdlib:amd64 (3.11.2-6+deb12u8) ...
#7 93.56 Setting up librsvg2-2:amd64 (2.54.7+dfsg-1~deb12u1) ...
#7 93.56 Setting up libmatio11:amd64 (1.5.23-2+deb12u1) ...
#7 93.57 Setting up libvips42:amd64 (8.14.1-3+deb12u3) ...
#7 93.58 Setting up libpython3-stdlib:amd64 (3.11.2-1+b1) ...
#7 93.59 Setting up python3.11 (3.11.2-6+deb12u8) ...
#7 93.96 Setting up python3 (3.11.2-1+b1) ...
#7 93.97 running python rtupdate hooks for python3.11...
#7 93.97 running python post-rtupdate hooks for python3.11...
#7 94.02 Setting up libvips-tools (8.14.1-3+deb12u3) ...
#7 ...

#22 [build 7/7] RUN node --input-type=module <<'JS'
#22 DONE 0.2s

#7 [runtime  2/12] RUN apt-get update     && apt-get install -y --no-install-recommends qpdf libvips-tools util-linux     && rm -rf /var/lib/apt/lists/*     && groupadd --gid 10001 fiscalizacion     && useradd --uid 10001 --gid 10001 --no-create-home fiscalizacion     && mkdir -p /datos/archivos     && chown 10001:10001 /datos/archivos
#7 94.02 Processing triggers for libc-bin (2.36-9+deb12u14) ...
#7 DONE 98.8s

#23 [runtime  3/12] WORKDIR /app
#23 DONE 2.2s

#24 [runtime  4/12] COPY --from=build --chown=10001:10001 /app/.next/standalone ./
#24 DONE 4.0s

#25 [production-dependencies 1/1] RUN pnpm prune --prod
#25 CACHED

#26 [runtime  5/12] COPY --from=production-dependencies /app/node_modules ./node_modules
#26 DONE 16.5s

#27 [runtime  6/12] COPY --from=build /app/.next/static ./.next/static
#27 DONE 6.8s

#28 [runtime  7/12] COPY --from=build /app/drizzle ./drizzle
#28 DONE 4.4s

#29 [runtime  8/12] COPY --from=build /compiled/src/server ./src/server
#29 DONE 2.5s

#30 [runtime  9/12] COPY --from=build /compiled/src/package.json ./src/package.json
#30 DONE 3.0s

#31 [runtime 10/12] COPY --from=build /compiled/scripts ./scripts
#31 DONE 2.0s

#32 [runtime 11/12] COPY --from=build /compiled/migrar.js ./migrar.js
#32 DONE 2.1s

#33 [runtime 12/12] COPY --chmod=755 scripts/entrypoint.sh ./scripts/entrypoint.sh
#33 DONE 2.1s

#34 exporting to image
#34 exporting layers
#34 exporting layers 7.3s done
#34 writing image sha256:5333f827a8cc9c766539f11a5e5e9a96c180eb674ec58cfebe735fdceaa6c867 0.0s done
#34 naming to docker.io/library/fiscalizacion:prueba 0.1s done
#34 DONE 7.6s

```

## Herramientas y usuario dentro de la imagen

Comando: `docker run --rm --entrypoint sh fiscalizacion:prueba -c 'qpdf --version && vips --version && prlimit --version && id -u && test -w .next && echo ".next escribible por el usuario de servicio"'`. Código de salida 0:

```text
qpdf version 11.3.0
Run qpdf --copyright to see copyright and license information.
vips-8.14.1
prlimit from util-linux 2.38.1
10001
.next escribible por el usuario de servicio

```

## Fixtures dentro de la imagen

Comando: `bash scripts/validar-imagen.sh fiscalizacion:prueba`. Copia los fixtures al contenedor y ejecuta detectarTipo/validarArchivo reales, con VALIDACION_MEMORIA_BYTES=536870912. Se repitió sobre el digest final; código de salida 0:

```text
cifrado-sin-clave.pdf: rechazado
cifrado.pdf: rechazado
falso.pdf: rechazado
texto.txt: rechazado
truncado.jpg: rechazado
truncado.pdf: rechazado
truncado.png: rechazado
valido.jpg: válido {"mime":"image/jpeg","ancho":64,"alto":48}
valido.pdf: válido {"mime":"application/pdf","paginas":1}
valido.png: válido {"mime":"image/png","ancho":64,"alto":48}
10 fixtures comprobados; qpdf/vips bajo prlimit --as=536870912.

```

## Prueba runtime con PostgreSQL 16 y límites de producción

Harness Python local: crea red efímera, inicializa postgres:16-alpine con deploy/initdb/01-roles.sh y claves aleatorias no expuestas, arranca la imagen final con 700 MiB y 1 CPU, espera healthy, comprueba login y /proc/1/limits, ejecuta dos CLI administrativos concurrentes y consulta la base. Retira todos sus contenedores y la red. Código de salida 0:

```text
postgres:16-alpine: initdb correcto, 256 MiB, sin puertos publicados.
Imagen final: healthy, login 200, 700 MiB, 1 CPU, core dumps deshabilitados para PID 1.
Dos admin-crear concurrentes: un alta y un rechazo; una sola clave emitida (contenido omitido).
Admin único, cambio obligatorio, red normalizada y auditoría en la base: 1|t|t|t
Recursos efímeros de imagen final retirados.

```

La prueba anterior de los mismos cambios de aplicación comprobó además assets, redirecciones, cookie y rechazos de CLI. Salida real, código de salida 0:

```text
initdb: fiscalizacion creada con legajos_owner y legajos_app.
app: healthy con 700 MiB y 1 CPU; UID=10001
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
   ▲ Next.js 15.5.27
   - Local:        http://localhost:3000
   - Network:      http://0.0.0.0:3000

 ✓ Starting...
 ✓ Ready in 112ms
GET /fiscalizacion/login: 200; assets con basePath; sin X-Powered-By.
GET /fiscalizacion/legajos sin cookie: 307 a /fiscalizacion/login.
POST logout: 303 a APP_ORIGIN/fiscalizacion/login; cookie Path=/fiscalizacion, Secure, HttpOnly.
admin-crear: una sola clave temporal (contenido omitido), IPv4-mapped /120 normalizada a IPv4 /24.
admin|admin|t|192.168.5.0/24|login_admin|f
Segundo admin: rechazado, sin clave en stdout.
CLI con rol app: rechazado, sin clave en stdout.
CLI con IP octal: rechazada, sin clave en stdout.
Contenedores y red de la prueba runtime retirados.

```

## Matcher, Compose y comprobaciones estáticas

Harness Node con NextURL y getMiddlewareMatchers del Next instalado; código de salida 0:

```text
pathname=/legajos; basePath=/fiscalizacion
redirect=https://192.168.5.104/fiscalizacion/login
matcher: legajos incluido; _next/static y favicon excluidos.

```

Compose resuelto con `docker compose --env-file deploy/.env.example -f deploy/compose.prod.yml config --no-env-resolution --format json`, TAG=prueba; aserciones de imagen, puertos, memoria y dependencia. Código de salida 0:

```text
{'app': {'image': 'fiscalizacion:prueba', 'ports': [{'mode': 'ingress', 'host_ip': '127.0.0.1', 'target': 3000, 'published': '3000', 'protocol': 'tcp'}], 'mem_limit': '734003200', 'depends_on': {'db': {'condition': 'service_healthy', 'required': True}}}, 'db': {'image': 'postgres:16-alpine', 'ports': None, 'mem_limit': '268435456', 'depends_on': None}}
compose válido: db postgres:16-alpine sin puertos, 256 MiB; app loopback, 700 MiB, dependencia healthy.
```

Comandos `git diff --check`, `bash -n scripts/deploy.sh scripts/validar-imagen.sh` y `sh -n scripts/entrypoint.sh deploy/initdb/01-roles.sh`: código 0, sin salida.

Búsqueda equivalente a la pedida en la spec; todos los matches están dentro de conBase:

```text
src/app/(app)/legajos/[id]/documentos/[docId]/page.tsx:44:          ? <iframe className="visor" src={conBase(`/api/archivos/${archivo.id}`)}
src/app/(app)/legajos/[id]/documentos/[docId]/page.tsx:49:              src={conBase(`/api/archivos/${archivo.id}`)} alt={`Vista de ${archivo.nombreOriginal}`} />
src/app/(app)/legajos/[id]/documentos/[docId]/page.tsx:51:        <p><a href={conBase(`/api/archivos/${archivo.id}?descargar=1`)}>Descargar</a></p>
src/app/(app)/legajos/[id]/page.tsx:173:                <a href={conBase(`/api/archivos/${archivo.id}`)} target="_blank" rel="noopener noreferrer">
src/app/(app)/legajos/[id]/page.tsx:177:                <a href={conBase(`/api/archivos/${archivo.id}?descargar=1`)}>Descargar</a>
src/app/(app)/legajos/[id]/componentes/SubirDocumento.tsx:83:    peticion.open('POST', conBase('/api/documentos'));
```

## Incidencias durante la verificación

Primera ejecución sin redirigir el estado de pnpm: código 1, antes de correr el lint:

```text
[ERROR] unable to open database file
For help, run: pnpm help run
```

Con XDG dentro del repo, la base local preexistente tenía correlativos consumidos. La corrida falló en tres tests; se repitió sobre una base efímera vacía y pasó, sin cambiar código fuera del alcance ni resetear la base compartida. Salida real del intento con datos previos, código 1:

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
 ✓ test/login.test.ts (14 tests) 3631ms
   ✓ Login y cambio de clave con Postgres real como legajos_app > cinco fallos bloquean; la clave correcta no pasa hasta +16 minutos  380ms
   ✓ Login y cambio de clave con Postgres real como legajos_app > inexistente usa señuelo, con mediana de cinco muestras a menos del 30%  445ms
   ✓ Login y cambio de clave con Postgres real como legajos_app > 20 fallos por IP, el 21 no verifica ni modifica cuenta; ventana vencida reinicia  929ms
   ✓ Login y cambio de clave con Postgres real como legajos_app > 25 concurrentes desde una IP: sólo 20 verifican argon2  888ms
 ✓ test/logout-y-cli.test.ts (12 tests) 2859ms
   ✓ Logout y recuperación administrativa > CLI imprime una clave de 16 caracteres una vez, agrega IPv6 y cierra todas las sesiones  525ms
   ✓ Logout y recuperación administrativa > CLI normaliza IPv4-mapped y agrega /32  349ms
   ✓ Logout y recuperación administrativa > CLI rechaza usuario no admin, sin modificaciones ni clave en stdout  343ms
   ✓ Logout y recuperación administrativa > CLI rechaza legajos online y acepta la aplicación detenida  749ms
   ✓ Logout y recuperación administrativa > CLI falla si el lock está ocupado  344ms
 ✓ test/documentos.test.ts (43 tests) 1184ms
 ✓ test/admin.test.ts (18 tests) 1079ms
   ✓ Administración contra Postgres real como legajos_app > dos admins que se desactivan mutuamente en paralelo dejan al menos uno activo  376ms
 ✓ test/archivos-validar.test.ts (15 tests) 718ms
 ✓ test/acciones.test.ts (24 tests) 516ms
 ✓ test/rutas-documentos.test.ts (16 tests) 403ms
 ❯ test/legajos.test.ts (17 tests | 3 failed) 346ms
   ✓ Legajos contra Postgres real como legajos_app > usa el rol app sin heredar owner 2ms
   × Legajos contra Postgres real como legajos_app > dos legajos empiezan en AAAA-0001 y AAAA-0002 25ms
     → expected [ '2090-0003', '2090-0004' ] to deeply equal [ '2090-0001', '2090-0002' ]
   × Legajos contra Postgres real como legajos_app > 10 altas concurrentes reservan correlativos 1..10 sin repetidos 88ms
     → expected [ Array(10) ] to deeply equal [ 1, 2, 3, 4, 5, 6, 7, 8, 9, 10 ]
   × Legajos contra Postgres real como legajos_app > el primer legajo del año siguiente vuelve al correlativo 1 8ms
     → expected '2092-0002' to be '2092-0001' // Object.is equality
   ✓ Legajos contra Postgres real como legajos_app > usa el año de Asunción aunque el instante en UTC ya sea 2027 12ms
   ✓ Legajos contra Postgres real como legajos_app > rechaza sin cédulas y con dos originales antes de escribir 3ms
   ✓ Legajos contra Postgres real como legajos_app > audita el legajo y todas sus cédulas y devuelve UUIDv7 y fechas ISO 9ms
   ✓ Legajos contra Postgres real como legajos_app > relaciona sin duplicar y sólo por números de cédulas vivas 37ms
   ✓ Legajos contra Postgres real como legajos_app > encuentra José buscando jose, por prefijo y con filtros combinados AND 19ms
   ✓ Legajos contra Postgres real como legajos_app > trata % como literal en la búsqueda 16ms
   ✓ Legajos contra Postgres real como legajos_app > trata _ como literal en la búsqueda 17ms
   ✓ Legajos contra Postgres real como legajos_app > trata \ como literal en la búsqueda 15ms
   ✓ Legajos contra Postgres real como legajos_app > pagina con total exacto, sin duplicados y de más nuevo a más antiguo 25ms
   ✓ Legajos contra Postgres real como legajos_app > audita vistas y consultas incluso sin resultados 12ms
   ✓ Legajos contra Postgres real como legajos_app > consulta no crea ni edita; el guard entrega el contexto sin elevar permisos 5ms
   ✓ Legajos contra Postgres real como legajos_app > editarLegajo preserva estado y campos omitidos; el grant bloquea cambios de estado 12ms
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

 ✓ test/cedulas.test.ts (14 tests) 247ms
 ✓ test/interacciones.test.ts (12 tests) 244ms
 ✓ test/archivos-almacen.test.ts (19 tests) 156ms
 ✓ test/auth-guard.test.ts (40 tests) 153ms
 ✓ test/schema.test.ts (53 tests) 126ms
 ✓ test/triggers.test.ts (21 tests) 111ms
 ✓ test/guard-cobertura.test.ts (12 tests) 41ms
 ✓ test/permisos.test.ts (29 tests) 39ms
 ✓ test/humo.test.ts (3 tests) 20ms
 ✓ test/ip.test.ts (24 tests) 8ms
 ✓ test/permisos.unit.test.ts (48 tests) 4ms

⎯⎯⎯⎯⎯⎯⎯ Failed Tests 3 ⎯⎯⎯⎯⎯⎯⎯

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

⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯[1/3]⎯

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

⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯[2/3]⎯

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

⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯[3/3]⎯


 Test Files  1 failed | 18 passed (19)
      Tests  3 failed | 431 passed (434)
   Start at  10:22:59
   Duration  20.08s (transform 342ms, setup 0ms, collect 3.85s, tests 11.89s, environment 2ms, prepare 716ms)

 ELIFECYCLE  Test failed. See above for more details.
 ELIFECYCLE  Command failed with exit code 1.

```

El primer docker build intentó actualizar el estado de buildx fuera del área escribible. Se corrigió usando DOCKER_CONFIG dentro de node_modules/.cache. Salida real, código 1:

```text
ERROR: failed to build: failed to update builder last activity time: open /home/ecenturion/.docker/buildx/activity/.tmp-default2259834241: read-only file system
```

Primer chequeo de fixtures de Bookworm antes de G_DEBUG; código 1:

```text
cifrado-sin-clave.pdf: rechazado
cifrado.pdf: rechazado
falso.pdf: rechazado
texto.txt: rechazado
node:internal/modules/run_main:123
    triggerUncaughtException(
    ^

AssertionError [ERR_ASSERTION]: truncado.jpg debió ser rechazado
    at file:///app/[eval1]:20:10 {
  generatedMessage: false,
  code: 'ERR_ASSERTION',
  actual: false,
  expected: true,
  operator: '==',
  diff: 'simple'
}

Node.js v22.23.3

```

El harness runtime tuvo dos intentos fallidos al comprobar core dumps: primero consultaba el shell de docker exec, que no hereda el límite de PID 1, y después se estaba probando el tag sobrescrito por la construcción anterior. Se corrigió el chequeo a /proc/1/limits y se fijó el digest final. La prueba final pegada arriba pasó; no se cambió el validador ni se ocultó el fallo inicial de vips.

## Lo no ejecutado y límites

- No se conectó al servidor 192.168.5.104, no se desplegó, no se tocó Apache/SSL/firewall reales ni se creó el admin de producción. Eso queda para el arquitecto.
- Se entregó y revisó la guía de backup/restauración; no se ejecutó una restauración de datos reales ni la herramienta archivos-huerfanos, que aún pertenece al trabajo L11.
- El build local advierte que detecta un lockfile superior en /home/ecenturion. La imagen construye en /app sin esa advertencia. No se tocó ese lockfile ni se cambiaron opciones ajenas a lo pedido.
- El migrador existente emite advertencias de revocación sobre funciones de extensiones al inicializar con owner; su salida real está incluida. Las migraciones terminaron y la app quedó healthy. No se modificaron migraciones, schema ni grants fuera del alcance.
- Sin commit, push, cambios de roles/spec ni movimiento de la tarea a done/.
