#!/usr/bin/env bash
#
# smoke.sh — comprueba que los tres CLIs siguen encontrando su archivo de rol
# con el cableado actual (cwd en la raiz, sin symlinks en el repo del codigo).
#
# Corrertelo despues de tocar cualquier archivo de rol o de mover carpetas.
# Cada uno tiene que contestar con SU nombre y SU archivo, no con "arquitecto".
#
set -uo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/rutas.sh"
cd "$RAIZ"

PREGUNTA="Estas en $RAIZ. Lee %s. ?Que agente sos y cual es tu archivo de rol? Dos frases, no toques ningun archivo."

verde "── codex ──"
codex exec --sandbox read-only --skip-git-repo-check -C "$RAIZ" \
  "$(printf "$PREGUNTA" "$REL_AGENTES/CODEX.md")" 2>&1 | tail -6

verde "── opencode ($MODELO_OPENCODE) ──"
opencode run --agent build -m "$MODELO_OPENCODE" \
  "$(printf "$PREGUNTA" "$REL_AGENTES/OPENCODE.md")" 2>&1 | tail -6

verde "── agy ──"
agy -p "$(printf "$PREGUNTA" "$REL_AGENTES/AGY.md")" 2>&1 | tail -12
