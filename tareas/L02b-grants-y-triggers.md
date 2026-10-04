# L02b — Grants por rol y columna, triggers y catálogos de arranque

**Arquitecto:** claude-code · **Implementa:** CODEX sombrero B · **Audita:** claude-code + AGY (CODEX no audita lo suyo)
**Fuente:** `docs/diseno.md` §2.2, §2.3, §2.4, §9.4–§9.7, §10.1–§10.2 y §14. **La sección más alta manda.**
**Base:** L02a (`0ac843a`): tablas en `legajos`, migraciones 0000–0001.

## Alcance de archivos (4)
1. `drizzle/0002_*.sql`: **custom**, con `pnpm drizzle-kit generate --custom --name grants_y_triggers`.
2. `drizzle/meta/0002_snapshot.json` y `drizzle/meta/_journal.json`, que los genera el comando.
3. `test/permisos.test.ts`: **nuevo**.
4. `test/triggers.test.ts`: **nuevo**.

## 0002 — Contenido

### Permisos (§2.4, §9.6)
- `REVOKE ALL ON ALL TABLES IN SCHEMA legajos FROM PUBLIC, legajos_app`.
- `REVOKE ALL ON ALL FUNCTIONS IN SCHEMA legajos FROM PUBLIC`.
- `REVOKE CREATE ON SCHEMA legajos, public FROM PUBLIC`.
- `GRANT USAGE ON SCHEMA legajos TO legajos_app`.
- `GRANT EXECUTE ON FUNCTION legajos.f_unaccent(text) TO legajos_app` (la usa la búsqueda).
- `SELECT, INSERT` para `legajos_app` en **todas** las tablas.
- **Nunca** `DELETE`, `TRUNCATE`, `REFERENCES` ni `TRIGGER`.

`UPDATE` **sólo por columna**, y sólo esto:

| Tabla | Columnas con UPDATE |
|---|---|
| `usuario` | nombre, hash, rol, activo, debe_cambiar_clave, intentos_fallidos, bloqueado_hasta |
| `usuario_ip` | activo, descripcion |
| `sesion` | ultimo_uso, cerrada_en, motivo_cierre |
| `limite_ip` | ventana_inicio, intentos |
| `estado_legajo`, `tipo_interaccion` | nombre, orden, activo |
| `tipo_documento` | nombre, obligatorio, vigencia_dias, multiples_archivos, activo |
| `contador_legajo` | ultimo |
| `legajo` | fecha_deteccion, observacion (**no** estado_id) |
| `cedula` | nombres, apellidos, fecha_nacimiento, fecha_emision, es_original, observacion, anulado_en, anulado_por, motivo_anulacion |
| `documento` | observacion, anulado_en, anulado_por, motivo_anulacion (**no** legajo_id, tipo_id ni version_de) |
| `interaccion` | anulado_en, anulado_por, motivo_anulacion |
| `solicitud_documento` | documento_recibido_id |
| `documento_archivo`, `acceso_log`, `auditoria` | **ninguna** |


### Triggers y funciones
Todas en el esquema `legajos`, de `legajos_owner`, con `SET search_path = legajos, pg_temp`, referencias
calificadas y `REVOKE EXECUTE … FROM PUBLIC`.

**a) Estado del legajo.** `legajos.tg_interaccion_estado()`, `SECURITY DEFINER`, `AFTER INSERT ON interaccion
FOR EACH ROW WHEN (NEW.estado_nuevo_id IS NOT NULL)`:
- `SELECT estado_id … FOR UPDATE` del legajo;
- si `estado_id IS DISTINCT FROM NEW.estado_anterior_id` → `RAISE EXCEPTION … USING ERRCODE = 'P0001'`, con el
  mensaje `estado_desactualizado`;
- si no, `UPDATE legajo SET estado_id = NEW.estado_nuevo_id`.

