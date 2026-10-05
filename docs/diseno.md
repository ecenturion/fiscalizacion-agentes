# Legajos — Diseño v0.2

Sale de `docs/requisitos.md` v0.3 y de las decisiones del 2026-10-04 (§7). Ante una contradicción, mandan los
requisitos. v0.2 incorpora la auditoría de codex (`informes/diseno.auditoria.md`, 18 hallazgos).

## 1. Stack y convenciones
- **Next.js 15.5.x fijado** (App Router, runtime Node) + TypeScript estricto. Un proyecto en `~/develop/legajos`, con pnpm.
- **PostgreSQL 16 + Drizzle** (`drizzle-kit generate`). Hay dos roles:
  - `legajos_owner`: migraciones y dueño de todo;
  - `legajos_app`: la app, con permisos mínimos (§2.4).
- **Librerías:**
  - contraseñas: `@node-rs/argon2` (argon2id);
  - IPs y CIDR: `ipaddr.js`;
  - multipart en stream: `busboy`;
  - tipo de archivo: `file-type` + verificación estructural (§3.6);
  - validación: zod;
  - fechas: Luxon.
- **Tests:**
  - vitest contra un Postgres real (`compose.test.yml`);
  - Playwright para e2e (L10).
  - `pnpm verificar` = lint + typecheck + test + build.
- **Convenciones:**
  - ids UUIDv7 generados en la app;
  - `timestamptz` en UTC y `America/Asuncion` sólo al presentar y al calcular "hoy" y "año";
  - `date` para nacimiento, emisión y detección;
  - **nunca `DELETE`**: el rol de la app no tiene ese permiso en ninguna tabla. Se anula con `anulado_en`,
    `anulado_por` y `motivo_anulacion` (not null, no vacío), con un check que exige los tres juntos o ninguno.

```
src/app/(auth)/login, /logout (route handler)       src/app/(app)/legajos[/id], /admin/{usuarios,catalogos,accesos,auditoria}
src/app/api/documentos (POST multipart)             src/app/api/archivos/[id] (GET)
src/server/{db,auth,ip,csrf,archivos,auditoria}     src/server/servicios/{legajos,cedulas,documentos,interacciones,usuarios,catalogos}
scripts/admin-recuperar.ts                          scripts/archivos-huerfanos.ts
```

## 2. Modelo de datos

Todas las FK son `NOT NULL` salvo indicación. Los nombres de catálogo son únicos sin distinguir mayúsculas
(`unique(lower(nombre))`).

| Tabla | Columnas | Reglas |
|---|---|---|
| `usuario` | usuario (único, minúsculas), nombre, hash, rol check(`admin`,`operador`,`consulta`), activo, debe_cambiar_clave, intentos_fallidos ≥ 0, bloqueado_hasta null, creado_en | se desactiva, no se anula |
| `usuario_ip` | usuario_id, red `cidr`, descripcion, activo, creado_por/en | IP suelta = /32 o /128 |
| `sesion` | usuario_id, token_hash (único), ip, creada_en, ultimo_uso, cerrada_en null, motivo_cierre null | |
| `acceso_log` | usuario_id null, usuario_intentado, ip `inet`, resultado check(`ok`,`clave_incorrecta`,`usuario_inexistente`,`ip_rechazada`,`bloqueado`,`inactivo`,`limite_ip`,`sesion_ip_rechazada`), ruta, creado_en | append-only; índice `(ip, creado_en)` |
| `estado_legajo` / `tipo_interaccion` | nombre, orden, activo | catálogos |
| `tipo_documento` | nombre, obligatorio, vigencia_dias null check(> 0), multiples_archivos, activo | catálogo |
| `contador_legajo` | anio (pk), ultimo ≥ 0 | §2.1 |
| `legajo` | anio, correlativo > 0, numero (generada: `anio \|\| '-' \|\| lpad(correlativo,4,'0')`), fecha_deteccion, observacion, estado_id, creado_por/en | `unique(anio, correlativo)`; **no se anula** (para eso está el estado) |
| `cedula` | legajo_id, numero (check sólo dígitos), nombres, apellidos, fecha_nacimiento null, fecha_emision null, es_original, observacion, creado_por/en, anulado_* | índice único parcial `(legajo_id) where es_original and anulado_en is null`; índice `(numero)` |
| `documento` | legajo_id, tipo_id, fecha_emision, observacion, version_de null (**único**), creado_por/en, anulado_* | §2.3 |
| `documento_archivo` | documento_id, orden > 0, path_relativo (único), nombre_original, mime check(pdf/jpeg/png), bytes > 0, sha256 | `unique(documento_id, orden)` |
| `interaccion` | legajo_id, tipo_id, fecha, nota (check no vacía), usuario_id, estado_anterior_id null, estado_nuevo_id null, creado_en, anulado_* | §2.2 |
| `solicitud_documento` | interaccion_id, legajo_id, tipo_documento_id, documento_recibido_id null | §2.3 |
| `auditoria` | usuario_id null, ip, entidad, entidad_id, accion check(`alta`,`cambio`,`anulacion`,`vista`,`descarga`,`login_admin`), antes jsonb, despues jsonb, creado_en | append-only |

### 2.1 Numeración
- El año sale de la fecha de alta en Asunción.
- En la transacción del alta:
  `INSERT INTO contador_legajo (anio, ultimo) VALUES ($1, 1) ON CONFLICT (anio) DO UPDATE SET ultimo = contador_legajo.ultimo + 1 RETURNING ultimo`.
  Es atómico, incluso con el primer legajo del año. Si la transacción falla, el contador vuelve atrás, así que no
  hay huecos en el caso normal, pero tampoco se garantiza que no los haya.
- **El alta de un legajo exige al menos una cédula en la misma transacción.** Puede ser una sola y sin original
  marcada. Lo controla el servicio y lo cubre un test.
- Estado inicial: el estado activo de menor `orden`.

