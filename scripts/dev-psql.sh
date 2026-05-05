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

# Tenant: demo por defecto, acepta argumento
TENANT="${1:-demo}"

echo "Conectando a tenant_${TENANT} en ${POSTGRES_DB}..."
echo "  search_path activo: tenant_${TENANT}, public"
echo "  Salir: \\q"
echo ""

# PGOPTIONS pasa parámetros de conexión al servidor sin romper el modo interactivo
docker compose exec \
    -e "PGOPTIONS=-c search_path=tenant_${TENANT},public" \
    -it postgres \
    psql -U "${POSTGRES_USER}" -d "${POSTGRES_DB}"
