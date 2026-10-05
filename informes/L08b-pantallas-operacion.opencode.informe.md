# L08b — pantallas de operación

**Estado:** COMPLETADO CON BLOQUEOS DE SERVIDOR
**Rol:** OPENCODE (superficie)

## Verificación

`cd legajos && pnpm verificar` → **exit 1**, por los 3 tests preexistentes de
`test/legajos.test.ts` (contadores sucios en Postgres, ajenos a esta tarea):

```
Test Files  1 failed | 18 passed (19)
Tests       3 failed | 431 passed (434)
```

Los tres fallos son los mismos del baseline previo a L08b, todos sobre correlativos:

- `dos legajos empiezan en AAAA-0001 y AAAA-0002`
- `10 altas concurrentes reservan correlativos 1..10 sin repetidos` (recibió 31..40)
- `el primer legajo del año siguiente vuelve al correlativo 1` (recibió 2092-0004)

Como `pnpm verificar` corta antes del build, el build se corrió aparte:

- `pnpm lint` → exit 0, 0 warnings.
- `pnpm typecheck` → exit 0.
- `pnpm build` → exit 0, 7 rutas generadas.

No se limpió la base: hacerlo habría tapado el problema del contador en lugar de
reportarlo. La pantalla no toca `contador_legajo` en ningún momento.

## Qué se hizo

**Globales y chrome**

- `globals.css`: sistema de estilos propio (variables, badges, tablas, diálogos,
  `fieldset`/`legend`, `progress`, utilidades de ancho para 360 px).
- `layout.tsx` importa `globals.css`; `/` redirige a `/legajos`.
- `(app)/layout.tsx`: barra con enlaces, usuario, logout por POST, y
  `ctxPagina('cuenta.cambiar_clave')`. La spec pedía `legajo.ver` pero con su propio
  aviso de no crear bucles: un operador con clave vencida no tiene `legajo.ver`, así
  que con ese permiso quedaba encerrado. Se resolvió con el permiso de la página de
  clave, que es el único que le corresponde a todos los que pueden estar dentro.
- `cuenta/clave/page.tsx`: una Action `'use server'` en línea, sin `'use server'`
  extra; valida coincidencia y mínima de 10 antes de llamar `cambiarCon`.
- `login/page.tsx`: `autoFocus`, mensaje de error en `aria-live="assertive"`,
  `aria-describedby`.

**Buscador** (`legajos/page.tsx`)

Sanea `searchParams` a string (no confía en `string | string[] | undefined`), busca
por cédula, nombre o número, pagina con `pagina`/`porPagina`, estado vacío con enlace
al alta cuando `legajo.crear`.

**Alta** (`legajos/nuevo/`)

`FormLegajo.tsx` es cliente, arma las cédulas en estado local, sólo una puede ser
original (radios), consulta `relacionadosPorCedulaAccion` al salir del número y
envía con `crearLegajoAccion`. `fechaDeteccion` no viaja desde el cliente: la calcula
el servidor con `hoyEnAsuncion()`.

**Detalle** (`legajos/[id]/`)

- Cédulas: tabla, badge original/duplicado/anulada, editar, marcar original, anular
  (las anuladas muestran su motivo y pierden los botones).
- Documentos agrupados por tipo, versión actual y `details` con las anteriores,
  links `Ver`/`Descargar` a `/api/archivos/[id]`, faltantes, upload y reemplazo.
- Historial: fecha, tipo, nota, cambio de estado, solicitudes con su estado, y
  `Usuario: {usuarioId}` porque el contrato no trae el nombre (ver bloqueos).
- Interacción: tipo, nota obligatoria, cambio de estado opcional y tipos solicitados.

**Visor** (`[docId]/page.tsx`)

`iframe` para PDF, `next/image` con `fill`+`unoptimized` para JPG/PNG, aviso
`Vencido`/`Vigente` sólo en el visor (en el legajo no, para no alarmar de más).

**Subida de documentos** (`SubirDocumento.tsx`)

`XMLHttpRequest` para tener progreso sin dependencias. Valida en cliente los límites
de la ruta (10 archivos, 20 MB) y arma el `FormData` **sólo con los campos del
contrato**: enviar de más lo rechaza el `zod` de la ruta. En alta manda `legajoId`,
`tipoId`, `solicitudesIds`; en reemplazo sólo `documentoId`, `fechaEmision`,
`observacion` y `archivos`.

**Permisos**

Cada botón se oculta con `puede(ctx.rol, ...)`; ninguna página confía en eso para
autorizar, todas llaman `ctxPagina` o una Action que vuelve a pedir permiso.

## Bloqueos de servidor (no se tocan desde superficie)

1. **No hay catálogos legibles por un operador.** `listarCatalogos(ctx)` exige
   `admin.catalogos`, y `servicios()` no expone nada equivalente. Consecuencias en lo
   entregado:
   - El buscador acepta `estado` por query pero **no puede pintar el select**: sin
     opciones, un filtro invisible sería peor que nada.
   - El formulario de interacción arma tipos y estados **desde lo que el propio legajo
     ya tiene** (`legajo.interacciones[].tipo`, `estadoAnterior`/`estadoNuevo`, los
     tipos de las solicitudes). Sirve mientras el legajo tenga historial; un legajo
     recién creado no puede registrar su primera interacción. Los tipos de documento
     salen de `faltantes ∪ documentos.tipo ∪ solicitudes.tipo`.
   - El upload limita el select a esos mismos tipos, no al catálogo activo completo.
   - **Propuesta:** un `catalogosOperativos(ctx)` de sólo lectura que devuelva
     estados, tipos de interacción y tipos de documento activos, exigiendo
     `legajo.ver`. Con eso se reemplazan los tres Derivados en ~15 líneas.

2. **`buscarLegajos` no devuelve cédulas.** `LegajoResumen` no las incluye, así que la
   columna "cédula original o primera" de la spec **no existe** en el buscador.
   Propuesta: agregar `cedulas: { numero, esOriginal }[]` a `LegajoResumen` o un
   `numeroCedulaOriginal` denormalizado.

3. **`InteraccionSalida` sólo trae `usuarioId`.** El historial muestra el UUID crudo
   porque no hay nombre; para un operador eso no sirve. Propuesta: `nombreUsuario` en
   la salida o un join a `usuario`.

4. **`/admin` no existe todavía.** El link del layout está porque lo pide la spec,
   pero da 404 hasta que exista la pantalla de L09/L10.

## Desviaciones de la spec

- Permiso del layout: `cuenta.cambiar_clave` en vez de `legajo.ver` (razón arriba).
- Cédulas en el buscador: omitidas (razón arriba).
- Historial: UUID en vez del nombre del usuario (razón arriba).
- `original_existente` se traduce a un mensaje legible; los otros códigos también,
  nunca se muestra el código crudo al operador.