### 2.2 Estado e interacciones
- `legajo.estado_id` es la fuente de verdad y **sólo cambia por un trigger** `AFTER INSERT ON interaccion` con
  `estado_nuevo_id` no nulo. El trigger es `SECURITY DEFINER`, de `legajos_owner`, y hace lo siguiente:
  1. bloquea el legajo (`FOR UPDATE`);
  2. exige `estado_anterior_id = legajo.estado_id`; si no coincide, falla con un código propio y la API lo devuelve como conflicto;
  3. actualiza el estado.
- `legajos_app` **no tiene `UPDATE` sobre `legajo.estado_id`**: se le dan grants por columna.
- Si se cambia de estado, la nota es obligatoria por el check de `interaccion`.
- **Anular una interacción no toca el estado.** Para corregirlo se registra otra interacción.
- Una interacción no se edita: `legajos_app` sólo puede hacer `UPDATE` de las columnas `anulado_*`.

### 2.3 Documentos, versiones y solicitudes
- **Cardinalidad:** todo documento tiene al menos 1 archivo. Si el tipo no admite múltiples, exactamente 1. Lo
  controla el servicio en la misma transacción que la subida, más un test.
- **Versiones, al reemplazar:**
  1. bloquear el anterior (`FOR UPDATE`) y exigir que esté vivo y sea del **mismo legajo y tipo**. Lo controla un
     trigger `BEFORE INSERT`;
  2. crear el nuevo con `version_de = anterior`;
  3. anular el anterior con el motivo "reemplazado por <id>".

  Todo en una transacción. `version_de` es único, así que no hay ramas. Los documentos son inmutables (no hay
  `UPDATE` de `version_de`), así que no hay ciclos. Los archivos anteriores se conservan.
- **Solicitudes:**
  - una interacción puede pedir N tipos, y cada uno da una fila.
  - Al cargar un documento, el operador elige **qué solicitudes pendientes de ese tipo y de ese legajo** quedan
    satisfechas; la UI preselecciona la más antigua. Eso se guarda en `documento_recibido_id`.
  - Un trigger valida que el documento sea del mismo legajo y del mismo tipo.
  - Estado **derivado**: es `recibida` si `documento_recibido_id` apunta a un documento vivo. Si no, es `pendiente`.
    Anular el documento la devuelve a pendiente, aunque haya otro documento del tipo.
  - Al **reemplazar** un documento, sus solicitudes pasan a apuntar a la versión nueva, en la misma transacción.
- **Vencimiento**, derivado: `fecha_emision + vigencia_dias` del tipo **actual**, porque un cambio de vigencia
  rige para todo. Se muestra "Vencido" **sólo al ver el documento**.
- **Faltantes:** tipos obligatorios **activos** sin ningún documento vivo en el legajo.
- **Catálogos desactivados:** no se ofrecen para cargas nuevas y se siguen mostrando con su nombre en el historial.

### 2.4 Permisos de PostgreSQL (append-only real)
- `legajos_app` no es dueño de ninguna tabla, no es miembro de `legajos_owner` y no tiene `TRUNCATE`, `DELETE`,
  `REFERENCES` ni `TRIGGER`.
- `acceso_log` y `auditoria`: sólo `SELECT` e `INSERT`.
- El resto: `SELECT` e `INSERT`, más `UPDATE` **por columna** sólo donde hace falta (anulación, datos editables,
  `usuario.*` de bloqueo).
- Las funciones `SECURITY DEFINER` fijan `search_path`.
- Un test prueba los permisos efectivos con `has_table_privilege` y `has_column_privilege`, e intenta
  `UPDATE`/`DELETE`/`TRUNCATE` → 42501.

## 3. Seguridad

### 3.1 IP del cliente — sólo detrás de Nginx
- La app escucha en `127.0.0.1` (`next start -H 127.0.0.1`) y el puerto se cierra en `ufw`. Nginx es el único
  punto de entrada y hace lo siguiente:
  - **sobrescribe** `X-Real-IP $remote_addr`;
  - borra `X-Forwarded-For` (`proxy_set_header X-Forwarded-For ""`);
  - fija `Host $host`.
- La app lee **sólo `X-Real-IP`**, desde `headers()`, en páginas, Actions y handlers. No hay fallback al socket.
- Si el header falta o es inválido → 403 y registro en `acceso_log`.
- Normaliza con `ipaddr.process`, que convierte IPv4-mapped en IPv4, y compara con `ipaddr.parseCIDR` +
  `match`, nunca por texto.
- En desarrollo y tests el header se inyecta. La guía de instalación documenta el aislamiento y una comprobación
  con `curl` desde fuera.

### 3.2 Autorización en cada operación
- `src/server/auth.ts` exporta `requerirSesion({ permiso, mutacion })`. Devuelve un `Contexto` con un **tipo
  marcado** (branded), que sólo puede construir esa función.
- Todos los servicios de `src/server/servicios` reciben `Contexto` como primer argumento, así que no se pueden
  llamar sin pasar por el guard.
- Cada servicio exige su permiso explícito con `puede(ctx, 'documento.anular')` y similares. La matriz de
  rol × permiso vive en un solo archivo y tiene test.
- Lo que hace en cada llamada, sin caché entre requests:
  1. lee la cookie;
  2. busca la sesión viva y no vencida;
  3. comprueba que el usuario esté activo y no bloqueado;
  4. comprueba que la IP esté en alguna `usuario_ip` activa;
  5. comprueba el permiso;
  6. si es una mutación, comprueba el `Origin` (§3.5).

  Se invoca **antes** de cualquier lectura o escritura, en cada página de `(app)` (no en layouts), cada route
  handler y cada Server Action.
- Si falla, lanza una redirección a `/logout?motivo=…`. Ese route handler borra la cookie y cierra la sesión,
  porque un Server Component no puede borrar cookies.
- Hay e2e (L10) contra la app real: revocar la IP de un usuario logueado → la siguiente página, Action y
  descarga se rechazan.

