# Informe — M1-base-v2

**Estado:** BLOQUEADO
**Agente:** codex · sombrero B
**Fecha:** 2026-10-05

## Bloqueo que requiere definición del arquitecto

La firma exigida de `legajos.corregir_cedula(p_legajo uuid, p_nueva text, p_usuario uuid, p_motivo text, p_ip inet)` no recibe el UUID de la fila de auditoría que debe insertar. La convención 8 de AGENTS.md exige «UUIDv7 generados en la app», sin defaults en la base.

Se consultó cómo proporcionar ese UUID. Propuesta: conservar los cinco parámetros y exigir que la app pase el UUIDv7 con `set_config('legajos.auditoria_id', uuidv7, true)` dentro de la misma transacción. Alternativas: ampliar la firma con `p_auditoria_id uuid`, o autorizar una excepción para generarlo en la función. **Ninguna alternativa se implementó sin definición.**

AGENTS.md §4.9 indica: «Si la spec es ambigua o contradictoria, detenete y reportá». Por eso se pausó la implementación.

## Archivos modificados

- `src/server/db/schema.ts`: cambio parcial a v2: persona por cédula normalizada y única, tablas de trámites, vínculos vivos con unicidad y original parcial, procedencia nullable y FKs de interacción/solicitud hacia trámite. Índice de nombres sin acentos trasladado al legajo.
- `drizzle/meta/_journal.json`: entrada generada para 0003.

## Archivos creados

- `drizzle/0003_needy_virginia_dare.sql`: **salida original del generador, pendiente de edición manual; NO está lista para aplicar**. Incluye `CASCADE` y el orden de drops generado no satisface §16.4.5. No se aplicó.
- `drizzle/meta/0003_snapshot.json`: snapshot generado del schema v2.

No se modificaron migraciones 0000–0002, servicios, app, otros tests ni roles. No se hizo commit ni push.

## Decisiones y evidencia

- Se eligió crear `contador_tramite` y eliminar `contador_legajo`, según §16.4.5, que manda sobre la referencia anterior al renombre.
- Interacción y solicitud renombraron la columna en el generador; la migración manual debe quitar la FK anterior y crear la nueva explícitamente.
- Se inspeccionó `node_modules/drizzle-orm/pg-core/dialect.js`: `migrate` usa `session.transaction` alrededor del bucle de migraciones pendientes. La futura 0003 queda dentro de esa transacción.
- El pnpm global es 11.22.0; el proyecto pide 11.0.0. Sin ajuste, pnpm falla al abrir su store en el entorno restringido. Para generar y ejecutar lint se usó `pnpm_config_verify_deps_before_run=false pnpm --pm-on-fail=ignore …`, evitando el cambio de versión y la reinstalación automática. No se cambiaron dependencias ni configuración del proyecto.

## Salida real

### Generación inicial

Comando, ejecutado en `legajos/`:

```sh
pnpm_config_verify_deps_before_run=false pnpm --pm-on-fail=ignore db:generate
```

Salida final del generador tras elegir crear tablas y renombrar las dos columnas:

```text
19 tables
acceso_log 7 columns 1 indexes 1 fks
auditoria 9 columns 0 indexes 1 fks
contador_tramite 2 columns 0 indexes 0 fks
documento 12 columns 1 indexes 6 fks
documento_archivo 8 columns 0 indexes 1 fks
estado_legajo 4 columns 1 indexes 0 fks
interaccion 12 columns 1 indexes 6 fks
legajo 9 columns 1 indexes 1 fks
limite_ip 3 columns 0 indexes 0 fks
sesion 8 columns 0 indexes 1 fks
solicitud_documento 5 columns 0 indexes 4 fks
tipo_documento 5 columns 1 indexes 0 fks
tipo_interaccion 4 columns 1 indexes 0 fks
tipo_tramite 4 columns 1 indexes 0 fks
tipo_tramite_documento 3 columns 0 indexes 2 fks
tramite 10 columns 0 indexes 3 fks
tramite_legajo 9 columns 2 indexes 4 fks
usuario 10 columns 0 indexes 0 fks
usuario_ip 7 columns 0 indexes 2 fks

[✓] Your SQL migration file ➜ drizzle/0003_needy_virginia_dare.sql 🚀
```

Código de salida: 0.

### Lint con ajuste del entorno

```sh
pnpm_config_verify_deps_before_run=false pnpm --pm-on-fail=ignore lint
```

```text
$ eslint .
```

Código de salida: 0; sin salida adicional.

### Comando de verificación exigido por la spec

Ejecutado en `legajos/`:

```sh
pnpm lint && docker compose -f compose.test.yml down && docker compose -f compose.test.yml up -d --wait && pnpm vitest run test/schema.test.ts test/triggers.test.ts test/permisos.test.ts test/migracion-0003.test.ts test/humo.test.ts
```

```text
[ERROR] unable to open database file
For help, run: pnpm help run
```

Código de salida: 1. La cadena se detuvo en pnpm lint: no ejecutó down/up ni vitest.

### Segundo criterio exigido

```sh
pnpm db:generate
```

```text
[ERROR] unable to open database file
For help, run: pnpm help run
```

Código de salida: 1. No se verificó «No schema changes».

## Pendiente

- Resolver el mecanismo del UUID de auditoría.
- Editar la migración generada con red de seguridad, drops explícitos sin CASCADE y el orden de §16.4.5.
- Implementar triggers, grants mínimos explícitos, corregir_cedula y seed.
- Reescribir los tres tests permitidos y crear migracion-0003.test.ts.
- Ejecutar la verificación completa de base y confirmar «No schema changes».
- Someter el resultado terminado a AGY y al arquitecto; este informe no es una auditoría de código propio.

