# Informe — L05-legajos-y-cedulas

**Estado:** BLOQUEADO
**Implementador:** CODEX · sombrero B
**Fecha:** 2026-10-04

## Bloqueo de la spec

La spec exige simultáneamente calcular el año del instante actual en `America/Asuncion` con Luxon y obtener 2026 al inyectar `2026-12-31T23:30-04:00`. En el runtime disponible, ese instante corresponde a **2027-01-01 a las 00:30 en Asunción**, cuyo offset es -03:00.

La implementación convierte el instante a `America/Asuncion`; el test conserva el resultado 2026 exigido por la spec y falla. Forzar 2026 cambiaría la interpretación del instante o dejaría de respetar la zona indicada.

Me detuve al comprobarlo, conforme a `legajos-agents/AGENTS.md` §4.9: «Si la spec es ambigua o contradictoria, detenete y reportá». No modifiqué el criterio ni sustituí la zona.

**Corrección propuesta para el arquitecto:** cambiar el ejemplo a `2026-12-31T23:30-03:00`. En ese caso el año de Asunción sigue siendo 2026 y en UTC ya es 2027. Alternativamente, conservar el instante -04:00 y exigir 2027. Hace falta resolver esta contradicción antes de continuar.

## Archivos creados y modificados

Creados en `legajos/`:

- `src/server/uuid.ts`.
- `src/server/servicios/legajos.ts`.
- `src/server/servicios/cedulas.ts`.
- `src/server/servicios/mapeo.ts`.
- `test/legajos.test.ts`.
- `test/cedulas.test.ts`.

Modificados en `legajos/`:

- `src/server/login.ts`: extracción de UUIDv7 e importación desde `uuid.ts`; reexportación de compatibilidad para los tests y el CLI existentes.
- `src/server/servicios/contratos.ts`: agregado de `editarLegajoEntrada`, su tipo y `editarLegajo` con salida `LegajoResumen`.

Modificado en `legajos-agents/`:

- `informes/L05-legajos-y-cedulas.codex.informe.md`: reemplaza el informe del intento anterior.

`src/server/errores.ts` **ya estaba modificado al iniciar** por la corrección indicada en la nota de despacho. No lo edité. No hice commit, push, despliegue ni movimiento de la tarea.

## Implementación parcial y decisiones

- Factories sin base global; cada método exige permiso, valida con Zod y usa una transacción con auditoría.
- Numeración mediante upsert atómico, año con Luxon en Asunción, estado activo de menor orden y alta conjunta de legajo y cédulas.
- Lecturas con aislamiento repeatable read para mantener consistentes el detalle y el total paginado.
- Relacionados por cédulas vivas mediante EXISTS, sin duplicar legajos; detalle con cédulas anuladas y TODO(L06/L07) explícito.
- Búsqueda combinable con AND, sin acentos y con escape de porcentajes, guiones bajos y barras invertidas.
- Consultas de búsqueda y relacionados generan registros de vista con filtros e IDs devueltos, incluso si el resultado está vacío.
- Ediciones con columnas explícitas; campos opcionales omitidos conservan su valor y null los vacía. El estado del legajo no se actualiza.
- Las mutaciones de cédulas bloquean primero el legajo para coordinar también las altas concurrentes. Marcar original bloquea además las cédulas vivas con FOR UPDATE y audita el desmarcado y el marcado.
- Anulación conserva la marca histórica de original, mientras el índice parcial y las operaciones consideran originales sólo las cédulas vivas.
- Traducción de 23505 de `cedula_original_unq` a `ErrorConflicto('original_existente')`, incluyendo errores envueltos por Drizzle en cause.
- Contextos de tests obtenidos mediante `requerirSesion` con dependencias inyectadas y sesiones reales. Servicios ejecutados como `legajos_app`; owner sólo siembra fixtures y cierra sus sesiones.
- UUIDv7 mantiene la exportación previa en login para evitar modificar consumidores fuera del alcance.
- Los tests eligen años libres para los casos de numeración 1..10, sin borrar fixtures ni reiniciar contadores existentes.

## Pendientes y limitaciones

