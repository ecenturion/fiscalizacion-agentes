# Informe — M2b-servicios-resto-y-acciones

**Estado:** COMPLETADO
**Implementador:** CODEX, sombrero B
**Rama:** modelo-v2

## Resultado

Interacciones y solicitudes migradas al trámite; documentos con procedencia opcional, validación del vínculo vivo bajo candado y reemplazos que heredan la procedencia histórica. Catálogo de tipos de trámite y conjunto de documentos obligatorios administrados sin borrar filas. Acciones v2 con guard, Origin, validación, resultados, revalidación y variantes Con; alta de trámite redirige después de confirmar.

Verificación final: lint y 498 tests pasan (20 archivos), contra PostgreSQL 16 real. Los servicios usan legajos_app. El filtro de typecheck está vacío: los 62 errores restantes pertenecen exclusivamente a pantallas de M3 permitidas por la spec.

## Archivos

Las rutas siguientes son relativas a legajos/.

### Creados

- `src/app/(app)/tramites/acciones.ts`

### Modificados

- `src/app/(app)/admin/acciones.ts`
- `src/app/(app)/legajos/acciones.ts`
- `src/app/api/documentos/route.ts`
- `src/server/acciones/contexto.ts`
- `src/server/servicios/admin.ts`
- `src/server/servicios/contratos.ts`
- `src/server/servicios/documentos.ts`
- `src/server/servicios/interacciones.ts`
- `src/server/servicios/tramites.ts`
- `test/acciones.test.ts`
- `test/admin.test.ts`
- `test/auth-guard.test.ts`
- `test/documentos.test.ts`
- `test/guard-cobertura.test.ts`
- `test/interacciones.test.ts`
- `test/rutas-documentos.test.ts`

### Eliminados

- `src/server/servicios/cedulas.ts` — servicio de cédulas retirado por la spec.

## Decisiones y motivos

- El registro de interacción bloquea primero el trámite; el trigger mantiene el cambio de estado y P0001/estado_desactualizado se devuelve como 409.
- La subida con procedencia bloquea el trámite antes de comprobar el vínculo. Solicitudes de otro trámite, otro tipo o inexistentes dan 409/solicitud_invalida; recibidas por un documento vivo dan 409/solicitud_recibida. Sin trámite, una lista de solicitudes no vacía da 422.
- Se bloquean los documentos recibidos por id antes de las solicitudes por id. El reemplazo bloquea los trámites de procedencia y de las solicitudes afectadas en orden, luego el documento y finalmente las solicitudes. Hereda tramite_id incluso después de desvincular; conserva archivos históricos y la política previa ante un COMMIT incierto.
- verTramite reutiliza cargarInteracciones, el mismo lector transaccional que usa listarInteracciones. Así interacciones, solicitudes y auditoría quedan en la transacción y snapshot del detalle, sin abrir una transacción independiente. Las solicitudes conservan la derivación recibida sólo cuando el documento está vivo.
- listarDocumentosLegajo devuelve todas las versiones y tramiteNumero, mediante LEFT JOIN al trámite. Se agregó DocumentoLegajoSalida para tipar ese dato sin cambiar el DTO general de documento ni editar legajos.ts, fuera del alcance.
- editarCatalogo/activarCatalogo incorporan catalogo=tramite; no se duplicaron operaciones existentes. La unicidad de nombres usa la restricción de PostgreSQL y traduce 23505 a 409/nombre_existente.
- definirDocumentosObligatorios bloquea el tipo de trámite para serializar el reemplazo completo; inserta asociaciones nuevas, reactiva las anteriores y desactiva las retiradas. Cada alta/cambio queda auditado en la misma transacción.
- Las acciones revalidan los layouts de legajos y trámites porque datos, vínculos, catálogos y documentos pueden afectar varios detalles y sus faltantes. buscarPorCedula es lectura y no exige Origin ni revalida.
- POST /api/documentos ya parseaba subirDocumentoEntrada, cuyo contrato M2a exige legajoId y admite tramiteId opcional. Se conservó ese parser y se comprobó el comportamiento v2 con pruebas HTTP reales.
- La carrera carga/desvinculación usa una transacción que retiene el trámite, handshake de adquisición y observación de locks desde legajos_app. Se prueban ambos órdenes: cargar primero conserva procedencia histórica; desvincular primero rechaza la carga sin filas ni finales.
- Los fixtures de catálogos usan rollback y savepoints reales para no alterar las aserciones de semillas. Las altas de trámites de esta tarea usan años 2080–2089; las acciones usan un reloj controlado en 2088.

