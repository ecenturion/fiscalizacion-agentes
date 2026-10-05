# L08b — Pantallas de operación (login, buscador, alta y detalle de legajo)

**Arquitecto:** claude-code · **Implementa:** OPENCODE · **Audita:** arquitecto (revisión + `guard-cobertura`)
**Fuente:** requisitos §2.1–§2.4, diseño §2.3 (vencimiento: aviso **sólo al ver el documento**) y §7.
**Base:** L08a (`ae30755`). Sólo usás lo que ya existe:
- **lectura en Server Components:** `const ctx = await ctxPagina(permiso)` (devuelve el `Contexto`) y
  `servicios().legajos.verLegajo(ctx, …)`, etc., de `@/server/acciones/contexto`;
- **escrituras:** las Actions de `src/app/(app)/legajos/acciones.ts`, que devuelven `Resultado` (`ok` / `error {
  codigo, mensaje, campos? }`);
- **subida de documentos:** `fetch('/api/documentos', { method: 'POST', body: FormData })` desde un componente
  cliente. Campos: `legajoId`, `tipoId`, `fechaEmision`, `observacion?`, `solicitudesIds` (uno por solicitud
  elegida), `documentoId` si es un reemplazo, y `archivos` (varios);
- **ver y descargar:** links a `/api/archivos/[id]` y `/api/archivos/[id]?descargar=1`;
- **permisos en la UI:** `puede(ctx.rol, permiso)` de `@/server/permisos`, **sólo para ocultar botones**. La
  seguridad real ya está en las Actions.

**NO tocás:** `src/server/**`, `src/app/api/**`, ni los `acciones.ts`, ni `package.json`. No agregás
dependencias. Si te falta algo del servidor, **parás y lo decís en el informe**.

## Alcance de archivos
1. `src/app/globals.css`: estilos propios, sin frameworks.
   - Sobrio e institucional: tipografía del sistema, base de 16 px, contraste AA, foco visible.
   - Tablas legibles y botones primario, secundario y peligro.
   - Badges: original, duplicado, anulado (tachado y gris), vencido (rojo), pendiente y recibida.
   - Responsive mínimo: hasta 360 px de ancho sin scroll horizontal en formularios.
2. `src/app/layout.tsx`: importa `globals.css`, `lang="es"`, título "Fiscalización".
3. `src/app/page.tsx`: `redirect('/legajos')`.
4. `src/app/(auth)/login/page.tsx`: estilos, el error genérico de `entrar` y autofocus en usuario. **No cambies
   `acciones.ts`.**
5. `src/app/(app)/layout.tsx`: mantené `dynamic = 'force-dynamic'` y agregá la barra superior: "Fiscalización",
   links a Legajos y Administración (el de Administración, sólo si `puede(rol, 'admin.usuarios')`), el nombre de
   usuario y el botón **Salir**. Salir es un `<form method="post" action="/logout">`, nunca un link GET.
   - El layout **no** autoriza nada (§3.2). Para mostrar el usuario, llama a `ctxPagina('legajo.ver')`. Las
     páginas siguen llamando a su propio `ctxPagina`.
   - **Ojo:** el layout usa `ctxPagina('cuenta.cambiar_clave')`, no `'legajo.ver'`. Si no, un usuario con
     `debe_cambiar_clave` entra en un bucle de redirección a `/cuenta/clave`.
6. `src/app/(app)/cuenta/clave/page.tsx`: estilos y mensajes (clave actual, nueva, repetir; 10 caracteres como
   mínimo).
7. `src/app/(app)/legajos/page.tsx`, **buscador**:
   - `searchParams`: `cedula`, `nombre`, `numero`, `estado` y `pagina`;
   - tabla con número (link), estado, fecha de detección y la cédula original o la primera;
   - paginado y botón "Nuevo legajo" (`legajo.crear`);
   - estado vacío: "No hay legajos que coincidan".
8. `src/app/(app)/legajos/nuevo/page.tsx` + `componentes/FormLegajo.tsx` (cliente):
   - fecha de detección, observación y una lista **dinámica** de cédulas (agregar y quitar). Cada cédula tiene
     número, nombres, apellidos, nacimiento, emisión, original (radio, como máximo uno) y observación;
   - **al salir del campo número**, `relacionadosPorCedulaAccion`: si hay, muestra el aviso "Esta cédula ya figura
     en: 2026-0003, 2026-0010" con links. **No bloquea** (§7).
9. `src/app/(app)/legajos/[id]/page.tsx`, **detalle**, con `verLegajo` y `faltantes`:
   - **cabecera:** número, estado (badge), fecha de detección, observación y "Editar" (`legajo.editar`);
   - **Cédulas:** tabla con original o duplicado, y las anuladas tachadas, con su motivo en un tooltip o texto.
     Acciones según permiso: agregar, editar, marcar original y anular. Anular pide el motivo en un `<dialog>`;
   - **Relacionados:** lista con links;
   - **Documentos:**
     - agrupados por tipo, con fecha de emisión, archivos (Ver / Descargar) y versiones anteriores plegadas;
     - "Faltantes" como lista de tipos obligatorios sin documento;
     - **el aviso "Vencido el dd/mm/aaaa" aparece sólo en el visor del documento** (punto 10), no en la lista
       (decisión §7).
     - Botones: subir (`documento.subir`), reemplazar y anular (`documento.anular`);
   - **Historial:** interacciones en orden descendente con fecha (dd/mm/aaaa hh:mm, America/Asuncion), tipo,
     usuario, nota y "Estado: X → Y" si cambió. Sus solicitudes llevan un badge pendiente o recibida. Las anuladas
     se muestran tachadas con su motivo. "Anular" (`interaccion.anular`);
   - **Registrar interacción** (`interaccion.crear`): tipo (sólo activos), nota (obligatoria), un check "Cambiar
     estado" con selector del estado nuevo (se manda `anteriorId = estado actual`) y tipos de documento solicitados
     (multiselección). Si vuelve `estado_desactualizado`: "El legajo cambió de estado; recargá la página".
10. `src/app/(app)/legajos/[id]/documentos/[docId]/page.tsx`, **visor**:
    - datos del documento con el **aviso de vencido** si `vencido` ("Vencido el …"), o "Vigente hasta …" si tiene
      vigencia;
    - archivos embebidos: un `<iframe>` para PDF y un `<img>` para imágenes, apuntando a `/api/archivos/[id]`;
    - link de descarga.
11. `src/app/(app)/legajos/[id]/componentes/*.tsx`: los componentes cliente que necesites (formularios,
    diálogos, subida). La subida muestra el progreso **sin** dependencias (`XMLHttpRequest` con `upload.onprogress`
    está bien) y, si sale bien, `router.refresh()`.

## Reglas
- Fechas con Luxon en `America/Asuncion`, formato es-PY.
- Todos los textos en español y sin jerga técnica:
  - `original_existente` → "Ya hay una cédula marcada como original";
  - `permiso_denegado` → "No tenés permiso para esta acción";
  - `archivo_invalido` → "El archivo está dañado o no es un PDF/JPG/PNG válido";
  - 413 → "El archivo supera 20 MB".
- Accesibilidad: labels en todos los inputs, `aria-live` para los avisos y botones con texto.
- Nada de `fetch` a endpoints que no existen. Nada de `localStorage` con datos de legajos.

## Criterios
```
cd legajos && pnpm verificar
```
- `test/guard-cobertura.test.ts` sigue en verde.
- `grep -rn "fetch(" src/app` → sólo `/api/documentos`.

Sin `any`, sin `console.log`. Sin commit ni push.
