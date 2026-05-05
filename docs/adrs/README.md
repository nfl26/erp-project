# Architecture Decision Records (ADRs)

> Registro de decisiones arquitectónicas significativas del proyecto. Cada ADR documenta una decisión concreta, su contexto, las alternativas que consideramos, y las consecuencias aceptadas.

---

## Por qué usamos ADRs

El código responde **qué** hace el sistema. Los ADRs responden **por qué** es así. Sin ADRs, seis meses después nadie recuerda por qué no usamos MongoDB y alguien propone cambiarlo "porque sería más simple". Los ADRs son la memoria institucional del proyecto.

En un proyecto con agentes IA los ADRs son especialmente críticos porque los agentes pueden leer el código pero no pueden inferir las conversaciones que llevaron a escribirlo así. Los ADRs cierran ese gap.

---

## Cuándo escribir un ADR

**Sí** requiere ADR:
- Elegir entre dos o más tecnologías rivales (PostgreSQL vs MongoDB, NestJS vs Fastify).
- Definir una invariante de dominio con impacto monetario (cálculo de costos, vigencia temporal).
- Establecer un patrón que se replicará en todo el sistema (eventos, RBAC, multi-tenancy).
- Decisión que sería cara de revertir después (schema de BD, división de servicios).

**No** requiere ADR:
- Elegir una librería pequeña (ej: qué logger usar, qué biblioteca de validación).
- Convenciones de código (eso va en linter y style guide).
- Decisiones de implementación dentro de un módulo (eso vive en el código con comentarios).
- Cambios que se pueden revertir en un día.

---

## Formato

Cada ADR sigue la misma estructura:

```
# ADR-NNN: Título corto de la decisión

- Status: proposed | accepted | deprecated | superseded by ADR-XXX
- Date: YYYY-MM-DD
- Deciders: TL, PO, <otros involucrados>
- Tags: <tags libres para búsqueda>

## Contexto
<Qué problema estamos resolviendo. Qué fuerzas están en juego.>

## Decisión
<La decisión concreta, en imperativo. "Usaremos X porque Y.">

## Alternativas consideradas
<Lista con pros/cons de cada alternativa descartada.>

## Consecuencias
<Qué implica esta decisión. Lo bueno y lo malo que aceptamos.>

## Referencias
<Links a tickets, docs externos, PRs.>
```

---

## Cómo proponer un ADR nuevo

1. Crear archivo `ADR-NNN-titulo-en-kebab-case.md` en este directorio (siguiente número disponible).
2. Escribir con status `proposed`.
3. Abrir PR y etiquetar al Tech Lead.
4. Discutir en ceremonia de Prompt Review o sync específico.
5. Al aprobar, cambiar status a `accepted` y mergear.
6. Si supera a un ADR previo, actualizar el anterior con `superseded by ADR-NNN`.

---

## Índice de ADRs

| # | Título | Status | Fecha | Tema |
|---|--------|--------|-------|------|
| [001](ADR-001-microservicios-por-dominio.md) | Microservicios por dominio de negocio | accepted | 2026-04 | arquitectura |
| [002](ADR-002-dos-backends-nestjs-spring.md) | Dos backends: NestJS + Spring Boot | 🚫 supersedado por ADR-010 | 2026-04 | stack |
| [003](ADR-003-multi-tenancy-por-schema.md) | Multi-tenancy por schema en PostgreSQL | accepted | 2026-04 | datos |
| [004](ADR-004-jsonb-para-campos-dinamicos.md) | JSONB para campos dinámicos | accepted | 2026-04 | datos |
| [005](ADR-005-stock-calculado-desde-movimientos.md) | Stock calculado desde movimientos, no editable | accepted | 2026-04 | dominio |
| [006](ADR-006-rabbitmq-para-mensajeria.md) | RabbitMQ para mensajería entre servicios | accepted | 2026-04 | infraestructura |
| [007](ADR-007-tarifas-temporales.md) | Tarifas con vigencia temporal inmutables | accepted | 2026-04 | dominio |
| [008](ADR-008-excel-validation-como-guardrail.md) | Validación contra Excel como guardrail de CI | accepted | 2026-04 | calidad |
| [009](ADR-009-claude-code-como-herramienta-estandar.md) | Claude Code como herramienta estándar de agentes | accepted | 2026-04 | proceso |

---

**Mantenedor:** Tech Lead
**Frecuencia de revisión:** cada cambio de fase o cuando se propone un ADR nuevo
