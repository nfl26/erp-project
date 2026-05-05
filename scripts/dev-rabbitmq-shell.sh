#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
cd "$PROJECT_DIR"

if [ ! -f ".env" ]; then
    echo "ERROR: archivo .env no encontrado. Ejecute: cp .env.example .env" >&2
    exit 1
fi

set -o allexport
# shellcheck disable=SC1091
source .env
set +o allexport

MGMT_PORT="${RABBITMQ_MGMT_PORT:-15672}"

echo "Management UI : http://localhost:${MGMT_PORT}"
echo "  Usuario     : ${RABBITMQ_DEFAULT_USER}"
echo "  Password    : ver RABBITMQ_DEFAULT_PASS en .env"
echo ""
echo "Abriendo shell rabbitmqctl en el contenedor..."
echo "  Ejemplos:"
echo "    rabbitmqctl list_vhosts"
echo "    rabbitmqctl list_exchanges -p /erp"
echo "    rabbitmqctl list_queues -p /erp"
echo "    rabbitmqadmin list users"
echo ""

docker compose exec -it rabbitmq bash -c \
    "echo 'Shell rabbitmq — escribe rabbitmqctl <comando>' && bash"
