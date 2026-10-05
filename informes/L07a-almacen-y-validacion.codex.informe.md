# Informe — L07a-almacen-y-validacion

**Estado:** COMPLETADO
**Implementador:** codex · sombrero B
**Verificación:** `pnpm sistema:check && pnpm verificar` terminó con código 0.

## Archivos creados

- `src/server/archivos/rutas.ts`
- `src/server/archivos/validar.ts`
- `src/server/archivos/recibir.ts`
- `src/server/archivos/publicar.ts`
- `scripts/generar-fixtures.sh` (ejecutable)
- `test/archivos-validar.test.ts`
- `test/archivos-almacen.test.ts`
- `test/fixtures/archivos/valido.pdf`
- `test/fixtures/archivos/valido.jpg`
- `test/fixtures/archivos/valido.png`
- `test/fixtures/archivos/cifrado.pdf`
- `test/fixtures/archivos/falso.pdf`
- `test/fixtures/archivos/truncado.pdf`
- `test/fixtures/archivos/truncado.jpg`
- `test/fixtures/archivos/truncado.png`
- `test/fixtures/archivos/texto.txt`
- Este informe, en `legajos-agents/informes/L07a-almacen-y-validacion.codex.informe.md`.

## Archivos modificados

- `package.json`: exclusivamente las dependencias solicitadas, con versiones exactas.
- `pnpm-lock.yaml`: resolución de esas dependencias.
- `src/server/errores.ts`: exclusivamente la clase `ErrorArchivoGrande`, con status 413.

## Implementación y decisiones

- Rutas finales con UUIDv7 generado por el servidor. Validación de identificadores y extensiones; contención mediante `path.relative`, `realpath` y rechazo de symlinks mediante `lstat` en cada componente.
- Directorios creados por componentes con `mkdir({ recursive: true, mode: 0o700 })`; cada padre se comprueba antes de crear el siguiente para evitar escribir a través de un symlink.
- Publicación con `link`, sin sobrescritura, y fsync del directorio. El temporal se conserva; `descartarFinal` permite rollback explícito.
- Tipo detectado con `file-type`, por contenido. Validación exclusivamente con `execFile`, sin shell, bajo `prlimit --as=536870912 --cpu=20 --`; timeout de reloj de 20 segundos y SIGKILL.
- Se respeta el orden de las tres operaciones PDF y el código 2 de `qpdf --is-encrypted` para archivos sin cifrar. Las imágenes se decodifican con el único argumento `<tmp>[fail_on=error]`.
- **Puerta §13.3 verificada con 512 MiB:** JPEG y PNG válidos aceptados y truncados rechazados con prlimit real. Se mantiene el valor por defecto 536870912; no fue necesario subirlo a 1 GiB. `VALIDACION_MEMORIA_BYTES` permite configurarlo.
- Recepción de multipart en streaming con contador del total, límites Busboy, SHA256 y temporales UUIDv7 abiertos con `wx` y modo 0600. Se usa `flush: true` de Node 22 para fsync antes del cierre; `pipeline` espera la finalización.
- Al abortar se desconectan los pipes, se destruyen las escrituras, se espera cada close y luego se eliminan los temporales creados por esta carga. La destrucción del parser se difiere a una microtarea para evitar reentrar en Busboy desde sus callbacks de límite.
- Se conserva el primer error de la carga. Ante una colisión de nombre y EEXIST, la limpieza no elimina un temporal perteneciente a otra carga; esto tiene un test con filesystem real.
- Los nombres originales se conservan únicamente como metadatos: sin caracteres de control y con máximo de 255 caracteres. Los campos usan un objeto sin prototipo.
- Fixtures pequeños generados con Python estándar, vips y qpdf; no se incorporaron sharp ni pdf-lib. Los nueve binarios/textos generados quedan en el árbol para su posterior commit por el arquitecto.
- 33 tests nuevos: 14 de validación y 19 de almacenamiento. Incluyen timeout con un proceso sleep real y comprobación ESRCH después del rechazo, señal del hijo, límites de archivos/campos/partes/total, interrupción de entrada, multipart incompleto, symlinks y conservación de temporales ajenos.

## Incidencias resueltas y límites

- Inicialmente pnpm falló con `[ERROR] unable to open database file` porque intentaba usar una caché fuera de las carpetas autorizadas. Se redirigieron XDG_CACHE_HOME y XDG_DATA_HOME dentro de `legajos/node_modules`, sin modificar configuración global.
- Para instalar se indicó además `--store-dir "$PWD/node_modules/.pnpm-store"`, que coincide con el almacén existente. Se instalaron `busboy@1.6.0`, `file-type@22.1.1` y `@types/busboy@1.5.4`.
- La primera corrida dirigida encontró un error de tipado en la captura del PID de un test y una cabecera de fixture multipart inválida. Se corrigieron; el nombre con controles se envía usando filename* con codificación porcentual, aceptada por Busboy.
- El build emitió una advertencia por múltiples lockfiles y selección de la raíz del workspace. No impidió compilar ni cambió el alcance.
- No quedó trabajo pendiente de esta spec. No se hicieron commit, push, deploy ni cambios en servicios o rutas Next. No se movió la tarea.
- `legajos-agents/estado.jsonl` aparece modificado en el estado del repo hermano; este implementador no lo editó.
- `git diff --check` terminó con código 0 y sin salida. Los tests eliminan sus directorios temporales dentro de `test/fixtures/archivos`.