### 3.3 Sesiones
- Token aleatorio de 32 bytes. En la base va sólo su SHA-256.
- Cookie `HttpOnly`, `SameSite=Lax`, `Path=/` y **`Secure` obligatoria en producción**, lo que requiere HTTPS (§6).
- Vencimiento: 8 h de inactividad y 12 h absolutas.
- `ultimo_uso` se actualiza de forma atómica:
  `UPDATE … SET ultimo_uso = now() WHERE id = $1 AND cerrada_en IS NULL AND ultimo_uso > now() - interval '8 hours' RETURNING …`.
- El logout cierra la sesión. Cambiar la clave, la recuperación del admin o desactivar al usuario cierran **todas**
  sus sesiones.

### 3.4 Login y bloqueos
- Contraseñas de al menos **10 caracteres**. El admin la asigna y el usuario **la cambia en el primer ingreso**
  (`debe_cambiar_clave`).
- Orden:
  1. límite por IP: 20 fallos desde esa IP en 15 min, contados en `acceso_log` → `limite_ip`;
  2. el usuario existe y está activo;
  3. bloqueo de cuenta;
  4. IP permitida;
  5. clave.
- Si el usuario no existe, igual se verifica contra un hash señuelo, para que el tiempo de respuesta sea el mismo.
- Contador por cuenta, en un solo `UPDATE`:
  `intentos_fallidos = intentos_fallidos + 1, bloqueado_hasta = CASE WHEN intentos_fallidos + 1 >= 5 THEN now() + interval '15 min' END`.
  Con un login correcto vuelve a 0.
- Respuesta siempre genérica. Todo resultado va a `acceso_log`, sin contraseñas ni tokens.

### 3.5 CSRF
- `APP_ORIGIN` va en la configuración (por ejemplo `https://legajos.institucion.local`).
- Las mutaciones exigen un header `Origin` **exactamente igual** a `APP_ORIGIN`. Un `Origin` ausente o `null` → 403.
  Aplica a route handlers (subida, logout por POST) y Server Actions: el guard lo comprueba además del chequeo
  propio de Next. `serverActions.allowedOrigins` no se toca.

### 3.6 Archivos
- **Subida:** route handler `POST /api/documentos` (runtime Node). Pasos:
  1. autenticar y autorizar **antes de leer el cuerpo**;
  2. parsear `request.body` en stream con `busboy`, con estos límites:
     - `fileSize` de 20 MB, con corte durante la recepción;
     - hasta 10 archivos;
     - campos chicos;
  3. escribir cada archivo en `ARCHIVOS_DIR/.tmp/<uuid>` con `wx` (exclusivo), calculando el sha256 en el stream;
  4. tipo: `file-type` sobre los primeros bytes, que sólo admite pdf/jpeg/png, más una verificación estructural:
     - PDF: cabecera `%PDF-` y `%%EOF` al final;
     - JPEG y PNG: dimensiones legibles con `image-size`;
     - lo desconocido o truncado se rechaza;
  5. publicar con `link(tmp, final)`, que falla si el destino existe, así que nunca sobrescribe, y después `unlink(tmp)`;
  6. transacción en la base;
  7. si la base falla, se borran los finales recién creados.

  Si se aborta, se limpian los temporales. `scripts/archivos-huerfanos.ts` lista lo que está en disco sin fila en
  la base y viceversa. Nginx tiene `client_max_body_size 205m`.
- **Rutas:**
  - `<legajo_id>/<documento_id>/<uuid>.<ext>`, todo generado por el servidor;
  - directorios `0700` creados por la app;
  - contención con `path.relative(raiz, realpath(p))`, que no debe empezar con `..` ni ser absoluta;
  - `lstat` rechaza symlinks.
- **Descarga y vista:** `GET /api/archivos/[id]` busca por id y comprueba guard + permiso. Responde con:
  - el MIME validado de la base;
  - `Content-Disposition` (`inline` para ver, `attachment` con `?descargar=1`), con el nombre saneado;
  - `X-Content-Type-Options: nosniff`;
  - `Cache-Control: private, no-store`.

  Registra `vista` o `descarga` en la auditoría.

### 3.7 Recuperación del admin
`pnpm admin:recuperar <usuario> <ip>` corre en el servidor con el rol owner. Hace lo siguiente:
- genera una clave temporal, la imprime una vez y marca `debe_cambiar_clave`;
- agrega la IP;
- cierra las sesiones;
- registra `login_admin` en la auditoría.

## 4. Despliegue (Ubuntu, red interna)
- Node 22 + PM2 + Nginx + PostgreSQL local, con `ARCHIVOS_DIR=/srv/legajos/archivos` (`0700`, usuario del servicio).
- `scripts/deploy.sh`, con las filosofías de siempre: pull, install, migrate (rol owner), build y restart.
- Ejemplo de Nginx con los headers de §3.1 y el `client_max_body_size`.
- **Backup:** `pg_dump` + `rsync` de `ARCHIVOS_DIR` en el mismo horario. Restaurar los dos juntos y después correr
  `archivos-huerfanos` para comprobar la consistencia.

## 5. Plan de tareas

