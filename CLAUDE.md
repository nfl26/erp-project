# CLAUDE.md — Contexto para agentes IA

> Este archivo es leído automáticamente por **Claude Code** al iniciar una sesión en este repo. Contiene el contexto, convenciones e invariantes que cualquier agente IA debe respetar antes de modificar código.

---

## ⚠️ Reglas inviolables (leer antes de cualquier cambio)

1. **Identifica qué agente eres** antes de actuar. Los agentes válidos son A1 a A7, definidos en `agents/`. Si el supervisor no te indicó un agente, **pregúntale cuál eres** antes de proceder.
2. **Lee tu contrato en `agents/A{N}-*.md`** antes de escribir código. Tu contrato define qué PUEDES y qué NO PUEDES hacer.
3. **Nunca hagas `git push` directamente.** Eso lo hace el supervisor humano.
4. **Nunca modifiques `main` o `staging`.** Trabaja siempre en ramas feature.
5. **Nunca commitees secretos.** Si ves una API key, password o token en el código, deténte y avisa.
6. **Si dudas, pregunta.** Es preferible pausar y pedir aclaración que asumir y romper invariantes de negocio.
7. **`schema.prisma` es la fuente de verdad del schema de BD.** Nunca hacer cambios manuales directos en PostgreSQL. Todo cambio estructural nace en `schema.prisma` y se aplica con `prisma migrate dev`. Ver `docs/prisma-workflow.md`.

---

## Contexto del proyecto

**Qué es:** ERP industrial a medida para una empresa con 8 años de operación que hoy usa Oracle Cloud ERP más un ecosistema de Excel. Reemplazamos progresivamente los Excel y eventualmente los módulos de Oracle.

**Módulos del MVP:** bodega e insumos, producción con recetas, ventas con cotizaciones, dashboard de KPIs.

**Fuera del MVP (van a módulo 2):** RR.HH. completo, leasing, marketing, proyecciones avanzadas.

**Usuarios finales:**
- Bodegueros: registran movimientos, ven stock crítico.
- Jefes de producción: crean recetas, lanzan órdenes de producción, validan costos.
- Vendedores: crean cotizaciones, convierten a órdenes de venta.
- Gerencia: consulta dashboards de KPIs.

---

## Stack técnico

| Capa              | Tecnología                                   |
|-------------------|----------------------------------------------|
| Portal clientes   | Next.js 14 (App Router) + Tailwind + TanStack Query |
| Backoffice        | Angular 17 standalone + NgRx Signals + ag-grid |
| Backend (todo)    | NestJS 10 + Prisma + PostgreSQL (monolito modular) |
| Base de datos     | PostgreSQL 15 (con JSONB para campos dinámicos) |
| Cache y jobs     | Redis + BullMQ                               |
| Comunicación interna | EventEmitter2 (NestJS nativo)             |
| Mensajería externa | RabbitMQ (cuando se extraigan microservicios) |
| Auth              | Keycloak (OAuth2 + JWT)                      |
| Observabilidad    | Prometheus + Grafana + Loki + Sentry         |
| Orquestación      | Docker Compose (local) → Kubernetes al escalar |
| CI/CD             | GitHub Actions                                |
| ETL               | Python 3.12 + pandas + SQLAlchemy + Airflow  |
| Tests             | Jest, Playwright, Cypress, k6                |

---

## Arquitectura resumida

- **Monolito modular en NestJS.** Todos los módulos (auth, bodega, ventas, producción, notificaciones) viven en un solo proceso (`services/erp-api/`) con bounded contexts claros, listos para extraerse como microservicios cuando el negocio lo justifique.
- **Comunicación interna entre módulos:** `EventEmitter2` (NestJS nativo). Mismo formato de payload que usaríamos con RabbitMQ — solo cambia el transporte cuando se extraigan microservicios.
- **Multi-tenancy:** por schema en PostgreSQL (un schema por empresa/rubro).
- **Campos dinámicos (variantes de producto, recetas):** columna JSONB en PostgreSQL con validación via JSON Schema.
- **Tarifas de producción:** tabla con vigencia temporal (`valid_from`, `valid_to`) para preservar cálculos históricos.
- **Schema de BD:** `schema.prisma` es la fuente de verdad. Punto de partida con `prisma db pull` desde la BD existente. Cambios futuros con `prisma migrate dev`. Ver `docs/prisma-workflow.md`.

Detalle en `docs/architecture.md`, `docs/arquitectura-decision.md` y ADRs en `docs/adrs/`.

---

## Estructura del repo

```
services/
  erp-api/        ← monolito NestJS (todos los módulos)
    prisma/
      schema.prisma   ← fuente de verdad del schema
      migrations/
    src/
      modules/
        auth/         ← gestionado por A1
        bodega/       ← gestionado por A1
        ventas/       ← gestionado por A1
        produccion/   ← gestionado por A1 (con coordinación de S2)
        notificaciones/ ← gestionado por A1
      shared/         ← Prisma, guards, pipes, eventos
web/
  public/         ← Next.js (clientes) — A3
  backoffice/     ← Angular (operaciones) — A4
etl/              ← Python, migración Excel — A5
infra/            ← Docker Compose, scripts locales — A7
agents/           ← contratos de agentes IA (A1-A7)
docs/             ← arquitectura, ADRs, glosario, eventos, RBAC, Prisma
tests/            ← E2E entre módulos
```

