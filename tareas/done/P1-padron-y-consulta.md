# P1 — Copia del padrón y servicio de consulta de cédula

**Arquitecto:** claude-code · **Implementa:** CODEX sombrero B · **Audita:** arquitecto (mutaciones)
**Rama:** `main`. **Fuente:** requisitos §8 y diseño §17. **No te conectes al servidor.** El script de copia se
prueba localmente contra una base "verificacion" de test que armás vos con 3 tablas mínimas (mismas columnas que
`verificacion`). Las columnas reales están en §17.1. Los tipos de origen son `varchar`/`char`/`date`/`numeric`; la
cédula es `varchar` con ceros a la izquierda (7 a 9 de largo).

## Alcance de archivos
1. **`drizzle/0004_*.sql`** (custom) + `meta`:
   - esquema `padron`, de owner;
   - las 4 tablas de §17.1 con sus índices;
   - `GRANT USAGE ON SCHEMA padron` y `SELECT` sobre todas las tablas a `legajos_app`, sin nada más;
   - `REVOKE ALL … FROM PUBLIC`;
   - `ALTER DEFAULT PRIVILEGES IN SCHEMA padron GRANT SELECT ON TABLES TO legajos_app`, para que el swap no pierda
     el grant. Igual el script re-otorga.

   Si drizzle no maneja bien el esquema aparte, definí las tablas en `schema.ts` con `pgSchema('padron')` sólo
   para tipar las lecturas, y verificá que `db:generate` quede sin cambios.
2. **`src/server/db/schema.ts`**: las tablas `padron.*`, de sólo lectura para la app.
3. **`deploy/padron-sync.sh`**: script de host según §17.1.
   - `set -euo pipefail` y `flock -n /var/lock/legajos-mantenimiento`. En el servidor de producción es
     `/var/lock/…`; en tests se puede configurar con una variable;
   - lee `/srv/fiscalizacion/.env-padron` o la ruta de `PADRON_ENV`. **Nunca** imprime la clave: usa
     `PGPASSWORD` sólo en el entorno de ese `psql`;
   - **fuente:** `psql` del host (cliente 13) con `\copy (SELECT … ) TO STDOUT WITH (FORMAT csv)`, sólo las
     columnas de §17.1;
   - **destino:** `docker compose -f /srv/fiscalizacion/compose.prod.yml exec -T db psql -U legajos_owner -d
     fiscalizacion`. En tests, un comando configurable con `PADRON_DESTINO_CMD`;
   - **pasos:**
     1. registra el inicio en `padron.sincronizacion`;
     2. crea `*_carga` con `LIKE … INCLUDING ALL`, sin índices pesados todavía;
     3. `\copy` de cada tabla;
     4. completa los `_norm` (`ltrim(x,'0')`, y vacío → NULL);
     5. crea los índices;
     6. **swap** en una transacción (`DROP` de la vieja, `RENAME`, re-`GRANT SELECT`);
     7. `ANALYZE`;
     8. registra `ok` con los conteos.
   - **Ante cualquier error:** `trap` → borra las `*_carga`, registra `error` con el detalle (sin credenciales) y
     sale con código ≠ 0. Las tablas vigentes quedan intactas.
   - Duplicados de `cedula_norm` en `persona` (por ejemplo `0123` y `123`): se queda con la fila de `cedula` más
     larga y cuenta los descartes en el `detalle`.
4. **`deploy/fiscalizacion-padron.cron`**: `0 2 * * * root /srv/fiscalizacion/padron-sync.sh >>
   /var/log/fiscalizacion-padron.log 2>&1`. Se instala en `/etc/cron.d/` desde el README; **no** desde
   `deploy.sh`.
5. **`scripts/deploy.sh`**: copia `deploy/padron-sync.sh` a `/srv/fiscalizacion/` (700). **No** crea
   `.env-padron`.
6. **`src/server/permisos.ts`**: `consulta.cedula` para los 3 roles, y su test.
7. **`src/server/servicios/padron.ts`** (**nuevo**): `consultarCedula(ctx, { cedula })` según §17.2, más
   `datosPadron(ctx, { cedula })` para precargar el legajo, y `sugerenciaTramite(ctx, { cedula })` → `{ habilitante:
   datos|null, duplicadas: datos[], advertencia?: 'muchas_duplicadas'|'sin_habilitante' }`.
   - Normalizá con `normalizarCedula`;
   - **una consulta por fuente**, no N+1 por duplicada;
   - auditoría `vista` con `entidad: 'consulta_cedula'` y la cédula consultada;
   - agregalo a `servicios()` en `src/server/acciones/contexto.ts` y a `contratos.ts`.
8. **`deploy/README.md`**: sección "Padrón", con la primera copia manual, el cron y cómo crear `.env-padron` (600)
   **sin pegar la clave en la terminal**: `read -s`.
9. **Tests:**
   - **`test/padron-sync.test.ts`**:
     - crea una base `verificacion_test` (fuente) con las 3 tablas y filas de ejemplo: ceros a la izquierda, una
       habilitante con 3 duplicadas, una cancelada sin habilitante, una cancelación DEVUELTA y un duplicado de
       normalización;
     - corre `padron-sync.sh` con `PADRON_ENV` y `PADRON_DESTINO_CMD` apuntando a la base de test (`psql` local
       como owner);
     - comprueba los conteos, los `_norm`, los índices, el grant SELECT (y **sin** INSERT para app) y la fila `ok`;
     - **falla a mitad** (`PADRON_FALLAR_EN=dupl`) → las tablas anteriores quedan intactas, sin `*_carga`
       sueltas, y con fila `error`;
     - la clave no aparece en stdout ni stderr.
   - **`test/padron.test.ts`**, como `legajos_app`:
     - `consultarCedula` de una habilitante → sus 3 duplicadas, de las dos fuentes, sin repetir;
     - de una cancelada → su habilitante y las hermanas;
     - de una sin habilitante → advertencia;
     - con ceros (`0001234` = `1234`);
     - `legajos` marca cuáles ya tienen legajo;
     - auditoría `vista`;
     - consulta → ok; una sesión inválida → 401;
     - `sugerenciaTramite` con más de 20 → `muchas_duplicadas`.

## Criterios
```
cd legajos && docker compose -f compose.test.yml down && docker compose -f compose.test.yml up -d --wait && pnpm verificar
pnpm db:generate     # sin cambios
bash -n deploy/padron-sync.sh
```
Sin `any`, sin `console.log`. Sin commit ni push. **No toques la UI**: va en P2.
