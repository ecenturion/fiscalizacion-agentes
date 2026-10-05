Veredicto: CAMBIOS

§16 refleja el núcleo de §7: legajo por cédula, original por trámite, estado e historial en el trámite y documentos permanentes en el legajo. Faltan precisiones de integridad y hay decisiones funcionales agregadas sin confirmación.

**Alta — corregir antes de implementar**

- **Concurrencia de vínculos y original** — [diseño:504](/home/ecenturion/develop/legajos-agents/docs/diseno.md:504), 517–519: dos transacciones pueden anular distintos vínculos y dejar cero vivos. Bloquear primero la fila de `tramite`, recontar después del bloqueo y usar ese mismo candado para vincular, desvincular y marcar original. Mantener ambos índices únicos parciales y el check de las tres columnas de anulación.
- **Procedencia histórica** — [diseño:507](/home/ecenturion/develop/legajos-agents/docs/diseno.md:507): un documento válido queda aparentemente incoherente cuando se anula después su vínculo. Definir pertenencia viva **al cargar**, conservar `tramite_id` histórico e inmutable y serializar carga/desvinculación con el candado del trámite.
- **Solicitudes** — [diseño:506](/home/ecenturion/develop/legajos-agents/docs/diseno.md:506): falta definir el efecto de desvincular el legajo receptor. Recomendación: la solicitud vuelve a pendiente, conservando documento e historial; aplicar y auditar en la misma transacción. Validar trámite de la interacción, tipo, documento vivo y vínculo vivo.
- **Carrera solicitud/anulación/reemplazo** — [0002:117](/home/ecenturion/develop/legajos/drizzle/0002_grants_y_triggers.sql:117): el trigger actual lee sin bloqueo y acepta documentos anulados; §10.2 depende del servicio. En v2 explicitar un orden común de locks para trámites y documentos, verificaciones posteriores al lock y reapuntamiento atómico de solicitudes.
- **Versiones con procedencia** — [diseño:507](/home/ecenturion/develop/legajos-agents/docs/diseno.md:507): “mismo legajo y tipo” permite cambiar o perder `tramite_id`; exigir vínculo vivo también impediría reemplazar tras desvincular. Definir si se hereda la procedencia; recomendado: conservarla, admitiendo el reemplazo histórico bajo esa regla.
- **0003 todavía no verificable** — [diseño:535](/home/ecenturion/develop/legajos-agents/docs/diseno.md:535): no existe el SQL. El esquema permite una migración incremental, pero el párrafo actual no demuestra orden correcto ni permisos efectivos.

**Media — completar el contrato de diseño**

- **Orden de migración** — §16.3: retirar triggers afectados antes de cambiar columnas; crear destinos antes de trasladar FKs; renombrar `interaccion.legajo_id` y `solicitud_documento.legajo_id` **y sustituir sus FKs**, que un rename conserva apuntando al viejo legajo. Eliminar `numero` generado antes de `anio/correlativo`; retirar constraints dependientes y evitar `CASCADE` indiscriminado.
- **Triggers y grants** — [0002:25](/home/ecenturion/develop/legajos/drizzle/0002_grants_y_triggers.sql:25): los grants existentes no cubren tablas nuevas. Dar SELECT/INSERT explícitos y UPDATE mínimo por columna; no conceder UPDATE de estado, identidades, FKs ni procedencia. Rehacer estado con lock sobre `tramite`, propietario owner, `search_path` fijo y EXECUTE revocado; conservar cardinalidad de archivos.
- **Red de seguridad** — [diseño:539](/home/ecenturion/develop/legajos-agents/docs/diseno.md:539): con las FKs actuales, las cuatro tablas comprobadas cubren también solicitudes y archivos dependientes. Agregar comprobación de `contador_legajo`: podría contener numeración consumida. Ejecutar comprobación y DDL en una transacción, sin escritores concurrentes; probar restauración y rollback ante rechazo.
- **Seed** — §16.3: fijar UUID estable de “Múltiple cedulación”; no inventar documentos obligatorios. Revisar los `obligatorio=true` existentes antes de eliminar la columna: abortar o trasladarlos mediante una regla explícita. Los valores del seed 0002 son todos false.
- **Faltantes** — [diseño:520](/home/ecenturion/develop/legajos-agents/docs/diseno.md:520): precisar vínculos vivos y versión válida según las reglas heredadas; documentos anulados no satisfacen. Aclarar: **un documento vencido sí satisface el obligatorio**, con aviso sólo en visor. Mantener cambios de obligatoriedad aplicables a trámites existentes.
- **Alcance agregado** — §16.1–16.2: “legajo no se anula”, reutilización de documentos de cualquier trámite para faltantes y reglas de desvinculación son decisiones propuestas, no respuestas expresas de §7. Además, §2.5 conserva anulación de cédulas: resolver esa contradicción explícitamente.
- **Unicidad con anulados** — [diseño:499](/home/ecenturion/develop/legajos-agents/docs/diseno.md:499): UNIQUE global de cédula es correcto para el 1:1 permanente; nunca parcial por anulación. Los vínculos anulados permiten revincular, pero no crear otro legajo. Alta concurrente: resolver conflicto por UNIQUE y recuperar el existente.

**Decisiones menores para el cliente — máximo 4**

1. ¿`00123` y `123` representan la misma cédula? **Recomendado:** normalizar ceros iniciales si no tienen valor identificatorio.
2. ¿Se corrige el número de cédula de un legajo? **Recomendado:** sólo admin, con auditoría y unicidad global.
3. ¿Qué obligatorios tendrá inicialmente “Múltiple cedulación”? **Recomendado:** ninguno hasta recibir la lista.
4. ¿Cómo mostrar vínculos sin original marcada? **Recomendado:** “Original sin determinar”; evitar presentar automáticamente todos como duplicados.

Auditoría estática de archivos; sin modificaciones ni ejecución de migraciones.