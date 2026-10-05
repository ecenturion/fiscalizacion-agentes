# Auditoría L07b - Documentos

Veredicto: RECHAZADO

## Hallazgos

### Defectos en el código (`src/server/servicios/documentos.ts`)
- **reemplazo sin serializar (bloqueo fuera de orden)**: En `reemplazarDocumento`, las filas se bloquean en orden de ID (`idMenor`, `idMayor`) en las líneas 190-191, pero esto ocurre **después** de haber actualizado (y por ende bloqueado exclusivamente) la fila `anterior` en la línea 184. Esto anula el propósito del bloqueo ordenado.
- **solicitudes asignadas sin lock**: En `subirDocumento` (línea 110), cuando se verifica si la solicitud ya tiene un documento recibido (`sol.documento_recibido_id !== null`), se hace un `SELECT` del documento recibido sin `.for('update')`. Esto podría causar una condición de carrera si otra transacción está anulando ese documento simultáneamente. Además, en la línea 106 se hace un `.for('update')` sobre el documento recién insertado, lo cual es redundante.

### Defectos en las pruebas (`test/rutas-documentos.test.ts` y `test/documentos.test.ts`)
La suite de pruebas presenta mutaciones en rojo, indicando deficiencias en la cobertura:
- **auth después de consumir el cuerpo (3)**: En `src/app/api/archivos/[id]/route.ts` (línea 20) y `src/app/api/documentos/route.ts` (línea 23). Las pruebas no detectan si la autenticación se realiza después de leer parámetros o el cuerpo. Específicamente, en `test/rutas-documentos.test.ts:188`, la prueba "GET sin sesión" sigue recibiendo un 401 si se altera el orden, pasando falsamente.
- **sin lock de la solicitud (concurrencia, 2 de 3 corridas)**: La prueba `5d` (`test/documentos.test.ts:223`) utiliza `Promise.allSettled` para simular concurrencia, pero no fuerza una superposición exacta. Esto causa inestabilidad (flakiness), permitiendo que la prueba pase a veces incluso si se elimina `.for('update')`.
- **sin resolverSeguro (2)**: La prueba `8c` (`test/documentos.test.ts:287`) espera que el rechazo contenga exactamente 'Ruta fuera del almacén'. Si se elimina `resolverSeguro`, la ruta adulterada (`../../etc/passwd`) podría arrojar un error del sistema de archivos (`ENOENT`), lo cual hace fallar la aserción y debería matar la mutación. Sin embargo, la supervivencia indica que hay rutas de ejecución o resoluciones que la prueba no intercepta correctamente.
