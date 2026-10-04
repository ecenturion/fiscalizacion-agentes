# ORQUESTA.md — cómo se reparte y se despacha el trabajo

Manual del **despachador** (Claude Code). Los otros agentes no necesitan leerlo entero, pero acá
está la explicación de por qué les llega lo que les llega.

## Lo primero de la sesión: `git pull` en los dos repos

Antes de leer una spec, antes de elegir agente, antes de nada:

```bash
git -C legajos pull
git -C legajos-agents pull
```

Y `git push` después de cada commit. **Es responsabilidad del despachador, no de Emilio.**

El 2026-09-02 esta sesión arrancó sobre copias tres y siete commits atrás, y rehizo T23, T25 y
T26 enteras: ya estaban hechas y pusheadas el día anterior. Un día de trabajo tirado, y no se
notó hasta el `push`. Estar desactualizado **no se siente distinto** mientras trabajás: los
tests pasan, las specs parecen pendientes, todo cierra. Se descubre tarde o no se descubre.

## El pelotón

| Agente | CLI | Rol | Zona del código | Riesgo que se le confía |
|---|---|---|---|---|
| **Claude Code** | `claude` | Arquitecto · revisor · despachador | Ninguna: escribe specs, revisa diffs, hace el merge | Decisiones de diseño |
| **AGY** | `agy` | Implementador principal | `src/server/**`, `src/app/api/**`, schema, migraciones, scripts | Alto: el núcleo |
| **CODEX** | `codex` | Verificador adversarial · segundo implementador | Sombrero A: ninguna (read-only). Sombrero B: lo que se le asigne, disjunto | Alto, pero siempre auditado |
| **OPENCODE** | `opencode` | Peón de superficie | Pantallas de `src/app/(app)` y `(auth)`, componentes, docs | Bajo por diseño |

Regla que ordena todo lo demás: **cuanto más cerca de la auth, la IP, los grants y los archivos, más
arriba en esta tabla tiene que estar el agente que lo toca.**

## Matriz de despacho

| Lo que hay que hacer | Va a | Auditado por |
|---|---|---|
| Schema, migraciones, grants, triggers | AGY | CODEX (sombrero A) — **obligatorio** |
| Auth, sesiones, IP, CSRF, servicios, archivos | AGY | CODEX (sombrero A) — **obligatorio** |
| Servicios de sólo lectura, búsquedas | AGY o CODEX (B) | el otro de los dos |
| Pantallas, componentes, estados vacíos | OPENCODE | Claude Code |
| Formato es-PY, helpers de presentación | OPENCODE | Claude Code |
| Seeds, fixtures | OPENCODE | Claude Code |
| e2e Playwright | AGY | CODEX |
| Docs, README de paquetes | OPENCODE | Claude Code |
| Refactor mecánico declarado en la spec | OPENCODE | CODEX si toca más de 10 archivos |

**Auditoría obligatoria de CODEX** para todo diff que toque: schema, grants, auth, IP, sesiones,
servicios o archivos. Para el resto, la decide el arquitecto.

## El ciclo de una tarea

```
   spec (Claude)
       │
       ▼
   implementa (AGY | CODEX-B | OPENCODE)   ──► informe con salida real
       │
       ▼
   pnpm verificar   ← lo corre Claude, siempre, con sus propios ojos
       │
       ├── falla ──► error → hasta 2 reintentos → si sigue: error claude-code, se re-planifica
       │
       ▼
   auditoría CODEX (si toca zona crítica)  ──► legajos-agents/informes/<tarea>.auditoria.md
       │
       ├── RECHAZADO ──► vuelve al implementador con los hallazgos
       │
       ▼
   Claude aprueba → estado hecho → informe → spec a done/ → commit del repo de agentes
```

**El arquitecto siempre corre `pnpm verificar` él mismo.** Un informe que dice "pasa" no es
evidencia; la salida del comando en la terminal del arquitecto sí.

## Comandos de delegación

Uno solo, para los cuatro casos:

