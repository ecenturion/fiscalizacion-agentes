#!/usr/bin/env bash
#
# consumo.sh — cuánto gasta opencode (Zen) y si la sesión en curso sigue viva
#
#     ./scripts/consumo.sh opencode
#
# Los modelos gratis de Zen (opencode/big-pickle y compañía) no tienen un % de
# cuota: no hay cuenta ni contador. Lo que sí puede frenarlos es la saturación
# del servidor (503 "request queue is full", "Model is unavailable") y, peor, el
# cuelgue sin salida visto el 2026-09-02 (ORQUESTA.md). Por eso esto muestra:
#
#   1. pedidos y tokens de Zen en las últimas 5 h y en el día;
#   2. el último error de Zen y hace cuánto fue;
#   3. la última sesión lanzada desde la raíz (donde corre despachar.sh), los
#      minutos desde su último movimiento y, si hay un `opencode run` vivo sin
#      moverse hace más del umbral, el aviso de cuelgue.
#
# Lee ~/.local/share/opencode/opencode.db en modo sólo lectura.
#
# Variables para probar sin tocar lo real:
#   OPENCODE_DB, CONSUMO_UMBRAL_MIN (default 15), CONSUMO_AHORA_MS, CONSUMO_PROCESO_VIVO (0|1)
#
set -euo pipefail

source "$(dirname "${BASH_SOURCE[0]}")/rutas.sh"

uso() {
  sed -n '3,5p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,4\}//' >&2
  exit 2
}

cmd_opencode() {
  local db="${OPENCODE_DB:-$HOME/.local/share/opencode/opencode.db}"
  [[ -f "$db" ]] || { echo "opencode · no hay base en $db"; return 0; }
  command -v python3 >/dev/null || { rojo "Falta python3"; exit 1; }

  # Sólo cuentan los `opencode run` con cwd en la raíz: los de otro repo no son nuestros.
  local pids="" pid
  if [[ -n "${CONSUMO_PROCESO_VIVO:-}" ]]; then
    [[ "$CONSUMO_PROCESO_VIVO" == 1 ]] && pids="(simulado)"
  else
    for pid in $(pgrep -f 'opencode run' 2>/dev/null || true); do
      [[ "$(readlink "/proc/$pid/cwd" 2>/dev/null)" == "$RAIZ" ]] && pids="${pids:+$pids }$pid"
    done
  fi

  DB="$db" RAIZ_TRABAJO="$RAIZ" PIDS="$pids" \
  UMBRAL_MIN="${CONSUMO_UMBRAL_MIN:-15}" AHORA_MS="${CONSUMO_AHORA_MS:-}" \
  python3 - <<'PY'
import json, os, sqlite3, time

db = sqlite3.connect(f"file:{os.environ['DB']}?mode=ro", uri=True)
raiz = os.environ["RAIZ_TRABAJO"]
pids = os.environ["PIDS"]
vivo = bool(pids)
umbral = int(os.environ["UMBRAL_MIN"])
ahora = int(os.environ["AHORA_MS"] or time.time() * 1000)

ROJO, VERDE, GRIS, FIN = "\033[31m", "\033[32m", "\033[90m", "\033[0m"

def miles(n): return f"{int(n):,}".replace(",", ".")
def hora(ms): return time.strftime("%d/%m %H:%M", time.localtime(ms / 1000))
def hace(ms):
    m = (ahora - ms) // 60000
    if m < 60: return f"hace {m} min"
    if m < 48 * 60: return f"hace {m // 60} h"
    return f"hace {m // 1440} días"

lt = time.localtime(ahora / 1000)
inicio_hoy = int(time.mktime((lt.tm_year, lt.tm_mon, lt.tm_mday, 0, 0, 0, 0, 0, -1)) * 1000)
inicio_5h = ahora - 5 * 3600 * 1000

ventanas = {"5h": [0, 0, 0], "hoy": [0, 0, 0]}  # pedidos, tokens, errores
modelos, ultimo_error = set(), None
for data, creado in db.execute(
        "select data, time_created from message "
        "where json_extract(data, '$.role') = 'assistant' "
        "and json_extract(data, '$.providerID') = 'opencode' and time_created <= ? order by time_created", (ahora,)):
    m = json.loads(data)
    err = m.get("error")
    if err:
        texto = str((err.get("data") or {}).get("message") or err.get("name") or "error")
        ultimo_error = (creado, texto.strip('"')[:100])
    for clave, desde in (("5h", inicio_5h), ("hoy", inicio_hoy)):
        if creado >= desde:
            v = ventanas[clave]
            v[0] += 1
            v[1] += (m.get("tokens") or {}).get("total") or 0
            v[2] += 1 if err else 0
            modelos.add(m.get("modelID"))

print(f"opencode · Zen · sin % de cuota: los modelos gratis de Zen no tienen contador")
if modelos:
    print(f"  modelos usados hoy: {', '.join(sorted(x for x in modelos if x))}")
for clave, etiqueta in (("5h", "últimas 5 h:"), ("hoy", "hoy:        ")):
    p, t, e = ventanas[clave]
    extra = f" · {ROJO}{e} con error{FIN}" if e else ""
    print(f"  {etiqueta} {miles(p)} pedidos · {miles(t)} tokens{extra}")

if ultimo_error is None:
    print("  último error: ninguno registrado")
else:
    creado, texto = ultimo_error
    color = ROJO if ahora - creado < 3600 * 1000 else GRIS
    print(f"  último error: {color}{hora(creado)} ({hace(creado)}) · {texto}{FIN}")

# Última sesión lanzada desde la raíz. Su movimiento incluye el de sus subagentes.
fila = db.execute(
    "select id, title from session where directory = ? and parent_id is null "
    "and time_created <= ? order by time_updated desc limit 1", (raiz, ahora)).fetchone()
if fila is None:
    print(f"  sesión: ninguna lanzada desde {raiz}")
    raise SystemExit(0)

sid, titulo = fila
ids = [sid] + [r[0] for r in db.execute("select id from session where parent_id = ?", (sid,))]
marcas = ",".join("?" * len(ids))
mov = max(
    db.execute(f"select coalesce(max(time_updated), 0) from part where session_id in ({marcas})", ids).fetchone()[0],
    db.execute(f"select coalesce(max(time_updated), 0) from message where session_id in ({marcas})", ids).fetchone()[0],
)
ultimo = db.execute(
    "select data from message where session_id = ? and json_extract(data, '$.role') = 'assistant' "
    "order by time_created desc limit 1", (sid,)).fetchone()
terminada = bool(ultimo and (json.loads(ultimo[0]).get("time") or {}).get("completed"))

print(f"  sesión: \"{titulo}\" · último movimiento {hora(mov)} ({hace(mov)})")
quieto_min = (ahora - mov) // 60000
if not vivo:
    estado = "terminada" if terminada else "cortada sin terminar el último mensaje"
    print(f"  estado: {GRIS}sin `opencode run` corriendo · {estado}{FIN}")
elif quieto_min >= umbral:
    print(f"  estado: {ROJO}POSIBLE CUELGUE · {quieto_min} min sin moverse (umbral {umbral}){FIN}")
    print(f"  {ROJO}→ matalo (kill -TERM {pids}) y redespachá a CODEX sombrero B{FIN}")
else:
    print(f"  estado: {VERDE}trabajando · se movió {hace(mov)}{FIN}")
PY
}

case "${1:-}" in
  opencode) cmd_opencode ;;
  *) uso ;;
esac
