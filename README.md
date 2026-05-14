# ERP Industrial — Sistema híbrido humanos + IA

> Sistema ERP a medida construido en 6 meses por un equipo de 7 supervisores humanos + 7 agentes IA. Reemplaza Excel + Oracle Cloud ERP del cliente actual.

---

## Resumen del proyecto

- **Cliente:** Empresa industrial de 8 años de operación con schema "Arteo" en PostgreSQL.
- **Plazo:** 6 meses (Sprint 0 + 6 sprints de 4 semanas).
- **Equipo:** 7 supervisores humanos (S1, S2, S3, DO, QA, PO, TL) + 7 agentes IA (A1–A7) ejecutando tareas bajo supervisión.
- **Arquitectura inicial:** Monolito modular NestJS con módulos extractables a microservicios cuando el negocio lo justifique. Ver [`docs/arquitectura-decision.md`](docs/arquitectura-decision.md).

## Stack

| Capa | Tecnología |
|---|---|
| Backend (todo) | NestJS 10 + Prisma + PostgreSQL 15 |
| Comunicación interna | EventEmitter2 (NestJS nativo) |
| Frontend público | Next.js 14 |
| Backoffice | Angular 17 |
| Cache | Redis 7 |
| Auth | Keycloak |
| ETL/migración | Python 3.12 + pandas |
| Tests | Jest + Playwright + Cypress |
| Observabilidad | Prometheus + Grafana + Sentry |
| CI/CD | GitHub Actions + Docker Compose |

Ver detalle en [`docs/stack.md`](docs/stack.md).

## Estructura del repositorio

```
erp-project/
├── README.md
├── CLAUDE.md                   ← contexto automático para agentes IA
├── agents/                     ← 7 contratos de agentes (A1-A7)
├── docs/                       ← arquitectura, decisiones, eventos, RBAC, Prisma
│   └── adrs/                   ← 10 Architectural Decision Records
├── prompts/                    ← tickets del backlog con detalles operacionales
│   ├── templates/
│   └── backlog/
├── services/
│   └── erp-api/                ← monolito NestJS (todos los módulos)
├── web/
│   ├── public/                 ← Next.js 14 (portal público)
│   └── backoffice/             ← Angular 17 (backoffice)
├── etl/                        ← Python (migración Excel → PostgreSQL)
├── infra/                      ← Docker Compose, configs locales
├── scripts/                    ← pre-pr-check.sh y utilidades
├── dashboard/                  ← panel HTML del proyecto
└── .github/                    ← workflows, templates, CODEOWNERS
```

## Desarrollo local

Requisitos: Docker Desktop 4.x, Docker Compose v2, 2 GB RAM libres.

```bash
cp .env.example .env      # copiar template de variables
./scripts/dev-up.sh       # levantar PostgreSQL + Redis + pgAdmin + RabbitMQ
```

| Servicio | URL |
|---|---|
| PostgreSQL | `localhost:5432` |
| pgAdmin 4 | `http://localhost:5050` |
| RabbitMQ UI | `http://localhost:15672` |
| Redis | `localhost:6379` |

Ver guía completa: [`docs/runbooks/dev-environment.md`](docs/runbooks/dev-environment.md)

```bash
./scripts/dev-down.sh     # detener (conserva datos)
./scripts/dev-reset.sh    # reset completo (borra volúmenes)
./scripts/dev-psql.sh     # shell psql en tenant_erp
```

## Arrancar el proyecto

1. Leer [`CLAUDE.md`](CLAUDE.md) — instrucciones para agentes IA y supervisores.
2. Leer [`docs/arquitectura-decision.md`](docs/arquitectura-decision.md) — por qué monolito modular.
3. Ejecutar tickets en orden: ver [`prompts/backlog/`](prompts/backlog/).

## Documentos clave

- [`docs/arquitectura-decision.md`](docs/arquitectura-decision.md) — decisión de monolito vs microservicios
- [`docs/architecture.md`](docs/architecture.md) — vistas del sistema con diagramas
- [`docs/prisma-workflow.md`](docs/prisma-workflow.md) — flujo de trabajo con Prisma
- [`docs/events.md`](docs/events.md) — catálogo de eventos internos y externos
- [`docs/rbac-matrix.md`](docs/rbac-matrix.md) — roles y permisos
- [`docs/glossary.md`](docs/glossary.md) — terminología del negocio
- [`docs/stack.md`](docs/stack.md) — tecnologías y por qué
- [`docs/roadmap-microservicios.md`](docs/roadmap-microservicios.md) — plan de migración futura
- [`docs/adrs/README.md`](docs/adrs/README.md) — índice de decisiones arquitectónicas

## Modelo de trabajo

Los agentes IA escriben código, tests, migraciones y documentación. Los supervisores humanos deciden, revisan y aprueban. Ningún PR entra a `main` sin revisión humana + CI verde. Ver [`docs/adrs/ADR-009-claude-code-como-herramienta-estandar.md`](docs/adrs/ADR-009-claude-code-como-herramienta-estandar.md).