```bash
./scripts/despachar.sh agy      <tarea>   # núcleo: schema, auth, servicios, archivos
./scripts/despachar.sh codex    <tarea>   # sombrero A: audita el diff, read-only
./scripts/despachar.sh codex-b  <tarea>   # sombrero B: implementa, alcance disjunto
./scripts/despachar.sh opencode <tarea>   # superficie: componentes, es-PY, seeds, docs
```

`despachar.sh` es el único lugar donde vive el cableado de cada CLI: el cwd, el sandbox, el
modelo, las banderas y la ruta del archivo de rol. Si un CLI cambia de comportamiento, se
arregla ahí y no en cinco prompts copiados a mano. Antes de despachar registra el estado;
después imprime **lo que quedó escrito de verdad**, comparando `git status --short` del repo
del código antes y después. Esa foto es la evidencia, no el informe del agente.

### La regla del cwd: todo corre desde la raíz de trabajo

```
<raiz>/                    <- acá corren los tres CLIs
  legajos/            <- sólo código. Ni un archivo de agente adentro.
  legajos-agents/     <- roles, specs, informes, estado, scripts
```

De ahí salen las rutas que van en los prompts: `legajos-agents/AGY.md`,
`legajos-agents/tareas/<tarea>.md`, y el código en `legajos/`. Las rutas del
**"Alcance de archivos"** de una spec son relativas a `legajos/`.

Que el repo del código esté limpio no es estética: el sandbox de `codex` no puede marcar
read-only un path que cruza un symlink saliente, y el viejo `legajos/.agents ->
../legajos-agents` era exactamente eso. Sin él, `--sandbox workspace-write` funciona.

**Ningún CLI carga su archivo de rol solo.** Los roles viven en este repo y el repo del código
sólo tiene código: ninguno de los tres los descubre por su cuenta. Por eso **cada prompt de
delegación nombra el archivo de rol por ruta**, y por eso el prompt lo arma `despachar.sh` y no
la memoria de nadie. Un prompt que dice sólo "siguiendo OPENCODE.md" no alcanza: el agente
contesta que su rol sale de su propio system prompt y trabaja sin las convenciones del proyecto.

### Fallas del cableado y cómo se arreglan (revisado 2026-09-02)

Ninguna es del código del proyecto. Las que ya están resueltas en `despachar.sh` quedan
anotadas para que nadie las vuelva a introducir.

