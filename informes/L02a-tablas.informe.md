# L02a — tablas y constraints

**Estado:** COMPLETADO · AGY se cortó dos veces por el allowlist (`rm`, `git restore`); CODEX sombrero B implementó partiendo del schema de AGY. Revisó el arquitecto (CODEX no audita lo que escribió).

Corrección del arquitecto: `vigencia_dias` vuelve a ser nullable (omisión del diseño §9.1, corregida en §14) y regeneró la 0001 conservando el SQL a mano (pg_trgm, unaccent, `f_unaccent` IMMUTABLE, índice GIN). Test nuevo: tipo sin vigencia → ok.

Verificación: `pnpm verificar` exit 0 (56 tests), `db:generate` sin cambios, 3 corridas estables desde base limpia. Mutaciones en rojo: índice de original no único → 1; check de estado `true` → 3; sin chequeo de motivo vacío → 1.
