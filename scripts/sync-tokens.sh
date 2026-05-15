#!/usr/bin/env bash
# sync-tokens.sh — Opción B: copia tokens CSS desde la fuente única hacia el backoffice.
#
# Uso:
#   ./scripts/sync-tokens.sh           # copia desde web/public → web/backoffice
#   ./scripts/sync-tokens.sh --check   # solo verifica que los archivos son idénticos (sin copiar)
#
# Integración recomendada (pendiente A7):
#   - pre-commit hook via husky
#   - job CI que ejecuta con --check y falla si hay diferencias

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

SOURCE="$REPO_ROOT/web/public/styles/tokens.css"
TARGET_DIR="$REPO_ROOT/web/backoffice/src/styles"
TARGET="$TARGET_DIR/tokens.css"

if [[ ! -f "$SOURCE" ]]; then
  echo "ERROR: fuente no encontrada: $SOURCE" >&2
  echo "       Asegúrate de que T-006 (portal Next.js) está mergeado." >&2
  exit 1
fi

mkdir -p "$TARGET_DIR"

if [[ "${1:-}" == "--check" ]]; then
  if diff -q "$SOURCE" "$TARGET" > /dev/null 2>&1; then
    echo "OK: tokens.css es idéntico en ambos frontends."
    exit 0
  else
    echo "FAIL: tokens.css difiere entre frontends." >&2
    diff "$SOURCE" "$TARGET" >&2
    exit 1
  fi
fi

cp "$SOURCE" "$TARGET"
echo "OK: tokens.css sincronizado → $TARGET"
