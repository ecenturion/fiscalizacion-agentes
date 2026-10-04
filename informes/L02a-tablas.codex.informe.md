# Informe — L02a-tablas

**Estado:** COMPLETADO
**Implementador:** CODEX · sombrero B
**Fecha:** 2026-10-04

## Archivos creados y modificados

Modificados en `legajos/`:
- `src/server/db/schema.ts`: se conservó el schema previo y se agregó `NOT NULL` a `legajo.numero` y `tipo_documento.vigencia_dias`.
- `drizzle/meta/_journal.json`: entrada de la migración 0001.

Creados en `legajos/`:
- `drizzle/0001_safe_fabian_cortez.sql`: 16 tablas, checks, únicos, índices y 26 FK con `ON DELETE RESTRICT`; al final, extensiones, wrapper e índice trigram.
- `drizzle/meta/0001_snapshot.json`: snapshot de las tablas.
- `test/schema.test.ts`: 52 casos contra PostgreSQL 16 real como `legajos_owner`, cada caso en su propia transacción con rollback.

Creado en `legajos-agents/`:
- `informes/L02a-tablas.codex.informe.md` (este informe).

## Decisiones

- Se partió del schema que dejó AGY y se aplicaron cambios parciales. La migración y el snapshot 0000 quedaron intactos.
- Se aplicó literalmente la lista de nulabilidad de §9.1, que prevalece sobre §2: `vigencia_dias` no figura entre las excepciones y queda `NOT NULL`. Se mantuvo el check pedido `vigencia_dias IS NULL OR vigencia_dias > 0`. Los fixtures usan 365 días. La prueba de nulabilidad detectó esta omisión del intento previo.
- Drizzle emitió la columna generada con la expresión de §9.2, los índices por `lower(nombre)` y el índice único parcial del original. No hizo falta agregarlos manualmente.
- `pg_trgm` y `unaccent` se instalaron en `legajos`; el índice GIN usa `legajos.f_unaccent(nombres || ' ' || apellidos)` y `legajos.gin_trgm_ops`. El wrapper es `IMMUTABLE`, `STRICT`, `PARALLEL SAFE`, con referencias calificadas y search_path fijo; no es `SECURITY DEFINER`. Se documentó que cambiar el diccionario exige reconstruir el índice. Referencias consultadas: [unaccent de PostgreSQL 16](https://www.postgresql.org/docs/16/unaccent.html) y [pg_trgm de PostgreSQL 16](https://www.postgresql.org/docs/16/pgtrgm.html).
- La migración 0001 se generó inicialmente con el pnpm 11.0.0 ya instalado, invocado mediante Node. Después del primer test se corrigió parcialmente el NOT NULL de vigencia en schema, SQL 0001 y snapshot, manteniendo toda la tarea en 0001.
- Los tests cubren los nueve criterios, las seis combinaciones de anulación parcial en cada una de las tres tablas anulables, motivos vacíos, anulación completa, los tres catálogos, path único, los tres MIME permitidos, nulabilidad, UUID sin defaults, FK restrictivas y extensiones/índice trigram. Los rechazos usan `.rejects.toMatchObject({ code })`.
- El pnpm global es 11.22.0 y fallaba antes de ejecutar los scripts al intentar abrir el store fuera del repo para cambiar de versión o reinstalar dependencias. La corrida final usa `PNPM_CONFIG_PM_ON_FAIL=ignore` y `PNPM_CONFIG_VERIFY_DEPS_BEFORE_RUN=false` sólo como variables de entorno, con las dependencias existentes. No se modificaron configuración ni dependencias.
- Tras corregir la migración 0001 se recreó únicamente el contenedor local de pruebas, cuyo almacenamiento es tmpfs, mediante `docker compose -f compose.test.yml down && docker compose -f compose.test.yml up -d --wait`. Así la verificación final aplicó las migraciones desde una base limpia.

## Verificación final — salida real completa

Comando, desde `/home/ecenturion/develop/legajos`:

```sh
PNPM_CONFIG_PM_ON_FAIL=ignore PNPM_CONFIG_VERIFY_DEPS_BEFORE_RUN=false pnpm verificar && PNPM_CONFIG_PM_ON_FAIL=ignore PNPM_CONFIG_VERIFY_DEPS_BEFORE_RUN=false pnpm db:generate
```

Código de salida: **0**.

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
Migraciones aplicadas
 ✓ test/schema.test.ts (52 tests) 121ms
 ✓ test/humo.test.ts (3 tests) 22ms

 Test Files  2 passed (2)
      Tests  55 passed (55)
   Start at  15:26:32
   Duration  1.29s (transform 35ms, setup 0ms, collect 40ms, tests 143ms, environment 0ms, prepare 76ms)

$ next build
 ⚠ Warning: Next.js inferred your workspace root, but it may not be correct.
 We detected multiple lockfiles and selected the directory of /home/ecenturion/pnpm-lock.yaml as the root directory.
 To silence this warning, set `outputFileTracingRoot` in your Next.js config, or consider removing one of the lockfiles if it's not needed.
   See https://nextjs.org/docs/app/api-reference/config/next-config-js/output#caveats for more information.
 Detected additional lockfiles: 
   * /home/ecenturion/develop/legajos/pnpm-lock.yaml

   ▲ Next.js 15.5.27

   Creating an optimized production build ...
 ✓ Compiled successfully in 770ms
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

## Primera corrida de verificación — salida real

Mismo comando de verificación con las variables de entorno anteriores. Código de salida: **1**. Falló la nulabilidad de `tipo_documento.vigencia_dias`; se corrigió antes de la corrida final.

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
Migraciones aplicadas
 ❯ test/schema.test.ts (52 tests | 1 failed) 127ms
   ✓ Tablas y constraints de legajos (legajos_owner) > conecta como legajos_owner 17ms
   ✓ Tablas y constraints de legajos (legajos_owner) > genera 2026-0001 y conserva los cinco dígitos de 2026-12345 2ms
   ✓ Tablas y constraints de legajos (legajos_owner) > rechaza un (anio, correlativo) duplicado 7ms
   ✓ Tablas y constraints de legajos (legajos_owner) > rechaza dos cédulas originales vivas del mismo legajo 3ms
   ✓ Tablas y constraints de legajos (legajos_owner) > permite otra original cuando la anterior está anulada 3ms
   ✓ Tablas y constraints de legajos (legajos_owner) > rechaza el número de cédula 12a 2ms
   ✓ Tablas y constraints de legajos (legajos_owner) > Anulación de cedula > rechaza la combinación parcial (true, false, false) 3ms
   ✓ Tablas y constraints de legajos (legajos_owner) > Anulación de cedula > rechaza la combinación parcial (false, true, false) 2ms
   ✓ Tablas y constraints de legajos (legajos_owner) > Anulación de cedula > rechaza la combinación parcial (false, false, true) 2ms
   ✓ Tablas y constraints de legajos (legajos_owner) > Anulación de cedula > rechaza la combinación parcial (true, true, false) 2ms
   ✓ Tablas y constraints de legajos (legajos_owner) > Anulación de cedula > rechaza la combinación parcial (true, false, true) 2ms
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
   ✓ Tablas y constraints de legajos (legajos_owner) > Anulación de interaccion > rechaza la combinación parcial (false, true, true) 2ms
   ✓ Tablas y constraints de legajos (legajos_owner) > Anulación de interaccion > rechaza un motivo con sólo espacios 2ms
   ✓ Tablas y constraints de legajos (legajos_owner) > Anulación de interaccion > acepta las tres columnas completas 2ms
   ✓ Tablas y constraints de legajos (legajos_owner) > rechaza la nota vacía "" 3ms
   ✓ Tablas y constraints de legajos (legajos_owner) > rechaza la nota vacía "  " 2ms
   ✓ Tablas y constraints de legajos (legajos_owner) > rechaza sólo estado_nuevo_id 1ms
   ✓ Tablas y constraints de legajos (legajos_owner) > rechaza sólo estado_anterior_id 2ms
   ✓ Tablas y constraints de legajos (legajos_owner) > rechaza ambos estados iguales 1ms
   ✓ Tablas y constraints de legajos (legajos_owner) > acepta ambos estados nulos 1ms
   ✓ Tablas y constraints de legajos (legajos_owner) > acepta ambos estados distintos 1ms
   ✓ Tablas y constraints de legajos (legajos_owner) > rechaza vigencia_dias = 0 2ms
   ✓ Tablas y constraints de legajos (legajos_owner) > rechaza Nota y nota en estado_legajo 2ms
   ✓ Tablas y constraints de legajos (legajos_owner) > rechaza Nota y nota en tipo_interaccion 2ms
   ✓ Tablas y constraints de legajos (legajos_owner) > rechaza Nota y nota en tipo_documento 2ms
   ✓ Tablas y constraints de legajos (legajos_owner) > rechaza archivos image/gif 2ms
   ✓ Tablas y constraints de legajos (legajos_owner) > rechaza el orden repetido en un documento 2ms
   ✓ Tablas y constraints de legajos (legajos_owner) > rechaza un path_relativo repetido aunque cambie el orden 2ms
   ✓ Tablas y constraints de legajos (legajos_owner) > acepta un archivo application/pdf 2ms
   ✓ Tablas y constraints de legajos (legajos_owner) > acepta un archivo image/jpeg 1ms
   ✓ Tablas y constraints de legajos (legajos_owner) > acepta un archivo image/png 1ms
   ✓ Tablas y constraints de legajos (legajos_owner) > rechaza dos versiones que apuntan al mismo documento 2ms
   ✓ Tablas y constraints de legajos (legajos_owner) > acepta ip nula para un acceso con resultado ip_invalida 2ms
   ✓ Tablas y constraints de legajos (legajos_owner) > todas las FK aplican ON DELETE RESTRICT 2ms
   × Tablas y constraints de legajos (legajos_owner) > los UUID no tienen DEFAULT y la nulabilidad coincide con §9.1 9ms
     → tipo_documento.vigencia_dias: expected 'YES' to be 'NO' // Object.is equality
   ✓ Tablas y constraints de legajos (legajos_owner) > las extensiones y el índice trigram usan el esquema legajos 3ms
 ✓ test/humo.test.ts (3 tests) 22ms

⎯⎯⎯⎯⎯⎯⎯ Failed Tests 1 ⎯⎯⎯⎯⎯⎯⎯

 FAIL  test/schema.test.ts > Tablas y constraints de legajos (legajos_owner) > los UUID no tienen DEFAULT y la nulabilidad coincide con §9.1
AssertionError: tipo_documento.vigencia_dias: expected 'YES' to be 'NO' // Object.is equality

Expected: "NO"
Received: "YES"

 ❯ test/schema.test.ts:294:40
    292|         || nombre === 'cedula.fecha_emision' || nombre === 'acceso_log…
    293|         || nombre === 'acceso_log.ip' || nombre === 'auditoria.usuario…
    294|       expect(fila.is_nullable, nombre).toBe(permiteNull ? 'YES' : 'NO'…
       |                                        ^
    295|     }
    296|     expect(filas.find((fila) => fila.table_name === 'legajo' && fila.c…

⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯[1/1]⎯


 Test Files  1 failed | 1 passed (2)
      Tests  1 failed | 54 passed (55)
   Start at  15:24:42
   Duration  1.31s (transform 38ms, setup 0ms, collect 40ms, tests 148ms, environment 0ms, prepare 78ms)

[ELIFECYCLE] Test failed. See above for more details.
[ELIFECYCLE] Command failed with exit code 1.
```

## Problema inicial del entorno — salida real

Comando: `pnpm db:generate`. Código de salida: **1**.

```text
[ERROR] unable to open database file
For help, run: pnpm help run
```

## Revisión de alcance — salida real

Comando:

```sh
git diff --exit-code -- drizzle/0000_adorable_red_skull.sql drizzle/meta/0000_snapshot.json && git diff --check && git status --short
```

Código de salida: **0**. Los dos primeros controles no emitieron salida.

```text
 M drizzle/meta/_journal.json
 M src/server/db/schema.ts
?? drizzle/0001_safe_fabian_cortez.sql
?? drizzle/meta/0001_snapshot.json
?? test/schema.test.ts
```

## Pendientes y límites

- No quedó trabajo de implementación o verificación pendiente para L02a.
- El build muestra una advertencia de Next.js por varios lockfiles y la raíz de tracing inferida; no se cambió la configuración porque está fuera del alcance.
- El índice trigram y las extensiones son agregados SQL manuales; `db:generate` compara el schema con sus snapshots, y los tests verifican también esos objetos en PostgreSQL.
- Grants, triggers, seeds y las demás funciones quedan para L02b, según la spec.
- No se usó `any`, no se crearon archivos de prueba sueltos, no se hizo commit ni push y no se movió la tarea a `done/`.

