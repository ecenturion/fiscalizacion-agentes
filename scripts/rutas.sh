#!/usr/bin/env bash
#
# rutas.sh — se hace `source` desde los demas scripts. Define el cableado.
#
# La regla que ordena todo: los agentes corren con el cwd en la RAIZ (el padre
# de los dos repos), nunca dentro del repo del codigo. Asi el repo del codigo
# no necesita ningun symlink ni ningun archivo de agente adentro, y el sandbox
# de codex no tropieza con nada.
#
#   RAIZ/
#     legajos/          <- solo codigo
#     legajos-agents/   <- roles, specs, informes, estado (este repo)

AGENTES="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RAIZ="$(dirname "$AGENTES")"
CODIGO="$RAIZ/legajos"

# Nombres relativos a RAIZ: son los que van en los prompts.
REL_AGENTES="$(basename "$AGENTES")"
REL_CODIGO="$(basename "$CODIGO")"

# Modelos. Se pueden pisar por entorno.
: "${MODELO_OPENCODE:=opencode/big-pickle}"
: "${MODELO_CODEX_ESFUERZO:=high}"

rojo()  { printf '\033[31m%s\033[0m\n' "$*"; }
verde() { printf '\033[32m%s\033[0m\n' "$*"; }
gris()  { printf '\033[90m%s\033[0m\n' "$*"; }

exigir_tarea() {
  local tarea="${1:-}"
  [[ -n "$tarea" ]] || { rojo "Falta el nombre de la tarea"; exit 2; }
  [[ -f "$AGENTES/tareas/$tarea.md" ]] || {
    rojo "No existe $REL_AGENTES/tareas/$tarea.md"
    gris "Disponibles:"; ls "$AGENTES/tareas" | grep '\.md$' | sed 's/\.md$//' | sed 's/^/  · /'
    exit 2
  }
}

# Foto del arbol del codigo antes de despachar, para poder decir despues que
# escribio realmente el agente (y no lo que dice su informe).
#
# 'status --short' solo no alcanza: si un archivo YA estaba modificado antes del
# despacho, su linea no cambia por mas que el agente lo reescriba entero, y la
# foto miente diciendo "sin cambios". Por eso va tambien 'diff --numstat', que
# cuenta lineas y si se mueve.
instantanea() {
  {
    git -C "$CODIGO" status --short
    git -C "$CODIGO" diff --numstat
    # Y los sin trackear por contenido: un archivo nuevo que el agente vuelve a
    # escribir tampoco mueve su linea de status.
    git -C "$CODIGO" ls-files --others --exclude-standard -z \
      | (cd "$CODIGO" && xargs -0 -r md5sum)
  } 2>/dev/null || true
}

foto_antes() {
  instantanea > /tmp/legajos-antes.txt
}

foto_despues() {
  instantanea > /tmp/legajos-despues.txt
  echo
  verde "── Lo que quedo escrito de verdad (git status --short) ──"
  local nuevos
  # diff devuelve 1 cuando hay diferencias, que es justo el caso normal aca:
  # sin el '|| true' el 'set -e' del despachador mata el script al final.
  nuevos="$(diff /tmp/legajos-antes.txt /tmp/legajos-despues.txt | sed -n 's/^> /  /p' || true)"
  if [[ -n "$nuevos" ]]; then
    echo "$nuevos"
  else
    gris "  (sin cambios nuevos respecto de antes del despacho)"
  fi
  echo
  gris "Recorda: el arquitecto corre 'pnpm verificar' el mismo, en $REL_CODIGO/."
}