1. Resolver el criterio horario contradictorio.
2. Corregir el orden de las consultas de auditoría de los tests nuevos: usan `registros[0]` / `registros[1]` sin ORDER BY. En la corrida focalizada fallaron dos aserciones por este motivo; en la verificación completa falló una. Es un defecto de los tests escritos en este intento, pendiente de corrección tras resolver la spec.
3. Evitar que los fixtures persistentes de L05 ocupen `2026-0001`, que `test/schema.test.ts:51` inserta dentro de su transacción de fixture. Las nuevas altas confirmadas produjeron esta colisión y los 53 tests de schema fallaron al sembrar. `schema.test.ts` está fuera del alcance y no se modificó; corresponde aislar los fixtures de L05 o ampliar el alcance para corregir el fixture existente.
4. La traducción del 23505 está implementada, pero aún falta un test que fuerce el error nativo dentro del servicio. Los tests de concurrencia comprueban el conflicto del servicio y la unicidad final.
5. Completar la verificación satisfactoria y el build. La implementación queda parcial y sin aprobación; no la presento como terminada ni como auditoría de mi propio código.

## Evidencia del instante

Comando ejecutado en `legajos/`:

```sh
node --input-type=module -e 'import { DateTime } from "luxon"; const instante = DateTime.fromISO("2026-12-31T23:30:00-04:00", { setZone: true }); console.info(JSON.stringify({entrada: instante.toISO(), utc: instante.toUTC().toISO(), asuncion: instante.setZone("America/Asuncion").toISO(), anioAsuncion: instante.setZone("America/Asuncion").year, node: process.version, icu: process.versions.icu, tz: process.versions.tz}, null, 2));'
```

Salida real (código 0):

```text
{
  "entrada": "2026-12-31T23:30:00.000-04:00",
  "utc": "2027-01-01T03:30:00.000Z",
  "asuncion": "2027-01-01T00:30:00.000-03:00",
  "anioAsuncion": 2027,
  "node": "v22.23.1",
  "icu": "78.2",
  "tz": "2025c"
}
```

## Verificación obligatoria

Comando solicitado: `cd legajos && pnpm verificar`.

Al iniciar, `pnpm typecheck` y `pnpm --version` fallaron con:

```text
[ERROR] unable to open database file
```

Se ejecutó la verificación con configuración de proceso que permite usar el store dentro del repositorio, sin editar configuración ni agregar dependencias:

```sh
cd legajos
PNPM_CONFIG_MANAGE_PACKAGE_MANAGER_VERSIONS=false PNPM_CONFIG_STORE_DIR=/home/ecenturion/develop/legajos/node_modules/.store pnpm verificar
```

**Código de salida: 1.**

Lint y typecheck finalizaron satisfactoriamente. Vitest: **219 aprobados, 55 fallidos, 274 en total**. El build no se ejecutó porque la cadena se detuvo en los tests.

