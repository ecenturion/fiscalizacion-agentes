# M3 — Pantallas del modelo v2: legajos por cédula y trámites

**Arquitecto:** claude-code · **Implementa:** OPENCODE · **Audita:** arquitecto
**Rama:** `modelo-v2` (cd legajos && git branch --show-current → `modelo-v2`).
**Fuente:** requisitos §7 y diseño §16.2/§16.4 (UI: "Original sin determinar"; el aviso de vencido **sólo** en el
visor). Base: M2b (`a67a7b0`).

Usás **sólo** lo que existe (como en L08b):
- **lectura:** `const ctx = await ctxPagina(permiso)` y `servicios().legajos | tramites | interacciones |
  documentos | admin` de `@/server/acciones/contexto`. Las firmas están en `src/server/servicios/contratos.ts`;
  leelas;
- **escritura:** las Actions de `src/app/(app)/legajos/acciones.ts`, `src/app/(app)/tramites/acciones.ts` y
  `src/app/(app)/admin/acciones.ts`;
- **subida:** XHR POST a `conBase('/api/documentos')`, con `legajoId` (obligatorio), `tramiteId` (opcional),
  `tipoId`, `fechaEmision`, `observacion`, `solicitudesIds`, `documentoId` si es un reemplazo, y `archivos`;
- `conBase()` para cualquier `href`, `action` o `src` crudo, y `puede(ctx.rol, permiso)` sólo para ocultar botones.

**NO tocás** `src/server/**`, `src/app/api/**`, los `acciones.ts` ni `package.json`.

**Hoy `typecheck` falla sólo en las pantallas viejas.** Al terminar, `pnpm verificar` tiene que dar **exit 0**.

## Alcance de archivos
1. **Barra** (`src/app/(app)/layout.tsx`): los enlaces son **Trámites**, **Legajos** y Administración (esta
   última, si `admin.usuarios`). La raíz `/` redirige a `/tramites`.
2. **`/legajos`**, buscador de legajos:
   - filtros: cédula (prefijo; se puede escribir con puntos o ceros, el servidor normaliza) y nombre o apellido;
   - tabla con cédula (formato con puntos al mostrar, `1.234.567`), apellidos y nombres, nacimiento y cantidad de
     trámites;
   - botón "Nuevo legajo".
3. **`/legajos/nuevo`**: formulario con cédula, nombres, apellidos, nacimiento, emisión y observación.
   - **Al salir del campo cédula**, `buscarPorCedulaAccion`. Si existe, muestra "Esta cédula ya tiene legajo:
     Pérez, Juan" con un link y **deshabilita** el guardar: no se duplica.
   - Al guardar, `obtenerOCrearLegajoAccion` → redirige al legajo.
4. **`/legajos/[id]`**, el **archivo** de la cédula:
   - **cabecera:** cédula, apellidos y nombres, nacimiento, emisión y observación, con "Editar datos"
     (`legajo.editar`) y **"Corregir número de cédula"** (sólo `legajo.corregir_cedula`, en un diálogo con motivo
     obligatorio; `cedula_existente` → "Ya existe otro legajo con esa cédula");
   - **Trámites:** número (link), tipo, estado y **papel** en ese trámite: "Original", "Duplicado" o "Original sin
     determinar". Para el texto: si el trámite tiene una original y no es este legajo → Duplicado; si no tiene
     ninguna → sin determinar. Los vínculos anulados se muestran en gris, como "Desvinculado";
   - **Relacionados:** los otros legajos con los que comparte trámites, con un link a cada uno;
   - **Documentos:** todos los del legajo, agrupados por tipo, con la fecha de emisión, la **procedencia**
     ("Trámite 2026-0003" con link, o "Cargado en el legajo") y los archivos (Ver / Descargar). Las versiones
     anteriores van plegadas y los anulados tachados. Botones: "Subir documento" (al legajo, sin trámite),
     reemplazar y anular (admin).
