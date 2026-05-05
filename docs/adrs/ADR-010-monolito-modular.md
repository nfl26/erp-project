# ADR-010: Monolito Modular como arquitectura inicial

**Fecha:** Abril 2026
**Estado:** Aceptado
**Supercede parcialmente:** ADR-001 (microservicios por dominio), ADR-002 (dos backends)
**Decidido por:** Tech Lead + Product Owner

---

## Contexto

El diseño original del proyecto (ADR-001, ADR-002) planteaba una arquitectura de microservicios desde el día 1 con cinco servicios separados (core, bodega, ventas, produccion, notificaciones) usando dos stacks de backend distintos (NestJS + Spring Boot).

Al evaluar el contexto real del proyecto:

- **Plazo:** 6 meses para entregar un ERP funcional.
- **Equipo:** 7 personas (supervisores + agentes IA).
- **Mantenimiento:** el mismo equipo mantiene el sistema post-entrega.
- **Prioridad declarada:** escalabilidad a múltiples rubros y clientes.
- **Base de datos:** PostgreSQL existente con schema Arteo.

Se identificó que microservicios desde el día 1 introduce complejidad operativa que consumiría 2-3 semanas de setup antes de escribir la primera línea de negocio, sin que los beneficios de microservicios sean necesarios en esta fase.

---

## Decisión

**Construir un Monolito Modular en NestJS como arquitectura inicial**, con los módulos organizados como bounded contexts bien aislados, listos para extraerse como microservicios cuando el negocio lo justifique.

---

## Qué cambia respecto al diseño anterior

### Se abandona

- Spring Boot como segundo backend.
- JPA/Hibernate y Flyway como ORM/migración.
- RabbitMQ para comunicación interna entre módulos.
- Kong API Gateway desde el día 1.
- Kubernetes desde el día 1.
- La separación en 5 repositorios o 5 procesos.

### Se mantiene

- Los mismos 5 bounded contexts (auth, bodega, ventas, produccion, notificaciones).
- Multi-tenancy por schema PostgreSQL (ADR-003 vigente).
- Prisma como ORM y fuente de verdad del schema.
- PostgreSQL 15 con JSONB para campos dinámicos (ADR-004 vigente).
- Stock calculado desde movimientos (ADR-005 vigente).
- Tarifas con vigencia temporal (ADR-007 vigente).
- Validación Excel como guardrail CI (ADR-008 vigente).
- Frontends: Next.js + Angular (sin cambios).
- Redis, Keycloak, Prometheus, GitHub Actions (sin cambios).

### Stack resultante

| Capa | Tecnología |
|---|---|
| Backend (todos los módulos) | NestJS 10 + Prisma |
| Mensajería interna | EventEmitter2 (NestJS nativo) |
| Mensajería externa (futuro) | RabbitMQ cuando haya microservicios reales |
| API Gateway | NestJS Guards + módulo gateway (nativo) |
| Orquestación | Docker Compose ahora → K8s al extraer el primer servicio |

---

## Reglas del Monolito Modular (obligatorias)

Para que el monolito sea extractable en el futuro, desde el día 1:

1. **Interfaces públicas explícitas.** Cada módulo solo expone sus servicios declarados en `exports`. Ningún módulo importa repositorios de otro módulo.

2. **Comunicación por eventos.** Los módulos usan `EventEmitter2` con el mismo formato de payload que usarán cuando sean microservicios con RabbitMQ. Solo cambia el transporte, nunca la lógica.

3. **Tablas por módulo.** Cada módulo es dueño de sus tablas. Ningún módulo hace queries a tablas de otro módulo.

4. **Sin dependencias circulares.** El grafo de dependencias entre módulos es acíclico y explícito.

---

## Consecuencias positivas

- El equipo escribe lógica de negocio desde el día 3 en lugar del día 21.
- Un solo lenguaje (TypeScript/NestJS) en todo el backend.
- Un solo ORM (Prisma) para todos los módulos.
- Debugging simple: un proceso, un log, un stack trace.
- Costo operativo bajo: Docker Compose es suficiente para empezar.
- Los bounded contexts están bien definidos y son extractables.

## Consecuencias negativas y mitigaciones

| Consecuencia | Mitigación |
|---|---|
| No se puede escalar módulos individualmente | Aceptable hasta que haya carga real. Los criterios de extracción están definidos. |
| Un bug crítico en un módulo puede afectar a todos | Buena cobertura de tests + circuit breakers internos en módulos críticos. |
| El proceso crece en memoria con el tiempo | Monitorear. Extraer módulos cuando el consumo sea problema real. |

---

## Criterios para migrar a microservicios

Definidos en `docs/arquitectura-decision.md`. Resumen:

- Un módulo necesita escalar independientemente por carga.
- Equipo > 8 personas en el mismo módulo.
- Necesidad de stack diferente (ej: Python para ML en producción).
- SLA diferente entre módulos.

---

## Relación con ADRs anteriores

| ADR | Estado | Notas |
|---|---|---|
| ADR-001 (microservicios por dominio) | Parcialmente supersedado | Los bounded contexts se mantienen, pero dentro de un proceso |
| ADR-002 (dos backends) | Supersedado | Solo NestJS en el monolito |
| ADR-003 (multi-tenancy) | Vigente | Sin cambios |
| ADR-004 (JSONB) | Vigente | Sin cambios |
| ADR-005 (stock inmutable) | Vigente | Sin cambios |
| ADR-006 (RabbitMQ) | Postergado | Se incorpora al extraer el primer microservicio |
| ADR-007 (tarifas) | Vigente | Sin cambios |
| ADR-008 (Excel validation) | Vigente | Sin cambios |
| ADR-009 (Claude Code) | Vigente | Sin cambios |

---

## Revisión

Este ADR se revisa cuando se cumpla alguno de los criterios de extracción. La extracción de cada módulo generará un ADR nuevo (ADR-011, ADR-012, etc.) documentando esa decisión específica.