Salida real completa, concatenada de las respuestas del proceso:

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
 ❯ test/legajos.test.ts (17 tests | 1 failed) 368ms
   ✓ Legajos contra Postgres real como legajos_app > usa el rol app sin heredar owner 2ms
   ✓ Legajos contra Postgres real como legajos_app > dos legajos empiezan en AAAA-0001 y AAAA-0002 17ms
   ✓ Legajos contra Postgres real como legajos_app > 10 altas concurrentes reservan correlativos 1..10 sin repetidos 71ms
   ✓ Legajos contra Postgres real como legajos_app > el primer legajo del año siguiente vuelve al correlativo 1 5ms
   × Legajos contra Postgres real como legajos_app > usa el año de Asunción aunque el instante en UTC ya sea 2027 10ms
     → expected 2027 to be 2026 // Object.is equality
   ✓ Legajos contra Postgres real como legajos_app > rechaza sin cédulas y con dos originales antes de escribir 2ms
   ✓ Legajos contra Postgres real como legajos_app > audita el legajo y todas sus cédulas y devuelve UUIDv7 y fechas ISO 8ms
   ✓ Legajos contra Postgres real como legajos_app > relaciona sin duplicar y sólo por números de cédulas vivas 35ms
   ✓ Legajos contra Postgres real como legajos_app > encuentra José buscando jose, por prefijo y con filtros combinados AND 16ms
   ✓ Legajos contra Postgres real como legajos_app > trata % como literal en la búsqueda 15ms
   ✓ Legajos contra Postgres real como legajos_app > trata _ como literal en la búsqueda 14ms
   ✓ Legajos contra Postgres real como legajos_app > trata \ como literal en la búsqueda 16ms
   ✓ Legajos contra Postgres real como legajos_app > pagina con total exacto, sin duplicados y de más nuevo a más antiguo 86ms
   ✓ Legajos contra Postgres real como legajos_app > audita vistas y consultas incluso sin resultados 13ms
   ✓ Legajos contra Postgres real como legajos_app > consulta no crea ni edita; el guard entrega el contexto sin elevar permisos 5ms
   ✓ Legajos contra Postgres real como legajos_app > editarLegajo preserva estado y campos omitidos; el grant bloquea cambios de estado 11ms
   ✓ Legajos contra Postgres real como legajos_app > ver inexistente devuelve 404 y valida los UUID y el paginado 2ms
 ❯ test/cedulas.test.ts (13 tests | 1 failed) 209ms
   ✓ Cédulas contra Postgres real como legajos_app > usa legajos_app sin pertenecer a owner 1ms
   ✓ Cédulas contra Postgres real como legajos_app > permite repetir un número en el mismo legajo y audita el alta 19ms
   ✓ Cédulas contra Postgres real como legajos_app > agregar una segunda original devuelve 409 sin desmarcar ni auditar un alta 12ms
   ✓ Cédulas contra Postgres real como legajos_app > marcarOriginal cambia ambas filas con antes/después y dos auditorías 14ms
   ✓ Cédulas contra Postgres real como legajos_app > dos cambios concurrentes con original inicial=true dejan exactamente una 21ms
   ✓ Cédulas contra Postgres real como legajos_app > dos cambios concurrentes con original inicial=false dejan exactamente una 15ms
   ✓ Cédulas contra Postgres real como legajos_app > dos altas originales concurrentes tienen un éxito y un conflicto 12ms
   ✓ Cédulas contra Postgres real como legajos_app > alta y marcado concurrentes preservan una sola original 14ms
   × Cédulas contra Postgres real como legajos_app > editar sólo modifica los campos autorizados y preserva los opcionales omitidos 20ms
     → expected { Object (antes, despues) } to match object { antes: { nombres: 'Ana' }, …(1) }
