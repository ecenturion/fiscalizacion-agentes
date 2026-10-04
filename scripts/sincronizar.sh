#!/usr/bin/env bash
#
# sincronizar.sh — lo primero de la sesion, siempre.
#
#     ./scripts/sincronizar.sh          # pull de los dos repos y que hay de nuevo
#     ./scripts/sincronizar.sh --ver    # solo mira, no toca
#
# El 2026-09-02 una sesion arranco sobre copias tres y siete commits atras y
# rehizo tres tareas enteras que ya estaban hechas. Estar desactualizado no se
# siente distinto mientras trabajas: los tests pasan y las specs parecen
# pendientes. Por eso esto va antes de leer una spec, no despues.
#
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/rutas.sh"

SOLO_VER=false
[[ "${1:-}" == "--ver" ]] && SOLO_VER=true

hubo_novedad=false
salteado=false

for repo in "$CODIGO" "$AGENTES"; do
  nombre="$(basename "$repo")"
  verde "── $nombre ──"

  if [[ -n "$(git -C "$repo" status --porcelain)" ]]; then
    rojo "  Hay cambios sin commitear. Resolvelos antes de sincronizar:"
    git -C "$repo" status --short | sed 's/^/    /'
    salteado=true
    continue
  fi

  git -C "$repo" fetch --quiet origin
  detras="$(git -C "$repo" rev-list --count HEAD..origin/main)"
  adelante="$(git -C "$repo" rev-list --count origin/main..HEAD)"

  if [[ "$detras" == "0" && "$adelante" == "0" ]]; then
    gris "  al dia"
    continue
  fi

  hubo_novedad=true

  if [[ "$detras" != "0" ]]; then
    rojo "  $detras commit(s) en el remoto que no tenes. LEELOS antes de planificar:"
    git -C "$repo" log --oneline --format='    %h %s' HEAD..origin/main
    $SOLO_VER || { git -C "$repo" merge --ff-only origin/main >/dev/null && verde "  → actualizado"; }
  fi

  if [[ "$adelante" != "0" ]]; then
    gris "  $adelante commit(s) tuyos sin subir:"
    git -C "$repo" log --oneline --format='    %h %s' origin/main..HEAD
    $SOLO_VER || { git -C "$repo" push --quiet origin main && verde "  → pusheado"; }
  fi
done

if $salteado; then
  # Que un repo sucio no se lea como "todo bien": esa es la falsa tranquilidad
  # que hace perder un dia.
  rojo "NO se sincronizo todo: hay repos con cambios sin commitear (arriba)."
  exit 1
fi
$hubo_novedad || verde "Los dos repos al dia."
