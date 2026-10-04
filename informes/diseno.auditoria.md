Veredicto: CAMBIOS

1. **ALTA — Solicitudes (§2).** La derivación no cumple el vínculo al documento recibido: cualquier documento posterior satisface todas las solicitudes del tipo; anular uno puede dejarla recibida por otro. Agregar `documento_recibido_id`, validar mismo legajo/tipo y derivar pendiente si ese documento está anulado. Precisar asignación ante solicitudes múltiples y reemplazos; no resolverla con timestamps.

2. **ALTA — Numeración concurrente (§2).** “Transacción con lock” no define qué se bloquea, especialmente al iniciar un año. Especificar contador persistente por año con incremento atómico y tratamiento del primer registro; conservar unicidad aun anulados. Derivar `numero` de año/correlativo y definir el año en Asunción, sin imponer ausencia de huecos.

3. **ALTA — Integridad del modelo (§2).** Explicitar FK, `NOT NULL`, checks de roles/acciones, correlativo positivo, vigencia no negativa y anulación coherente con motivo no vacío. El índice parcial de original es correcto bajo concurrencia: conservarlo. Garantizar al crear el legajo al menos una cédula, permitiendo una sola y ninguna original.

4. **ALTA — Estado e interacciones (§2).** Bloquear el legajo al cambiar estado y guardar anterior/nuevo más auditoría en la misma transacción; impedir cambios por otros servicios. Exigir nota no vacía. Definir qué ocurre al anular una interacción que cambió estado sin recalcular silenciosamente la fuente de verdad ni borrar su historia.

5. **ALTA — Versiones (§2).** `version_de` permite ramas, ciclos y enlaces entre tipos/legajos si no se restringe. Definir cadenas compatibles, predecessor único, exclusión de ciclos y reemplazo concurrente serializado. Anular el anterior y publicar el nuevo atómicamente; preservar archivos anteriores y especificar el efecto sobre solicitudes vinculadas.

6. **ALTA — Append-only (§2).** Revocar sólo UPDATE/DELETE no alcanza si existen otros permisos. Dar al rol app únicamente SELECT/INSERT en logs, sin TRUNCATE, propiedad, membresía del migrador ni funciones que permitan alterar registros; probar permisos efectivos, incluidos heredados. [PostgreSQL 16](https://www.postgresql.org/docs/16/ddl-priv.html).

7. **ALTA — IP detrás de Nginx (§3).** `TRUST_PROXY=1` es una condición de configuración, no una comprobación del emisor. Documentar el aislamiento efectivo del backend y que Nginx sobrescribe encabezados de IP; rechazar IP ausente/inválida. El fallback al socket no está disponible directamente en páginas/Actions/`NextRequest`; definir un adaptador real o exigir exclusivamente el proxy. [NextRequest](https://nextjs.org/docs/15/app/api-reference/functions/next-request).

8. **ALTA — Autorización por request (§3).** Buscar texto en archivos no demuestra ejecución del guard ni cubre Actions externas a esos directorios. Exigir guard antes de cada lectura/mutación protegida y permisos explícitos por operación, especialmente anulaciones. Añadir pruebas HTTP de páginas/RSC, Actions directas y handlers, con revocación inmediata de IP y sin caché compartida de autorización. Los layouts no bastan. [Next.js](https://nextjs.org/docs/app/guides/authentication).

9. **ALTA — Sesiones (§1/3).** Conservar token aleatorio y hash; concretar expiración y actualización atómica de `ultimo_uso`, logout e invalidación al recuperar contraseña. Separar validación de sesión de limpieza de cookie: una página Server Component no puede modificarla. Resolver HTTPS antes de producción y exigir `Secure` allí.

10. **ALTA — Bloqueos de login (§3).** Falta almacenamiento/algoritmo del contador por IP y atomicidad del contador por cuenta. Definir ventanas, vencimientos, reinicio y concurrencia, incluyendo usuarios inexistentes e IPs rechazadas; mantener respuesta genérica y registrar todos los resultados sin contraseñas ni tokens.

11. **ALTA — Subida en stream (§3).** Elegir un route handler Node con parser multipart incremental sobre `request.body`; `request.formData()` y recibir `File` en una Action no acreditan corte durante recepción. Actions tienen límite predeterminado de 1 MB. Coordinar límite por archivo, total y overhead con Nginx; autenticar antes de consumir y limpiar temporales al abortar. [Server Actions](https://nextjs.org/docs/15/app/api-reference/config/next-config-js/serverActions).

12. **ALTA — Archivos e integridad (§2/3).** Precisar contención mediante `path.relative`, no prefijo textual; controlar symlinks y apertura/escritura exclusiva. `rename` puede sobrescribir: definir publicación sin reemplazo y recuperación ante fallo entre disco/BD. Garantizar documento con archivos y cardinalidad según tipo; `orden=1` por sí solo no expresa la regla completa.

13. **ALTA — CSRF (§3).** “Origin igual al host” mezcla formatos y confía en un host potencialmente manipulable. Comparar origen completo contra configuración permitida, rechazar ausente/`null` en mutaciones y cubrir login/logout/subidas; fijar Host y encabezados reenviados en Nginx. Mantener protección de Actions sin ampliar indiscriminadamente `allowedOrigins`. [Next.js](https://nextjs.org/docs/15/app/api-reference/config/next-config-js/serverActions).

14. **MEDIA — Tipo real (§3).** Aclarar que `file-type` detecta firmas y no valida estructura completa. Definir rechazo de desconocidos/truncados y validación con parser si se pretende garantizar formato válido; servir con MIME validado y nombre de descarga saneado. [file-type](https://github.com/sindresorhus/file-type).

15. **MEDIA — Alcance agregado (§1/2/3).** Pasar a preguntas abiertas la anulación de legajos y unicidad de cédula dentro del caso: v0.3 no las pide. Quitar la regla funcional de contraseña mínima de 10 caracteres hasta confirmación. Eliminar auditoría obligatoria de descargas o confirmar y ampliar su enum: actualmente `descarga` contradice el modelo.

16. **MEDIA — Cobertura funcional (§2/5).** Agregar matriz requisito→modelo→servicio→pantalla→prueba. Falta explicitar aviso con otros legajos durante la carga, altas/cambios auditados de usuarios/IPs/catálogos y comportamiento histórico de catálogos desactivados. Conservar aplicación retroactiva de vigencia/obligatoriedad y aviso de vencimiento únicamente al ver el documento.

17. **MEDIA — Middleware Next 15 (§1/3).** Fijar versión menor y parches: Node fue experimental en 15.2 y estable en 15.5; Edge sigue predeterminado. Ninguno sustituye controles en páginas, Actions y handlers ni aporta automáticamente acceso al socket. Mantener middleware sólo orientativo es correcto. [Middleware](https://nextjs.org/docs/15/app/api-reference/file-conventions/middleware).

18. **MEDIA — Plan (§5).** Dividir L03 en sesiones/IP, bloqueo y recuperación; L04 en numeración/cédulas e interacciones/solicitudes; L05 en almacenamiento, subida y versiones. Crear primero auditoría y contratos compartidos: L04/L05 dependen entre sí aunque no compartan archivos. Paralelizar después; L07 puede avanzar junto a L06. Iniciar contratos de Nginx/límites temprano y cerrar con pruebas integradas, concurrencia, permisos PG y restauración consistente de BD/archivos.