| # | Tarea | Implementa | Audita |
|---|---|---|---|
| L01 | Esqueleto: Next 15.5, TS, lint, vitest, Drizzle, `compose.test.yml` con los dos roles, `pnpm verificar` | agy | arquitecto |
| L02 | Esquema + migraciones + grants por rol/columna + triggers (§2.2, §2.3) + contador + seeds de catálogos; tests de constraints, triggers y permisos efectivos | agy | codex |
| L03 | Base compartida: `Contexto`, matriz de permisos, servicio de auditoría, lectura de IP, CSRF | agy | codex |
| L04 | Login, sesiones, bloqueos, cambio de clave obligatorio, logout, `acceso_log`, CLI de recuperación | agy | codex |
| L05 | Legajos y cédulas: alta con numeración, original, relacionados y aviso, búsqueda | agy | codex |
| L06 | Interacciones, cambio de estado y solicitudes (derivación) | agy | codex |
| L07 | Archivos: subida en stream, validación, publicación, versiones, descarga y vista, huérfanos | agy (después de L05) | codex |
| L08 | Pantallas de operación: login, cambio de clave, buscador, legajo (cédulas, relacionados, documentos con vencido, faltantes, historial, solicitudes) | opencode | arquitecto |
| L09 | Admin: usuarios + IPs, catálogos, visor de accesos y auditoría (en paralelo con L08) | opencode | arquitecto |
| L10 | e2e Playwright: flujo completo, revocación de IP en página/Action/descarga, CSRF, traversal, permisos por rol | agy | codex |
| L11 | Deploy: `deploy.sh`, Nginx, backup y restauración, guía de instalación | agy | codex |

L01 → L02 → L03 → L04 → (L05 → L06 ∥ L07) → (L08 ∥ L09) → L10 → L11. L06 y L07 no comparten archivos.

## 6. Pendiente con la institución (no bloquea hasta L11)
- **HTTPS interno**, con certificado de una CA propia o autofirmado: hace falta para la cookie `Secure`.
- ¿Se permite Docker? (opcional)

## 7. Decisiones del 2026-10-04 (además de los requisitos v0.3)
- Anular una interacción **no** cambia el estado.
- **El legajo no se anula.**
- Las vistas y descargas **se auditan**.
- Contraseña de 10 caracteres como mínimo, con cambio en el primer ingreso.
- Si se repite un número de cédula, sea en el mismo legajo o en otro, **se avisa, no se bloquea**.

## 8. Trazabilidad

| Requisito | Modelo | Servicio | Pantalla | Prueba |
|---|---|---|---|---|
| Legajo con número y estado | legajo, contador | L05 | L08 | L02, L05 |
| Cédulas original y duplicados | cedula | L05 | L08 | L02, L05 |
| Aviso de cédula repetida y relacionados | índice `cedula.numero` | L05 | L08 | L05 |
| Tipos dinámicos y faltantes | tipo_documento | L05/L07 | L08/L09 | L07 |
| Vigencia y aviso al ver | derivado | L07 | L08 | L07 |
| Varios archivos y versiones | documento(_archivo) | L07 | L08 | L02, L07 |
| Path y no binarios en la base | documento_archivo | L07 | — | L07 |
| Historial, estado y solicitudes | interaccion, solicitud | L06 | L08 | L02, L06 |
| Usuario y contraseña, roles | usuario, sesion | L03/L04 | L08/L09 | L04, L10 |
| IP por usuario | usuario_ip | L03/L04 | L09 | L04, L10 |
| Registro de accesos | acceso_log | L04 | L09 | L04 |
| Nada se borra y auditoría | grants + auditoria | L03 | L09 | L02, L10 |

## 9. Revisión tras la segunda auditoría de codex (manda sobre §1–§8)
Los números entre corchetes remiten a `informes/diseno.auditoria2.md`.

**Modelo**

1. **Nulabilidad explícita [3].**
   - Todas las columnas son `NOT NULL` salvo estas: `observacion`, `descripcion`, `motivo_cierre`, `cerrada_en`,
     `bloqueado_hasta`, `version_de`, `documento_recibido_id`, `estado_anterior_id`, `estado_nuevo_id`,
     `fecha_nacimiento`, `fecha_emision` de `cedula`, `acceso_log.usuario_id`, `acceso_log.ip`,
     `auditoria.usuario_id`, `antes`/`despues` y las `anulado_*`.
   - Las `anulado_*` llevan un check "las tres o ninguna".
   - `acceso_log.ip` es nula para registrar `ip_invalida`, que se agrega al check de `resultado`.
2. **Número [2].**
   - `numero text` generado: `anio::text || '-' || lpad(correlativo::text, greatest(4, length(correlativo::text)), '0')`;
   - `UNIQUE(numero)`;
   - check `anio between 2000 and 2100`.
3. **Estado [4].**
   - Check `(estado_anterior_id IS NULL) = (estado_nuevo_id IS NULL)` y `estado_nuevo_id IS DISTINCT FROM estado_anterior_id`.
   - El trigger compara con `IS DISTINCT FROM`.
   - El servicio escribe la auditoría del cambio en la misma transacción que la interacción.
4. **Solicitudes [1].**
   - Un trigger en `solicitud_documento` exige que `legajo_id` sea el de su interacción, y que el documento
     recibido sea del mismo legajo y del mismo tipo.
   - El reemplazo de un documento bloquea con `FOR UPDATE` sus solicitudes antes de reapuntarlas.
5. **Versiones [5].**
   - `documento.legajo_id`, `tipo_id` y `version_de` no tienen grant de `UPDATE`: son inmutables.
   - Hay un trigger de mismo legajo y mismo tipo.
6. **Funciones privilegiadas [6, nuevo].**
   - Las funciones `SECURITY DEFINER` viven en el esquema `legajos`, de `legajos_owner`, con
     `SET search_path = legajos, pg_temp` y todas las referencias calificadas.
   - `REVOKE CREATE ON SCHEMA public, legajos FROM PUBLIC`.
   - `REVOKE EXECUTE ON FUNCTION … FROM PUBLIC`, y se le da sólo a quien la necesita; las funciones de trigger no
     se otorgan.
   - Test de permisos efectivos **heredados**: `pg_has_role` y `has_function_privilege`.
   - **Los tests de servicios corren conectados como `legajos_app`.**
7. **Drizzle con grants por columna [nuevo].** Todo `update().set({...})` lista columnas explícitas y nunca
   recibe una fila completa. Lint: una regla `no-restricted-syntax` contra `set(` con spread.

**Sesión y acceso**

