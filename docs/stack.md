# Stack tecnológico

> Referencia completa del stack del ERP. Este documento es de lectura obligatoria para cualquier desarrollador humano o agente IA antes de tocar código. Si una tecnología no está en este documento, **no debe introducirse sin un ADR aprobado**.

---

## Tabla de contenidos

- [Frontend](#frontend)
- [Backend](#backend)
- [Datos](#datos)
- [Autenticación y seguridad](#autenticación-y-seguridad)
- [ETL y migración](#etl-y-migración)
- [Infraestructura y DevOps](#infraestructura-y-devops)
- [Observabilidad](#observabilidad)
- [Testing](#testing)
- [Herramientas del equipo](#herramientas-del-equipo)
- [Criterios de decisión](#criterios-de-decisión-detrás-del-stack)
- [Lo que NO usamos](#lo-que-no-usamos-y-por-qué)

---

## Frontend

Dos aplicaciones distintas con públicos distintos.

| Componente | Tecnología | Versión | Propósito |
|---|---|---|---|
| Portal público | Next.js | 14 (App Router) | Portal para clientes, cotizaciones, dashboards ejecutivos |
| Backoffice interno | Angular | 17 (standalone) | Operaciones pesadas: bodega, producción, órdenes |
| Styling portal | Tailwind CSS | 3.x | Utility-first para Next.js |
| Styling backoffice | Design tokens CSS | — | Variables CSS compartidas con Next.js |
| Data fetching Next | TanStack Query | 5.x | Cache, sync, mutations |
| Forms Angular | Reactive Forms | nativo | Formularios complejos de producción |
| Estado Angular | NgRx Signals | 17+ | Estado reactivo moderno |
| Tablas densas | ag-grid | community | Listados con miles de filas (bodega, OPs) |
| Validación | Zod (Next), Angular Validators | — | Validación client-side |
| E2E tests | Playwright (Next), Cypress (Angular) | — | Tests de integración UI |

**Agentes responsables:** A3 (Next.js) y A4 (Angular).

---

## Backend

Dos frameworks conviviendo por razones específicas del dominio.

| Componente | Tecnología | Versión | Propósito |
|---|---|---|---|
| Servicios generales | NestJS | 10 | Bodega, auth, usuarios, ventas, notificaciones |

| Runtime NestJS | Node.js | 20 LTS | — |

| ORM NestJS | Prisma | latest | Type-safe queries + migraciones |

| Validación NestJS | class-validator + class-transformer | — | DTOs estrictos |

| Logging | Pino | — | Logs estructurados JSON |

**Agente responsable:** A1 (Arquitecto NestJS) gestiona el monolito completo. A2 (Ingeniero Producción) está en espera para cuando se extraiga el módulo producción como microservicio independiente.

**¿Un solo backend?** Sí. Decidido en [ADR-010](adrs/ADR-010-monolito-modular.md). Empezamos con un monolito modular en NestJS que contiene los 5 módulos (auth, bodega, ventas, producción, notificaciones) con bounded contexts claros. Cuando el módulo de producción necesite escalar independientemente o incorporar ML/optimización (Python), se extraerá como microservicio. Ver `docs/roadmap-microservicios.md`.

---

## Datos

| Componente | Tecnología | Versión | Propósito |
|---|---|---|---|
| Base transaccional | PostgreSQL | 15 | OLTP, multi-tenant por schema |
| Campos dinámicos | PostgreSQL JSONB | nativo | Variantes de producto, recetas con campos custom |
| Cache + jobs | Redis | 7 | Sesiones, rate limiting, BullMQ para colas |
| Analytics / OLAP | ClickHouse o TimescaleDB | — | Proyecciones, series temporales, dashboards pesados |
| Almacenamiento archivos | S3 o MinIO | — | PDFs de cotizaciones, exports, imágenes |
| Mensajería eventos | RabbitMQ | 3.12 | Bus de eventos entre microservicios |
| Queue en proceso | BullMQ (NestJS) | latest | Jobs asincrónicos dentro de un servicio |

**Nota sobre analytics:** ClickHouse o TimescaleDB no entran desde el día uno. Se agregan cuando los dashboards de proyecciones necesiten consultas que saturarían PostgreSQL. En el MVP, todo vive en PostgreSQL.

**Multi-tenancy:** por schema en PostgreSQL. Un schema por empresa/rubro. Decisión documentada en `docs/adrs/ADR-003-multi-tenancy.md`.

---

## Autenticación y seguridad

| Componente | Tecnología | Propósito |
|---|---|---|
| Identity Provider | Keycloak | SSO, OAuth2, manejo de usuarios |
| Protocolo auth | JWT + OAuth2 | Tokens short-lived + refresh |
| Autorización | RBAC custom | Roles por módulo (admin-bodega, vendedor, etc.) |
| Secretos en K8s | K8s Secrets + Vault | Nunca en el repo |
| Secret scanning | gitleaks | En pre-commit y CI |
| SAST | Semgrep o SonarQube | Análisis estático en cada PR |
| Encriptación en reposo | PostgreSQL TDE + S3 SSE | Datos sensibles |

---

## ETL y migración

| Componente | Tecnología | Propósito |
|---|---|---|
| Runtime | Python 3.12 | — |
| Parsing Excel | pandas + openpyxl | Leer los Excel del cliente |
| Orquestación | Apache Airflow | Pipelines programados de migración |
| DB client | SQLAlchemy | Escritura a PostgreSQL |
| Data quality | Great Expectations | Validación de migraciones |
| Tests | pytest + ruff | Unit tests + linting |

**Agente responsable:** A5.

---

## Infraestructura y DevOps

| Componente | Tecnología | Propósito |
|---|---|---|
| Containerización | Docker | Imágenes de cada servicio |
| Orquestación | Kubernetes (EKS en AWS) | Clústeres staging y producción |
| Package manager K8s | Helm 3 | Charts por servicio |
| IaC | Terraform | Provisión de AWS (VPC, EKS, RDS, S3) |
| GitOps | ArgoCD | Deploy declarativo desde Git |
| CI/CD | GitHub Actions | Pipelines de test + build + deploy |
| API Gateway (futuro) | Kong | Cuando haya múltiples microservicios. Hoy: NestJS Guards + interceptors nativos |
| Ingress | nginx-ingress | Entrada al clúster |
| TLS | cert-manager + Let's Encrypt | SSL automático |

**Agente responsable:** A7.

---

## Observabilidad

| Componente | Tecnología | Propósito |
|---|---|---|
| Métricas | Prometheus | Scraping de métricas de servicios |
| Dashboards | Grafana | Visualización de métricas y logs |
| Logs centralizados | Loki | Agregación de logs de todos los pods |
| Errores de aplicación | Sentry | Captura de excepciones con stack traces |
| Tracing distribuido | OpenTelemetry | Seguimiento de requests entre servicios |
| Alertas | Alertmanager + Slack | Notificaciones a `#erp-alerts` |

---

## Testing

| Tipo | Tecnología | Dónde corre |
|---|---|---|
| Unit NestJS | Jest | Local + CI |
| Integración NestJS | Jest + Testcontainers | CI (levanta PostgreSQL real en Docker) |
| Contract tests | Pact | CI (verifica que servicios cumplen su OpenAPI) |
| E2E portal | Playwright | CI + staging |
| E2E backoffice | Cypress | CI + staging |
| Carga | k6 | Pre-release, no en cada PR |
| Excel validation | Jest custom matchers | CI obligatorio para cambios en costos |

**Agente responsable:** A6.

---

## Herramientas del equipo

Modelo híbrido: 7 supervisores humanos + 7 agentes IA.

| Herramienta | Usuarios | Propósito |
|---|---|---|
| Claude Code | 7 supervisores humanos | Ejecución de agentes IA desde terminal |
| Cowork | Product Owner solamente | Automatización de Excel del cliente |
| GitHub | Todo el equipo | Repo, PRs, Actions, Pages (dashboard) |
| Jira o Linear | Todo el equipo | Backlog, tickets, sprints |
| Slack | Todo el equipo | Canales: `#erp-build`, `#erp-alerts`, `#erp-agents` |
| Notion o Confluence | Todo el equipo | Docs largos, actas, decisiones ejecutivas |

---

## Criterios de decisión detrás del stack

Algunas de estas elecciones merecen justificación porque no son obvias.

### Por qué Keycloak y no Auth0
El cliente tiene requerimientos de data residency (los datos no pueden salir del país) y Keycloak se autohostea. Auth0 hubiera sido más rápido pero saca los tokens de identidad a servidores externos.

### Por qué RabbitMQ y no Kafka
El equipo es pequeño (7 personas) y RabbitMQ es más simple de operar. Kafka brilla cuando hay millones de eventos/día o necesitas replay histórico. En un ERP interno con decenas de miles de eventos/día, RabbitMQ es la elección pragmática. Si el volumen crece, migrar a Kafka es factible porque usamos contratos de eventos con esquemas JSON, no APIs específicas de broker.

### Por qué Prisma único ORM
Prisma tiene excelente DX y type safety en TypeScript. Su limitación con relaciones complejas se compensa con queries SQL crudos cuando es necesario (`prisma.$queryRaw`). Para el monolito modular, tener un solo ORM elimina la complejidad de mapear entidades entre dos sistemas. Cuando el módulo producción se extraiga como microservicio Python, podrá usar SQLAlchemy si conviene.

### Workflow de Prisma (obligatorio)

El proyecto parte de una **base de datos existente**. El flujo es:

1. **Setup inicial (una sola vez por servicio):**
   ```bash
   npx prisma db pull          # genera schema.prisma desde la BD existente
   npx prisma migrate dev --name init   # establece el baseline de migraciones
   npx prisma generate         # genera el cliente TypeScript
   ```

2. **Cambios en desarrollo (código → BD):**
   ```bash
   # 1. Editar schema.prisma
   npx prisma migrate dev --name descripcion_cambio
   npx prisma generate
   ```

3. **Sincronizar cambio externo (BD → código):**
   ```bash
   npx prisma db pull
   npx prisma migrate dev --name sync_cambio_externo
   ```

4. **En producción/CI:**
   ```bash
   npx prisma migrate deploy   # nunca prisma migrate dev en producción
   ```

**Regla clave:**
-  → cuando el cambio nace en el código
-  → cuando el cambio nació en la base de datos

Nunca se hacen cambios manuales directos en PostgreSQL. Ver detalle completo en `docs/prisma-workflow.md`.

### Por qué ag-grid en Angular
Los bodegueros y operarios trabajan con listados de miles de filas (insumos, movimientos, órdenes). ag-grid community es gratis, tiene virtualización nativa y la integración con Angular es de primer nivel. Alternativas como Material Table se caen con más de ~500 filas.

### Por qué Helm y no Kustomize
Helm permite parametrizar charts por ambiente (staging vs producción vs multi-tenant futuro) con values files. Kustomize es más limpio pero menos flexible para multi-tenancy, que es justo lo que el negocio quiere a futuro.

---

## Lo que NO usamos (y por qué)

Vale aclarar esto porque son decisiones conscientes.

### No usamos un monolito
Tentador con solo 7 personas, pero escalar a más rubros después requiere poder desplegar módulos independientemente.

### No usamos MongoDB ni DynamoDB
PostgreSQL con JSONB cubre los casos de "campos dinámicos" sin perder las garantías relacionales que necesita un ERP (integridad referencial de órdenes, insumos, ventas).

### No usamos GraphQL
Añade complejidad de N+1 queries y caching que no compensa. REST + OpenAPI es más que suficiente y todos lo entienden.

### No usamos un BaaS tipo Supabase
Lock-in fuerte, control limitado sobre multi-tenancy, y el cliente tiene requisitos de compliance que requieren infraestructura propia.

### No usamos Vercel para Next.js
Self-hosted en K8s por las mismas razones de data residency y compliance.

### No usamos Deno, Bun o Elysia
Estables en 2026, pero el ecosistema de herramientas empresariales (observabilidad, APM, librerías enterprise) sigue siendo mejor con Node.js LTS.

---

## Introducir una nueva tecnología

Si un desarrollador (humano o agente IA) considera que hace falta una tecnología no listada aquí, el proceso es:

1. **Abrir un ADR** en `docs/adrs/ADR-NNN-nombre-tecnologia.md` explicando el problema, alternativas consideradas, y propuesta.
2. **Presentarlo en la ceremonia de Prompt Review** o en un sync con el Tech Lead.
3. **Si se aprueba**, agregar la tecnología a este documento actualizando la versión al final.
4. **Si no se aprueba**, documentar en el ADR la razón del rechazo para que no se re-discuta.

**Los agentes IA nunca introducen dependencias por su cuenta.** Si durante la ejecución de un ticket el agente detecta que necesita una librería nueva, debe pausar y avisar al supervisor humano.

---

**Última actualización:** abril 2026
**Versión del documento:** 1.0
**Mantenedor:** Tech Lead
**Frecuencia de revisión:** cada inicio de fase / sprint mayor
