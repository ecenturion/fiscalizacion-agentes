# M1 — base v2

**Estado:** COMPLETADO, en la rama `modelo-v2`. CODEX sombrero B; un bloqueo legítimo (UUID de auditoría en `corregir_cedula`), resuelto con `p_auditoria_id`. Revisó el arquitecto.

Verificación:
- 147 tests de base, 2 corridas;
- `db:generate` sin cambios;
- sin `CASCADE`.

Mutaciones en rojo:
- sin red de seguridad → 3;
- procedencia sin vínculo vivo → 1;
- solicitud con un legajo desvinculado → 1;
- grant de `estado_id` → 2.
