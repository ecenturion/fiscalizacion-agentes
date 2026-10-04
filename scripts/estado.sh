#!/usr/bin/env bash
#
# estado.sh — log append-only del avance de las tareas
#
# Vive en el repo de agentes; el repo del codigo no sabe que existe.
#
#     ./scripts/estado.sh <tarea> <estado> <agente>
#     ./scripts/estado.sh T02-packages-db en_progreso agy
#     ./scripts/estado.sh --ver              # últimas 20 líneas legibles
#     ./scripts/estado.sh --ver T02-packages-db
#
# Estados válidos: pendiente | en_progreso | error | hecho
# Agentes válidos: claude-code | agy | codex | opencode
#
set -euo pipefail

RAIZ="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ARCHIVO="$RAIZ/estado.jsonl"

if [[ "${1:-}" == "--ver" ]]; then
  [[ -f "$ARCHIVO" ]] || { echo "Sin eventos todavía"; exit 0; }
  if [[ -n "${2:-}" ]]; then
    grep "\"tarea\":\"$2\"" "$ARCHIVO" || echo "Sin eventos para $2"
  else
    tail -20 "$ARCHIVO"
  fi
  exit 0
fi

TAREA="${1:-}"
ESTADO="${2:-}"
AGENTE="${3:-claude-code}"

[[ -n "$TAREA" && -n "$ESTADO" ]] || {
  echo "Uso: ./scripts/estado.sh <tarea> <pendiente|en_progreso|error|hecho> [claude-code|agy|codex|opencode]" >&2
  exit 2
}

case "$ESTADO" in
  pendiente|en_progreso|error|hecho) ;;
  *) echo "Estado inválido: $ESTADO (pendiente|en_progreso|error|hecho)" >&2; exit 2 ;;
esac

case "$AGENTE" in
  claude-code|agy|codex|opencode) ;;
  *) echo "Agente inválido: $AGENTE (claude-code|agy|codex|opencode)" >&2; exit 2 ;;
esac

mkdir -p "$(dirname "$ARCHIVO")"
printf '{"ts":"%s","tarea":"%s","estado":"%s","agente":"%s"}\n' \
  "$(date -Iseconds)" "$TAREA" "$ESTADO" "$AGENTE" >> "$ARCHIVO"

echo "· $TAREA → $ESTADO ($AGENTE)"