(13 matching properties omitted from actual)
   ✓ Cédulas contra Postgres real como legajos_app > anular la original deja el legajo sin original viva y permite marcar otra 18ms
   ✓ Cédulas contra Postgres real como legajos_app > anular exige motivo y rechaza editar, marcar o anular una cédula ya anulada 12ms
   ✓ Cédulas contra Postgres real como legajos_app > consulta no crea ni edita ni marca; operador no anula 9ms
   ✓ Cédulas contra Postgres real como legajos_app > valida cada entrada y devuelve 404 para IDs inexistentes 4ms
 ✓ test/login.test.ts (14 tests) 3631ms
   ✓ Login y cambio de clave con Postgres real como legajos_app > cinco fallos bloquean; la clave correcta no pasa hasta +16 minutos  369ms
   ✓ Login y cambio de clave con Postgres real como legajos_app > inexistente usa señuelo, con mediana de cinco muestras a menos del 30%  447ms
   ✓ Login y cambio de clave con Postgres real como legajos_app > 20 fallos por IP, el 21 no verifica ni modifica cuenta; ventana vencida reinicia  934ms
   ✓ Login y cambio de clave con Postgres real como legajos_app > 25 concurrentes desde una IP: sólo 20 verifican argon2  890ms
 ✓ test/logout-y-cli.test.ts (12 tests) 2863ms
   ✓ Logout y recuperación administrativa > CLI imprime una clave de 16 caracteres una vez, agrega IPv6 y cierra todas las sesiones  528ms
   ✓ Logout y recuperación administrativa > CLI normaliza IPv4-mapped y agrega /32  350ms
   ✓ Logout y recuperación administrativa > CLI rechaza usuario no admin, sin modificaciones ni clave en stdout  345ms
   ✓ Logout y recuperación administrativa > CLI rechaza legajos online y acepta la aplicación detenida  749ms
   ✓ Logout y recuperación administrativa > CLI falla si el lock está ocupado  342ms
 ✓ test/auth-guard.test.ts (40 tests) 161ms
 ❯ test/schema.test.ts (53 tests | 53 failed) 82ms
   × Tablas y constraints de legajos (legajos_owner) > conecta como legajos_owner 20ms
     → duplicate key value violates unique constraint "legajo_anio_correlativo_unq"
   × Tablas y constraints de legajos (legajos_owner) > genera 2026-0001 y conserva los cinco dígitos de 2026-12345 2ms
     → duplicate key value violates unique constraint "legajo_anio_correlativo_unq"
   × Tablas y constraints de legajos (legajos_owner) > rechaza un (anio, correlativo) duplicado 1ms
     → duplicate key value violates unique constraint "legajo_anio_correlativo_unq"
   × Tablas y constraints de legajos (legajos_owner) > rechaza dos cédulas originales vivas del mismo legajo 1ms
     → duplicate key value violates unique constraint "legajo_anio_correlativo_unq"
   × Tablas y constraints de legajos (legajos_owner) > permite otra original cuando la anterior está anulada 1ms
     → duplicate key value violates unique constraint "legajo_anio_correlativo_unq"
   × Tablas y constraints de legajos (legajos_owner) > rechaza el número de cédula 12a 1ms
     → duplicate key value violates unique constraint "legajo_anio_correlativo_unq"
   × Tablas y constraints de legajos (legajos_owner) > Anulación de cedula > rechaza la combinación parcial (true, false, false) 1ms
     → duplicate key value violates unique constraint "legajo_anio_correlativo_unq"
   × Tablas y constraints de legajos (legajos_owner) > Anulación de cedula > rechaza la combinación parcial (false, true, false) 1ms
     → duplicate key value violates unique constraint "legajo_anio_correlativo_unq"
   × Tablas y constraints de legajos (legajos_owner) > Anulación de cedula > rechaza la combinación parcial (false, false, true) 1ms
     → duplicate key value violates unique constraint "legajo_anio_correlativo_unq"
   × Tablas y constraints de legajos (legajos_owner) > Anulación de cedula > rechaza la combinación parcial (true, true, false) 1ms
     → duplicate key value violates unique constraint "legajo_anio_correlativo_unq"
   × Tablas y constraints de legajos (legajos_owner) > Anulación de cedula > rechaza la combinación parcial (true, false, true) 1ms
     → duplicate key value violates unique constraint "legajo_anio_correlativo_unq"
   × Tablas y constraints de legajos (legajos_owner) > Anulación de cedula > rechaza la combinación parcial (false, true, true) 1ms
     → duplicate key value violates unique constraint "legajo_anio_correlativo_unq"
   × Tablas y constraints de legajos (legajos_owner) > Anulación de cedula > rechaza un motivo con sólo espacios 1ms
     → duplicate key value violates unique constraint "legajo_anio_correlativo_unq"
   × Tablas y constraints de legajos (legajos_owner) > Anulación de cedula > acepta las tres columnas completas 1ms
     → duplicate key value violates unique constraint "legajo_anio_correlativo_unq"
   × Tablas y constraints de legajos (legajos_owner) > Anulación de documento > rechaza la combinación parcial (true, false, false) 1ms
     → duplicate key value violates unique constraint "legajo_anio_correlativo_unq"
   × Tablas y constraints de legajos (legajos_owner) > Anulación de documento > rechaza la combinación parcial (false, true, false) 1ms
     → duplicate key value violates unique constraint "legajo_anio_correlativo_unq"
   × Tablas y constraints de legajos (legajos_owner) > Anulación de documento > rechaza la combinación parcial (false, false, true) 1ms
     → duplicate key value violates unique constraint "legajo_anio_correlativo_unq"
   × Tablas y constraints de legajos (legajos_owner) > Anulación de documento > rechaza la combinación parcial (true, true, false) 1ms
     → duplicate key value violates unique constraint "legajo_anio_correlativo_unq"
   × Tablas y constraints de legajos (legajos_owner) > Anulación de documento > rechaza la combinación parcial (true, false, true) 1ms
     → duplicate key value violates unique constraint "legajo_anio_correlativo_unq"
   × Tablas y constraints de legajos (legajos_owner) > Anulación de documento > rechaza la combinación parcial (false, true, true) 1ms
     → duplicate key value violates unique constraint "legajo_anio_correlativo_unq"
   × Tablas y constraints de legajos (legajos_owner) > Anulación de documento > rechaza un motivo con sólo espacios 1ms
     → duplicate key value violates unique constraint "legajo_anio_correlativo_unq"
   × Tablas y constraints de legajos (legajos_owner) > Anulación de documento > acepta las tres columnas completas 1ms
     → duplicate key value violates unique constraint "legajo_anio_correlativo_unq"
   × Tablas y constraints de legajos (legajos_owner) > Anulación de interaccion > rechaza la combinación parcial (true, false, false) 1ms
     → duplicate key value violates unique constraint "legajo_anio_correlativo_unq"
   × Tablas y constraints de legajos (legajos_owner) > Anulación de interaccion > rechaza la combinación parcial (false, true, false) 1ms
     → duplicate key value violates unique constraint "legajo_anio_correlativo_unq"
   × Tablas y constraints de legajos (legajos_owner) > Anulación de interaccion > rechaza la combinación parcial (false, false, true) 1ms
     → duplicate key value violates unique constraint "legajo_anio_correlativo_unq"
   × Tablas y constraints de legajos (legajos_owner) > Anulación de interaccion > rechaza la combinación parcial (true, true, false) 1ms
     → duplicate key value violates unique constraint "legajo_anio_correlativo_unq"
   × Tablas y constraints de legajos (legajos_owner) > Anulación de interaccion > rechaza la combinación parcial (true, false, true) 1ms
     → duplicate key value violates unique constraint "legajo_anio_correlativo_unq"
   × Tablas y constraints de legajos (legajos_owner) > Anulación de interaccion > rechaza la combinación parcial (false, true, true) 1ms
     → duplicate key value violates unique constraint "legajo_anio_correlativo_unq"
   × Tablas y constraints de legajos (legajos_owner) > Anulación de interaccion > rechaza un motivo con sólo espacios 1ms
     → duplicate key value violates unique constraint "legajo_anio_correlativo_unq"
   × Tablas y constraints de legajos (legajos_owner) > Anulación de interaccion > acepta las tres columnas completas 1ms
     → duplicate key value violates unique constraint "legajo_anio_correlativo_unq"
   × Tablas y constraints de legajos (legajos_owner) > rechaza la nota vacía "" 1ms
     → duplicate key value violates unique constraint "legajo_anio_correlativo_unq"
   × Tablas y constraints de legajos (legajos_owner) > rechaza la nota vacía "  " 1ms
     → duplicate key value violates unique constraint "legajo_anio_correlativo_unq"
   × Tablas y constraints de legajos (legajos_owner) > rechaza sólo estado_nuevo_id 1ms
     → duplicate key value violates unique constraint "legajo_anio_correlativo_unq"
   × Tablas y constraints de legajos (legajos_owner) > rechaza sólo estado_anterior_id 1ms
     → duplicate key value violates unique constraint "legajo_anio_correlativo_unq"
   × Tablas y constraints de legajos (legajos_owner) > rechaza ambos estados iguales 1ms
     → duplicate key value violates unique constraint "legajo_anio_correlativo_unq"
   × Tablas y constraints de legajos (legajos_owner) > acepta ambos estados nulos 1ms
     → duplicate key value violates unique constraint "legajo_anio_correlativo_unq"
   × Tablas y constraints de legajos (legajos_owner) > acepta ambos estados distintos 1ms
     → duplicate key value violates unique constraint "legajo_anio_correlativo_unq"
   × Tablas y constraints de legajos (legajos_owner) > acepta un tipo sin vigencia (requisitos §2.3: es opcional) 1ms
     → duplicate key value violates unique constraint "legajo_anio_correlativo_unq"
   × Tablas y constraints de legajos (legajos_owner) > rechaza vigencia_dias = 0 1ms
     → duplicate key value violates unique constraint "legajo_anio_correlativo_unq"
   × Tablas y constraints de legajos (legajos_owner) > rechaza Prueba y prueba en estado_legajo 1ms
     → duplicate key value violates unique constraint "legajo_anio_correlativo_unq"
   × Tablas y constraints de legajos (legajos_owner) > rechaza Prueba y prueba en tipo_interaccion 1ms
     → duplicate key value violates unique constraint "legajo_anio_correlativo_unq"
   × Tablas y constraints de legajos (legajos_owner) > rechaza Prueba y prueba en tipo_documento 1ms
     → duplicate key value violates unique constraint "legajo_anio_correlativo_unq"
   × Tablas y constraints de legajos (legajos_owner) > rechaza archivos image/gif 1ms
     → duplicate key value violates unique constraint "legajo_anio_correlativo_unq"
   × Tablas y constraints de legajos (legajos_owner) > rechaza el orden repetido en un documento 1ms
     → duplicate key value violates unique constraint "legajo_anio_correlativo_unq"
   × Tablas y constraints de legajos (legajos_owner) > rechaza un path_relativo repetido aunque cambie el orden 1ms
     → duplicate key value violates unique constraint "legajo_anio_correlativo_unq"
   × Tablas y constraints de legajos (legajos_owner) > acepta un archivo application/pdf 1ms
     → duplicate key value violates unique constraint "legajo_anio_correlativo_unq"
   × Tablas y constraints de legajos (legajos_owner) > acepta un archivo image/jpeg 1ms
     → duplicate key value violates unique constraint "legajo_anio_correlativo_unq"
   × Tablas y constraints de legajos (legajos_owner) > acepta un archivo image/png 1ms
     → duplicate key value violates unique constraint "legajo_anio_correlativo_unq"
   × Tablas y constraints de legajos (legajos_owner) > rechaza dos versiones que apuntan al mismo documento 1ms
     → duplicate key value violates unique constraint "legajo_anio_correlativo_unq"
   × Tablas y constraints de legajos (legajos_owner) > acepta ip nula para un acceso con resultado ip_invalida 1ms
     → duplicate key value violates unique constraint "legajo_anio_correlativo_unq"
   × Tablas y constraints de legajos (legajos_owner) > todas las FK aplican ON DELETE RESTRICT 2ms
     → duplicate key value violates unique constraint "legajo_anio_correlativo_unq"
   × Tablas y constraints de legajos (legajos_owner) > los UUID no tienen DEFAULT y la nulabilidad coincide con §9.1 1ms
     → duplicate key value violates unique constraint "legajo_anio_correlativo_unq"
   × Tablas y constraints de legajos (legajos_owner) > las extensiones y el índice trigram usan el esquema legajos 1ms
     → duplicate key value violates unique constraint "legajo_anio_correlativo_unq"
 ✓ test/triggers.test.ts (21 tests) 114ms
 ✓ test/permisos.test.ts (29 tests) 38ms
 ✓ test/humo.test.ts (3 tests) 21ms
 ✓ test/ip.test.ts (24 tests) 7ms
 ✓ test/permisos.unit.test.ts (48 tests) 4ms