**b) Versiones.** `legajos.tg_documento_version()`, `BEFORE INSERT ON documento WHEN (NEW.version_de IS NOT NULL)`,
**no** `SECURITY DEFINER`. Hace `SELECT … FOR UPDATE` del anterior y exige:
- que exista;
- que esté vivo (`anulado_en IS NULL`);
- `legajo_id` igual;
- `tipo_id` igual.

Si no se cumple → `ERRCODE 23514`.

**c) Solicitudes.** `legajos.tg_solicitud_coherente()`, `BEFORE INSERT OR UPDATE OF documento_recibido_id ON
solicitud_documento`. Exige:
- `NEW.legajo_id` = el legajo de su interacción;
- si `documento_recibido_id` no es nulo, que ese documento sea del mismo legajo y **del mismo tipo**
  (`tipo_documento_id`).

Si no se cumple → 23514. La regla de "documento vivo" con su candado (§10.2) **no** va acá: es del servicio (L06/L07).

**d) Cardinalidad de archivos** (§2.3). Trigger `BEFORE INSERT ON documento_archivo` que rechaza (23514):
- `orden > 1` si el tipo del documento tiene `multiples_archivos = false`;
- cualquier archivo sobre un documento anulado.

El mínimo de 1 archivo por documento lo controla el servicio (L07).

### Catálogos de arranque (requisitos §4), con UUIDs fijos escritos en la migración
- **Estados:** Detectado (1), Notificado (2), En trámite (3), Resuelto (4), Archivado (5).
- **Interacciones:** Se presentó, Notificación, Llamada, Entrega de documentos.
- **Documentos:**
  - Nota: obligatorio no, multiples_archivos **sí**, sin vigencia;
  - Certificado de nacimiento y Certificado de casamiento: obligatorio no, sin vigencia;
  - Certificado de vida y Certificado de residencia: obligatorio no, sin vigencia (la carga el admin).

## Criterios
```
cd legajos && docker compose -f compose.test.yml down && docker compose -f compose.test.yml up -d --wait && pnpm verificar
pnpm db:generate     # "No schema changes"
```

**`test/permisos.test.ts`**, conectado como `legajos_app`:
1. Recorre todas las tablas: `has_table_privilege` de DELETE, TRUNCATE, REFERENCES y TRIGGER → false; SELECT e
   INSERT → true.
2. Recorre todas las columnas: `has_column_privilege(UPDATE)` coincide **exactamente** con la tabla de arriba.
   El test tiene la tabla como fuente.
3. Reales: `DELETE FROM legajos.legajo` → 42501; `UPDATE legajos.legajo SET estado_id = …` → 42501;
   `UPDATE legajos.auditoria SET accion = 'alta'` → 42501; `TRUNCATE legajos.acceso_log` → 42501.
4. `pg_has_role('legajos_app','legajos_owner','MEMBER')` → false.
5. `has_function_privilege` de las funciones de trigger → false para `legajos_app`.
6. `CREATE TABLE legajos.x` y `CREATE TABLE public.x` → 42501.

**`test/triggers.test.ts`**, insertando como `legajos_app` (la siembra base, como owner, en el `beforeAll`):
1. Estado: interacción con anterior = actual y nuevo distinto → `legajo.estado_id` cambia. Con anterior viejo →
   P0001 y el estado no cambia. Sin cambio de estado → no toca el legajo.
2. **Concurrencia de estado:** dos transacciones con el mismo `estado_anterior_id`. La segunda, al esperar el lock
   y ver el estado nuevo, falla con P0001.
3. Versiones: con anterior vivo del mismo legajo y tipo → ok. Con anterior anulado, de otro legajo o de otro tipo → 23514.
4. Solicitudes: con un legajo distinto al de la interacción, o con un documento de otro tipo o de otro legajo → 23514.
5. Cardinalidad: tipo sin múltiples y `orden 2` → 23514. Archivo sobre un documento anulado → 23514.
6. Los catálogos de arranque están: 5 estados, 4 tipos de interacción y 5 de documento.

Sin `any`. **Sin commit ni push.** No toques `drizzle/0000_*` ni `0001_*`.
