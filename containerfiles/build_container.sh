#!/usr/bin/env bash
set -euo pipefail

FORCE=0
OUTDIR=""
APPTAINER_ARGS=()

# --- parse flags ---
ARGS=()
while [[ $# -gt 0 ]]; do
  case "$1" in
    --force) FORCE=1; shift ;;
    --out) OUTDIR="$2"; shift 2 ;;
    --apptainer) APPTAINER_ARGS+=("$2"); shift 2 ;;
    *) ARGS+=("$1"); shift ;;
  esac
done
set -- "${ARGS[@]}"

if [[ $# -ne 1 ]]; then
  echo "Usage: $0 [--force] [--out DIR] [--apptainer '<arg>'] <tool/ver | path.def>" >&2
  exit 1
fi

INPUT="$1"

# Resolve repo root (parent of this script)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
CONTAINER_DIR="$ROOT/containerfiles"

# --- resolve .def path ---
if [[ "$INPUT" == *.def ]]; then
  DEF_PATH="$INPUT"
  [[ "$DEF_PATH" != /* ]] && DEF_PATH="$(cd "$PWD" && realpath "$DEF_PATH")"
  NAME="$(basename "${DEF_PATH%.def}")"
else
  TOOL="${INPUT%%/*}"
  VER="${INPUT##*/}"
  DEF_PATH="$CONTAINER_DIR/${TOOL}/${VER}/${TOOL}_${VER}.def"
  NAME="${TOOL}_${VER}"
fi

if [[ ! -f "$DEF_PATH" ]]; then
  echo "Definition file not found: $DEF_PATH" >&2
  exit 2
fi

# Default OUTDIR to the .def folder if not provided
if [[ -z "$OUTDIR" ]]; then
  OUTDIR="$(dirname "$DEF_PATH")"
fi
mkdir -p "$OUTDIR"
SIF="${OUTDIR%/}/${NAME}.sif"

module load apptainer 2>/dev/null || module load singularity 2>/dev/null || true
if ! command -v apptainer >/dev/null 2>&1; then
  echo "ERROR: apptainer (or singularity) not found on PATH." >&2
  exit 3
fi

export APPTAINER_CACHEDIR="${APPTAINER_CACHEDIR:-${SCRATCH:-/tmp}/.apptainer-cache}"
export APPTAINER_TMPDIR="${APPTAINER_TMPDIR:-${SCRATCH:-/tmp}/tmp}"
mkdir -p "$APPTAINER_CACHEDIR" "$APPTAINER_TMPDIR"

if [[ -f "$SIF" && $FORCE -eq 0 ]]; then
  echo "Already exists: $SIF  (use --force to rebuild)"
  exit 0
fi

if [[ -w /tmp ]]; then
  echo "✅ /tmp is writable. Building normally."
  export APPTAINER_TMPDIR="/tmp"
else
  echo "⚠️ /tmp is not writable. Using $HOME/tmp and enabling fakeroot."
  export APPTAINER_TMPDIR="$HOME/tmp"
  mkdir -p "$APPTAINER_TMPDIR"
  FAKEROOT_FLAG=(--fakeroot)
fi 

echo "Building SIF:"
echo "  DEF : $DEF_PATH"
echo "  OUT : $SIF"
[[ ${#APPTAINER_ARGS[@]} -gt 0 ]] && echo "  Extra apptainer args: ${APPTAINER_ARGS[*]}"

env -u APPTAINER_BINDPATH -u SINGULARITY_BINDPATH \
  apptainer build "${FAKEROOT_FLAG[@]}" "${APPTAINER_ARGS[@]}" "$SIF" "$DEF_PATH"

echo "Done: $SIF"
