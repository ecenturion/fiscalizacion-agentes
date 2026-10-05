# L07b — documentos

**Estado:** COMPLETADO.
- AGY implementó el servicio y las rutas en 2 intentos, pero se cortó: le negaron `psql` y `tsc`, y un `sed`
  global le rompió el test.
- CODEX sombrero B completó y reescribió los tests (54 nuevos).
- Auditó AGY (lectura): RECHAZADO. El arquitecto lo revisó:
  - los 3 hallazgos sobre tests confunden "mutación en rojo" (detectada) con mutación sobreviviente: no aplican;
  - el test de concurrencia 5d depende del timing: es cierto, ya estaba anotado;
  - el orden de los locks en el reemplazo es falso: el anterior se bloquea al principio, y el nuevo no lo ve
    nadie más;
  - la lectura del documento recibido sin lock era una carrera benigna (un 409 de más). Se endureció con
    `FOR UPDATE`.

Verificación: `pnpm verificar` exit 0 · 380 tests, en 2 corridas más una después del ajuste.

Mutaciones en rojo:
- `verArchivo` sin `resolverSeguro` → 2 (path adulterado y symlink);
- auth después de leer el cuerpo → 3;
- sin lock de la solicitud → la concurrencia falla en 2 de 3 corridas.

Pendiente menor:
- hacer determinista el test 5d con una barrera (advisory lock);
- el `FOR UPDATE` sobre el documento recién insertado es redundante, pero inocuo.