## Comando de verificación y salida real

Ejecutado desde `/home/ecenturion/develop/legajos`, usando caché local para respetar los permisos:

```bash
export XDG_CACHE_HOME="$PWD/node_modules/.cache" XDG_DATA_HOME="$PWD/node_modules/.data"
pnpm sistema:check && pnpm verificar
```

Salida completa de la corrida final, sin resumir:

```text
$ bash scripts/chequear-sistema.sh
Dependencias del sistema: ok (qpdf, vips, vipsheader, prlimit).
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
 ✓ test/interacciones.test.ts (12 tests) 258ms
 ✓ test/login.test.ts (14 tests) 3858ms
   ✓ Login y cambio de clave con Postgres real como legajos_app > cinco fallos bloquean; la clave correcta no pasa hasta +16 minutos  427ms
   ✓ Login y cambio de clave con Postgres real como legajos_app > inexistente usa señuelo, con mediana de cinco muestras a menos del 30%  476ms
   ✓ Login y cambio de clave con Postgres real como legajos_app > 20 fallos por IP, el 21 no verifica ni modifica cuenta; ventana vencida reinicia  997ms
   ✓ Login y cambio de clave con Postgres real como legajos_app > 25 concurrentes desde una IP: sólo 20 verifican argon2  926ms
 ✓ test/logout-y-cli.test.ts (12 tests) 2967ms
   ✓ Logout y recuperación administrativa > CLI imprime una clave de 16 caracteres una vez, agrega IPv6 y cierra todas las sesiones  536ms
   ✓ Logout y recuperación administrativa > CLI normaliza IPv4-mapped y agrega /32  363ms
   ✓ Logout y recuperación administrativa > CLI rechaza usuario no admin, sin modificaciones ni clave en stdout  359ms
   ✓ Logout y recuperación administrativa > CLI rechaza legajos online y acepta la aplicación detenida  787ms
   ✓ Logout y recuperación administrativa > CLI falla si el lock está ocupado  357ms
 ✓ test/archivos-validar.test.ts (14 tests) 707ms
 ✓ test/legajos.test.ts (17 tests) 320ms
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

 ✓ test/cedulas.test.ts (14 tests) 246ms
 ✓ test/archivos-almacen.test.ts (19 tests) 161ms
 ✓ test/auth-guard.test.ts (40 tests) 156ms
 ✓ test/schema.test.ts (53 tests) 131ms
 ✓ test/triggers.test.ts (21 tests) 114ms
 ✓ test/permisos.test.ts (29 tests) 40ms
 ✓ test/humo.test.ts (3 tests) 23ms
 ✓ test/ip.test.ts (24 tests) 7ms
 ✓ test/permisos.unit.test.ts (48 tests) 4ms

 Test Files  14 passed (14)
      Tests  320 passed (320)
   Start at  07:46:19
   Duration  14.67s (transform 228ms, setup 0ms, collect 2.14s, tests 8.99s, environment 2ms, prepare 549ms)

$ next build
 ⚠ Warning: Next.js inferred your workspace root, but it may not be correct.
 We detected multiple lockfiles and selected the directory of /home/ecenturion/pnpm-lock.yaml as the root directory.
 To silence this warning, set `outputFileTracingRoot` in your Next.js config, or consider removing one of the lockfiles if it's not needed.
   See https://nextjs.org/docs/app/api-reference/config/next-config-js/output#caveats for more information.
 Detected additional lockfiles: 
   * /home/ecenturion/develop/legajos/pnpm-lock.yaml

   ▲ Next.js 15.5.27

   Creating an optimized production build ...
 ✓ Compiled successfully in 2.3s
   Linting and checking validity of types ...
   Collecting page data ...
   Generating static pages (0/6) ...
   Generating static pages (1/6) 
   Generating static pages (2/6) 
   Generating static pages (4/6) 
 ✓ Generating static pages (6/6)
   Finalizing page optimization ...
   Collecting build traces ...

Route (app)                                 Size  First Load JS
┌ ○ /                                      139 B         103 kB
├ ○ /_not-found                            996 B         104 kB
├ ƒ /cuenta/clave                          139 B         103 kB
├ ƒ /legajos                               139 B         103 kB
├ ○ /login                                 688 B         104 kB
└ ƒ /logout                                139 B         103 kB
+ First Load JS shared by all             103 kB
  ├ chunks/758-942e49721ce48ac0.js       46.5 kB
  ├ chunks/d36d6ee9-817a06892149dc1d.js  54.4 kB
  └ other shared chunks (total)          1.87 kB


ƒ Middleware                             34.1 kB

○  (Static)   prerendered as static content
ƒ  (Dynamic)  server-rendered on demand

```

**Código de salida:** 0.

