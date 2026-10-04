# L05 — legajos y cédulas

**Estado:** COMPLETADO · CODEX sombrero B en 4 intentos. Los 3 bloqueos fueron legítimos y por errores de la spec:
- `ErrorConflicto` con código fijo: el arquitecto lo parametrizó y agregó `ErrorNoEncontrado`;
- ejemplo horario en UTC−4: Paraguay usa UTC−3 todo el año desde 2024;
- colisión de años de test entre archivos: hay una tabla fija de años por archivo en la spec.

Auditoría: AGY (lectura) se cortó por el allowlist sin escribir nada. Revisó el arquitecto: las 8 funciones con `exigir` + una transacción + auditoría + `.set` explícito.

Verificación: `pnpm verificar` exit 0 · 275 tests, 2 corridas desde base limpia.

Mutaciones en rojo:
- año en UTC → 1;
- sin escape en la búsqueda → 3;
- sin traducir el 23505 → 1.
