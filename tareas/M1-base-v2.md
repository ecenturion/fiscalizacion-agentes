# M1 — Base de datos del modelo v2: migración 0003, schema y tests de base

**Arquitecto:** claude-code · **Implementa:** CODEX sombrero B · **Audita:** AGY (lectura) + arquitecto (mutaciones)
**Fuente:** requisitos §7, diseño **§16 completo, con §16.4 que manda**. Se mantienen §9.1 (nulabilidad), §9.6
(funciones privilegiadas) y §9.7 (`.set` explícito).
**Base:** `main` actual. Migraciones 0000–0002 aplicadas también en producción: **no se tocan**.

Los servicios (`src/server/servicios/**`) **se van a romper** al cambiar el schema. Los adapta M2, no los toques.
Por eso la verificación de esta tarea es sólo de base: `typecheck` y `build` pueden fallar por los servicios, y está
previsto.

## Alcance de archivos
1. `src/server/db/schema.ts`: el schema v2 de §16.1 y §16.4.
   - `legajo` con `cedula` y datos de la persona;
   - `tipo_tramite`, `tipo_tramite_documento`, `contador_tramite`, `tramite` y `tramite_legajo`;
   - `interaccion.tramite_id`, `solicitud_documento.tramite_id` y `documento.tramite_id` (nullable);
   - sin `cedula`, sin `contador_legajo` y sin `tipo_documento.obligatorio`.
2. `drizzle/0003_*.sql` y `drizzle/meta/0003_snapshot.json` + `_journal.json`. Se genera con `pnpm db:generate` y
   se **edita a mano** hasta dejar exactamente el orden de §16.4.5:
   1. red de seguridad;
   2. drops de triggers y constraints;
   3. alter y create;
   4. renombres con FK nueva;
   5. triggers;
   6. grants;
   7. la función `corregir_cedula`;
   8. el seed.

   Todo en una transacción: drizzle ya aplica cada archivo en transacción, verificalo. **Sin `CASCADE`.**
   - El check de la cédula normalizada es `cedula ~ '^[1-9][0-9]*$'`. El servicio normaliza: saca los ceros a la
     izquierda.
   - Triggers nuevos, en el esquema `legajos`, con `SET search_path = legajos, pg_temp` y `REVOKE EXECUTE … FROM
     PUBLIC`:
     - **estado** (`SECURITY DEFINER`): sobre `tramite`, con `FOR UPDATE` e `IS DISTINCT FROM`, igual que 0002;
     - **solicitud**: misma interacción y trámite; documento del tipo, de un legajo con vínculo **vivo** al trámite
       y **vivo** (`FOR SHARE`);
     - **versión**: mismo legajo y tipo, anterior vivo, `NEW.tramite_id` **igual** al del anterior (hereda);
     - **procedencia** (`BEFORE INSERT ON documento WHEN tramite_id IS NOT NULL`): `FOR UPDATE` del trámite y
       vínculo vivo `(tramite_id, legajo_id)`. Se exceptúa si es una versión (`version_de` no nulo), porque hereda
       una procedencia histórica;
     - **cardinalidad de archivos**: conservar el de 0002.
   - **`legajos.corregir_cedula(p_legajo uuid, p_nueva text, p_usuario uuid, p_motivo text, p_ip inet)`**:
     - `SECURITY DEFINER`;
     - valida que el usuario esté **activo** con rol `admin`, el motivo no vacío y la cédula normalizada con el
       check;
     - hace `UPDATE legajo SET cedula` (un 23505 si choca);
     - inserta en `auditoria` el antes y el después con el motivo;
     - `GRANT EXECUTE` sólo a `legajos_app`.
   - **Grants** según §16.4.5, punto 11. Revisá **todas** las tablas tocadas y dejá la lista exacta en un comentario
     al principio de la sección.
   - **Seed:** "Múltiple cedulación", con UUID fijo y orden 1, sin documentos obligatorios.
3. `test/setup-roles.sql`: sólo si hace falta.
4. `test/schema.test.ts`, `test/triggers.test.ts` y `test/permisos.test.ts`: **reescribir para v2**. Se mantienen
   los años asignados (schema 2098, triggers 2099), ahora para `tramite`. Cubren:
   - **schema:**
     - nulabilidad con la lista de §9.1 actualizada (`tramite_id` de documento nulo; `legajo` con fechas y
       observación nulas);
     - cédula `0123` → 23514 en la base (el servicio normaliza antes);
     - cédula duplicada → 23505;
     - número de trámite generado;
     - vínculo duplicado vivo → 23505, y revincular después de anular → ok;
     - dos originales vivas en el mismo trámite → 23505;
     - anulación parcial del vínculo → 23514;
   - **triggers:**
     - estado del trámite con su concurrencia (P0001), como antes;
     - solicitud: con un documento de un legajo no vinculado, de otro tipo o anulado → 23514;
     - procedencia: subir con `tramite_id` y un vínculo anulado → 23514, con un vínculo vivo → ok;
     - versión: hereda `tramite_id`, y con otro `tramite_id` → 23514. Un reemplazo después de desvincular → ok;
     - `corregir_cedula`: un operador → error; un admin inactivo → error; un choque → 23505; el caso feliz audita
       el motivo;
   - **permisos:**
     - la tabla de grants por columna **exacta** de v2 (como en L02b);
     - `UPDATE tramite.estado_id`, `documento.tramite_id` o `legajo.cedula` como app → 42501;
     - `EXECUTE corregir_cedula` sólo app; las funciones de trigger sin `EXECUTE` para app.
5. `test/migracion-0003.test.ts` (**nuevo**):
   - en una base aparte (créala y bórrala en el test, como owner), aplica 0000–0002, **inserta un legajo v1** y
     comprueba que 0003 **falla** con la red de seguridad y **no cambia nada**: rollback completo;
   - en otra base limpia, 0000–0003 → ok.

## Criterios
```
cd legajos && pnpm lint && docker compose -f compose.test.yml down && docker compose -f compose.test.yml up -d --wait \
  && pnpm vitest run test/schema.test.ts test/triggers.test.ts test/permisos.test.ts test/migracion-0003.test.ts test/humo.test.ts
pnpm db:generate     # "No schema changes"
```
Sin `any`. Sin commit ni push. **No toques** `src/server/servicios/**`, `src/app/**` ni otros tests.
