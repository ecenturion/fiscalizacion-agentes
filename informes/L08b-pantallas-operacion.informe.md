# L08b — pantallas de operación

**Estado:** COMPLETADO · OPENCODE implementó; revisó el arquitecto.

Verificación: `pnpm verificar` exit 0 · 434 tests · build con las 11 rutas. Por código: el aviso de vencido aparece sólo en el visor; hay 11 chequeos de `puede`; el único `fetch` es a `/api/documentos` (vía XHR); logout por POST.

Pendiente, que pasa a L11a:
- enlaces crudos sin basePath: logout, `/api/archivos`, `/api/documentos` y el form GET del buscador;
- el visor usa `next/image` sobre `/api/archivos`: el optimizador lo pediría sin cookie (401) y fuera del guard y la auditoría → `<img>`.
