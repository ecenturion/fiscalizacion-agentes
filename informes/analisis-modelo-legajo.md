La corrección cambia la unidad central: **el legajo es un archivo permanente; el trámite es una actuación que puede abrirse y cerrarse dentro de ese archivo**. No alcanza con cambiar nombres: hoy `legajo` representa el caso y `cedula` depende de él.

**1) Modelo del cliente y ambigüedades**
- Cédula → legajo propio → cero o muchos trámites; cada trámite puede incorporar documentos al archivo.
- Cada cédula conserva sus nombres, apellidos, nacimiento y emisión, aunque difieran de los de otras cédulas.
- Propuesta a confirmar: trámite con tipo, fecha de apertura/detección, estado, interacciones y solicitudes; legajo con identificación y documentación acumulada.
- La múltiple cedulación requiere vincular distintas cédulas y sus legajos; repetir un número ya no debería crear automáticamente otro archivo.
Tres interpretaciones posibles:
- **A. Archivo por número:** un número de cédula tiene un único legajo; las sucesivas emisiones se registran dentro de esa identidad documental.
- **B. Archivo por persona:** una persona tiene un legajo que reúne sus números de cédula; exige confirmar que el cliente usa “cédula” para referirse al titular.
- **C. Archivo por ejemplar emitido:** cada emisión tiene legajo propio, aunque repita número; exige distinguir número identificatorio y documento físico.
La frase favorece A, pero no resuelve si un caso de múltiple cedulación es un trámite compartido entre legajos ni qué significa “duplicado”.

**2) Preguntas al cliente, por impacto**
1. **¿Qué identifica un legajo?** Opciones: número de cédula / persona / ejemplar emitido.
   Recomendada: número de cédula, porque coincide con “archivo que pertenece a una cédula”; registrar emisiones aparte si deben conservarse.
2. **¿Cómo se gestiona un caso que involucra varias cédulas?** Opciones: trámite compartido entre legajos / trámite principal con legajos relacionados / trámites independientes vinculados.
   Recomendada: trámite compartido, porque permite un único seguimiento del caso sin fusionar los archivos de cada cédula.
3. **¿“Original y duplicados” significa números distintos atribuidos a la misma persona o ejemplares del mismo número?** Opciones: números distintos / reemisiones del mismo número / ambos.
   Recomendada: separar ambos conceptos si existen, porque la relación entre identidades y la renovación de un documento tienen reglas diferentes.
4. **¿Dónde se decide cuál cédula es la original?** Opciones: en cada caso/trámite / en una agrupación permanente de cédulas / como atributo global de la cédula.
   Recomendada: en cada caso, inicialmente sin original y luego como máximo una, porque puede ser una conclusión de la investigación.
5. **¿Dónde quedan los documentos y pueden usarse en varios trámites o legajos?** Opciones: sólo legajo / sólo trámite / legajo con vínculos a trámites / documento compartido con vínculos a ambos.
   Recomendada: documento archivado una sola vez y vínculos explícitos, porque conserva procedencia y evita duplicar archivos; confirmar acceso entre legajos.
6. **¿A qué pertenecen estado, interacciones y solicitudes?** Opciones: trámite / legajo / ambos con funciones distintas.
   Recomendada: trámite, porque cada gestión necesita su propio seguimiento; agregar estado del archivo sólo si tiene un significado independiente.
7. **¿Se admiten varios trámites simultáneos y reaperturas?** Opciones: varios simultáneos / uno activo por legajo / uno activo por tipo; cierre definitivo / reapertura.
   Recomendada: varios y reapertura mediante interacción auditada, porque distintas gestiones pueden coexistir sin perder historia.
8. **¿Habrá tipos de trámite y documentos obligatorios por tipo?** Opciones: catálogo con requisitos / catálogo sin requisitos / descripción libre.
   Recomendada: catálogo con requisitos, porque los faltantes deben responder a la gestión concreta y no a todo el archivo.
