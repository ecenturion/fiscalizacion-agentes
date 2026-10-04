# Informe — L05-legajos-y-cedulas

**Estado:** BLOQUEADO
**Implementador:** CODEX · sombrero B
**Fecha:** 2026-10-04
**Despacho:** tercer intento

## Bloqueo encontrado antes de editar código

La nota del tercer despacho pide mover el fixture de `test/schema.test.ts` a un año que ningún otro test use y especifica **2099**, con los números `2099-0001` y `2099-12345`.

Sin embargo, `test/triggers.test.ts:40–46` ya utiliza 2099: reserva un correlativo con un upsert e inserta un legajo dentro de una transacción que confirma. La consulta real de la base de tests confirma que **2099-0001 ya existe**. Mover schema a ese número produciría nuevamente el 23505 en la siembra y haría fallar sus 53 tests.

Me detuve conforme a `legajos-agents/AGENTS.md` §4.9: «Si la spec es ambigua o contradictoria, detenete y reportá». `test/triggers.test.ts` tampoco está en el alcance autorizado; CODEX.md exige parar si hace falta tocar otro archivo.

Se solicitó aclaración: usar **2098 exclusivamente para schema** (no tiene filas en la consulta realizada), o ampliar el alcance para mover los fixtures de triggers a otro año. No llegó respuesta durante esta ejecución. No sustituí por cuenta propia el año explícito de la spec ni edité triggers.

## Archivos creados y modificados en esta ejecución

- Código: **ningún archivo creado ni modificado**.
- Informe: `legajos-agents/informes/L05-legajos-y-cedulas.codex.informe.md`, actualizado con el bloqueo y la salida real de esta ejecución.

Al iniciar ya estaban presentes estos cambios de intentos anteriores:

- Modificados: `src/server/errores.ts`, `src/server/login.ts`, `src/server/servicios/contratos.ts`.
- Nuevos sin seguimiento: `src/server/uuid.ts`, `src/server/servicios/legajos.ts`, `src/server/servicios/cedulas.ts`, `src/server/servicios/mapeo.ts`, `test/legajos.test.ts`, `test/cedulas.test.ts`.

Se conservaron todos. `errores.ts` contiene las correcciones del arquitecto. `legajos-agents/estado.jsonl` ya estaba modificado y no se tocó. No se hizo commit, push, despliegue ni movimiento de la tarea.

## Verificación del árbol existente

Comando ejecutado: `cd legajos && pnpm verificar`.

**Código de salida: 1.**

- Lint y typecheck terminaron con éxito.
- Vitest: **219 aprobados, 55 fallidos, 274 en total**.
- El build no se ejecutó porque la cadena terminó en los tests.
- Los fallos del código heredado son: un caso horario que todavía usa UTC−4 y exige 2026, una aserción de auditoría sin orden, y 53 tests de schema que colisionan con el fixture confirmado de 2026.
- Esta ejecución no constituye una auditoría ni una aprobación de la implementación anterior.