## Entorno de verificación

El pnpm global (11.22.0) falló antes de ejecutar scripts al intentar abrir su store fuera del área permitida:

```text
[ERROR] unable to open database file
For help, run: pnpm help run
```

Se usó la instalación existente de pnpm 11.0.0, versión declarada por package.json, anteponiendo su binario al PATH de los comandos:

```sh
export PATH="/home/ecenturion/.local/share/pnpm/store/v11/links/@/pnpm/11.0.0/e45837f70c41a3f875992fed9b5aff0fd52577b9d87631e49da939d06a059476/bin:$PATH"
```

No se instalaron dependencias ni se modificaron archivos externos. Logs de ejecución en legajos/node_modules/.cache/. El único archivo escrito por CODEX en legajos-agents/ es este informe.

## Salida real de la verificación final

Comando, desde legajos/:

```sh
pnpm lint && docker compose -f compose.test.yml down && docker compose -f compose.test.yml up -d --wait && pnpm test
```

**Código de salida: 0.** Se incluye la salida completa, también los warnings de migración:

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
 ✓ test/login.test.ts (14 tests) 4213ms
   ✓ Login y cambio de clave con Postgres real como legajos_app > cinco fallos bloquean; la clave correcta no pasa hasta +16 minutos  405ms
   ✓ Login y cambio de clave con Postgres real como legajos_app > inexistente usa señuelo, con mediana de cinco muestras a menos del 30%  491ms
   ✓ Login y cambio de clave con Postgres real como legajos_app > 20 fallos por IP, el 21 no verifica ni modifica cuenta; ventana vencida reinicia  1042ms
   ✓ Login y cambio de clave con Postgres real como legajos_app > 25 concurrentes desde una IP: sólo 20 verifican argon2  1072ms
   ✓ Login y cambio de clave con Postgres real como legajos_app > cambiar clave cierra sesiones, emite otra válida y audita sin secretos  350ms
 ✓ test/logout-y-cli.test.ts (12 tests) 3637ms
   ✓ Logout y recuperación administrativa > CLI imprime una clave de 16 caracteres una vez, agrega IPv6 y cierra todas las sesiones  729ms
   ✓ Logout y recuperación administrativa > CLI normaliza IPv4-mapped y agrega /32  469ms
   ✓ Logout y recuperación administrativa > CLI rechaza usuario no admin, sin modificaciones ni clave en stdout  448ms
   ✓ Logout y recuperación administrativa > CLI no permite --sin-pm2 en producción  318ms
   ✓ Logout y recuperación administrativa > CLI rechaza legajos online y acepta la aplicación detenida  895ms
   ✓ Logout y recuperación administrativa > CLI falla si el lock está ocupado  385ms
 ✓ test/documentos.test.ts (45 tests) 2208ms
   ✓ Documentos contra Postgres real como legajos_app > 2b: Nota con tres archivos conserva orden 1, 2, 3  399ms
 ✓ test/admin.test.ts (19 tests) 1192ms
   ✓ Administración contra Postgres real como legajos_app > dos admins que se desactivan mutuamente en paralelo dejan al menos uno activo  371ms
 ✓ test/archivos-validar.test.ts (15 tests) 797ms
 ✓ test/acciones.test.ts (30 tests) 679ms
 ✓ test/tramites.test.ts (20 tests) 553ms
 ✓ test/rutas-documentos.test.ts (17 tests) 536ms
 ✓ test/migracion-0003.test.ts (4 tests) 456ms
 ✓ test/interacciones.test.ts (12 tests) 348ms
 ✓ test/triggers.test.ts (44 tests) 215ms
 ✓ test/legajos.test.ts (15 tests) 176ms
 ✓ test/archivos-almacen.test.ts (19 tests) 171ms
 ✓ test/auth-guard.test.ts (40 tests) 173ms
 ✓ test/schema.test.ts (60 tests) 178ms
 ✓ test/permisos.test.ts (36 tests) 49ms
 ✓ test/guard-cobertura.test.ts (12 tests) 48ms
 ✓ test/humo.test.ts (3 tests) 25ms
 ✓ test/ip.test.ts (24 tests) 10ms
 ✓ test/permisos.unit.test.ts (57 tests) 4ms

 Test Files  20 passed (20)
      Tests  498 passed (498)
   Start at  16:11:59
   Duration  25.24s (transform 404ms, setup 0ms, collect 4.45s, tests 15.67s, environment 3ms, prepare 842ms)