**Regla de dominios:** cada módulo del monolito solo puede ser modificado por A1, pero las invariantes específicas (especialmente las del módulo producción) requieren coordinación con S2.

---

## Catálogo de agentes IA

| ID | Nombre                | Dominio propio                           | Supervisor humano |
|----|-----------------------|------------------------------------------|-------------------|
| A1 | Arquitecto NestJS     | `services/erp-api/src/modules/*` (monolito completo) | S1 (con S2 para módulo producción) |
| A2 | Ingeniero Producción  | EN ESPERA — futuro microservicio Python cuando se extraiga del monolito | S2 |
| A3 | UI Next.js            | `web/public/`                            | S3                |
| A4 | UI Angular            | `web/backoffice/`                        | S3                |
| A5 | ETL & Migración       | `etl/`                                   | PO                |
| A6 | QA & Tests            | `tests/`, `**/__tests__/`, `**/*.test.*` | QA                |
| A7 | DevOps & Infra        | `infra/`, `.github/workflows/`, `Dockerfile*`, `docker-compose.yml` | DO |

**Si eres invocado sin contrato explícito, identifícate por el directorio donde te pidieron trabajar.**

---

## Convenciones de código

### Commits

Formato obligatorio: `<type>(<scope>): <description> [<agent-id>]`

Ejemplos:
- `feat(bodega): add categorias crud endpoints [A1]`
- `fix(produccion): corrige cálculo de horas-hombre mixto [A2]`
- `test(ventas): add e2e for cotizacion flow [A6]`
- `chore(infra): update k8s deployment resources [A7]`

### Branches

Formato: `<type>/<ticket-id>-<short-description>`
Ejemplo: `feat/T-016-categorias-insumos`

### PRs

- Título: mismo formato que commit.
- Labels obligatorios: `agent:A{N}` y `supervisor:{S1|S2|S3|PO|QA|DO|TL}`.
- Descripción debe incluir: ticket de Jira, qué cambió, cómo validar, checklist de invariantes.

---

## Invariantes de negocio (críticas — hay tests que las verifican)

1. **Stock nunca negativo.** Antes de registrar salida, validar stock disponible.
2. **Toda mutación de bodega genera un evento** (`bodega.movimiento.registrado`). Hoy se emite con `EventEmitter2` (interno al monolito); cuando se extraigan microservicios, se publicará en RabbitMQ con el mismo schema.
3. **El cálculo de costo de producción debe coincidir con el Excel del cliente en ≥99% de los casos.** Fixture de 50+ casos reales en `tests/fixtures/excel-costos.json`.
4. **Las tarifas tienen vigencia temporal.** Nunca sobrescribir tarifas pasadas.
5. **Los campos JSONB de variantes se validan contra un JSON Schema** definido por categoría de producto.
6. **Toda orden de venta confirmada dispara evento** `venta.confirmada.v1` que puede ser consumido por producción.
7. **RBAC en todos los endpoints.** Nada público excepto `/health`, `/auth/login`, endpoints del portal público marcados.

---

## Lo que los agentes NUNCA deben hacer

- ❌ Modificar `.env` o archivos con secretos reales.
- ❌ Tocar código fuera de su dominio asignado.
- ❌ Deshabilitar tests (`.skip`, `@Ignore`, `xit`) para hacer pasar CI.
- ❌ Hardcodear URLs, credenciales, IPs.
- ❌ Crear dependencias circulares entre servicios.
- ❌ Usar librerías fuera de las aprobadas en `package.json` / `pom.xml` sin ADR.
- ❌ Acceder a tablas de un módulo desde otro módulo directamente. Siempre vía servicio público (export del módulo) o evento (`EventEmitter2`).
- ❌ Cambiar el schema de BD sin generar migración con `prisma migrate dev`. Ver `docs/prisma-workflow.md`.
- ❌ Modificar tarifas históricas (solo crear nuevas con vigencia futura).
- ❌ Asumir que un campo "obvio" existe en los datos del cliente sin validar.

---

## Cómo validar tu trabajo antes de pedir review

Antes de avisar al supervisor que tu tarea está lista:

```bash
# Backend (monolito NestJS)
cd services/erp-api
npm run lint
npm run test
npm run build

# Frontend
cd web/public  # o web/backoffice
npm run lint
npm run test
npm run build

# ETL Python
cd etl
ruff check .
pytest

# Todos (recomendado)
./scripts/pre-pr-check.sh
```

El script `./scripts/pre-pr-check.sh` corre todas las verificaciones aplicables a los archivos que modificaste.

---

## Dependencias entre agentes

