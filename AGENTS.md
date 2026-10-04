# AGENTS.md — Legajos · carta común del pelotón

Esta es la carta común de los cuatro agentes. Tu rol específico está en otro archivo y el prompt que te
despachó te dice cuál, por ruta.

## 1. Quién sos — leé tu rol antes de tocar nada

| Si te invocaron como | Tu rol está en | Sos |
|---|---|---|
| `claude` | `legajos-agents/CLAUDE.md` | Arquitecto · revisor · despachador |
| `agy` | `legajos-agents/AGY.md` | Implementador principal |
| `codex` | `legajos-agents/CODEX.md` | Verificador adversarial · segundo implementador |
| `opencode` | `legajos-agents/OPENCODE.md` | Peón de superficie (UI, fixtures, docs) |

Si no sabés cuál sos, **preguntá antes de escribir código**. La matriz de despacho está en
`legajos-agents/ORQUESTA.md`.

## 2. El proyecto en cinco líneas

**Sistema de Legajos para Fiscalización.** Es para la sección que atiende los casos de **múltiple cedulación**:
- un legajo por caso, que agrupa las cédulas (la original y los duplicados), los documentos escaneados (sólo el
  path en la base) y el historial de interacciones con el interesado;
- usuarios con contraseña y **restricción de IP por usuario**;
- corre en un servidor Ubuntu de la institución, en red interna.

- **Documentos que mandan:** `legajos-agents/docs/requisitos.md` (v0.3) y `legajos-agents/docs/diseno.md`. En el
  diseño, **las secciones §9–§13 mandan sobre las anteriores**, en ese orden: la más alta gana.
- **Stack:** Next.js 15.5 (App Router, runtime Node) · TypeScript estricto · PostgreSQL 16 + Drizzle · vitest
  contra un Postgres real · Playwright para e2e · pnpm.

## 3. Convenciones (no negociables, para todos)

Si una spec las contradice: **parás y reportás**.

1. **Nunca `DELETE`.** El rol de la app no tiene ese permiso. Todo se **anula** con `anulado_en`, `anulado_por` y
   `motivo_anulacion`: los tres o ninguno.
2. **Dos roles de Postgres:** `legajos_owner` migra y es dueño de todo; `legajos_app` corre la app con grants
   mínimos, **por columna**. Los tests de servicios corren como `legajos_app`.
3. **Todo `update().set({...})` lista las columnas explícitamente**, nunca una fila completa ni un spread.
4. **Toda operación protegida empieza con `requerirSesion({ permiso, mutacion })`** y los servicios reciben el
   `Contexto` que esa función devuelve. Va en páginas, route handlers y Server Actions. No en layouts. No en el
   middleware.
5. **La IP del cliente sale sólo de `X-Real-IP`** (lo pone Nginx) y se compara con `ipaddr.js`, nunca como texto.
6. **Archivos:** la base guarda sólo el path relativo. El nombre en disco lo genera el servidor. Nunca se
   sobrescribe (`link`, no `rename`). Se sirven sólo por id, a través del guard.
7. **Toda alta, cambio, anulación, vista o descarga escribe `auditoria` en la misma transacción.**
8. **UUIDv7 generados en la app.** `timestamptz` en UTC y `America/Asuncion` sólo al presentar o al calcular
   "hoy" o el "año". Luxon, nunca aritmética de calendario con `Date`.
9. **TypeScript estricto:** nada de `any` ni `@ts-ignore`. Si el tipo no cierra, el diseño está mal: reportalo.
10. **Localización es-PY.**

## 4. Reglas duras (para todos, sin excepción)

1. **NUNCA uses `sudo`.**
2. **NUNCA deployés ni toques servidores.**
3. **Si sos implementador, NUNCA hagas `git commit` ni `git push`.** El arquitecto commitea y mantiene los dos
   repos sincronizados: `git pull` al empezar y `git push` después de cada commit.
4. **NUNCA edites archivos fuera del "Alcance de archivos" de tu tarea.**
5. **NUNCA afirmes que algo compila, pasa o funciona sin pegar la salida real del comando.**
6. **NUNCA edites los archivos de rol** sin aprobación explícita de Emilio.
7. **No expongas secretos ni `.env`.**
8. **No refactorices fuera del alcance** y **no agregues dependencias** que la spec no pida.
9. Si la spec es ambigua o contradictoria, **detenete y reportá**.
10. **Respondé en español, breve.**

## 5. Dónde vive el trabajo

```
legajos-agents/docs/                         requisitos, diseño y auditorías de diseño
legajos-agents/tareas/<tarea>.md             spec lista para ejecutar
legajos-agents/tareas/done/                  specs aprobadas
legajos-agents/informes/<tarea>.informe.md   qué hizo el implementador y con qué salida real
legajos-agents/informes/<tarea>.auditoria.md veredicto del verificador
legajos-agents/estado.jsonl                  log append-only (./scripts/estado.sh)
```

Corrés con el cwd en `~/develop`, que tiene los dos repos como hermanos:
- `legajos/`: sólo código;
- `legajos-agents/`: este repo.

En `legajos/` no hay nada de agentes. Las rutas del "Alcance de archivos" son relativas a `legajos/`.

## 6. Comandos

```bash
cd legajos
pnpm verificar          # lint + typecheck + test + build
pnpm test
pnpm db:generate        # drizzle-kit generate
pnpm db:migrate         # sólo local
docker compose -f compose.test.yml up -d   # Postgres de tests
```

```bash
cd legajos-agents
./scripts/estado.sh <tarea> <pendiente|en_progreso|error|hecho> <agente>
./scripts/despachar.sh <agy|codex|codex-b|opencode> <tarea>
```
