# Auditoría — L07a-almacen-y-validacion

**Veredicto:** RECHAZADO
**Auditor:** codex
**Diff auditado:** 7 archivos nuevos en src/server/archivos/ y test/

## Hallazgos

### 🔴 Críticos

- **src/server/archivos/recibir.ts:96** — **Temporales que quedan tras abortar**: La bandera `registro.creado` se activa como verdadera recién en el evento asíncrono `'open'`. Si la carga se aborta prematuramente (ej. por violar un límite como `filesLimit`), el bloque `abortar` llama a `destroy()` sobre el stream, pero Node.js aún puede llegar a crear el archivo vacío en disco. Como `creado` permanece en `false`, el bloque `catch` (línea 136) omite la llamada a `unlink` para ese archivo, dejándolo abandonado en el sistema y rompiendo el requerimiento de que "nunca quedan temporales de una carga abortada".
- **src/server/archivos/rutas.ts:49** — **Path traversal por Symlinks en mkdir**: La función `asegurarDirectorio` invoca a `mkdir(..., { recursive: true })` utilizando componentes concatenados *antes* de validarlos exhaustivamente con `resolverSeguro`. Si un atacante provee una ruta tipo `a/b/c` donde `a` existe previamente como un symlink apuntando hacia afuera del almacén (ej. `/etc`), la opción `recursive: true` resolverá nativamente el symlink y creará subdirectorios fuera del directorio raíz permitido antes de que el chequeo interno en `resolverSeguro` llegue a lanzar la excepción, comprometiendo gravemente el aislamiento.
- **src/server/archivos/validar.ts:44** — **Procesos hijos que sobreviven al timeout**: El parámetro `timeout` proporcionado a `execFile` desencadena el envío de la señal `SIGKILL` al proceso padre (`prlimit`) cuando se acaba el tiempo de reloj. Debido a que `prlimit` no gestiona grupos de procesos, muere de manera inmediata sin propagar el `SIGKILL` a la herramienta real de procesamiento (`qpdf` o `vips`). Esto provoca que la validación quede como un proceso huérfano ejecutándose indefinidamente en segundo plano, eludiendo por completo la restricción de los 20 segundos y posibilitando ataques de denegación de servicio (DoS) por agotamiento de memoria o CPU.
- **src/server/archivos/validar.ts:46** — **Códigos de salida mal interpretados**: Se asume de manera rígida que si el `error.code` devuelto por `execFile` coincide con `codigoEsperado`, la operación fue exitosa. Para el comando `qpdf --is-encrypted`, se espera un código `2` (documento no cifrado). Si la herramienta envoltorio `prlimit` falla internamente (por ejemplo, debido a errores de sintaxis en sus argumentos o restricciones imposibles de aplicar) y sale con código de error `2`, el sistema confundirá este fallo operativo con un éxito lógico y validará erróneamente un archivo sin siquiera haber ejecutado `qpdf`.
- **test/archivos-validar.test.ts:31** — **Tests vacuos (is-encrypted)**: La prueba que asegura rechazar `cifrado.pdf` es engañosa. Como la validación con `qpdf --check` (el primer paso) se ejecuta primero y falla ruidosamente al no poder parsear los streams cifrados del PDF, el flujo de ejecución arroja un error 422 prematuro y nunca alcanza el paso posterior que contiene `qpdf --is-encrypted`. Esto vuelve el código correspondiente inaccesible e irrastreable en la prueba, permitiendo que las mutaciones destructivas (como aceptar erróneamente el código `0` de cifrado) sobrevivan inadvertidas.
- **scripts/generar-fixtures.sh:49** — **Tests vacuos (fail_on=error)**: Para generar las imágenes inválidas (`truncado.jpg` y `truncado.png`), el script trunca artificialmente la mitad exacta de los bytes del archivo válido. Esta brusca corrupción de datos obliga a `vips avg` a abortar ruidosamente devolviendo error bajo su propio comportamiento por defecto, haciendo innecesaria la existencia del flag especializado `[fail_on=error]`. En consecuencia, el test pasa a ser vacuo, y al no discriminar casos más sutiles, ocasiona que las mutaciones que borran dicho parámetro pasen desapercibidas como reportó el arquitecto.

## Comandos que corrí

```bash
cd legajos && git status
cd legajos && git diff --staged
```