| Síntoma | Causa | Estado |
|---|---|---|
| `codex exec --sandbox workspace-write -C ~/develop/legajos` falla antes de correr nada: `cannot enforce sandbox read-only path .../legajos/.agents because it crosses writable symlink` | `.agents` era un symlink que salía del workspace; bubblewrap no puede marcar read-only un path que lo cruza. `writable_roots` **no** lo resuelve | **Resuelto.** Se borró el symlink y el repo del código quedó limpio; todo corre con `-C <raiz>`. No vuelvas a meter un symlink en `legajos/` |
| `agy -p` devuelve `status: CANCELED` a los 40 s con `num_turns: 1`, cortando justo antes del primer comando | En modo headless una herramienta que pide permiso **se auto-deniega**: no hay dónde preguntar. El mensaje real es `a tool required the "command" permission that headless mode cannot prompt for, so it was auto-denied` | **Resuelto.** El allowlist de `~/.gemini/antigravity-cli/settings.json` → `permissions.allow` ya tiene `pnpm`, `sed`, `find`, `rg`, `mkdir`, `echo` y compañía. Formato: `"command(pnpm)"`, que matchea por prefijo de palabra. Si aparece un comando nuevo auto-denegado, se agrega ahí |
| CODEX sombrero B verifica y `packages/db` falla con 10 de 11 archivos por conexión, aunque el contenedor esté arriba | El sandbox `workspace-write` de codex **bloquea la red**, y eso incluye `localhost:55432`. La verificación entera da un falso negativo | **Resuelto.** `despachar.sh codex-b` pasa `-c sandbox_workspace_write.network_access=true`. Comprobado el 2026-09-02: con la bandera, 81/81; sin ella, 10 archivos fallan y 78 tests quedan skipped |
| `agy` pide login OAuth y muere con `authentication timed out` a los 60 s | El token de `~/.gemini/antigravity-cli/antigravity-oauth-token` caducó. En headless nadie puede pegar el código a tiempo | **Resuelto por Emilio el 2026-09-02.** Se renueva corriendo `agy` interactivo y completando el OAuth en el navegador. Un código pegado tarde no sirve: el `code_challenge` es de esa corrida |
| `agy` responde `Error: Individual quota reached. Please upgrade your subscription to increase your limits. Resets in 1h43m` | Cuota de la suscripción agotada. No es configuración ni permisos: autenticado está | **No tiene arreglo técnico**: se espera a que resetee o se sube el plan. Verificado el 2026-09-02, justo después de renovar el login. Mientras tanto el núcleo lo cubre CODEX sombrero B |
| `opencode -m opencode/big-pickle` se queda colgado: **51 minutos sin una sola línea de salida** y sin escribir un archivo. No falla, no sale, no avanza | Sin diagnosticar. No es cuota —big-pickle no pasa por Google— ni permisos: leyó la spec y los dos archivos de rol, y ahí se quedó. Visto el 2026-09-02 | **Ponele un reloj.** Si pasan ~15 min sin que `git -C legajos diff --numstat` se mueva, matalo (`kill -TERM`) y redespachá a CODEX sombrero B. No esperes una hora a ver si reacciona |
| `opencode run -m google/gemini-3.1-pro-preview` corta con `Quota exceeded ... limit: 0` | El free tier de Gemini tiene cuota **cero** para 3.1 Pro | **Descartado** hasta que haya cuota |
| `opencode` termina con `exit 0` a mitad de la tarea, sin verificación ni informe | **No es que "se corte": es cuota.** `gemini-3.5-flash` en free tier permite 20 requests (`limit: 20`, `Please retry in 48s`) y opencode sale en vez de esperar. Una tarea de 12 archivos gasta eso en cinco | **Resuelto.** El default de `despachar.sh` es `opencode/big-pickle`, que no pasa por Google ni consume cuota de Gemini. Para forzar otro: `MODELO_OPENCODE=google/gemini-3.5-flash ./scripts/despachar.sh opencode <tarea>`, y ahí sí, lotes de 3-4 archivos |

**AGY se corta a los ~7 minutos por invocación.** En T22 devolvió `CANCELED` a los 430 s con
`--print-timeout 25m`, así que el corte no lo gobierna esa bandera: alcanzó a hacer 7 de 11
archivos y quedó a mitad. Contá con **seis o siete archivos por despacho**, no más. La foto que
imprime `despachar.sh` al final te dice qué quedó escrito.

**No corras `pnpm test` mientras una auditoría de CODEX está en vuelo.** Comparten la base de
`compose.test.yml` y los `TRUNCATE` entre suites se pisan: en T24a la auditoría reportó un fallo
de `apps/api` que no existía —los 137 pasaban al correrlos solos—. Si hay que auditar y probar a
la vez, pedile a CODEX que sólo lea el código.

**No pidas `JSX.Element` como tipo de retorno en una spec.** React 19 no expone el namespace
global `JSX` y no compila (`TS2503`). El proyecto no anota el retorno de sus componentes.

**La regla que sale de todo esto:** un `exit 0` de un agente **no significa que la tarea esté
hecha**. En T19 opencode salió con código 0 tres veces dejando 5 de 12 archivos, después 6,
después 7, y el error de cuota aparece en la última línea del log, no en el estado de salida.
Por eso el despacho termina siempre mostrando el `git status --short` real.

### Modelos y credenciales (verificado 2026-09-02 en esta máquina)

| Agente | Modelo | Estado |
|---|---|---|
| `agy` | `Claude Opus 4.6 (Thinking)`, fijado en `~/.gemini/antigravity-cli/settings.json` | ⏳ login renovado y allowlist al día, pero **sin cuota**: `Individual quota reached`. Vuelve solo cuando resetea. Mientras, el núcleo lo cubre CODEX sombrero B |
| `codex` | `gpt-5.6-sol` (openai) | ✅ lectura, auditoría y escritura, con el workspace en la raíz |
| `opencode` | `opencode/big-pickle` (default de `despachar.sh`) | ✅ verificado; no consume cuota de Google |
| `opencode` | `google/gemini-3.5-flash` | ⚠️ anda, pero muere a los 20 requests por cuota del free tier |

