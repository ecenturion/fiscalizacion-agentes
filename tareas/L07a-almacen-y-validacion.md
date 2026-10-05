# L07a — Almacenamiento de archivos y validación nativa

**Arquitecto:** claude-code · **Implementa:** AGY · **Audita:** CODEX (sombrero A)
**Fuente:** diseño §3.6, §9.13–§9.15, §10.5–§10.7, §11.3, §12.1 y **§13**. **§13 manda** sobre las anteriores.
**Base:** L06 (`7c7e06c`). En la máquina están `qpdf`, `vips`, `vipsheader` y `prlimit` (`pnpm sistema:check` ok).

Esta tarea **no** toca la base ni Next: son módulos puros de servidor con sus tests. Los servicios y las rutas
van en L07b.

## Alcance de archivos (nuevos)
1. `src/server/archivos/rutas.ts`:
   - `rutaFinal(raiz, legajoId, documentoId, ext)` → `<legajoId>/<documentoId>/<uuidv7>.<ext>`, relativa, generada
     por el servidor. Nunca recibe un nombre del cliente.
   - `resolverSeguro(raiz, relativo)`:
     1. hace `realpath` de la raíz;
     2. `path.resolve` + `realpath` del destino;
     3. comprueba `path.relative(raizReal, real)`: no empieza con `..` y no es absoluta → si no, lanza;
     4. `lstat` de **cada componente** desde la raíz: si alguno es un symlink → lanza.
   - `asegurarDirectorio(raiz, relativoDir)` usa `mkdir` con `recursive` y `mode 0o700`.
2. `src/server/archivos/validar.ts`, según §12.1 y §13. Pasos:
   1. `detectarTipo(tmp)`: los primeros bytes con `file-type` → `application/pdf`, `image/jpeg` o `image/png`. Si
      no es ninguno → `ErrorValidacion('tipo_no_permitido')`;
   2. `validarArchivo(tmp, mime)`: corre las herramientas con `execFile` (**sin shell**). Cada comando va como
      `prlimit --as=536870912 --cpu=20 -- <cmd> <args>`, con un timeout de reloj de 20 s y `SIGKILL`:
      - **PDF**, en este orden (§13.2):
        1. `qpdf --check` → código 0 = ok; si no, inválido;
        2. `qpdf --is-encrypted` → **2 = sin cifrar (ok)**, 0 = cifrado (inválido); cualquier otro código, inválido;
        3. `qpdf --show-npages` → 0 = ok, y devuelve las páginas;
      - **JPEG y PNG:**
        1. `vips avg "<tmp>[fail_on=error]"` (§13.1). El argumento va como **un solo elemento** del array de
           `execFile`;
        2. `vipsheader -f width <tmp>` y `vipsheader -f height <tmp>`;
   3. resultado: `{ mime, paginas? , ancho?, alto? }`. Si falla una señal, el código o el timeout →
      `ErrorValidacion('archivo_invalido')`.
   - El límite `--as` se lee de `VALIDACION_MEMORIA_BYTES` (por defecto 536870912). Si vips no arranca con 512 MiB,
     el test lo detecta y se sube a 1 GiB documentándolo (§13.3).
3. `src/server/archivos/recibir.ts`, **stream a disco** (§9.13, §10.5). `recibirMultipart(request, { raiz,
   maxArchivo = 20 MiB, maxArchivos = 10, maxTotal = 205 MiB })` hace lo siguiente:
   - `Readable.fromWeb(request.body)` → un contador de bytes que corta a `maxTotal` → `busboy` con
     `limits: { fileSize, files, fields: 20, parts: 30, fieldSize: 10 KiB }`;
   - cada archivo va a `<raiz>/.tmp/<uuidv7>` con `flags: 'wx'` y `mode 0o600`, con el sha256 calculado en el
     stream. Al cerrar, `fsync` y `close`;
   - lanza `ErrorArchivoGrande` (413) ante:
     - `limit` de un archivo;
     - `truncated`;
     - `filesLimit`, `fieldsLimit` o `partsLimit`;
     - un campo con `nameTruncated` o `valueTruncated`;
     - pasarse del total.

     Agregá `ErrorArchivoGrande` a `errores.ts`: es el único cambio permitido ahí;
   - **al abortar**, en este orden:
     1. `unpipe`;
     2. `destroy` de cada escritura;
     3. `await` de su `close`;
     4. `unlink` de cada temporal.

     Nunca quedan temporales de una carga abortada;
   - devuelve `{ campos: Record<string,string>, archivos: { tmp, nombreOriginal, bytes, sha256 }[] }`. El nombre
     original es sólo un metadato: se recorta a 255 y se le sacan caracteres de control.
4. `src/server/archivos/publicar.ts` (§9.15). `publicar(raiz, tmp, relativoFinal)` hace:
   1. `asegurarDirectorio`;
   2. `link(tmp, final)`, que **falla si existe**. Nunca `rename` ni `copyFile`;
   3. `fsync` del directorio;
   4. **no** borra el tmp: eso lo hace L07b, después del COMMIT.

   `descartarFinal(raiz, relativo)` existe para el rollback explícito.
5. `test/fixtures/archivos/`, archivos **chicos** generados con `scripts/generar-fixtures.sh` (también nuevo,
   commiteable). La salida va commiteada:
   - `valido.pdf`, `valido.jpg` y `valido.png`;
   - `cifrado.pdf` (`qpdf --encrypt`);
   - `falso.pdf`: texto con `%PDF-` al principio y `%%EOF` al final, sin estructura;
   - `truncado.pdf`;
   - `truncado.jpg` y `truncado.png`, que conservan la cabecera y les falta la mitad de los datos;
   - `texto.txt`.
6. `test/archivos-validar.test.ts`, la **puerta de §13.3**, con `prlimit` real:
   - válidos → ok, con páginas o dimensiones;
   - `cifrado.pdf`, `falso.pdf`, `truncado.*` → `archivo_invalido`;
   - `texto.txt` y un PNG renombrado a `.pdf` → se decide por contenido, no por la extensión;
   - un timeout simulado (un comando que duerme, inyectado) → `archivo_invalido` y el proceso hijo no sigue vivo.
7. `test/archivos-almacen.test.ts`:
   - `resolverSeguro` rechaza `../x`, rutas absolutas, symlinks a afuera y un symlink de directorio intermedio;
   - `publicar` no sobrescribe un final existente (`EEXIST`) y crea directorios con 0700;
   - `recibirMultipart`, con un `Request` armado en el test:
     - 2 archivos ok, con su sha256;
     - un archivo de 21 MiB → 413 y **`.tmp` queda vacío**;
     - 11 archivos → 413 y `.tmp` vacío;
     - un campo de 11 KiB → 413;
     - un total de más de 205 MiB → 413. Para eso se puede inyectar `maxTotal` chico.

## Dependencias (versiones exactas)
`busboy@1.6.0`, `@types/busboy@1.5.4` y `file-type@22.1.1`.
**Nada de `sharp` ni `pdf-lib`** (§12.1).

## Criterios
```
cd legajos && pnpm sistema:check && pnpm verificar
```
Sin `any`, sin `console.log`, sin shell en `execFile`. Sin commit ni push.