⎯⎯⎯⎯⎯⎯ Failed Tests 55 ⎯⎯⎯⎯⎯⎯⎯

 FAIL  test/cedulas.test.ts > Cédulas contra Postgres real como legajos_app > editar sólo modifica los campos autorizados y preserva los opcionales omitidos
AssertionError: expected { Object (antes, despues) } to match object { antes: { nombres: 'Ana' }, …(1) }
(13 matching properties omitted from actual)

- Expected
+ Received

  {
    "antes": {
-     "nombres": "Ana",
+     "nombres": "María",
    },
    "despues": {
      "nombres": "María",
    },
  }

 ❯ test/cedulas.test.ts:156:26
    154|     const registros = await app`SELECT antes, despues FROM legajos.aud…
    155|     expect(registros).toHaveLength(2);
    156|     expect(registros[0]).toMatchObject({ antes: { nombres: 'Ana' }, de…
       |                          ^
    157|     const prohibida = { cedulaId: c.id, nombres: 'María', apellidos: '…
    158|     await expect(cedulas.editarCedula(operador, prohibida)).rejects.to…

⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯[1/55]⎯

 FAIL  test/legajos.test.ts > Legajos contra Postgres real como legajos_app > usa el año de Asunción aunque el instante en UTC ya sea 2027
AssertionError: expected 2027 to be 2026 // Object.is equality

- Expected
+ Received

- 2026
+ 2027

 ❯ test/legajos.test.ts:103:25
    101|     expect(now.toUTC().year).toBe(2027);
    102|     const salida = await crearServiciosLegajos(db, { now: () => now })…
    103|     expect(salida.anio).toBe(2026);
       |                         ^
    104|     expect(salida.numero).toMatch(/^2026-[0-9]{4,}$/);
    105|   });

⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯[2/55]⎯

 FAIL  test/schema.test.ts > Tablas y constraints de legajos (legajos_owner) > conecta como legajos_owner
 FAIL  test/schema.test.ts > Tablas y constraints de legajos (legajos_owner) > genera 2026-0001 y conserva los cinco dígitos de 2026-12345
 FAIL  test/schema.test.ts > Tablas y constraints de legajos (legajos_owner) > rechaza un (anio, correlativo) duplicado
 FAIL  test/schema.test.ts > Tablas y constraints de legajos (legajos_owner) > rechaza dos cédulas originales vivas del mismo legajo
 FAIL  test/schema.test.ts > Tablas y constraints de legajos (legajos_owner) > permite otra original cuando la anterior está anulada
 FAIL  test/schema.test.ts > Tablas y constraints de legajos (legajos_owner) > rechaza el número de cédula 12a
 FAIL  test/schema.test.ts > Tablas y constraints de legajos (legajos_owner) > Anulación de cedula > rechaza la combinación parcial (true, false, false)
 FAIL  test/schema.test.ts > Tablas y constraints de legajos (legajos_owner) > Anulación de cedula > rechaza la combinación parcial (false, true, false)
 FAIL  test/schema.test.ts > Tablas y constraints de legajos (legajos_owner) > Anulación de cedula > rechaza la combinación parcial (false, false, true)
 FAIL  test/schema.test.ts > Tablas y constraints de legajos (legajos_owner) > Anulación de cedula > rechaza la combinación parcial (true, true, false)
 FAIL  test/schema.test.ts > Tablas y constraints de legajos (legajos_owner) > Anulación de cedula > rechaza la combinación parcial (true, false, true)
 FAIL  test/schema.test.ts > Tablas y constraints de legajos (legajos_owner) > Anulación de cedula > rechaza la combinación parcial (false, true, true)
 FAIL  test/schema.test.ts > Tablas y constraints de legajos (legajos_owner) > Anulación de cedula > rechaza un motivo con sólo espacios
 FAIL  test/schema.test.ts > Tablas y constraints de legajos (legajos_owner) > Anulación de cedula > acepta las tres columnas completas
 FAIL  test/schema.test.ts > Tablas y constraints de legajos (legajos_owner) > Anulación de documento > rechaza la combinación parcial (true, false, false)
 FAIL  test/schema.test.ts > Tablas y constraints de legajos (legajos_owner) > Anulación de documento > rechaza la combinación parcial (false, true, false)
 FAIL  test/schema.test.ts > Tablas y constraints de legajos (legajos_owner) > Anulación de documento > rechaza la combinación parcial (false, false, true)
 FAIL  test/schema.test.ts > Tablas y constraints de legajos (legajos_owner) > Anulación de documento > rechaza la combinación parcial (true, true, false)
 FAIL  test/schema.test.ts > Tablas y constraints de legajos (legajos_owner) > Anulación de documento > rechaza la combinación parcial (true, false, true)
 FAIL  test/schema.test.ts > Tablas y constraints de legajos (legajos_owner) > Anulación de documento > rechaza la combinación parcial (false, true, true)
 FAIL  test/schema.test.ts > Tablas y constraints de legajos (legajos_owner) > Anulación de documento > rechaza un motivo con sólo espacios
 FAIL  test/schema.test.ts > Tablas y constraints de legajos (legajos_owner) > Anulación de documento > acepta las tres columnas completas
 FAIL  test/schema.test.ts > Tablas y constraints de legajos (legajos_owner) > Anulación de interaccion > rechaza la combinación parcial (true, false, false)
 FAIL  test/schema.test.ts > Tablas y constraints de legajos (legajos_owner) > Anulación de interaccion > rechaza la combinación parcial (false, true, false)
 FAIL  test/schema.test.ts > Tablas y constraints de legajos (legajos_owner) > Anulación de interaccion > rechaza la combinación parcial (false, false, true)
 FAIL  test/schema.test.ts > Tablas y constraints de legajos (legajos_owner) > Anulación de interaccion > rechaza la combinación parcial (true, true, false)
 FAIL  test/schema.test.ts > Tablas y constraints de legajos (legajos_owner) > Anulación de interaccion > rechaza la combinación parcial (true, false, true)
 FAIL  test/schema.test.ts > Tablas y constraints de legajos (legajos_owner) > Anulación de interaccion > rechaza la combinación parcial (false, true, true)
 FAIL  test/schema.test.ts > Tablas y constraints de legajos (legajos_owner) > Anulación de interaccion > rechaza un motivo con sólo espacios
 FAIL  test/schema.test.ts > Tablas y constraints de legajos (legajos_owner) > Anulación de interaccion > acepta las tres columnas completas
 FAIL  test/schema.test.ts > Tablas y constraints de legajos (legajos_owner) > rechaza la nota vacía ""
 FAIL  test/schema.test.ts > Tablas y constraints de legajos (legajos_owner) > rechaza la nota vacía "  "
 FAIL  test/schema.test.ts > Tablas y constraints de legajos (legajos_owner) > rechaza sólo estado_nuevo_id
 FAIL  test/schema.test.ts > Tablas y constraints de legajos (legajos_owner) > rechaza sólo estado_anterior_id
 FAIL  test/schema.test.ts > Tablas y constraints de legajos (legajos_owner) > rechaza ambos estados iguales
 FAIL  test/schema.test.ts > Tablas y constraints de legajos (legajos_owner) > acepta ambos estados nulos
 FAIL  test/schema.test.ts > Tablas y constraints de legajos (legajos_owner) > acepta ambos estados distintos
 FAIL  test/schema.test.ts > Tablas y constraints de legajos (legajos_owner) > acepta un tipo sin vigencia (requisitos §2.3: es opcional)
 FAIL  test/schema.test.ts > Tablas y constraints de legajos (legajos_owner) > rechaza vigencia_dias = 0
 FAIL  test/schema.test.ts > Tablas y constraints de legajos (legajos_owner) > rechaza Prueba y prueba en estado_legajo
 FAIL  test/schema.test.ts > Tablas y constraints de legajos (legajos_owner) > rechaza Prueba y prueba en tipo_interaccion
 FAIL  test/schema.test.ts > Tablas y constraints de legajos (legajos_owner) > rechaza Prueba y prueba en tipo_documento
 FAIL  test/schema.test.ts > Tablas y constraints de legajos (legajos_owner) > rechaza archivos image/gif
 FAIL  test/schema.test.ts > Tablas y constraints de legajos (legajos_owner) > rechaza el orden repetido en un documento
 FAIL  test/schema.test.ts > Tablas y constraints de legajos (legajos_owner) > rechaza un path_relativo repetido aunque cambie el orden
 FAIL  test/schema.test.ts > Tablas y constraints de legajos (legajos_owner) > acepta un archivo application/pdf
 FAIL  test/schema.test.ts > Tablas y constraints de legajos (legajos_owner) > acepta un archivo image/jpeg
 FAIL  test/schema.test.ts > Tablas y constraints de legajos (legajos_owner) > acepta un archivo image/png
 FAIL  test/schema.test.ts > Tablas y constraints de legajos (legajos_owner) > rechaza dos versiones que apuntan al mismo documento
 FAIL  test/schema.test.ts > Tablas y constraints de legajos (legajos_owner) > acepta ip nula para un acceso con resultado ip_invalida
 FAIL  test/schema.test.ts > Tablas y constraints de legajos (legajos_owner) > todas las FK aplican ON DELETE RESTRICT
 FAIL  test/schema.test.ts > Tablas y constraints de legajos (legajos_owner) > los UUID no tienen DEFAULT y la nulabilidad coincide con §9.1
 FAIL  test/schema.test.ts > Tablas y constraints de legajos (legajos_owner) > las extensiones y el índice trigram usan el esquema legajos
PostgresError: duplicate key value violates unique constraint "legajo_anio_correlativo_unq"
 ❯ ErrorResponse node_modules/.pnpm/postgres@3.4.9/node_modules/postgres/src/connection.js:815:30
 ❯ handle node_modules/.pnpm/postgres@3.4.9/node_modules/postgres/src/connection.js:489:6
 ❯ Socket.data node_modules/.pnpm/postgres@3.4.9/node_modules/postgres/src/connection.js:324:9
 ❯ cachedError node_modules/.pnpm/postgres@3.4.9/node_modules/postgres/src/query.js:170:23
 ❯ new Query node_modules/.pnpm/postgres@3.4.9/node_modules/postgres/src/query.js:36:24
 ❯ sql node_modules/.pnpm/postgres@3.4.9/node_modules/postgres/src/index.js:112:11
 ❯ test/schema.test.ts:51:11
     49|       VALUES (${base.tipoDocumento}, 'Documento de prueba', false, 365…
     50|     `;
     51|     await tx`
       |           ^
     52|       INSERT INTO legajos.legajo (id, anio, correlativo, fecha_detecci…
     53|       VALUES (${base.legajo}, 2026, 1, '2026-01-01', ${base.estado}, $…

⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯[3/55]⎯


 Test Files  3 failed | 8 passed (11)
      Tests  55 failed | 219 passed (274)
   Start at  16:39:47
   Duration  12.03s (transform 184ms, setup 0ms, collect 1.71s, tests 7.50s, environment 1ms, prepare 419ms)

 ELIFECYCLE  Test failed. See above for more details.
 ELIFECYCLE  Command failed with exit code 1.

```
