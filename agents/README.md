# Contratos de agentes IA

> Este directorio contiene los **contratos versionados** de cada agente IA del proyecto. Un contrato define la identidad, el dominio propio, las capacidades, las restricciones y los invariantes que un agente debe respetar.

---

## Por qué existen estos contratos

Un agente IA sin contrato es impredecible: puede generar código excelente en un módulo y romper invariantes en otro. Los contratos son **la delimitación explícita de su jurisdicción**: qué puede tocar, qué no, bajo qué reglas.

En este proyecto, los contratos cumplen tres funciones:

1. **Prevenir alucinaciones por exceso de contexto:** si el agente sabe que su territorio es `services/erp-api/src/modules/bodega/`, no "ayuda" modificando código de producción "porque estaba cerca".
2. **Facilitar la supervisión humana:** el supervisor humano revisa PRs comparando contra el contrato. Desviaciones son auditables.
3. **Sobrevivir cambios de modelo:** si mañana cambiamos a un modelo IA más nuevo, los contratos siguen sirviendo. El modelo cambia, el contrato persiste.

---

## Catálogo de agentes

| ID | Nombre | Stack | Territorio | Supervisor |
|----|--------|-------|------------|------------|
| [A1](A1-nestjs.md) | Arquitecto NestJS | NestJS + Prisma | `services/erp-api/src/modules/auth, bodega, ventas, notificaciones` | S1 |
| [A2](A2-springboot.md) | Ingeniero Producción | EN ESPERA — futuro Python/FastAPI | (cuando se extraiga del monolito) | S2 |
| [A3](A3-nextjs.md) | UI Next.js | Next.js 14 + React | `web/public` | S3 |
| [A4](A4-angular.md) | UI Angular | Angular 17 + NgRx Signals | `web/backoffice` | S3 |
| [A5](A5-etl.md) | ETL & Migración | Python + pandas + Airflow | `etl/` | PO |
| [A6](A6-qa.md) | QA & Tests | Jest + Playwright + Cypress + Pact | Tests en todo el repo | QA |
| [A7](A7-devops.md) | DevOps & Infra | K8s + Helm + Terraform | `infra/`, `.github/workflows/` | DO |

---

## Estructura común de un contrato

Todos los contratos siguen la misma estructura, lo que permite a humanos y agentes navegarlos consistentemente:

1. **Identidad** — ID, nombre, stack, supervisor
2. **Misión** — qué aporta al proyecto
3. **Dominio propio** — directorios que puede modificar
4. **Dominio ajeno** — directorios prohibidos
5. **Capacidades** — qué puede hacer
6. **Restricciones** — qué no puede hacer
7. **Invariantes** — reglas inviolables con tests que las verifican
8. **Convenciones de código** — patrones específicos del agente
9. **Ejemplo de prompt típico** — cómo se invoca al agente
10. **Métricas** — cómo se mide su desempeño
11. **Canal de dudas** — a quién escalar

---

## Tipos de agentes según cómo se relacionan con el código

### Agentes con territorio vertical (A1, A2, A3, A4)

Son dueños de un conjunto de directorios. Todo lo que viva ahí es suyo; todo lo de afuera les está prohibido.

### Agente con territorio transitorio (A5)

Su trabajo se concentra en la fase de migración inicial. Su relación es con los Excel del cliente y con el schema destino; su supervisor es el PO, no un supervisor técnico.

### Agente transversal por tipo de archivo (A6)

No tiene un territorio por directorio sino por **tipo de archivo**: todos los `*.spec.ts`, `*Test.java`, `tests/` son suyos, vivan donde vivan.

### Agente transversal por capa técnica (A7)

Su territorio es la **infraestructura** del proyecto. Toca archivos en todos los servicios pero solo para configurarlos (Dockerfile, Helm chart), nunca para modificar su lógica.

---

## Cómo usar un contrato

### Humanos (supervisores)

Al abrir un PR generado por un agente, revisa:

1. ¿Las modificaciones están dentro del territorio del agente? (sección "Dominio propio")
2. ¿Rompió algún invariante? (sección "Invariantes")
3. ¿Cumplió con las convenciones? (sección "Convenciones de código")
4. ¿Respetó las restricciones? (sección "Restricciones")

Si algo falla, la corrección va al prompt del ticket primero, no al código directamente.

### Agentes (al iniciar una tarea)

Lectura obligatoria **antes de tocar código**:

1. `CLAUDE.md` en la raíz del repo (contexto global, automático).
2. **Este archivo** (`agents/A{N}-*.md`) que corresponde al agente invocado.
3. El archivo de prompt del ticket específico (`prompts/backlog/T-XXX-*.md`).
4. Los ADRs referenciados en el prompt o en el contrato.

---

## Modificación de contratos

Los contratos son **documentos vivos**, pero su modificación es controlada:

1. Identificar una desviación recurrente o una regla faltante en ceremonia **Prompt Review** semanal.
2. PR que modifica el contrato con justificación.
3. Aprobación requerida: Tech Lead + Supervisor del agente afectado.
4. Merge dispara versión nueva del contrato (`v1.1`, `v1.2`...).
5. Los tickets abiertos en sprints futuros referencian la versión nueva.

**No se modifican contratos a mitad de sprint.** Si aparece un caso urgente, se documenta como ambigüedad resuelta en el prompt del ticket específico, y el contrato se ajusta al final del sprint.

---

## Dependencias entre agentes

Un diagrama resumido de quién depende de quién:

- **A1 ↔ A2:** vía eventos (RabbitMQ) y API. Nunca código compartido.
- **A3 y A4 → A1 y A2:** consumen APIs del gateway. Nunca tocan backend.
- **A5 → A1 y A2:** escribe datos que después consumen los servicios. Coordina con ellos el schema destino.
- **A6 → todos:** genera tests para el código que los demás producen. Tests viven junto al código.
- **A7 → todos:** provee infra. Nadie toca infra.

Ningún agente escribe en el territorio de otro. Los límites son estrictos precisamente para que los agentes puedan trabajar en paralelo sin pisarse.

---

**Mantenedor:** Tech Lead
**Versión de esta guía:** 1.0
**Última revisión:** Abril 2026