8. **Guard sin efectos de navegador [nuevo, 9, 13].**
   - Sesión inválida (vencida, IP revocada, usuario inactivo): el guard **la cierra en el servidor** con un
     `UPDATE` y después:
     - en páginas: `redirect('/login')`, sin tocar la cookie (queda huérfana e inofensiva);
     - en Actions y API: 401.
   - Si sólo falta el permiso, responde 403 y **no cierra** la sesión.
   - El logout voluntario es **sólo POST** con `Origin` y no hay logout por GET.
9. **Sesión atómica [nuevo].** La validación es el propio `UPDATE … SET ultimo_uso = now() WHERE token_hash = $1
   AND cerrada_en IS NULL AND ultimo_uso > now() - 8h AND creada_en > now() - 12h RETURNING usuario_id`. Sin fila,
   la sesión es inválida.
10. **Cambio de clave obligatorio [nuevo].** Si `debe_cambiar_clave`, el guard sólo permite `cambiar_clave` y
    `logout`. Al cambiar la clave se cierran todas las sesiones y se emite una nueva.
11. **Bloqueos [10, nuevo].**
    - **Por IP:** tabla `limite_ip(ip inet pk, ventana_inicio, fallos)`, actualizada con un solo
      `INSERT … ON CONFLICT DO UPDATE`: si `ventana_inicio < now() - 15 min`, la ventana se reinicia; si no,
      `fallos + 1`. Devuelve `fallos`, y con más de 20 la respuesta es `limite_ip`.
    - **Por cuenta:** el `UPDATE` reinicia `intentos_fallidos` cuando `bloqueado_hasta < now()` antes de sumar.
      Con un login correcto vuelve a 0 sólo si no hubo un bloqueo nuevo en el medio
      (`WHERE bloqueado_hasta IS NULL OR bloqueado_hasta < now()`).
12. **Tiempo de respuesta constante [nuevo].** Después del límite por IP, **siempre** se ejecuta una verificación
    argon2: con el hash real si el usuario existe y, si no, con un señuelo de los mismos parámetros, generado al
    arrancar. Recién después se evalúan inactivo, bloqueado, IP y clave. La respuesta es la misma en todos los casos.

**Archivos**

13. **Proxy y stream [11, nuevo].**
    - Nginx: `proxy_request_buffering off` y `client_max_body_size 205m` **sólo** en `/api/documentos`.
    - Handler: `Readable.fromWeb(request.body)` → `busboy`, con límites `fileSize` 20 MB, `files` 10, `fields` 20,
      `parts` 30 y `fieldSize` 10 KB.
    - Si un archivo emite `limit`, la carga **se aborta entera**: se destruye el stream, se responde 413 y se
      borran los temporales. Con `filesLimit`, `fieldsLimit` o `partsLimit` → 413.
    - Se espera el `finish` y el `close` de cada escritura, con `fsync`, antes de publicar.
14. **Validación real [14, nuevo].**
    - Las imágenes se **decodifican completas** con `sharp` (`failOn: 'error'`, `limitInputPixels` de 50 Mpx).
    - Los PDF se **parsean** con `pdf-lib` (`load` sin `ignoreEncryption`; si está cifrado, se rechaza) y hay que
      leer el conteo de páginas. Hay un timeout.
    - Tests con un PDF falso que tiene los marcadores y con un JPEG y un PNG truncados que conservan la cabecera.
15. **Publicación por etapas [12, nuevo].**
    1. `.tmp` con `wx` y `fsync`;
    2. `link` al final y `fsync` del directorio;
    3. transacción en la base;
    4. `unlink` del tmp.

    Si la base **falla de forma explícita**, se borran los finales. Si el `COMMIT` es ambiguo o falla el `unlink`,
    **no se borra nada**. `archivos-huerfanos` lo informa, y borra sólo los tmp de más de 24 h y los finales sin
    fila de más de 24 h, siempre con `--aplicar`.

**Operación**

16. **Backup consistente [nuevo].** `scripts/backup.sh` hace lo siguiente:
    1. activa el modo mantenimiento: un archivo que el guard consulta, con el que las mutaciones responden 503;
    2. corre `pg_dump` y `rsync` de `ARCHIVOS_DIR`;
    3. desactiva el modo mantenimiento.

    Ventana nocturna. La guía de L11 incluye una **prueba de restauración** que corre `archivos-huerfanos` sin
    diferencias.
17. **Next [17].** Versión exacta fijada en el lockfile (`15.5.x` con parche concreto al crear L01). El middleware
    sólo redirige a `/login` si falta la cookie: no decide nada de seguridad.

**Cobertura**

18. **Cobertura [16].** La auditoría administrativa (usuarios, IPs, catálogos) la escribe el servicio, en L03 y
    L09. Que la obligatoriedad aplique también hacia atrás es un test de L07: marcar un tipo como obligatorio hace
    que aparezca como faltante en legajos viejos.
19. **Plan [18].**
    - Los contratos de servicios (tipos de entrada y salida) de L05, L06 y L07 se escriben en L03, antes de
      paralelizar.
    - La configuración de Nginx y los límites se adelantan como borrador en L03 (`deploy/nginx.conf.example`).
    - L11 cierra con la prueba de restauración.

## 10. Cierre de la tercera auditoría (manda sobre §9)
1. **Check de estado.** `(estado_anterior_id IS NULL AND estado_nuevo_id IS NULL) OR (estado_anterior_id IS NOT NULL
   AND estado_nuevo_id IS NOT NULL AND estado_anterior_id <> estado_nuevo_id)`.
2. **Solicitudes, un solo candado.** Toda escritura de `documento_recibido_id` (asignar, o reapuntar al reemplazar)
   sigue este orden:
   1. bloquea primero la fila del **documento** destino (y, al reemplazar, la del anterior) con `FOR UPDATE`, en
      orden de id;
   2. después de tomar el lock, verifica que el destino esté vivo.

   El reemplazo bloquea el mismo documento, así que las dos operaciones se serializan. Hay un test con dos
   transacciones concurrentes.
