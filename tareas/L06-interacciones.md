# L06 — Interacciones, cambio de estado y solicitudes

**Arquitecto:** claude-code · **Implementa:** CODEX sombrero B · **Audita:** claude-code (mutaciones)
**Fuente:** requisitos §2.4, diseño §2.2, §2.3 ("Solicitudes"), §7, §9.3, §9.4, §10.1 y §10.2.
**Base:** L05 (`89abf0a`). Los contratos están en `src/server/servicios/contratos.ts`
(`registrarInteraccionEntrada`, `anularInteraccionEntrada`, `InteraccionSalida`, `SolicitudSalida`).

## Alcance de archivos
1. `src/server/servicios/interacciones.ts` (**nuevo**): `crearServiciosInteracciones(db)` implementa
   `ServiciosInteracciones` y además `listarInteracciones(ctx, { legajoId })`.
2. `src/server/servicios/mapeo.ts`: agregá los mapeos de interacción y solicitud.
3. `src/server/servicios/contratos.ts`: agregá `listarInteracciones` a `ServiciosInteracciones`.
4. `src/server/servicios/legajos.ts`: **sólo** reemplazar `interacciones: []` de `verLegajo` por la lista real.
   Quitá el `TODO` de interacciones y dejá el de documentos para L07.
5. `test/interacciones.test.ts` (**nuevo**). **Años de test: 2085–2089** (`now` fijo al crear legajos).

## Reglas

### `registrarInteraccion` (permiso `interaccion.crear`)
Todo en una transacción:
1. valida con zod. La nota no puede estar vacía; `cambioEstado` es opcional y, si viene, anterior ≠ nuevo;
2. el tipo de interacción tiene que existir y estar **activo**. El estado nuevo, si viene, también tiene que
   estar activo. Los tipos de documento solicitados tienen que existir y estar activos. Si no → `ErrorValidacion`;
3. el legajo tiene que existir → si no, `ErrorNoEncontrado`;
4. `INSERT interaccion` con `estado_anterior_id` y `estado_nuevo_id` (los dos o ninguno), `fecha = now()` y
   `usuario_id = ctx.usuarioId`. **El cambio de estado lo hace el trigger.** Si el trigger lanza
   `estado_desactualizado` (P0001), se traduce a `ErrorConflicto('estado_desactualizado')`, con el mensaje
   "El legajo cambió de estado; recargá";
5. un `INSERT solicitud_documento` por tipo solicitado (`legajo_id`, `interaccion_id`, `tipo_documento_id`, sin
   documento);
6. auditoría:
   - `alta` de la interacción, con el después;
   - si hubo cambio de estado, un `cambio` sobre `legajo`, con antes `{estado_id}` y después `{estado_id}`;
   - una `alta` por solicitud.

### `anularInteraccion` (permiso `interaccion.anular`, que sólo tiene el admin)
- Motivo obligatorio y sólo sobre interacciones vivas.
- **No toca el estado del legajo** (decisión §7).
- **No toca** las solicitudes de esa interacción. Quedan como están: el historial es inalterable.
- Audita `anulacion`.

### `listarInteracciones` (permiso `legajo.ver`)
- Devuelve todas las interacciones, **incluidas las anuladas** con su marca, en orden cronológico descendente.
- Cada una lleva su tipo (con nombre aunque esté desactivado), estado anterior y nuevo, y sus solicitudes.
- **Estado derivado de la solicitud**: `recibida` si `documento_recibido_id` apunta a un documento **vivo**
  (`anulado_en IS NULL`); si no, `pendiente`. Se calcula en la consulta, no se guarda.
- Con varias interacciones con solicitudes, una sola consulta por tabla. No hace una consulta por cada interacción.

### Lo que NO va en L06
Asignar `documento_recibido_id` pertenece a la subida de documentos (L07), con el candado de §10.2. Acá no hay
ninguna función que lo escriba.

## Criterios
```
cd legajos && pnpm verificar
```

`test/interacciones.test.ts`, contra Postgres real como `legajos_app`:
1. Interacción sin cambio de estado → el estado del legajo no cambia y queda la auditoría `alta`.
2. Con cambio Detectado → Notificado → el legajo queda en Notificado y hay auditoría del cambio de legajo.
3. Con un `anteriorId` desactualizado (el legajo ya está en Notificado y se manda Detectado → En trámite) →
   `ErrorConflicto('estado_desactualizado')`, **sin filas nuevas** (ni interacción ni auditoría).
4. **Concurrencia:** dos `registrarInteraccion` en paralelo con el mismo anterior → una sale bien y la otra da
   409. El estado final es el de la que salió bien.
5. Tipo de interacción desactivado → `ErrorValidacion`. Estado nuevo desactivado → `ErrorValidacion`. Tipo de
   documento solicitado desactivado → `ErrorValidacion`.
6. Solicitudes: pedir dos tipos crea 2 filas `pendiente`. Si se simula la recepción (como owner, poniendo
   `documento_recibido_id` a un documento vivo del mismo tipo) → `recibida`. Si se anula ese documento (owner) →
   vuelve a `pendiente`.
7. Anular (admin) → la interacción queda anulada, **el estado del legajo no cambia** y sus solicitudes siguen
   igual. Operador anulando → 403. Motivo vacío → `ErrorValidacion`. Anular dos veces → `ErrorConflicto`.
8. `verLegajo` trae las interacciones en orden descendente, con las anuladas marcadas.
9. `consulta` → no registra (403) y sí lista.

Sin `any`, sin `console.log`, `.set()` explícito. Sin commit ni push.
