# P2 — Pantalla "Consulta" de cédula (reemplazo de cta) y precargas

**Arquitecto:** claude-code · **Implementa:** OPENCODE · **Audita:** arquitecto
**Fuente:** requisitos §8 y diseño §17.2–§17.3. Base: P1. Los servicios están en `src/server/servicios/padron.ts` y
`contratos.ts` (`consultarCedula`, `datosPadron`, `sugerenciaTramite`). **Leé las firmas exactas.**
Lectura con `ctxPagina('consulta.cedula')` + `servicios().padron…`. Escrituras con las Actions existentes.
`conBase()` para los enlaces crudos.

**NO tocás** `src/server/**`, `src/app/api/**`, ningún `acciones.ts` ni `package.json`. **Antes de terminar, leé la
sección de bloqueos de tu propio informe:** si algo del servidor te falta, decilo ahí claramente y no lo
reemplaces con un workaround que derive datos de otra cosa.

## Alcance de archivos
1. **Barra**: el primer enlace pasa a ser **"Consulta"** (`/consulta`). La raíz `/` redirige a `/consulta`.
2. **`/consulta`** (`?cedula=` en la URL, form GET con `conBase`):
   - campo "Número de cédula" (acepta puntos y ceros) y botón Buscar;
   - **"Información del Ciudadano"** con la misma tabla que `cta`: cédula, nombre, apellidos, prontuario, sexo,
     IC (`oficina-fecha-folio-tomo-acta`), fecha de nacimiento (dd/mm/aaaa) y lugar de nacimiento;
   - **"CÉDULA CANCELADA"**, en rojo, si tiene cancelaciones: una tarjeta por cada una, con su fuente.
     - De la lista de duplicadas: cédula, prontuario, funcionario, fecha de cancelación, observaciones y
       **cédula hábil**, con un link a `/consulta?cedula=<hábil>`.
     - De la cancelación nueva: cédula confirmada (con link), fecha, usuario, comentario, estado (PROCESADA o
       DEVUELTA) y la nota (número y fecha).
   - **"Cédula habilitante y duplicadas"**: la habilitante y sus duplicadas, con nombre y un link a la consulta de
     cada una;
   - **Fiscalización:**
     - por cada cédula de ese grupo, "Ver legajo" (si existe) o "Crear legajo" (link a
       `/legajos/nuevo?cedula=X`);
     - el botón **"Cargar trámite"** → `/tramites/nuevo?cedula=<consultada>`;
   - "Datos actualizados al dd/mm/aaaa hh:mm" (`sincronizadoEn`). Si **no hubo ninguna copia**: "El padrón todavía
     no se copió; la consulta no tiene datos";
   - si no hay resultado: "No se encontró información para la cédula X".
3. **`/tramites/nuevo?cedula=X`**: con `sugerenciaTramite`, prearma las filas.
   - La habilitante va como **original** y las duplicadas **tildadas**, con sus datos del padrón, que quedan como
     legajo nuevo si no existe.
   - Se puede destildar cualquiera.
   - `muchas_duplicadas` → aviso "Esta cédula habilitante tiene N duplicadas: revisá cuáles corresponden".
   - `sin_habilitante` → aviso "No hay cédula habilitante cargada en identificación; la original queda sin
     determinar".
   - Sin `?cedula`, funciona como hoy.
4. **`/legajos/nuevo?cedula=X`**: precarga nombres, apellidos y nacimiento con `datosPadron`, editables.
5. **`/legajos/[id]`**: bloque **"Estado en identificación"**, con `consultarCedula` de la cédula del legajo:
   "Habilitada", o "Cancelada" con sus datos y la habilitante, y un link a la consulta.

## Criterios
```
cd legajos && pnpm verificar
```
- `guard-cobertura` en verde.
- Ningún enlace crudo sin `conBase`.
- Sin `any`, sin `console.log`, sin `localStorage`. Sin commit ni push.
