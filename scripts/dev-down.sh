#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$(dirname "$SCRIPT_DIR")"

echo "Deteniendo entorno ERP local (los volúmenes se conservan)..."
docker compose -f docker-compose.yml -f docker-compose.dev.yml down

echo "Servicios detenidos. Para reiniciar: ./scripts/dev-up.sh"
