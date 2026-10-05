# L08a — Server Actions y lectura para las pantallas

**Arquitecto:** claude-code · **Implementa:** CODEX sombrero B · **Audita:** AGY (lectura) + arquitecto
**Fuente:** diseño §3.2 (guard en cada Action), §3.5 (CSRF), §9.8 y §9.10.
**Base:** L09a (servicios de admin) y L07b (documentos).

**Objetivo:** una capa fina y uniforme que opencode use en las pantallas (L08b, L09b) **sin tocar** guard,
servicios ni base.

## Alcance de archivos
1. `src/server/acciones/resultado.ts`:
   - `type Resultado<T> = { ok: true; datos: T } | { ok: false; error: { codigo: string; mensaje: string;
     campos?: Record<string,string> } }`;
   - `aResultado(fn)` traduce las excepciones conocidas:
     - `ErrorValidacion` y `ZodError` → `campos`;
     - `ErrorConflicto`, `ErrorPermiso`, `ErrorNoEncontrado` y `ErrorArchivoGrande`;
     - `ErrorNoAutenticado` → **`redirect('/login')`**;
     - cualquier otra → `{ codigo: 'interno', mensaje: 'Error inesperado.' }`, **sin filtrar el mensaje
       original**.
2. `src/server/acciones/contexto.ts`:
   - `servicios()` arma, una vez por proceso, todos los servicios con `dbApp()` y `ARCHIVOS_DIR`;
   - `ctxPagina(permiso)`: para Server Components, llama a `requerirSesion({ permiso, mutacion: false })`.
     - Con `ErrorNoAutenticado` → `redirect('/login')`.
     - Con `ErrorPermiso('debe_cambiar_clave')` → `redirect('/cuenta/clave')`.
     - Con `ErrorPermiso` → `notFound()`. No revela que existe.
3. `src/app/(app)/legajos/acciones.ts` (`'use server'`). Cada acción hace `requerirSesion({ permiso, mutacion:
   true })`, llama al servicio dentro de `aResultado`, hace `revalidatePath` de la ruta afectada y devuelve un
   `Resultado`:
   - `crearLegajoAccion`: si sale bien, `redirect` a `/legajos/[id]`;
   - `editarLegajoAccion`;
   - `agregarCedulaAccion`, `editarCedulaAccion`, `anularCedulaAccion` y `marcarOriginalAccion`;
   - `registrarInteraccionAccion` y `anularInteraccionAccion`;
   - `anularDocumentoAccion`;
   - `relacionadosPorCedulaAccion`: lectura, con `mutacion: false`. La UI la usa para avisar antes de guardar.

   La subida de documentos **no** es una Action: el cliente hace POST multipart a `/api/documentos`, que ya existe.
4. `src/app/(app)/admin/acciones.ts` (`'use server'`), con una acción por función de `ServiciosAdmin`:
   - usuarios: `crear`, `editar`, `activar`, `resetearClave` y `desbloquear`;
   - IPs: `agregarIp` y `desactivarIp`;
   - catálogos: `crearEstado`, `crearTipoInteraccion`, `crearTipoDocumento`, `editarCatalogo` y
     `activarCatalogo`.

   `crear` y `resetearClave` devuelven la clave temporal **sólo** en el `Resultado` de esa llamada. Nunca va a
   logs ni a cookies.
5. `src/app/(app)/cuenta/clave/acciones.ts`: adaptalo a `aResultado` sin cambiar su lógica.
6. `test/acciones.test.ts`: para testear sin Next, cada archivo de acciones exporta además una versión
   `…Con(deps)` que recibe las deps de sesión. La exportada para Next las llama sin deps. Cubre:
   - sin sesión → `redirect('/login')`: con `vi.mock('next/navigation')` se comprueba la llamada;
   - `consulta` creando un legajo → `{ ok:false, error.codigo:'permiso_denegado' }`;
   - `origin` ajeno → `origen_invalido`;
   - entrada inválida → `campos`;
   - feliz → `ok:true` y `revalidatePath` llamado (mock de `next/cache`);
   - un error interno inyectado → `interno`, **sin el texto original**;
   - `crearUsuario` → la clave sólo aparece en el resultado.
7. `test/guard-cobertura.test.ts`, el test de §3.2. Recorre `src/app/**/acciones.ts` y `src/app/api/**/route.ts`:
   - **cada** función exportada async de un archivo `'use server'` contiene `requerirSesion(` antes de cualquier
     `servicios()` o import de `@/server/servicios`;
   - cada `route.ts` llama `requerirSesion` antes de leer `request.body`, `request.formData`, `request.json` o
     `recibirMultipart`;
   - **excepciones explícitas**, en una lista dentro del test: `entrar` del login y `POST /logout`, que hacen su
     propio chequeo.

   Es un análisis por texto (AST de `typescript`, ya instalado). No reemplaza al e2e de L10.

## Criterios
```
cd legajos && pnpm verificar
```
Sin `any`, sin `console.log`. Sin commit ni push.