5. **`/legajos/[id]/documentos/[docId]`**, **visor**: el de L08b adaptado. **Es el único lugar con el aviso
   "Vencido el …" o "Vigente hasta …".**
6. **`/tramites`**, buscador de trámites: número, tipo, estado y cédula vinculada. La tabla tiene número,
   tipo, estado, fecha de detección y las cédulas vinculadas (la original marcada). Botón "Nuevo trámite".
7. **`/tramites/nuevo`**:
   - tipo de trámite (sólo activos), fecha de detección y observación;
   - **cédulas involucradas**, una lista dinámica. Por cada fila se escribe la cédula y al salir del campo se usa
     `buscarPorCedulaAccion`:
     - si existe, muestra "Pérez, Juan (legajo existente)" y la usa (`{ legajoId }`);
     - si no, despliega los campos para crear el legajo (`{ nuevo: … }`);
   - un radio "Original" por fila, más la opción "Sin determinar" (por defecto).
8. **`/tramites/[id]`**, el **trámite**:
   - **cabecera:** número, tipo, estado (badge), fecha de detección, observación y "Editar" (`tramite.editar`);
   - **Cédulas vinculadas:** cédula y nombre (link al legajo) y su papel: Original, Duplicado o "Original sin
     determinar" (§16.4). Acciones:
     - **"Marcar como original"** (`tramite.editar`), más "Dejar sin determinar";
     - **"Vincular cédula"** (`tramite.vincular`): igual que una fila de nuevo trámite;
     - **"Desvincular"** (`tramite.desvincular`, sólo admin): diálogo con motivo y el aviso "las solicitudes que
       esta cédula cumplía vuelven a pendiente". `ultimo_vinculo` → "Un trámite necesita al menos una cédula".
     - Los vínculos anulados van en gris;
   - **Documentos faltantes:** según el tipo del trámite. Si no hay obligatorios definidos: "Este tipo de trámite
     no tiene documentos obligatorios";
   - **Documentos aportados en este trámite:** los que tienen `tramite_id` igual a este, con su legajo;
   - **"Subir documento"**: hay que **elegir la cédula/legajo** (sólo vínculos vivos), el tipo, la emisión y la
     observación, y **qué solicitudes pendientes cumple**: las del tipo elegido, con la más antigua preseleccionada.
     `legajo_no_vinculado` → "Esa cédula ya no está vinculada al trámite; recargá";
   - **Historial:** interacciones con su tipo, nota, usuario, fecha (America/Asuncion), "Estado: X → Y" y sus
     solicitudes (pendiente o recibida). Las anuladas, tachadas. "Anular" (admin);
   - **Registrar interacción:** tipo, nota, cambio de estado opcional (`anteriorId` = el actual) y tipos
     solicitados. `estado_desactualizado` → "El trámite cambió de estado; recargá".
9. **Admin › Catálogos** (`/admin/catalogos`):
   - nueva sección **"Tipos de trámite"**: alta, edición, activar o desactivar y **"Documentos obligatorios"**
     (diálogo con checkboxes de los tipos de documento activos → `definirDocumentosObligatoriosAccion`);
   - en los tipos de documento **se quita** "obligatorio".
10. **Borrá** las pantallas y componentes v1 que ya no aplican (alta y detalle del legajo-caso, `FormLegajo`,
    `AgregarCedula`, `MarcarOriginal` v1, etc.) o reescribilos en sus rutas nuevas. Que no queden rutas huérfanas.

## Reglas (siguen las de L08b)
- Textos en español y es-PY; fechas con Luxon en Asunción.
- Errores traducidos con los mensajes de arriba.
- Accesibilidad: labels y `aria-live`.
- Sin `localStorage`, sin `fetch` salvo la subida, sin `any` y sin `console.log`.

## Criterios
```
cd legajos && pnpm verificar      # exit 0 — typecheck limpio
```
- `test/guard-cobertura.test.ts` en verde.
- `grep -rn "'/api\|\"/api\|action=\"/" src/app` → todo con `conBase`.
- Sin commit ni push.