9. **¿Qué identifica AAAA-NNNN y dónde queda la fecha de detección?** Opciones de número: legajo / trámite / ambos con series separadas; fecha: legajo / trámite.
   Recomendada: número y detección del trámite; identificar el archivo por cédula, porque año y correlativo describen una actuación.
10. **Si se vuelve a cargar el mismo número, ¿qué debe pasar?** Opciones: abrir legajo existente / avisar y permitir otro / registrar nueva emisión dentro del existente.
    Recomendada: abrir el existente y permitir registrar emisiones, porque evita fragmentar el archivo; definir normalización del número y tratamiento de anulados.

**3) Impacto y migración**
Basado en [requisitos](/home/ecenturion/develop/legajos-agents/docs/requisitos.md), [diseño §2, §7 y §15](/home/ecenturion/develop/legajos-agents/docs/diseno.md) y [schema real](/home/ecenturion/develop/legajos/src/server/db/schema.ts); el alcance definitivo depende de las respuestas.
- **Tablas:** independizar `cedula`, redefinir `legajo` y agregar `tramite`; para trámites compartidos, tabla de participación de legajos. Agregar emisiones/persona sólo si se confirma su necesidad.
- **Relaciones:** trasladar estado y detección al trámite; adaptar `interaccion` y `solicitud_documento`; mantener archivo documental y agregar vínculos según la respuesta 5.
- **Constraints e índices:** unicidad cédula–legajo y número normalizado; sustituir `cedula_original_unq` por la regla del caso; ajustar FK, índices de búsqueda, numeración y `contador_legajo`.
- **Triggers:** `interaccion_estado` actualizará y bloqueará el trámite; `solicitud_coherente` comprobará trámite, participación, tipo y documento elegible; revisar `documento_version` según el archivo propietario.
- **Permisos:** actualizar grants por columna y nuevas tablas; conservar cambio de estado exclusivamente por interacción, sin habilitar edición directa.
- **Servicios:** revisar `legajos`, `cedulas`, `interacciones`, `documentos`, contratos, mapeos y acciones; agregar trámites y reemplazar relaciones inferidas por número por relaciones explícitas.
- **Pantallas:** alta y búsqueda de cédula/archivo; detalle del legajo con trámites; alta/detalle del trámite con participantes, original, estado, solicitudes e historial; adaptar carga y consulta documental.
- **Tests:** cambiar `schema`, `triggers`, `permisos`, `legajos`, `cedulas`, `interacciones`, `documentos`, acciones y rutas; cubrir archivo único, trámites simultáneos, concurrencia y vínculos documentales inválidos.
- **Reutilizable tal cual:** autenticación, sesiones, IP, contraseñas, usuarios, registro de accesos, almacenamiento/validación segura de archivos y motor de auditoría.
- **Reutilizable con integración ajustada:** descargas, versionado, catálogos y admin; añadir tipos/estados de trámite y nuevas entidades auditadas. `documento_archivo` y su regla de cardinalidad pueden conservarse.
Plan de migración, dado que producción sólo tiene admin y ningún legajo:
1. Cerrar estas decisiones y actualizar requisitos/diseño con ejemplos reales; confirmar qué reglas previas continúan, incluida anulación sin reversión de estado.
2. Preparar una migración incremental nueva, sin reescribir las ya aplicadas ni reinicializar la base; preservar admin, hash, IP, accesos y auditoría.
3. Validar en una copia local la ausencia de datos de negocio, migración, grants y pruebas; no hace falta convertir casos históricos si efectivamente no existen.
4. Para la puesta en producción, respaldar base y archivos, impedir cargas durante el cambio y coordinar esquema con versión de aplicación compatible.
5. Usar la infraestructura real de §15: CentOS 7, Docker, PostgreSQL 16 y Apache bajo `/fiscalizacion`; verificar acceso del admin y restauración ensayada como contingencia.

No modifiqué archivos ni ejecuté cambios en producción.