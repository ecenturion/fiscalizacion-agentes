# L07a — almacén y validación de archivos

**Estado:** COMPLETADO · AGY no arrancó (OAuth vencido); implementó CODEX sombrero B. Auditó AGY (2do intento:
el primero se cortó por `git -C`), con veredicto RECHAZADO y 6 hallazgos. El arquitecto los verificó uno por uno.

| # | Hallazgo de AGY | Verificación | Acción |
|---|---|---|---|
| 1 | Temporal huérfano si se aborta antes de `open` | plausible | Se borran todos los temporales propios (ENOENT tolerado), salvo los que fallaron con EEXIST: son de otra carga |
| 2 | `mkdir` recursivo a través de symlinks | falso: cada componente se valida antes del siguiente | Igual se endureció: `mkdir` sin `recursive`, de a un componente |
| 3 | `prlimit` deja huérfanos tras SIGKILL | **falso**: `prlimit` hace exec (mismo PID); comprobado | ninguna |
| 4 | `prlimit` saliendo con 2 se confunde con "sin cifrar" | **falso**: sus errores salen con 1 o 127; comprobado | ninguna |
| 5 | El test de cifrado no ejercita `--is-encrypted` | **real**: `cifrado.pdf` ya falla en `--check` | Fixture nuevo `cifrado-sin-clave.pdf` (pasa `--check`); la mutación que ignora `--is-encrypted` ahora falla |
| 6 | `fail_on=error` no se prueba | **falso**: la mutación sin `fail_on` hace fallar los dos truncados | ninguna |

**Puerta §13.3:** cumplida. vips 8.18.3 y qpdf 12 bajo `prlimit --as=512MiB`: los válidos pasan y los truncados se
rechazan. No hizo falta subir a 1 GiB.

Verificación: `pnpm verificar` exit 0 · 321 tests en 2 corridas.

Mutaciones en rojo:
- sin `fail_on`;
- `--is-encrypted` aceptando 0;
- `--is-encrypted` ignorado;
- sin chequeo de symlinks.