Salida real completa del comando, concatenada de las respuestas del proceso:

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
 ❯ test/legajos.test.ts (17 tests | 1 failed) 294ms
   ✓ Legajos contra Postgres real como legajos_app > usa el rol app sin heredar owner 1ms
   ✓ Legajos contra Postgres real como legajos_app > dos legajos empiezan en AAAA-0001 y AAAA-0002 16ms
   ✓ Legajos contra Postgres real como legajos_app > 10 altas concurrentes reservan correlativos 1..10 sin repetidos 70ms
   ✓ Legajos contra Postgres real como legajos_app > el primer legajo del año siguiente vuelve al correlativo 1 5ms
   × Legajos contra Postgres real como legajos_app > usa el año de Asunción aunque el instante en UTC ya sea 2027 11ms
     → expected 2027 to be 2026 // Object.is equality
   ✓ Legajos contra Postgres real como legajos_app > rechaza sin cédulas y con dos originales antes de escribir 3ms
   ✓ Legajos contra Postgres real como legajos_app > audita el legajo y todas sus cédulas y devuelve UUIDv7 y fechas ISO 8ms
   ✓ Legajos contra Postgres real como legajos_app > relaciona sin duplicar y sólo por números de cédulas vivas 31ms
   ✓ Legajos contra Postgres real como legajos_app > encuentra José buscando jose, por prefijo y con filtros combinados AND 16ms
   ✓ Legajos contra Postgres real como legajos_app > trata % como literal en la búsqueda 14ms
   ✓ Legajos contra Postgres real como legajos_app > trata _ como literal en la búsqueda 14ms
   ✓ Legajos contra Postgres real como legajos_app > trata \ como literal en la búsqueda 15ms
   ✓ Legajos contra Postgres real como legajos_app > pagina con total exacto, sin duplicados y de más nuevo a más antiguo 22ms
   ✓ Legajos contra Postgres real como legajos_app > audita vistas y consultas incluso sin resultados 11ms
   ✓ Legajos contra Postgres real como legajos_app > consulta no crea ni edita; el guard entrega el contexto sin elevar permisos 4ms
   ✓ Legajos contra Postgres real como legajos_app > editarLegajo preserva estado y campos omitidos; el grant bloquea cambios de estado 10ms
   ✓ Legajos contra Postgres real como legajos_app > ver inexistente devuelve 404 y valida los UUID y el paginado 2ms
 ❯ test/cedulas.test.ts (13 tests | 1 failed) 202ms
   ✓ Cédulas contra Postgres real como legajos_app > usa legajos_app sin pertenecer a owner 1ms
   ✓ Cédulas contra Postgres real como legajos_app > permite repetir un número en el mismo legajo y audita el alta 19ms
   ✓ Cédulas contra Postgres real como legajos_app > agregar una segunda original devuelve 409 sin desmarcar ni auditar un alta 11ms
   ✓ Cédulas contra Postgres real como legajos_app > marcarOriginal cambia ambas filas con antes/después y dos auditorías 13ms
   ✓ Cédulas contra Postgres real como legajos_app > dos cambios concurrentes con original inicial=true dejan exactamente una 22ms
   ✓ Cédulas contra Postgres real como legajos_app > dos cambios concurrentes con original inicial=false dejan exactamente una 13ms
   ✓ Cédulas contra Postgres real como legajos_app > dos altas originales concurrentes tienen un éxito y un conflicto 12ms
   ✓ Cédulas contra Postgres real como legajos_app > alta y marcado concurrentes preservan una sola original 11ms
   × Cédulas contra Postgres real como legajos_app > editar sólo modifica los campos autorizados y preserva los opcionales omitidos 19ms
     → expected { Object (antes, despues) } to match object { antes: { nombres: 'Ana' }, …(1) }
