# L09a — Servicios de administración: usuarios, IPs, catálogos, accesos y auditoría

**Arquitecto:** claude-code · **Implementa:** CODEX sombrero B · **Audita:** AGY (lectura) + arquitecto (mutaciones)
**Fuente:** requisitos §2.5 y §4, diseño §2 (`usuario`, `usuario_ip`, catálogos), §3.3, §3.4, §7 y §9.10–§9.11.
**Base:** L07b (`d4caa27`). Los permisos `admin.usuarios`, `admin.catalogos` y `admin.accesos` ya existen en la
matriz y sólo los tiene el admin.

## Alcance de archivos
1. `src/server/servicios/contratos.ts`: **agregá** los contratos de abajo (zod de entrada, tipos de salida y
   `ServiciosAdmin`). Sin otros cambios.
2. `src/server/servicios/admin.ts` (**nuevo**): `crearServiciosAdmin(db)`.
3. `src/server/servicios/mapeo.ts`: los mapeos que hagan falta.
4. `test/admin.test.ts` (**nuevo**). Sin legajos, así que no necesita años.

## Contrato (todas reciben `ctx` primero, con `exigir` del permiso indicado)

### Usuarios (`admin.usuarios`)
- **`listarUsuarios()`** → `{ id, usuario, nombre, rol, activo, debeCambiarClave, bloqueadoHasta, ips: { id, red,
  descripcion, activo }[] }[]`. **Nunca** devuelve el hash.
- **`crearUsuario({ usuario, nombre, rol, ips: { red, descripcion? }[] (min 1) })`**:
  - el usuario se guarda en minúsculas y tiene que ser `^[a-z0-9._-]{3,32}$`;
  - **al menos una IP**: un usuario sin IPs no entra (§7);
  - genera una **clave temporal** de 16 caracteres con `randomBytes`, la hashea con `hashear` de `clave.ts` y
    pone `debe_cambiar_clave = true`;
  - devuelve `{ usuario, claveTemporal }`. La clave se muestra **una sola vez**: no se guarda ni se audita;
  - un usuario duplicado → `ErrorConflicto('usuario_existente')`.
- **`editarUsuario({ usuarioId, nombre?, rol? })`**:
  - **un admin no puede quitarse a sí mismo el rol admin**;
  - no se puede dejar al sistema **sin ningún admin activo** → `ErrorConflicto('ultimo_admin')`. Se comprueba con
    `FOR UPDATE` sobre los admins activos.
- **`activarUsuario({ usuarioId, activo })`**:
  - con las mismas protecciones: no desactivarse a sí mismo ni al último admin;
  - **desactivar cierra todas sus sesiones** (`motivo_cierre = 'desactivado'`).
- **`resetearClave({ usuarioId })`**:
  - genera una clave temporal nueva, pone `debe_cambiar_clave` y **cierra todas sus sesiones**;
  - también limpia `intentos_fallidos` y `bloqueado_hasta`;
  - devuelve la clave una vez.
- **`desbloquearUsuario({ usuarioId })`** → `intentos_fallidos = 0` y `bloqueado_hasta = null`.

### IPs (`admin.usuarios`)
- **`agregarIp({ usuarioId, red, descripcion? })`**:
  - `red` se valida y **normaliza** con `ipaddr.js`: una IP suelta se guarda como `/32` o `/128`, un CIDR con
    bits de host se normaliza a la red, y las formas no canónicas se rechazan (mismo criterio que `ip.ts`);
  - una red duplicada y activa del mismo usuario → `ErrorConflicto`.
- **`desactivarIp({ ipId })`**:
  - no se puede desactivar la **última IP activa** de un usuario activo → `ErrorConflicto('ultima_ip')`, con
    `FOR UPDATE` sobre sus IPs;
  - **las sesiones abiertas desde IPs que ya no matchean se cortan solas** en el próximo request, por el guard
    (L03). No hay nada extra que hacer, pero hay que probarlo.
- No existe "borrar IP": sólo desactivar.

### Catálogos (`admin.catalogos`)
- **`listarCatalogos()`** → `{ estados, tiposInteraccion, tiposDocumento }`, con los inactivos incluidos.
- **`crearEstado({ nombre, orden })`**, **`crearTipoInteraccion({ nombre, orden })`** y
  **`crearTipoDocumento({ nombre, obligatorio, vigenciaDias|null, multiplesArchivos })`**: un nombre duplicado,
  sin distinguir mayúsculas, → `ErrorConflicto('nombre_existente')`.
- **`editarCatalogo({ catalogo: 'estado'|'interaccion'|'documento', id, …campos })`**: sólo los campos con grant
  (L02b).
- **`activarCatalogo({ catalogo, id, activo })`**:
  - nunca se borra, se desactiva;
  - **no se puede desactivar el último estado activo**;
  - no se puede desactivar el **estado de menor orden** si es el único que puede ser inicial. Regla simple: tiene
    que quedar al menos un estado activo.

### Visores (`admin.accesos`)
- **`listarAccesos({ desde?, hasta?, usuario?, ip?, resultado?, pagina, porPagina≤200 })`** → filas de
  `acceso_log`, ordenadas por `creado_en` descendente, con el total.
- **`listarAuditoria({ desde?, hasta?, usuarioId?, entidad?, entidadId?, accion?, pagina, porPagina≤200 })`** →
  filas de `auditoria`, con el nombre del usuario. `antes` y `despues` van tal cual, porque ya no tienen hashes
  (L04).

### Reglas comunes
- Una transacción por operación, `.set()` explícito y auditoría en la misma transacción.
- **Nunca** pasa a la auditoría ni a la salida: `hash`, la clave temporal ni ningún token. Al auditar un usuario
  se usa una proyección sin `hash`.

## Criterios
```
cd legajos && pnpm verificar
```
`test/admin.test.ts`, contra Postgres real como `legajos_app`:
1. Permisos: `operador` y `consulta` → 403 en **cada** función.
2. Crear usuario:
   - la clave temporal funciona en `iniciarSesion` desde su IP y pide cambio;
   - desde otra IP → `ip_rechazada`;
   - sin IPs → `ErrorValidacion`;
   - duplicado (`Juan` contra `juan`) → 409;
   - la auditoría no contiene la clave ni el hash. Buscalo con `JSON.stringify` sobre todas las filas.
3. Último admin:
   - con un solo admin, quitarse el rol o desactivarse → 409;
   - con dos admins, A desactiva a B → ok y las sesiones de B quedan cerradas;
   - **concurrencia:** dos admins que se desactivan mutuamente en paralelo → queda al menos uno activo.
4. IPs:
   - `192.168.1.5` → `192.168.1.5/32`;
   - `192.168.1.77/24` → `192.168.1.0/24`;
   - `010.0.0.1` → `ErrorValidacion`;
   - desactivar la única → 409;
   - con dos, desactivar la de la sesión actual → **el siguiente `requerirSesion` desde esa IP da 401** y la
     sesión queda cerrada.
5. `resetearClave`: cierra las sesiones, la clave vieja ya no funciona, la temporal sí y pide cambio. Desbloquea
   una cuenta bloqueada.
6. Catálogos:
   - crear `Nota` con otro casing → 409;
   - desactivar un tipo en uso → ok, y el legajo que lo usa lo sigue mostrando (un `verLegajo` con un documento o
     interacción de ese tipo trae el nombre);
   - desactivar el último estado activo → 409.
7. Visores: filtros por usuario, resultado y rango de fechas, paginado con el total, `porPagina` de 500 →
   `ErrorValidacion`.

Sin `any`, sin `console.log`. Sin commit ni push.