3. **Backup con escritores detenidos.**
   1. `scripts/backup.sh` toma `flock /var/lock/legajos-mantenimiento`;
   2. `pm2 stop legajos`, que espera el cierre ordenado y drena los requests;
   3. `pg_dump` + `rsync`;
   4. `pm2 start legajos`.

   No hay otros escritores: los scripts (`admin-recuperar`, `archivos-huerfanos --aplicar`) toman el mismo `flock`
   y se niegan a correr con la app arriba. Se elimina el modo mantenimiento de §9.16.
4. **Límite por IP, reservar y devolver.** Antes de verificar, un `INSERT … ON CONFLICT DO UPDATE` atómico suma 1
   a `intentos` en la ventana vigente y devuelve el valor:
   - con más de 20 → `limite_ip`, sin verificar;
   - si el login sale bien → `intentos - 1` (devolución).

   Así los concurrentes no superan la cuota y los éxitos no la consumen.
5. **Stream completo.**
   - Un contador de bytes sobre el stream de entrada corta a 205 MB con 413.
   - Se rechazan los campos con `nameTruncated`/`valueTruncated` y los archivos con `truncated`.
   - Al abortar, en este orden:
     1. `unpipe`;
     2. `destroy` de cada escritura;
     3. `await` de su `close`;
     4. recién entonces `unlink` de los temporales.
6. **Parseo aislado.**
   - El PDF se valida en un `worker_thread` con `resourceLimits` (`maxOldGenerationSizeMb: 256`) y
     `worker.terminate()` a los 15 s.
   - Las imágenes, con `sharp` (`limitInputPixels`, `timeout: { seconds: 15 }`).
   - Un archivo que excede cualquiera de los dos → 422.
7. **Limpieza coordinada.** `archivos-huerfanos --aplicar` sólo corre con el `flock` y la app detenida, dentro de
   la ventana de backup, y **vuelve a consultar la base** inmediatamente antes de borrar cada archivo. Sin
   `--aplicar`, sólo informa y puede correr en cualquier momento.

## 11. Cierre de la cuarta auditoría (manda sobre §10)
1. **Backup verificado.** Después de `pm2 stop legajos` (`kill_timeout` 30 s), el script **comprueba** dos cosas:
   - que no quede el proceso (`pm2 pid legajos` vacío);
   - que no haya conexiones del rol de la app:
     `SELECT count(*) FROM pg_stat_activity WHERE usename = 'legajos_app'` = 0.

   Si alguna falla, **aborta**: no hace backup, vuelve a levantar la app y sale con error. Si un request murió a
   mitad de camino, Postgres revierte su transacción, y un archivo publicado sin fila es un huérfano que
   `archivos-huerfanos` detecta. El backup queda consistente.
2. **Devolución en la misma ventana.** La reserva devuelve `ventana_inicio`. La devolución es
   `UPDATE limite_ip SET intentos = intentos - 1 WHERE ip = $1 AND ventana_inicio = $reservada AND intentos > 0`.
   Si la ventana cambió, no devuelve nada.
3. **Validación en un proceso hijo con límite total.**
   - Cada archivo se valida en un **proceso hijo**:
     `prlimit --as=536870912 -- node --max-old-space-size=256 scripts/validar-archivo.js <tmp>`.
     `prlimit --as` limita **toda** la memoria virtual, incluidos los buffers y la memoria nativa de `sharp`.
   - El padre lo mata (`SIGKILL`) a los 20 s.
   - Si el hijo sale con un código distinto de 0, si muere por una señal o si se pasa del tiempo → 422.
   - El hijo sólo lee el tmp y escribe en stdout un JSON (`{mime, paginas|ancho, alto}`).

## 12. Cierre de la quinta auditoría (manda sobre §11)
1. **Validación con herramientas nativas, no con Node.** V8 no arranca con `RLIMIT_AS` bajo. El proceso hijo es
   una herramienta nativa que sí respeta el límite:
   - **PDF:** `prlimit --as=536870912 --cpu=20 -- qpdf --check <tmp>`, que valida la estructura completa. Un PDF
     cifrado se rechaza con `qpdf --is-encrypted`. Las páginas salen de `qpdf --show-npages`.
   - **JPEG/PNG:** `prlimit --as=536870912 --cpu=20 -- vips avg <tmp>`, que **decodifica todos los píxeles**
     (falla con un archivo truncado). Ancho y alto salen de `vipsheader -f width|height`.
   - El padre, en Node, además lo mata a los 20 s de reloj.
   - Si sale con un código distinto de 0, si muere por una señal o si se pasa del tiempo → 422.
   - `sharp` y `pdf-lib` salen del diseño.
   - Dependencias del sistema (Ubuntu): `apt install qpdf libvips-tools`. En desarrollo también, y L01 las chequea.
   - Tests con válidos reales (PDF, JPEG, PNG) **y** con inválidos (PDF falso con marcadores, JPEG y PNG truncados).
2. **Detención verificada.** El backup comprueba tres cosas, y si una consulta da error o alguna condición no se
   cumple, aborta:
   - `pm2 jlist` → la app `legajos` con `pm2_env.status == "stopped"`;
   - no hay ningún proceso vivo del servidor: `pgrep -u <usuario_servicio> -f "next start"` vacío;
   - `SELECT count(*) FROM pg_stat_activity WHERE usename = 'legajos_app'` = 0.

## 13. Cierre de la sexta auditoría (manda sobre §12)
1. **Imágenes:** `vips avg "<tmp>[fail_on=error]"`. Por defecto `fail_on` es `none` y aceptaría truncados.
2. **PDF, en este orden:**
   1. `qpdf --check <tmp>`: 0 = ok; cualquier otro código → 422;
   2. `qpdf --is-encrypted <tmp>`: **2 = sin cifrar (ok)**, **0 = cifrado → 422**, otro código → 422;
   3. `qpdf --show-npages <tmp>`: 0 = ok.

   La regla "un código distinto de 0 → 422" **no** se aplica a `--is-encrypted`.