```

Comando del filtro solicitado (la salida completa se capturó además con tee):

```sh
pnpm typecheck 2>&1 | grep "error TS" | grep -v "^src/app/(app)/.*\(page\.tsx\|componentes/\)"
```

Salida real:

```text
```

**Filtro vacío.** El último grep sale con 1 porque no encuentra errores fuera de las pantallas. El typecheck completo sale con 2 por los errores permitidos de M3. Su salida real completa:

```text
$ tsc --noEmit
src/app/(app)/admin/catalogos/componentes/AltaCatalogo.tsx(21,9): error TS2353: Object literal may only specify known properties, and 'obligatorio' does not exist in type '{ nombre: string; vigenciaDias: number | null; multiplesArchivos: boolean; }'.
src/app/(app)/admin/catalogos/componentes/EditarCatalogo.tsx(23,9): error TS2353: Object literal may only specify known properties, and 'obligatorio' does not exist in type '{ catalogo: "documento"; id: string; nombre?: string | undefined; vigenciaDias?: number | null | undefined; multiplesArchivos?: boolean | undefined; }'.
src/app/(app)/admin/catalogos/componentes/EditarCatalogo.tsx(51,40): error TS2339: Property 'obligatorio' does not exist on type 'TipoDocumentoAdminSalida'.
src/app/(app)/admin/catalogos/page.tsx(98,29): error TS2339: Property 'obligatorio' does not exist on type 'TipoDocumentoAdminSalida'.
src/app/(app)/legajos/[id]/componentes/AgregarCedula.tsx(5,10): error TS2724: '"../../acciones"' has no exported member named 'agregarCedulaAccion'. Did you mean 'corregirCedulaAccion'?
src/app/(app)/legajos/[id]/componentes/Anular.tsx(6,3): error TS2305: Module '"../../acciones"' has no exported member 'anularCedulaAccion'.
src/app/(app)/legajos/[id]/componentes/Anular.tsx(6,46): error TS2305: Module '"../../acciones"' has no exported member 'anularInteraccionAccion'.
src/app/(app)/legajos/[id]/componentes/EditarCedula.tsx(5,10): error TS2305: Module '"../../acciones"' has no exported member 'editarCedulaAccion'.
src/app/(app)/legajos/[id]/componentes/EditarLegajo.tsx(27,9): error TS2353: Object literal may only specify known properties, and 'fechaDeteccion' does not exist in type '{ legajoId: string; observacion?: string | null | undefined; nombres?: string | undefined; apellidos?: string | undefined; fechaNacimiento?: string | null | undefined; fechaEmision?: string | ... 1 more ... | undefined; }'.
src/app/(app)/legajos/[id]/componentes/EditarLegajo.tsx(36,54): error TS2339: Property 'numero' does not exist on type 'LegajoResumen'.
src/app/(app)/legajos/[id]/componentes/EditarLegajo.tsx(42,32): error TS2339: Property 'fechaDeteccion' does not exist on type 'LegajoResumen'.
src/app/(app)/legajos/[id]/componentes/MarcarOriginal.tsx(5,10): error TS2305: Module '"../../acciones"' has no exported member 'marcarOriginalAccion'.
src/app/(app)/legajos/[id]/componentes/RegistrarInteraccion.tsx(5,10): error TS2305: Module '"../../acciones"' has no exported member 'registrarInteraccionAccion'.
src/app/(app)/legajos/[id]/documentos/[docId]/page.tsx(23,39): error TS2339: Property 'id' does not exist on type 'LegajoSalida'.
src/app/(app)/legajos/[id]/documentos/[docId]/page.tsx(23,73): error TS2339: Property 'numero' does not exist on type 'LegajoSalida'.
src/app/(app)/legajos/[id]/page.tsx(40,50): error TS2339: Property 'faltantes' does not exist on type '{ subirDocumento(ctx: Contexto, entrada: { legajoId: string; tipoId: string; fechaEmision: string; tramiteId?: string | null | undefined; observacion?: string | null | undefined; solicitudesIds?: string[] | undefined; }, archivos: readonly ArchivoParaSubir[]): Promise<...>; reemplazarDocumento(ctx: Contexto, entrada...'.
src/app/(app)/legajos/[id]/page.tsx(47,15): error TS2339: Property 'interacciones' does not exist on type 'LegajoSalida'.
src/app/(app)/legajos/[id]/page.tsx(47,38): error TS7006: Parameter 'interaccion' implicitly has an 'any' type.
src/app/(app)/legajos/[id]/page.tsx(47,83): error TS7006: Parameter 's' implicitly has an 'any' type.
src/app/(app)/legajos/[id]/page.tsx(49,42): error TS2339: Property 'interacciones' does not exist on type 'LegajoSalida'.
src/app/(app)/legajos/[id]/page.tsx(49,61): error TS7006: Parameter 'interaccion' implicitly has an 'any' type.
src/app/(app)/legajos/[id]/page.tsx(51,12): error TS2339: Property 'estado' does not exist on type 'LegajoSalida'.
src/app/(app)/legajos/[id]/page.tsx(52,15): error TS2339: Property 'interacciones' does not exist on type 'LegajoSalida'.
src/app/(app)/legajos/[id]/page.tsx(52,38): error TS7006: Parameter 'i' implicitly has an 'any' type.
src/app/(app)/legajos/[id]/page.tsx(54,40): error TS2339: Property 'interacciones' does not exist on type 'LegajoSalida'.
src/app/(app)/legajos/[id]/page.tsx(55,15): error TS7006: Parameter 'interaccion' implicitly has an 'any' type.
src/app/(app)/legajos/[id]/page.tsx(56,14): error TS7006: Parameter 'solicitud' implicitly has an 'any' type.
src/app/(app)/legajos/[id]/page.tsx(57,11): error TS7006: Parameter 'solicitud' implicitly has an 'any' type.
src/app/(app)/legajos/[id]/page.tsx(64,34): error TS2339: Property 'cedulas' does not exist on type 'LegajoSalida'.
src/app/(app)/legajos/[id]/page.tsx(64,48): error TS7006: Parameter 'c' implicitly has an 'any' type.
src/app/(app)/legajos/[id]/page.tsx(68,26): error TS2339: Property 'numero' does not exist on type 'LegajoSalida'.
src/app/(app)/legajos/[id]/page.tsx(70,59): error TS2740: Type 'LegajoSalida' is missing the following properties from type 'LegajoResumen': id, cedula, nombres, apellidos, and 5 more.
src/app/(app)/legajos/[id]/page.tsx(75,53): error TS2339: Property 'estado' does not exist on type 'LegajoSalida'.
src/app/(app)/legajos/[id]/page.tsx(76,47): error TS2339: Property 'fechaDeteccion' does not exist on type 'LegajoSalida'.
src/app/(app)/legajos/[id]/page.tsx(78,13): error TS2339: Property 'observacion' does not exist on type 'LegajoSalida'.
src/app/(app)/legajos/[id]/page.tsx(78,48): error TS2339: Property 'observacion' does not exist on type 'LegajoSalida'.
src/app/(app)/legajos/[id]/page.tsx(83,25): error TS2345: Argument of type '"cedula.crear"' is not assignable to parameter of type 'Permiso'.
src/app/(app)/legajos/[id]/page.tsx(84,43): error TS2339: Property 'id' does not exist on type 'LegajoSalida'.
src/app/(app)/legajos/[id]/page.tsx(101,21): error TS2339: Property 'cedulas' does not exist on type 'LegajoSalida'.
src/app/(app)/legajos/[id]/page.tsx(101,34): error TS7006: Parameter 'cedula' implicitly has an 'any' type.
src/app/(app)/legajos/[id]/page.tsx(123,37): error TS2345: Argument of type '"cedula.editar"' is not assignable to parameter of type 'Permiso'.
src/app/(app)/legajos/[id]/page.tsx(127,37): error TS2345: Argument of type '"cedula.anular"' is not assignable to parameter of type 'Permiso'.
src/app/(app)/legajos/[id]/page.tsx(144,68): error TS2339: Property 'numero' does not exist on type 'LegajoResumen'.
src/app/(app)/legajos/[id]/page.tsx(145,32): error TS2339: Property 'estado' does not exist on type 'LegajoResumen'.
src/app/(app)/legajos/[id]/page.tsx(145,81): error TS2339: Property 'fechaDeteccion' does not exist on type 'LegajoResumen'.
src/app/(app)/legajos/[id]/page.tsx(154,44): error TS2339: Property 'id' does not exist on type 'LegajoSalida'.
src/app/(app)/legajos/[id]/page.tsx(181,46): error TS2339: Property 'id' does not exist on type 'LegajoSalida'.
src/app/(app)/legajos/[id]/page.tsx(185,50): error TS2339: Property 'id' does not exist on type 'LegajoSalida'.
src/app/(app)/legajos/[id]/page.tsx(202,50): error TS2339: Property 'id' does not exist on type 'LegajoSalida'.
src/app/(app)/legajos/[id]/page.tsx(212,31): error TS7006: Parameter 'tipo' implicitly has an 'any' type.
src/app/(app)/legajos/[id]/page.tsx(217,15): error TS2339: Property 'interacciones' does not exist on type 'LegajoSalida'.
src/app/(app)/legajos/[id]/page.tsx(219,18): error TS2339: Property 'interacciones' does not exist on type 'LegajoSalida'.
src/app/(app)/legajos/[id]/page.tsx(219,37): error TS7006: Parameter 'interaccion' implicitly has an 'any' type.
src/app/(app)/legajos/[id]/page.tsx(229,45): error TS7006: Parameter 'solicitud' implicitly has an 'any' type.
src/app/(app)/legajos/[id]/page.tsx(243,46): error TS2339: Property 'id' does not exist on type 'LegajoSalida'.
src/app/(app)/legajos/[id]/page.tsx(243,67): error TS2339: Property 'estado' does not exist on type 'LegajoSalida'.
src/app/(app)/legajos/nuevo/componentes/FormLegajo.tsx(5,10): error TS2724: '"../../acciones"' has no exported member named 'crearLegajoAccion'. Did you mean 'editarLegajoAccion'?
src/app/(app)/legajos/nuevo/componentes/FormLegajo.tsx(5,29): error TS2305: Module '"../../acciones"' has no exported member 'relacionadosPorCedulaAccion'.
src/app/(app)/legajos/nuevo/componentes/FormLegajo.tsx(143,72): error TS2339: Property 'numero' does not exist on type 'LegajoResumen'.
src/app/(app)/legajos/page.tsx(107,66): error TS2339: Property 'numero' does not exist on type 'LegajoResumen'.
src/app/(app)/legajos/page.tsx(108,29): error TS2339: Property 'estado' does not exist on type 'LegajoResumen'.
src/app/(app)/legajos/page.tsx(109,35): error TS2339: Property 'fechaDeteccion' does not exist on type 'LegajoResumen'.
 ELIFECYCLE  Command failed with exit code 2.
```

Comando adicional:

```sh
git diff --check
```

Salida real:

```text
```

**Código de salida: 0.** El chequeo de tipos any explícitos, @ts-ignore, as unknown as, console.log y tests omitidos en los archivos del alcance también devolvió cero coincidencias.

## Pendientes y límites

- Las pantallas de M3 conservan los errores arriba pegados; no se editaron porque están fuera del alcance. No se ejecutó build: la spec prescribe lint, tests y el filtro de typecheck en esta etapa.
- No se modificaron migraciones, grants, permisos, archivos de rol ni pantallas. No hubo commit, push ni despliegue. La tarea no se movió a done/.
- La auditoría del diff queda para AGY y el arquitecto; este informe es de implementación, no una auditoría propia.