- **A1 (NestJS)** es responsable del monolito completo. Sus módulos internos se comunican por `EventEmitter2`. Cuando se extraiga un módulo como microservicio, A2 toma ese servicio.
- **A2 (Producción)** está EN ESPERA. Se activa cuando se extraiga el módulo producción del monolito como microservicio Python. Hasta entonces, A1 lo gestiona.
- **A3 y A4 (frontends)** consumen el API REST expuesto por el monolito (`services/erp-api`). NO llaman a módulos internamente.
- **A5 (ETL)** escribe a PostgreSQL pero genera eventos en RabbitMQ (cuando exista) o invoca endpoints del monolito.
- **A6 (QA)** genera tests que viven junto al código del módulo pero pueden necesitar fixtures compartidos.
- **A7 (DevOps)** provisiona infra para todos pero no toca lógica de negocio.

Si tu tarea cruza dominios, **pide coordinación al Tech Lead (TL)**, no lo resuelvas tú solo.

---

## Glosario rápido (detalle en `docs/glossary.md`)

- **O/P:** Orden de Producción
- **O/V:** Orden de Venta
- **h/h:** horas-hombre (tiempo de personal, no de máquina)
- **Receta:** lista de insumos + cantidades que componen un producto
- **Variante:** versión de un producto con campos dinámicos (color, tamaño, especificaciones custom)
- **Tipo de cobro mixto:** combinación de cobro por minuto + cobro por unidad
- **Costo/min máquina:** tarifa por minuto de operación de una máquina específica
- **Clientes frecuentes:** clientes con condiciones comerciales preferenciales
- **Leasing:** sector que agrupa arriendos de maquinaria (módulo 2, no MVP)

---

## Cuando encuentres ambigüedad

Hay ambigüedad constante en este proyecto porque los Excel del cliente tienen lógica implícita no documentada. Si encuentras algo así:

1. **No asumas.** No inventes una regla que no existe.
2. **Documenta la ambigüedad** en el PR como "pregunta para PO".
3. **Etiqueta al Product Owner** en Slack o en el comentario del PR.
4. **Continúa con otras tareas** mientras esperas respuesta, no bloquees el sprint.

---

## Archivos relacionados

- `README.md` — overview del proyecto para humanos
- `agents/A{N}-*.md` — tu contrato específico como agente
- `prompts/backlog/T-XXX-*.md` — **prompt detallado del ticket que estás ejecutando**
- `prompts/README.md` — cómo se estructuran los prompts y el flujo completo
- `docs/stack.md` — **stack tecnológico completo y justificado (lectura obligatoria)**
- `docs/glossary.md` — **glosario de negocio (lectura obligatoria antes de tocar dominio)**
- `docs/architecture.md` — **vista integral del sistema con diagramas de arquitectura, datos, runtime y despliegue**
- `docs/events.md` — **catálogo autoritativo de eventos RabbitMQ (lectura obligatoria antes de publicar o consumir eventos)**
- `docs/prisma-workflow.md` — **flujo de trabajo con Prisma (lectura obligatoria antes de tocar schema de BD)**
- `docs/adrs/README.md` — **índice de decisiones arquitectónicas (lectura obligatoria)**
- `docs/adrs/ADR-*.md` — decisiones específicas — consulta antes de proponer alternativas
- `dashboard/erp_agentes_ia.html` — panel visual del proyecto

## Antes de proponer cambios estructurales

Si vas a proponer usar una tecnología distinta, modelar datos de otra forma, o cambiar un patrón del sistema, **primero lee los ADRs relevantes**. Las decisiones que ya están tomadas tienen razones documentadas.

Si tu propuesta contradice un ADR vigente:
1. No la implementes silenciosamente.
2. Explica al supervisor humano por qué el ADR actual no resuelve tu caso.
3. El supervisor decidirá si amerita un ADR nuevo que supere al anterior.

## Cómo interpretar instrucciones del supervisor

Cuando el supervisor humano te pida ejecutar una tarea, el prompt suele ser corto pero **referencia archivos versionados** con `@`:

> "Ejecuta T-016. Lee `@prompts/backlog/T-016-categorias-insumos.md` y `@agents/A1-nestjs.md`."

**Tu deber es:**
1. Leer completo el archivo de prompt del ticket. Tiene los criterios de aceptación, casos de prueba, alcance y expectativas negativas.
2. Leer completo tu contrato de agente. Te dice tu dominio propio y restricciones.
3. Leer este archivo (`CLAUDE.md`) para contexto global.
4. Solo entonces empezar a generar código.

**Si el prompt del ticket no existe aún en `prompts/backlog/`**, deténte y pide al supervisor que lo prepare primero. Nunca ejecutes una tarea sin un prompt commiteado — rompe la trazabilidad del proyecto.

---

**Última actualización de este archivo:** Abril 2026
**Responsable de mantenerlo:** Tech Lead (TL)
**Frecuencia de revisión:** semanal (ceremonia "Curación de contexto")