3. **Puerta de L07:** codex comprobó qpdf 12.3.2 bajo `--as=512MiB` (válido → 0, truncado → 2). Con vips no se
   pudo, porque no está instalado. **L07 no se aprueba** sin un test que corra con `prlimit` real sobre un JPEG y
   un PNG válidos (→ ok) y truncados (→ 422). Si `vips` no arranca con ese límite, se sube a 1 GiB y se registra
   en el informe.

## 14. Correcciones posteriores
1. **§9.1 omitió `tipo_documento.vigencia_dias`** de la lista de columnas que admiten nulos. Los requisitos
   (§2.3) la definen **opcional**, y mandan: es nullable (L02a).

## 15. Despliegue real (2026-10-05) — reemplaza §4
Servidor `192.168.5.104`: CentOS 7, kernel 3.10, glibc 2.17, 1 CPU y 1 GB. Comparte con Apache/PHP en el 80 y
con PostgreSQL 13, que tiene otras bases y no se usa.
- **Docker 26.1.4**. `container-selinux` vino de vault.centos.org porque los mirrors de *extras* ya no existen.
  App en `fiscalizacion:<sha>` (Node 22, qpdf 11.3, vips 8.14, uid 10001) y **`postgres:16-bookworm`**:
  alpine falla por seccomp en el kernel 3.10.
- **Apache 2.4.6** con `mod_ssl`, certificado autofirmado con SAN `IP:192.168.5.104` (hasta 2031) en
  `/etc/pki/fiscalizacion/`, `Include conf.d/fiscalizacion.inc` dentro del vhost 443 y
  `conf.d/fiscalizacion-redirect.conf` para que sólo `/fiscalizacion` pase del 80 al 443.
  - Respaldo: `conf.d/ssl.conf.antes-fiscalizacion`.
  - `X-Real-IP` vía `SetEnvIf Remote_Addr`, porque 2.4.6 no tiene `expr=`.
- Datos en `/srv/fiscalizacion/{pgdata,archivos,.env}`. El `.env` se generó en el servidor (600) y sus claves
  nunca salieron de ahí.
- firewalld: se agregó `https`. Efecto colateral: el sitio PHP también responde por HTTPS con el mismo contenido.
- Deploy: `scripts/deploy.sh` desde la PC: build local, `docker save | ssh docker load` y `compose up`.

## 16. Modelo v2: legajo por cédula y trámites (manda sobre §2, §2.1–§2.3, §9.2–§9.5 y §10.1–§10.2 en lo que se opongan)

### 16.1 Tablas
| Tabla | Columnas | Reglas |
|---|---|---|
| `legajo` | cedula (texto, sólo dígitos, **único**), nombres, apellidos, fecha_nacimiento null, fecha_emision null, observacion null, creado_por/en | 1 por número de cédula. **No se anula**; los datos son editables y auditados |
| `tipo_tramite` | nombre (único sin distinguir mayúsculas), orden, activo | catálogo |
| `tipo_tramite_documento` | tipo_tramite_id, tipo_documento_id, activo | PK compuesta; define los obligatorios por tipo de trámite |
| `contador_tramite` | anio pk, ultimo | ex `contador_legajo` |
| `tramite` | anio, correlativo, numero (generada §9.2), tipo_id, fecha_deteccion, observacion, estado_id, creado_por/en | **no se anula** (para eso está el estado "Archivado") |
| `tramite_legajo` | tramite_id, legajo_id, es_original, creado_por/en, anulado_* | único `(tramite_id, legajo_id)` vivo; original única **por trámite** (índice parcial vivo); al menos 1 vivo por trámite (servicio) |
| `interaccion` | **tramite_id** (antes legajo_id), lo demás igual | el trigger de estado actúa sobre `tramite` |
| `solicitud_documento` | **tramite_id**, interaccion_id, tipo_documento_id, documento_recibido_id | el documento recibido tiene que ser del tipo y de un legajo **vinculado (vivo) al trámite** |
| `documento` | legajo_id, **tramite_id null** (procedencia), tipo_id, fecha_emision, … | si `tramite_id` no es nulo, el legajo tiene que estar vinculado a ese trámite (trigger). Versiones: mismo legajo y tipo |
| `tipo_documento` | se elimina `obligatorio` (pasa a `tipo_tramite_documento`) | |
| `cedula` | **se elimina**: sus datos pasan a `legajo` y la original a `tramite_legajo` | |

### 16.2 Reglas
- **Alta de trámite**: tipo activo, fecha de detección y **al menos un legajo**, en la misma transacción.
  - Los legajos se eligen existentes o se crean al vuelo por número de cédula. Si el número ya existe, **se usa el
    legajo existente**: nunca hay duplicado.
  - Número `AAAA-NNNN` con el contador atómico (§2.1) y el año en Asunción.
  - Estado inicial: el activo de menor orden.
- **Vincular y desvincular** legajos de un trámite: desvincular = anular el vínculo, con motivo y sólo admin. No se
  puede dejar un trámite sin vínculos vivos.
- **Marcar original**: dentro del trámite, con `FOR UPDATE` de los vínculos (antes era por legajo).
- **Faltantes del trámite**: los `tipo_tramite_documento` activos de su tipo sin un **documento vivo de ese tipo en
  alguno de sus legajos vinculados**, cargado o no en este trámite, porque el legajo es un archivo permanente. Un
  documento vencido no cuenta como faltante; el aviso sigue estando sólo en el visor.
- **Legajo**: muestra sus datos, todos sus documentos (con el trámite de procedencia) y sus trámites (número, tipo,
  estado, con la marca original o duplicado en cada uno). **Relacionados** = otros legajos que comparten algún
  trámite vivo.