Las credenciales de DeepSeek están cargadas pero **sin saldo** (`Insufficient Balance`).
`opencode.json` fija modelo e `instructions`, pero **vive en este repo**: corriendo desde la
raíz opencode no lo lee, así que el modelo va siempre por `-m`, y de eso se ocupa
`despachar.sh`.

**Mientras AGY no responda** —por cuota o por lo que sea—, el reparto se corre un lugar: lo que iba a AGY va a CODEX sombrero
B, y la auditoría la hace Claude Code (regla intacta: **CODEX nunca audita código de CODEX**).

### Smoke test del cableado

Después de tocar cualquier archivo de rol, o de mover carpetas:

```bash
./scripts/smoke.sh
```

Le pregunta a cada CLI quién es y cuál es su archivo de rol. Tienen que contestar
`codex`/`CODEX.md`, `opencode`/`OPENCODE.md` y `agy`/`AGY.md`. Si alguno contesta que es el
arquitecto, se rompió la guarda de rol: `AGENTS.md` §1 y la cabecera de `CLAUDE.md`.

## Paralelismo (regla de seguridad)

Sólo se paralelizan tareas con **alcances de archivo disjuntos**. Si dos tareas comparten un
archivo, van en serie. Sin excepción: no hay merge automático que valga cuando el árbol está sin
commitear y tres agentes escriben encima.

Antes de lanzar dos agentes a la vez, el despachador escribe la intersección:

```bash
# alcance de cada spec, ordenado, y su intersección — tiene que dar vacío
comm -12 <(sort /tmp/alcance-A.txt) <(sort /tmp/alcance-B.txt)
```

**El merge lo hace siempre el arquitecto, nunca un implementador.** Y como el repo del código no
se commitea desde los agentes, dos implementadores en paralelo comparten el mismo working tree:
si sus alcances no son disjuntos, se pisan sin que nadie se entere.

Combinaciones seguras y probadas:

- **AGY en `src/server` + OPENCODE en `src/app/(app)`** — sin intersección, si la spec de OPENCODE sólo consume contratos ya commiteados.
- **CODEX sombrero A + cualquiera** — la auditoría es read-only, nunca colisiona.

Combinación prohibida: **dos implementadores en el mismo paquete**, aunque sean archivos distintos.

## Nombres de agente en `estado.jsonl`

Sólo estos cuatro, exactamente así: `claude-code` · `agy` · `codex` · `opencode`.
Cualquier otro rompe el filtrado del log.

```bash
./scripts/estado.sh --ver                    # últimos 20 eventos
./scripts/estado.sh --ver L04-login       # todo el historial de una tarea
```

## Nombres de informe

```
legajos-agents/informes/<tarea>.informe.md            implementación de AGY (el caso por defecto)
legajos-agents/informes/<tarea>.codex.informe.md      implementación de CODEX sombrero B
legajos-agents/informes/<tarea>.opencode.informe.md   implementación de OPENCODE
legajos-agents/informes/<tarea>.auditoria.md          veredicto de CODEX sombrero A
```

## Qué no se delega nunca

1. **La spec.** La escribe el arquitecto. Un implementador que se escribe su propia spec optimiza
   por lo que le resulta fácil de implementar, no por lo que el producto necesita.
2. **El merge** entre trabajos paralelos.
3. **La verificación final.** El arquitecto corre `pnpm verificar` con sus propios ojos.
4. **El deploy.** Lo hace Emilio, con `./scripts/deploy.sh`. Ningún agente toca el VPS.
5. **El commit y el push.** Los hace el arquitecto, nunca un implementador. Y **el `pull` al
   empezar tampoco se delega**: es lo primero de la sesión, en los dos repos, antes de mirar
   una spec.
