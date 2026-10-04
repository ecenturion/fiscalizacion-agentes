# L01 — Esqueleto del proyecto

**Arquitecto:** claude-code · **Implementa:** AGY · **Audita:** arquitecto
**Fuente:** `docs/diseno.md` §1 (stack y convenciones), §2.4 (roles) y §12.1 (dependencias del sistema).

**Objetivo:** que `~/develop/legajos` sea un proyecto Next.js 15.5 vacío pero completo en herramientas, con
`pnpm verificar` en verde, Postgres de tests con los dos roles y Drizzle configurado. **Sin funcionalidad.**

## Alcance de archivos (todos nuevos, en `legajos/`)
1. `package.json`:
   - nombre `legajos`, privado, `packageManager` pnpm 11, `engines.node` >= 22;
   - **versiones exactas** (sin `^`), ya resueltas por el arquitecto. **No consultes npm**: `npm info` no está
     permitido y no hace falta.
     - dependencias: `next@15.5.27`, `react@19.2.8`, `react-dom@19.2.8`, `drizzle-orm@0.45.3`, `postgres@3.4.9`,
       `zod@4.1.13`, `luxon@3.7.2`;
     - devDependencies: `drizzle-kit@0.31.11`, `typescript@5.9.3`, `vitest@3.2.7`, `tsx@4.23.15`, `eslint@9.39.5`,
       `eslint-config-next@15.5.27`, `@eslint/eslintrc@3.3.7`, `@types/node@22.20.5`, `@types/react@19.2.18`,
       `@types/react-dom@19.2.7`, `@types/luxon@3.7.6`;
   - scripts:
     - `dev`: `next dev -H 127.0.0.1`;
     - `build`;
     - `start`: `next start -H 127.0.0.1`;
     - `lint`: `eslint .`;
     - `typecheck`: `tsc --noEmit`;
     - `test`: `vitest run`;
     - `verificar`: `pnpm lint && pnpm typecheck && pnpm test && pnpm build`;
     - `db:generate`;
     - `db:migrate`: `tsx src/server/db/migrar.ts`;
     - `sistema:check`: `bash scripts/chequear-sistema.sh`.
2. `pnpm-lock.yaml`, generado.
3. `tsconfig.json`: `strict`, `noUncheckedIndexedAccess`, alias `@/*` → `src/*`.
4. `next.config.ts`: `poweredByHeader: false` y nada más.
5. `eslint.config.mjs`: flat config de next. Regla `no-restricted-syntax` que prohíbe un `SpreadElement` dentro
   del objeto que se pasa a `.set(...)`. Mensaje: "listá las columnas: grants por columna (diseño §9.7)".
   `@typescript-eslint/no-explicit-any`: error.
6. `vitest.config.ts`: entorno node, `fileParallelism: false` (una sola base de tests).
7. `compose.test.yml`: `postgres:16`, puerto **55433**, base `legajos_test`, `tmpfs` para los datos, healthcheck.
   El usuario del contenedor es superusuario: sólo para el setup.
8. `test/setup-roles.sql`, idempotente:
   - crea los roles `legajos_owner` (LOGIN, no superusuario, dueño de la base y del esquema `legajos`) y
     `legajos_app` (LOGIN, sin membresía en owner);
   - `REVOKE CREATE ON SCHEMA public FROM PUBLIC`;
   - esquema `legajos` de owner;
   - `ALTER ROLE legajos_app SET search_path = legajos`.
9. `test/global-setup.ts`: aplica `setup-roles.sql` como superusuario y después migra como `legajos_owner`.
   Variables:
   - `TEST_ADMIN_URL`, por defecto `postgres://postgres:postgres@localhost:55433/legajos_test`;
   - `TEST_OWNER_URL`;
   - `TEST_APP_URL`.
10. `drizzle.config.ts`: `schema` en `src/server/db/schema.ts`, `out` en `drizzle/`, `schemaFilter: ['legajos']`.
11. `src/server/db/schema.ts`: sólo `export const legajos = pgSchema('legajos')`, sin tablas, porque L02 las crea.
12. `src/server/db/index.ts`: `conectar(url)` con postgres.js + drizzle. Sin singletons globales mutables
    fuera de este archivo.
13. `src/server/db/migrar.ts`: aplica `drizzle/` con `MIGRATE_DATABASE_URL`, que es el rol owner.
14. `src/app/layout.tsx` y `src/app/page.tsx`: un `<h1>Legajos</h1>`, `lang="es"`.
15. `test/humo.test.ts`, que comprueba tres cosas:
    - (a) conecta como `legajos_app` y `select current_user` → `legajos_app`;
    - (b) `legajos_app` **no** es miembro de `legajos_owner` (`pg_has_role`);
    - (c) `legajos_app` no puede `CREATE TABLE legajos.x` → 42501.
16. `scripts/chequear-sistema.sh`: verifica que existan `qpdf`, `vips`, `vipsheader` y `prlimit`, e imprime
    qué falta con el `apt install` (Ubuntu) o `dnf install` (Fedora) correspondiente. Sale con 1 si falta algo.
    **No** lo llama `verificar`.
17. `.gitignore`: node_modules, `.next`, `.env*` salvo `.env.example`, `coverage`.
18. `.env.example`, con comentarios y **sin valores reales**:
    - `DATABASE_URL`, que es el rol app;
    - `MIGRATE_DATABASE_URL`, que es el rol owner;
    - `ARCHIVOS_DIR`;
    - `APP_ORIGIN`;
    - `TRUST_PROXY`.
19. `README.md`: qué es, requisitos (Node 22, pnpm, Docker para tests, qpdf y libvips), cómo levantar los tests y
    `pnpm verificar`.

## Criterios
```
cd legajos && docker compose -f compose.test.yml up -d --wait && pnpm install && pnpm verificar
```
- exit 0;
- `humo.test.ts`: 3/3;
- `next build` ok;
- `git status` sin basura (nada de `.next` ni `node_modules` sin ignorar).

Sin `any`, sin `console.log` en `src/`. **Sin commit ni push.**
