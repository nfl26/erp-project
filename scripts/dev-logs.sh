#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$(dirname "$SCRIPT_DIR")"

SERVICE="${1:-}"

if [ -n "$SERVICE" ]; then
    # Mapear nombre corto a container_name
    case "$SERVICE" in
        postgres|pg)   CONTAINER="erp_postgres"  ;;
        redis)         CONTAINER="erp_redis"      ;;
        pgadmin)       CONTAINER="erp_pgadmin"    ;;
        rabbitmq|rmq)  CONTAINER="erp_rabbitmq"   ;;
        *)             CONTAINER="$SERVICE"        ;;
    esac
    echo "Logs de $CONTAINER (Ctrl+C para salir)..."
    docker logs -f "$CONTAINER"
else
    echo "Logs de todos los servicios ERP (Ctrl+C para salir)..."
    echo "Uso: $0 [postgres|redis|pgadmin|rabbitmq]"
    echo ""
    docker compose -f docker-compose.yml -f docker-compose.dev.yml logs -f
fi
