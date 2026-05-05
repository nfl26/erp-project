#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
cd "$PROJECT_DIR"

RED='\033[0;31m'; YELLOW='\033[1;33m'; NC='\033[0m'

echo ""
echo -e "${RED}╔══════════════════════════════════════════════╗${NC}"
echo -e "${RED}║  ADVERTENCIA: RESET DESTRUCTIVO              ║${NC}"
echo -e "${RED}║  Se eliminarán TODOS los volúmenes Docker.   ║${NC}"
echo -e "${RED}║  Todos los datos de la BD se perderán.       ║${NC}"
echo -e "${RED}╚══════════════════════════════════════════════╝${NC}"
echo ""
echo -e "${YELLOW}¿Está seguro? Escriba 'RESET' para confirmar:${NC} "
read -r CONFIRM

if [ "$CONFIRM" != "RESET" ]; then
    echo "Cancelado."
    exit 0
fi

echo ""
echo "Deteniendo servicios y eliminando volúmenes..."
docker compose -f docker-compose.yml -f docker-compose.dev.yml down -v --remove-orphans

echo "Relevantando entorno desde cero..."
"$SCRIPT_DIR/dev-up.sh"
