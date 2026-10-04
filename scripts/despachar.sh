#!/usr/bin/env bash
#
# despachar.sh — un solo punto de entrada para mandar una tarea a un agente.
#
#     ./scripts/despachar.sh agy       T25-destino-del-dinero
#     ./scripts/despachar.sh codex     T25-destino-del-dinero   # sombrero A: auditoria
#     ./scripts/despachar.sh codex-b   T25-destino-del-dinero   # sombrero B: implementa
#     ./scripts/despachar.sh opencode  T25-destino-del-dinero
#
# Encapsula todo lo que se aprendio a los golpes sobre cada CLI: cwd, sandbox,
# modelo y la ruta del archivo de rol. Ninguno de los tres CLIs encuentra su rol
# solo: el prompt lo nombra por ruta, siempre.
#
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/rutas.sh"

AGENTE="${1:-}"
TAREA="${2:-}"

case "$AGENTE" in
  agy|codex|codex-b|opencode) ;;
  *) rojo "Uso: ./scripts/despachar.sh <agy|codex|codex-b|opencode> <tarea>"; exit 2 ;;
esac

exigir_tarea "$TAREA"

SPEC="$REL_AGENTES/tareas/$TAREA.md"
COMUN="$REL_AGENTES/AGENTS.md"
cd "$RAIZ"

# El bloque de orientacion que va al principio de todo prompt: donde esta cada
# cosa ahora que el repo del codigo no tiene nada de agentes adentro.
orientacion() {
  cat <<TXT
Trabajas desde $RAIZ, que contiene dos repos hermanos:
  $REL_CODIGO/        el codigo (unico lugar donde se edita codigo)
  $REL_AGENTES/       roles, specs e informes (no se toca salvo tu informe)
Las rutas del "Alcance de archivos" de la spec son relativas a $REL_CODIGO/.
Nada fuera de esas dos carpetas se toca. La verificacion se corre con
'cd $REL_CODIGO && pnpm verificar' (o el comando que indique la spec).
TXT
}

case "$AGENTE" in

  agy)
    "$AGENTES/scripts/estado.sh" "$TAREA" en_progreso agy
    gris "AGY se corta a los ~7 min por invocacion: conta 6-7 archivos por despacho, no mas."
    foto_antes
    agy -p "$(orientacion)

Lee $REL_AGENTES/AGY.md y $COMUN: sos AGY, el implementador principal.
Ejecuta la tarea descrita en $SPEC.
Al terminar corre el comando de verificacion que indica la tarea y escribi tu
informe en $REL_AGENTES/informes/$TAREA.informe.md con la salida real del comando." \
      --mode=accept-edits --output-format json || rojo "agy salio con error (mira si igual escribio algo)"
    foto_despues
    ;;

  codex)
    # Sombrero A: audita el diff sin commitear. Read-only, nunca escribe codigo.
    "$AGENTES/scripts/estado.sh" "$TAREA" en_progreso codex
    gris "No corras 'pnpm test' mientras esta auditoria esta en vuelo: comparten la base de compose.test.yml."
    codex exec --sandbox read-only --skip-git-repo-check -C "$RAIZ" \
      -o "$REL_AGENTES/informes/$TAREA.auditoria.md" \
      "$(orientacion)

Sos CODEX con el sombrero A: lee $REL_AGENTES/CODEX.md y $COMUN.
Audita el diff sin commitear de $REL_CODIGO/ contra la spec $SPEC.
No modifiques ningun archivo. Usa el formato exacto de CODEX.md."
    verde "Auditoria en $REL_AGENTES/informes/$TAREA.auditoria.md"
    ;;

  codex-b)
    # Sombrero B: implementa, con alcance disjunto del de cualquier otro agente en vuelo.
    "$AGENTES/scripts/estado.sh" "$TAREA" en_progreso codex
    gris "La base de compose.test.yml tiene que estar arriba: docker compose -f legajos/compose.test.yml up -d"
    foto_antes
    # network_access: sin esto el sandbox no llega al Postgres de compose.test.yml
    # y 10 de los 11 archivos de tests de packages/db fallan por conexion. La
    # verificacion daria un falso negativo entero.
    codex exec --sandbox workspace-write --skip-git-repo-check -C "$RAIZ" \
      -c model_reasoning_effort="$MODELO_CODEX_ESFUERZO" \
      -c sandbox_workspace_write.network_access=true \
      "$(orientacion)

Sos CODEX con el sombrero B: lee $REL_AGENTES/CODEX.md y $COMUN.
Ejecuta la tarea descrita en $SPEC.
Al terminar corre el comando de verificacion de la tarea y escribi tu informe en
$REL_AGENTES/informes/$TAREA.codex.informe.md con la salida real."
    foto_despues
    ;;

  opencode)
    "$AGENTES/scripts/estado.sh" "$TAREA" en_progreso opencode
    gris "Modelo: $MODELO_OPENCODE  (los modelos google/* del free tier mueren por cuota a los ~20 requests)"
    gris "Un 'exit 0' de opencode NO significa que la tarea este hecha. Mira la foto de abajo."
    foto_antes
    opencode run --agent build --auto -m "$MODELO_OPENCODE" \
      "$(orientacion)

Lee $REL_AGENTES/OPENCODE.md y $COMUN: sos OPENCODE, el peon de superficie.
Ejecuta la tarea descrita en $SPEC. Respeta el Alcance de archivos al pie de la letra.
Al terminar corre el comando de verificacion y escribi tu informe en
$REL_AGENTES/informes/$TAREA.opencode.informe.md con la salida real." \
      || rojo "opencode salio con error (mira si igual escribio algo)"
    foto_despues
    ;;
esac
