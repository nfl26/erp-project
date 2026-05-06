#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
cd "$PROJECT_DIR"

# ── Colores ──────────────────────────────────────────────────────────────────
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; BLUE='\033[0;34m'; NC='\033[0m'
info()    { echo -e "${BLUE}▸${NC} $*"; }
success() { echo -e "${GREEN}✓${NC} $*"; }
warn()    { echo -e "${YELLOW}⚠${NC}  $*"; }
err()     { echo -e "${RED}✗${NC} $*" >&2; }

# ── Verificar Docker ─────────────────────────────────────────────────────────
if ! docker info &>/dev/null; then
    err "Docker no está corriendo."
    echo "  Inicie Docker Desktop y espere a que el ícono muestre 'Running'."
    echo "  En Windows: busque Docker Desktop en el menú Inicio."
    exit 1
fi

# ── Verificar .env ────────────────────────────────────────────────────────────
if [ ! -f ".env" ]; then
    err "Archivo .env no existe."
    echo "  Ejecute: cp .env.example .env"
    echo "  Luego edite las variables según su entorno."
    exit 1
fi

# Cargar variables (para verificar puertos y configurar RabbitMQ)
set -o allexport
# shellcheck disable=SC1091
source .env
set +o allexport

# ── Verificar puertos ─────────────────────────────────────────────────────────
check_port() {
    local port="$1"
    if command -v lsof &>/dev/null; then
        lsof -iTCP:"$port" -sTCP:LISTEN &>/dev/null
    elif command -v nc &>/dev/null; then
        nc -z localhost "$port" &>/dev/null
    else
        return 1
    fi
}

declare -a PORTS=("${POSTGRES_PORT:-5432}" "${REDIS_PORT:-6379}" "${PGADMIN_PORT:-5050}" "${RABBITMQ_AMQP_PORT:-5672}" "${RABBITMQ_MGMT_PORT:-15672}")
declare -a NAMES=("PostgreSQL" "Redis" "pgAdmin" "RabbitMQ AMQP" "RabbitMQ Management")

for i in "${!PORTS[@]}"; do
    if check_port "${PORTS[$i]}"; then
        err "Puerto ${PORTS[$i]} ya en uso (esperado para ${NAMES[$i]})."
        echo "  Revise: lsof -i:${PORTS[$i]}"
        echo "  O configure otro puerto en .env"
        exit 1
    fi
done

# ── Generar pgpass para pgAdmin ───────────────────────────────────────────────
{
    echo "# Generado por dev-up.sh — NO commitear"
    echo "postgres:5432:*:${POSTGRES_USER}:${POSTGRES_PASSWORD}"
} > infra/local/pgadmin/pgpass
# Nota: en Linux se requiere chmod 600; en macOS/Docker Desktop no afecta

# ── Levantar servicios ────────────────────────────────────────────────────────
info "Levantando entorno local ERP..."
docker compose -f docker-compose.yml -f docker-compose.dev.yml up -d

# ── Esperar health checks ─────────────────────────────────────────────────────
wait_healthy() {
    local container="$1"
    local label="${2:-$container}"
    local max=60
    local n=0
    printf "${BLUE}▸${NC} Esperando %-25s" "$label..."
    while [ $n -lt $max ]; do
        STATUS=$(docker inspect --format='{{.State.Health.Status}}' "$container" 2>/dev/null || echo "")
        if [ "$STATUS" = "healthy" ]; then
            echo -e " ${GREEN}listo${NC}"
            return 0
        fi
        printf "."
        sleep 1
        ((n++))
    done
    echo ""
    err "$label no alcanzó estado healthy en ${max}s"
    echo "  Revise los logs: ./scripts/dev-logs.sh $container"
    return 1
}

wait_healthy "erp_postgres"  "PostgreSQL 15"
wait_healthy "erp_redis"     "Redis 7"
wait_healthy "erp_rabbitmq"  "RabbitMQ 3.12"

# pgAdmin no tiene health check, esperamos que el contenedor esté running
sleep 2
if docker inspect --format='{{.State.Status}}' erp_pgadmin 2>/dev/null | grep -q "running"; then
    success "pgAdmin 4                    listo"
else
    warn "pgAdmin puede tardar unos segundos más en estar disponible"
fi

# ── Configurar RabbitMQ ───────────────────────────────────────────────────────
info "Configurando usuarios de RabbitMQ..."

# Dar acceso al admin al vhost /erp
docker compose exec -T rabbitmq \
    rabbitmqctl set_permissions -p /erp "${RABBITMQ_DEFAULT_USER}" ".*" ".*" ".*" \
    2>/dev/null || true

# Crear dev-publisher (o actualizar password si ya existe)
docker compose exec -T rabbitmq \
    rabbitmqctl add_user "${RABBITMQ_PUBLISHER_USER}" "${RABBITMQ_PUBLISHER_PASSWORD}" \
    2>/dev/null || \
docker compose exec -T rabbitmq \
    rabbitmqctl change_password "${RABBITMQ_PUBLISHER_USER}" "${RABBITMQ_PUBLISHER_PASSWORD}" \
    2>/dev/null || true

docker compose exec -T rabbitmq \
    rabbitmqctl set_permissions -p /erp "${RABBITMQ_PUBLISHER_USER}" "" ".*" "" \
    2>/dev/null || true

# Crear dev-consumer (o actualizar password si ya existe)
docker compose exec -T rabbitmq \
    rabbitmqctl add_user "${RABBITMQ_CONSUMER_USER}" "${RABBITMQ_CONSUMER_PASSWORD}" \
    2>/dev/null || \
docker compose exec -T rabbitmq \
    rabbitmqctl change_password "${RABBITMQ_CONSUMER_USER}" "${RABBITMQ_CONSUMER_PASSWORD}" \
    2>/dev/null || true

docker compose exec -T rabbitmq \
    rabbitmqctl set_permissions -p /erp "${RABBITMQ_CONSUMER_USER}" "" "" ".*" \
    2>/dev/null || true

success "Usuarios RabbitMQ configurados"

# ── Resumen ───────────────────────────────────────────────────────────────────
echo ""
echo -e "${GREEN}══════════════════════════════════════════════${NC}"
echo -e "${GREEN}  Entorno ERP local listo${NC}"
echo -e "${GREEN}══════════════════════════════════════════════${NC}"
echo ""
printf "  %-14s → localhost:%-6s  (DB: %s)\n" "PostgreSQL" "${POSTGRES_PORT:-5432}" "${POSTGRES_DB}"
printf "  %-14s → localhost:%-6s\n" "Redis" "${REDIS_PORT:-6379}"
printf "  %-14s → http://localhost:%-6s\n" "pgAdmin" "${PGADMIN_PORT:-5050}"
printf "  %-14s → http://localhost:%-6s\n" "RabbitMQ UI" "${RABBITMQ_MGMT_PORT:-15672}"
echo ""
echo "  pgAdmin login  : ${PGADMIN_DEFAULT_EMAIL}"
echo "  PG password    : ver POSTGRES_PASSWORD en .env"
echo "  RabbitMQ admin : ${RABBITMQ_DEFAULT_USER} / ver RABBITMQ_DEFAULT_PASS en .env"
echo ""
echo "  Logs           : ./scripts/dev-logs.sh [servicio]"
echo "  psql demo      : ./scripts/dev-psql.sh"
echo "  Detener        : ./scripts/dev-down.sh"
echo ""