(13 matching properties omitted from actual)
   ✓ Cédulas contra Postgres real como legajos_app > anular la original deja el legajo sin original viva y permite marcar otra 17ms
   ✓ Cédulas contra Postgres real como legajos_app > anular exige motivo y rechaza editar, marcar o anular una cédula ya anulada 12ms
   ✓ Cédulas contra Postgres real como legajos_app > consulta no crea ni edita ni marca; operador no anula 8ms
   ✓ Cédulas contra Postgres real como legajos_app > valida cada entrada y devuelve 404 para IDs inexistentes 3ms
 ❯ test/schema.test.ts (53 tests | 53 failed) 80ms
   × Tablas y constraints de legajos (legajos_owner) > conecta como legajos_owner 19ms
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
   × Tablas y constraints de legajos (legajos_owner) > Anulación de documento > rechaza la combinación parcial (false, false, true) 2ms
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
   × Tablas y constraints de legajos (legajos_owner) > Anulación de interaccion > rechaza la combinación parcial (true, false, false) 2ms
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
   × Tablas y constraints de legajos (legajos_owner) > todas las FK aplican ON DELETE RESTRICT 1ms
     → duplicate key value violates unique constraint "legajo_anio_correlativo_unq"
   × Tablas y constraints de legajos (legajos_owner) > los UUID no tienen DEFAULT y la nulabilidad coincide con §9.1 2ms
     → duplicate key value violates unique constraint "legajo_anio_correlativo_unq"
   × Tablas y constraints de legajos (legajos_owner) > las extensiones y el índice trigram usan el esquema legajos 1ms
     → duplicate key value violates unique constraint "legajo_anio_correlativo_unq"
 ✓ test/login.test.ts (14 tests) 3634ms
   ✓ Login y cambio de clave con Postgres real como legajos_app > cinco fallos bloquean; la clave correcta no pasa hasta +16 minutos  371ms
   ✓ Login y cambio de clave con Postgres real como legajos_app > inexistente usa señuelo, con mediana de cinco muestras a menos del 30%  444ms
   ✓ Login y cambio de clave con Postgres real como legajos_app > 20 fallos por IP, el 21 no verifica ni modifica cuenta; ventana vencida reinicia  936ms
   ✓ Login y cambio de clave con Postgres real como legajos_app > 25 concurrentes desde una IP: sólo 20 verifican argon2  889ms
 ✓ test/logout-y-cli.test.ts (12 tests) 2819ms
   ✓ Logout y recuperación administrativa > CLI imprime una clave de 16 caracteres una vez, agrega IPv6 y cierra todas las sesiones  487ms
   ✓ Logout y recuperación administrativa > CLI normaliza IPv4-mapped y agrega /32  347ms
   ✓ Logout y recuperación administrativa > CLI rechaza usuario no admin, sin modificaciones ni clave en stdout  347ms
   ✓ Logout y recuperación administrativa > CLI rechaza legajos online y acepta la aplicación detenida  746ms
   ✓ Logout y recuperación administrativa > CLI falla si el lock está ocupado  346ms
 ✓ test/auth-guard.test.ts (40 tests) 153ms
 ✓ test/triggers.test.ts (21 tests) 111ms
 ✓ test/permisos.test.ts (29 tests) 39ms
 ✓ test/humo.test.ts (3 tests) 22ms
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
   Start at  16:44:59
   Duration  11.88s (transform 187ms, setup 0ms, collect 1.71s, tests 7.37s, environment 1ms, prepare 413ms)

 ELIFECYCLE  Test failed. See above for more details.
 ELIFECYCLE  Command failed with exit code 1.

```

## Evidencia adicional del año ocupado

Comando ejecutado en `legajos/`:

```sh
node --input-type=module <<'JS'
import postgres from 'postgres';
const app = postgres(process.env.TEST_APP_URL || 'postgres://legajos_app@localhost:55433/legajos_test');
try {
  const filas = await app`SELECT anio, correlativo, numero FROM legajos.legajo WHERE anio IN (2098, 2099) ORDER BY anio, correlativo`;
  process.stdout.write(JSON.stringify(filas, null, 2) + '\n');
} finally {
  await app.end();
}
JS
```

Salida real (código 0):

```text
[
  {
    "anio": 2099,
    "correlativo": 1,
    "numero": "2099-0001"
  },
  {
    "anio": 2099,
    "correlativo": 2,
    "numero": "2099-0002"
  }
]

```

## Pendientes para completar L05

1. Resolver la asignación exclusiva del año de schema y su alcance.
2. Aplicar las correcciones autorizadas del tercer despacho: UTC−3 antes y después del cambio a 2027, años fijos propios para los tests que no prueban numeración, y `ORDER BY creado_en, id` en sus consultas de auditoría.
3. Agregar un test contra Postgres real que fuerce el 23505 de `cedula_original_unq` dentro del servicio y compruebe `ErrorConflicto('original_existente')`.
4. Completar la implementación y ejecutar nuevamente `pnpm verificar` hasta obtener la verificación completa.

Las correcciones horarias y de auditoría del tercer despacho son claras; el bloqueo actual es exclusivamente la asignación de **2099** ya utilizada por otro archivo.
