# L09b — Pantallas de administración

**Arquitecto:** claude-code · **Implementa:** OPENCODE · **Audita:** arquitecto
**Fuente:** requisitos §2.5 y §4, decisiones §7. **Base:** L09a (servicios) y L08a (acciones en
`src/app/(app)/admin/acciones.ts`).
**Urgente:** el enlace "Administración" ya está en producción y hoy da 404.

Usás **sólo** lo que existe:
- **lectura:** `const ctx = await ctxPagina('admin.usuarios' | 'admin.catalogos' | 'admin.accesos')` y
  `servicios().admin.listarUsuarios(ctx)`, `.listarCatalogos(ctx)`, `.listarAccesos(ctx, filtros)` y
  `.listarAuditoria(ctx, filtros)`, todos de `@/server/acciones/contexto`;
- **escritura:** las Actions de `src/app/(app)/admin/acciones.ts`, que devuelven `Resultado`;
- **enlaces crudos** (`<form action>`, `href` a la API): `conBase()` de `@/lib/base`. `<Link>` y `redirect()` no lo
  necesitan;
- los estilos y componentes de `globals.css` y `src/app/(app)/legajos/[id]/componentes/Dialogo.tsx` (reusá el
  diálogo).

**NO tocás** `src/server/**`, `src/app/api/**`, ningún `acciones.ts`, `package.json` ni `globals.css`, salvo
agregar clases nuevas al final.

## Alcance de archivos
1. `src/app/(app)/admin/page.tsx`: índice con tres tarjetas: Usuarios, Catálogos y Accesos y auditoría.
2. **`src/app/(app)/admin/usuarios/page.tsx` + componentes cliente en `admin/usuarios/componentes/`**:
   - **tabla:** usuario, nombre, rol, estado (activo, inactivo o bloqueado hasta …), "debe cambiar clave" e IPs
     (chips con su red y descripción; las inactivas en gris);
   - **Nuevo usuario:** usuario, nombre, rol (admin, operador o consulta) y al menos una IP o red (lista dinámica
     con red y descripción). Si sale bien, muestra la **clave temporal una sola vez**, en un recuadro con
     "Copiar" y el texto "Anotala ahora: no se vuelve a mostrar". **No** se guarda en ningún estado persistente ni
     en `localStorage`;
   - **acciones por fila:**
     - editar nombre y rol;
     - activar o desactivar, con confirmación en un `<dialog>`;
     - **resetear clave**, que muestra la clave temporal igual que el alta;
     - desbloquear, sólo si está bloqueado;
     - agregar IP;
     - desactivar IP, desde una × en el chip y con confirmación;
   - **errores en español:**
     - `ultimo_admin` → "No se puede: quedaría el sistema sin administradores activos";
     - `ultima_ip` → "No se puede: el usuario quedaría sin IPs desde dónde entrar";
     - `sin_ips` → "Agregale primero una IP activa";
     - `usuario_existente` → "Ese usuario ya existe";
     - validación de red → "IP o red inválida (ej. 192.168.5.10 o 192.168.5.0/24)".
3. **`src/app/(app)/admin/catalogos/page.tsx` + componentes**, con tres secciones:
   - **Estados del legajo:** nombre y orden;
   - **Tipos de interacción:** nombre y orden;
   - **Tipos de documento:** nombre, obligatorio, vigencia en días (vacío = sin vigencia) y "admite varios
     archivos".

   Cada sección tiene un alta, edición en línea o en diálogo y activar o desactivar. Los inactivos aparecen en gris
   y al final. **No hay borrar.** Errores en español:
   - `nombre_existente` → "Ya existe uno con ese nombre";
   - el del último estado activo → "Tiene que quedar al menos un estado activo".
4. **`src/app/(app)/admin/accesos/page.tsx`**, con dos pestañas:
   - **Accesos:** desde, hasta, usuario, IP y resultado. Tabla con fecha y hora en Asunción, usuario, IP,
     resultado (badge: ok en verde y el resto en rojo/ámbar, traducido: `clave_incorrecta` → "Clave incorrecta",
     `ip_rechazada` → "IP no permitida", `bloqueado` → "Cuenta bloqueada", etc.) y ruta;
   - **Auditoría:** desde, hasta, entidad y acción. Tabla con fecha, usuario, IP, entidad, acción y un detalle
     plegable (`<details>`) con `antes` y `despues` en JSON formateado;
   - paginado con `?pagina=` y 50 filas por página. Los filtros van por `searchParams` (form GET con
     `action={conBase('/admin/accesos')}`).

Cada página llama a **su** `ctxPagina` con el permiso que corresponde. El layout no autoriza nada.

## Criterios
```
cd legajos && pnpm verificar
```
- `test/guard-cobertura.test.ts` sigue en verde.
- `grep -rn "'/api\|\"/api\|action=\"/" src/app` → todo con `conBase`.
- Sin `any`, sin `console.log` y sin `localStorage`. Sin commit ni push.