- **Búsqueda**:
  - legajos por número de cédula (prefijo) o por nombre o apellido (sin acentos);
  - trámites por número `AAAA-NNNN`, tipo, estado o cédula vinculada.
- Se mantiene todo lo de auth, IP, archivos, auditoría y admin. El admin suma el catálogo de tipos de trámite con
  sus documentos obligatorios.
- **Permisos nuevos**: `tramite.ver`, `tramite.crear`, `tramite.editar` y `tramite.vincular` (operador sí);
  `tramite.desvincular` (sólo admin). `legajo.*` se conserva para el archivo.

### 16.3 Migración
- **0003**, incremental. Producción no tiene datos de negocio: sólo admin, accesos y auditoría.
- Crea las tablas nuevas, traslada FKs, elimina `cedula`, `tipo_documento.obligatorio` y las columnas de caso de
  `legajo`, renombra el contador, y rehace triggers y grants por columna. Siembra "Múltiple cedulación" como tipo
  de trámite inicial.
- Antes de aplicarla en producción: `pg_dump`. La migración **falla a propósito** si encuentra filas en `legajo`,
  `cedula`, `documento` o `interaccion`, como red de seguridad.

### 16.4 Cierre de la auditoría del modelo v2 (manda sobre §16.1–§16.3)
**Decisiones de Emilio (2026-10-05):**
- **Número de cédula normalizado:** sólo dígitos y **sin ceros a la izquierda** (`0001234567` = `1234567`), tanto
  al guardar como al buscar. `UNIQUE` global y nunca parcial.
- **El legajo no se anula.** Si el número es incorrecto, **lo corrige el admin** (permiso `legajo.corregir_cedula`,
  con motivo y auditoría). Si choca con un legajo existente, da 409.
- **Faltantes:** satisface **cualquier documento vivo** del tipo en un legajo vinculado (vivo), sin importar de qué
  trámite vino. **Vencido sí satisface**: el aviso se ve sólo en el visor.
- **Desvincular** (sólo admin, con motivo):
  - los documentos quedan en el legajo con su `tramite_id` **histórico**;
  - las solicitudes de ese trámite satisfechas por documentos de ese legajo **vuelven a pendiente** (se pone
    `documento_recibido_id = null`), con auditoría y en la misma transacción.
- **"Múltiple cedulación"** se siembra **sin** documentos obligatorios hasta que llegue la lista.
- En la UI, un trámite sin original marcada muestra **"Original sin determinar"**. No se rotula a todos como duplicados.

**Integridad (auditoría de codex):**
1. **Un candado por trámite.** Vincular, desvincular, marcar original, registrar interacción, asignar solicitud y
   subir con `tramite_id` hacen **primero** `SELECT … FROM tramite WHERE id = $1 FOR UPDATE`. Después leen o
   recuentan y recién entonces escriben. Orden global de locks: trámite → documento(s) por id → solicitud(es) por id.
2. **Procedencia:** `documento.tramite_id` es **inmutable** (sin grant de UPDATE) y se valida **al cargar**: el
   vínculo tiene que estar vivo, bajo el candado del trámite. Una desvinculación posterior no lo invalida.
   **Reemplazo:** la versión nueva **hereda** el `tramite_id` del anterior y se admite aunque el vínculo ya no esté
   vivo (es histórico). Un reemplazo nuevo desde otro trámite crea un documento nuevo, no una versión.
3. **Solicitudes:** un trigger valida que la interacción sea del mismo trámite y que el documento sea del mismo
   tipo, de un legajo vinculado y esté **vivo**. Ahora `SELECT … FOR SHARE` del documento; antes aceptaba anulados.
4. **Unicidad:**
   - `tramite_legajo`: único `(tramite_id, legajo_id)` donde `anulado_en IS NULL`, original única por trámite viva
     y check de las tres columnas de anulación;
   - **revincular** un vínculo anulado crea una fila nueva;
   - **alta concurrente de un legajo** por número: `INSERT … ON CONFLICT (cedula) DO NOTHING` y después `SELECT`
     del existente.
5. **Migración 0003, en este orden:**
   1. red de seguridad: `RAISE` si hay filas en `legajo`, `cedula`, `documento`, `interaccion`,
      `solicitud_documento`, `documento_archivo` o `contador_legajo`, o algún `tipo_documento.obligatorio = true`;
   2. `DROP TRIGGER` de interacción/estado, solicitud y versión;
   3. `DROP` de constraints e índices dependientes, explícitos y **sin `CASCADE`**;
   4. `DROP TABLE cedula` y `contador_legajo`;
   5. en `legajo`: `DROP COLUMN numero` (la generada) y después `anio`, `correlativo`, `estado_id` y
      `fecha_deteccion`; `ADD` de `cedula`, `nombres`, `apellidos` y demás;
   6. crear `tipo_tramite`, `tipo_tramite_documento`, `contador_tramite`, `tramite` y `tramite_legajo`;
   7. en `interaccion` y `solicitud_documento`: `DROP` de la FK, `RENAME legajo_id TO tramite_id` y una FK nueva a
      `tramite`;
   8. `documento.tramite_id`;
   9. `tipo_documento DROP COLUMN obligatorio`;
   10. triggers nuevos (`SECURITY DEFINER` sólo el de estado; `search_path` fijo; `EXECUTE` revocado);
   11. **grants explícitos** para cada tabla nueva o modificada, con UPDATE por columna mínimo. Sin UPDATE en:
       `tramite.estado_id`, `tramite.numero/anio/correlativo`, `documento.tramite_id/legajo_id/tipo_id/version_de`,
       `tramite_legajo.tramite_id/legajo_id` y `legajo.cedula`. La corrección de la cédula usa una función
       `SECURITY DEFINER` `legajos.corregir_cedula(legajo, nueva, usuario, motivo, ip)`, que audita;
   12. seed de "Múltiple cedulación" con UUID fijo.

   Todo en **una transacción**. Antes, en producción: app detenida y `pg_dump`.
