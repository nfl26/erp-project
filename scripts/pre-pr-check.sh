#!/usr/bin/env bash
# scripts/pre-pr-check.sh
#
# Ejecuta las verificaciones aplicables a los archivos modificados
# antes de abrir un PR. Usado por humanos y agentes IA.

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}═══ pre-PR check ═══${NC}"

# Detectar archivos modificados vs main
CHANGED=$(git diff --name-only origin/main...HEAD 2>/dev/null || git diff --name-only HEAD)

if [ -z "$CHANGED" ]; then
  echo -e "${YELLOW}No hay cambios respecto a main.${NC}"
  exit 0
fi

echo -e "${BLUE}Archivos modificados:${NC}"
echo "$CHANGED" | sed 's/^/  /'
echo ""

# ── NestJS backend ──
if echo "$CHANGED" | grep -qE "^services/(core|bodega|ventas|notificaciones)/"; then
  echo -e "${BLUE}▸ Detectados cambios en backend NestJS${NC}"
  for svc in core bodega ventas notificaciones; do
    if echo "$CHANGED" | grep -qE "^services/$svc/"; then
      echo -e "${BLUE}  · ${svc}${NC}"
      (cd services/$svc && npm run lint && npm test -- --passWithNoTests)
    fi
  done
fi

# ── Spring Boot ──
if echo "$CHANGED" | grep -qE "^services/produccion/"; then
  echo -e "${BLUE}▸ Detectados cambios en producción (Spring Boot)${NC}"
  (cd services/produccion && ./mvnw -q verify)
fi

# ── Next.js ──
if echo "$CHANGED" | grep -qE "^web/public/"; then
  echo -e "${BLUE}▸ Detectados cambios en portal Next.js${NC}"
  (cd web/public && npm run lint && npm test -- --passWithNoTests && npm run build)
fi

# ── Angular ──
if echo "$CHANGED" | grep -qE "^web/backoffice/"; then
  echo -e "${BLUE}▸ Detectados cambios en backoffice Angular${NC}"
  (cd web/backoffice && npm run lint && npm test -- --watch=false && npm run build)
fi

# ── ETL Python ──
if echo "$CHANGED" | grep -qE "^etl/"; then
  echo -e "${BLUE}▸ Detectados cambios en ETL${NC}"
  (cd etl && ruff check . && pytest)
fi

# ── Verificaciones transversales ──
echo -e "${BLUE}▸ Verificación de secretos${NC}"
if command -v gitleaks &> /dev/null; then
  gitleaks protect --staged
else
  echo -e "${YELLOW}  gitleaks no instalado, saltando...${NC}"
fi

echo -e "${BLUE}▸ Verificación de CLAUDE.md vigente${NC}"
if [ ! -f "CLAUDE.md" ]; then
  echo -e "${RED}  ✗ CLAUDE.md no existe${NC}"
  exit 1
fi

# ── Checklist para agentes IA ──
echo ""
echo -e "${YELLOW}Checklist final para el supervisor humano:${NC}"
echo -e "  ${YELLOW}□${NC} ¿El código respeta los invariantes del dominio?"
echo -e "  ${YELLOW}□${NC} ¿El agente se mantuvo dentro de su contrato?"
echo -e "  ${YELLOW}□${NC} ¿Los tests cubren casos reales, no sólo los obvios?"
echo -e "  ${YELLOW}□${NC} ¿El commit sigue el formato y menciona el agente [A{N}]?"
echo -e "  ${YELLOW}□${NC} ¿El PR tiene labels agent:A{N} y supervisor:S{X}?"
echo ""

echo -e "${GREEN}✓ pre-PR check OK${NC}"
echo -e "${BLUE}Puedes abrir el PR con: ${NC}gh pr create"
