Veredicto: CAMBIOS

Evaluación del diseño; no se modificaron archivos. §7 resuelve las decisiones adicionales del cliente.

| # | Hallazgo anterior | Estado | Resultado en v0.2 |
|---|---|---|---|
| 1 | Solicitudes | parcial | Vínculo explícito; falta validar legajo de la interacción y concurrencia al reemplazar. |
| 2 | Numeración | parcial | Contador correcto; la expresión del número trunca correlativos largos. |
| 3 | Integridad | parcial | Mejora constraints; sólo declara NOT NULL para FK y contradice nulabilidad de anulación. |
| 4 | Estado/interacciones | parcial | Lock y política de anulación definidos; faltan comparación segura y auditoría atómica. |
| 5 | Versiones | parcial | Cadena serializada; falta impedir cambios posteriores de legajo/tipo y coordinar solicitudes. |
| 6 | Append-only | parcial | Grants mejorados; faltan permisos heredados y cierre de funciones privilegiadas. |
| 7 | IP/proxy | parcial | Aislamiento correcto; IP ausente/inválida no cabe en el log `inet NOT NULL`. |
| 8 | Autorización | resuelto | Guard por operación, permisos explícitos y e2e de revocación. |
| 9 | Sesiones | parcial | Expiraciones definidas; UPDATE incompleto y logout contradictorio. |
| 10 | Bloqueos | parcial | Incremento atómico; límite IP concurrente y reinicio temporal sin resolver. |
| 11 | Streaming | parcial | Handler Node elegido; falta adaptación Web→Node y manejo explícito de límites. |
| 12 | Archivos | parcial | Publicación exclusiva correcta; recuperación y durabilidad incompletas. |
| 13 | CSRF | parcial | Origen configurado; logout redirigido contradice POST obligatorio. |
| 14 | Tipo real | no | Cabecera/EOF y dimensiones no validan integridad estructural. |
| 15 | Alcance agregado | resuelto | §7 confirma contraseña, auditoría y duplicados; legajo no anulable. |
| 16 | Cobertura | parcial | Matriz presente; falta explicitar auditoría administrativa y cambio retroactivo de obligatoriedad. |
| 17 | Next 15 | parcial | Menor definida; `15.5.x` no fija parche ni explicita middleware orientativo. |
| 18 | Plan | parcial | Base compartida adelantada; contratos L06/L07, límites tempranos y backup consistente pendientes. |

Hallazgos nuevos y regresiones — ALTA:

- **Estado (§2.2):** comparar con `=` permite que NULL eluda una comprobación implementada ingenuamente. Exigir ambos estados juntos, usar `IS DISTINCT FROM` y escribir auditoría del cambio en la misma transacción.
- **SECURITY DEFINER (§2.4):** “fijar search_path” no garantiza seguridad. Usar esquemas confiables y `pg_temp` al final, referencias calificadas, revocar CREATE en esos esquemas y EXECUTE público; probar permisos efectivos/heredados. [PostgreSQL](https://www.postgresql.org/docs/16/sql-createfunction.html).
- **Logout (§3.2/3.5):** redirigir desde una página produce GET, pero logout exige POST+Origin; GET con cierre abre logout CSRF. Ante sesión inválida, cerrar en servidor sin depender del navegador; página→login, API→401/403, logout voluntario→POST. Un permiso insuficiente no debe cerrar una sesión válida. [Next.js](https://nextjs.org/docs/app/guides/redirecting).
- **Bloqueos (§3.4):** COUNT seguido de INSERT admite superar el límite por IP concurrentemente; tras vencer el bloqueo, conservar ≥5 fallos provoca rebloqueo al primer error. Serializar contador/ventana por IP y resetear cuenta al vencer; coordinar login correcto con fallos concurrentes.
- **Hash señuelo (§3.4):** usuario inexistente ejecuta Argon2, mientras usuario existente inactivo/bloqueado/IP rechazada sale antes: permite enumeración temporal. Ejecutar una verificación de costo equivalente en todas esas ramas, después del límite IP, y fijar parámetros del señuelo.
- **Carga (§3.6):** busboy consume streams Node; adaptar con `Readable.fromWeb`, manejar `limit`, `truncated`, límites de archivos/campos/partes, cancelación y cierre de escrituras antes de publicar. Su límite recorta el archivo; no garantiza abortar toda la recepción. [Node](https://nodejs.org/docs/latest-v22.x/api/stream.html), [busboy](https://github.com/mscdex/busboy).
- **Validación (§3.6):** PDF falso con marcadores e imagen truncada con dimensiones pueden pasar. Sustituir heurísticas por parseo PDF y decodificación completa de imágenes, con límites de recursos; probar truncados que conservan cabeceras.
- **Backup (§4):** `pg_dump` y rsync “en el mismo horario” no crean una instantánea común. Pausar mutaciones durante ambos o definir snapshot coordinado; probar restauración sin archivos faltantes. Listar inconsistencias después no recupera datos.

Hallazgos nuevos — MEDIA:

- **Número (§2):** `lpad(...,4)` trunca `10000` a `1000`, duplicando el número visible; además requiere cast a texto. Usar ancho `greatest(4,length(correlativo::text))` y UNIQUE(numero). [PostgreSQL](https://www.postgresql.org/docs/16/functions-string.html).
- **Sesión (§3.3):** agregar vencimiento absoluto al UPDATE atómico y usar su RETURNING como condición de autorización; verificar primero y actualizar después deja una carrera con cierre/expiración.
- **Publicación (§3.6):** `link()+unlink()` en el mismo filesystem es válido y evita sobrescritura; falta confirmar escrituras cerradas, durabilidad y recuperación por etapa. Un fallo de unlink o COMMIT ambiguo no debe borrar un final ya referenciado. [Node](https://nodejs.org/docs/latest-v22.x/api/fs.html).
- **Grants/Drizzle (§2.4):** son compatibles; concretar columnas permitidas y `.set()` explícitos, evitando guardar objetos completos con `estado_id/version_de`. Probar los servicios reales como `legajos_app`, no sólo grants aislados. [Drizzle](https://orm.drizzle.team/docs/update).
- **Primer ingreso (§3.4):** `debe_cambiar_clave` no se comprueba en el guard. Restringir esa sesión a cambio de clave/logout y definir emisión de la sesión posterior.
- **Streaming/proxy (§3.6):** Nginx bufferiza el cuerpo por defecto, por lo que autenticar en el handler ocurre después de recibirlo. Definir `proxy_request_buffering off` para subir y límites totales también en la app. [Nginx](https://nginx.org/en/docs/http/ngx_http_proxy_module.html#proxy_request_buffering).