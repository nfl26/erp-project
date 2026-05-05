# ADR-001: Microservicios por dominio de negocio
> ⚠️ **Parcialmente supersedado por [ADR-010](ADR-010-monolito-modular.md)** (Abril 2026).
>
> Los bounded contexts identificados aquí siguen siendo válidos, pero hoy viven como **módulos** dentro de un monolito modular NestJS, no como microservicios separados. Se extraerán como microservicios cuando se cumplan los criterios de `docs/arquitectura-decision.md`.


- **Status:** accepted
- **Date:** 2026-04-15
- **Deciders:** TL, PO, S1, S2
- **Tags:** arquitectura, servicios, escalabilidad

---

## Contexto

El proyecto tiene 6 meses para un MVP, 7 personas humanas + 7 agentes IA, y la intención explícita del cliente de **escalar a múltiples rubros** después del primer lanzamiento. Los módulos del sistema (bodega, producción, ventas, recursos humanos, leasing, marketing) tienen ritmos de cambio, equipos responsables y requisitos de escalabilidad muy distintos.

Específicamente:

- **Producción** es el corazón del negocio: lógica transaccional densa, cálculo monetario crítico, alto volumen de mutaciones.
- **Bodega** es CRUD + eventos: muchos endpoints simples, alto volumen de lecturas.
- **Ventas** tiene flujos largos (cotización → OV → facturación) con estados complejos.
- **Marketing** (módulo 2) es casi read-only sobre datos de otros dominios.

Un equipo pequeño tiende a favorecer simplicidad (monolito), pero un monolito con intención de multi-tenant y multi-rubro genera acoplamientos caros de revertir.

---

## Decisión

Implementaremos el sistema como **microservicios divididos por bounded context de negocio**, no por entidad ni por capa técnica.

Los servicios del MVP son:

| Servicio | Stack | Dominio | Agente dueño |
|---|---|---|---|
| `core` | NestJS | Auth, users, gateway | A1 |
| `bodega` | NestJS | Insumos, categorías, movimientos | A1 |
| `ventas` | NestJS | Clientes, cotizaciones, O/V | A1 |
| `produccion` | Spring Boot | Productos, recetas, O/P, costos | A2 |
| `notificaciones` | NestJS | Alertas, notificaciones, eventos | A1 |

**Regla de división:** un servicio contiene todo lo necesario para resolver su dominio end-to-end (datos, lógica, API). La comunicación entre servicios es vía API REST para consultas síncronas y vía eventos RabbitMQ para flujos asincrónicos.

---

## Alternativas consideradas

### A) Monolito modular

Un solo repositorio, un solo deployable, módulos internos bien separados.

**Pros:**
- Deploy mucho más simple.
- Transacciones distribuidas no existen (todo en la misma BD).
- Refactoring entre módulos es trivial.
- Menos overhead de coordinación.

**Cons:**
- Imposible escalar un módulo sin escalar todo.
- Un bug en cualquier módulo tumba todo el sistema.
- Multi-tenancy multi-rubro fuerza acoplamientos.
- Rendimiento de módulos read-heavy (dashboards) compite con módulos transaccionales.
- Migrar a microservicios después es costoso.

### B) Microservicios por entidad (uno por tabla principal)

Un servicio de insumos, uno de productos, uno de órdenes, etc.

**Pros:**
- Máxima granularidad.
- Teóricamente máxima escalabilidad.

**Cons:**
- Transacciones que cruzan entidades (muchas) se vuelven distribuidas.
- Cada operación de negocio toca 3-5 servicios → latencia pésima.
- Inviable para un equipo de 7 personas.
- Contradice los principios de DDD (bounded context, no tabla).

### C) Microservicios por dominio de negocio **(elegida)**

Un servicio por cada bounded context.

**Pros:**
- Cada servicio es autónomo y tiene equipo claro (agente + supervisor humano).
- Los dominios naturales del negocio coinciden con los límites de los servicios.
- Permite escalabilidad futura por rubro (multi-tenant, multi-región).
- Deploy independiente por servicio.
- Alineado con DDD.

**Cons:**
- Hay transacciones que cruzan dominios (ej: confirmar O/V genera O/P) y hay que manejarlas con eventos y eventual consistency.
- Más complejo que un monolito en infra (K8s, mensajería, observabilidad distribuida).
- Requiere disciplina con los contratos entre servicios.

---

## Consecuencias

### Positivas

- Cada agente IA tiene un territorio claramente delimitado (ver `agents/*.md`).
- El cliente puede pedir nuevos rubros sin tocar el código de los rubros existentes.
- Un bug en notificaciones no tumba producción.
- Escalar producción (donde estarán las máquinas) es independiente de escalar el portal.

### Negativas que aceptamos

- **Latencia más alta** en operaciones que cruzan servicios. Mitigación: usar eventos para lo no-crítico, caching agresivo para lo crítico.
- **Eventual consistency** en flujos de producción + ventas. Mitigación: idempotencia en consumers, sagas para transacciones largas.
- **Overhead de infraestructura** (K8s, RabbitMQ, Prometheus). Mitigación: A7 (DevOps) asume este costo, Helm charts templatizados.
- **Costo cognitivo** para los supervisores humanos al hacer code review cross-service. Mitigación: contratos de eventos versionados.

### Reglas derivadas que los agentes deben respetar

1. **Un servicio nunca consulta la BD de otro servicio.** Siempre vía API o evento.
2. **Los eventos son contratos versionados** (`bodega.movimiento.v1`). Una versión nueva no rompe consumidores viejos.
3. **Cada servicio es dueño de su schema de BD.** Incluye sus propias migraciones.
4. **Tests de contrato con Pact** para verificar que servicios cumplen lo que publicaron.

---

## Referencias

- Libro _Domain-Driven Design_ (Eric Evans) — concepto de bounded context.
- Libro _Team Topologies_ — alineación de equipos con servicios.
- `docs/architecture.md` — diagrama completo de servicios.
- `docs/events.md` — catálogo de eventos entre servicios.
- [ADR-002](ADR-002-dos-backends-nestjs-spring.md) — decisión de stack por servicio.
- [ADR-006](ADR-006-rabbitmq-para-mensajeria.md) — elección del bus de eventos.

---

**Revisitar esta decisión si:** el costo de coordinación entre servicios supera el 30% del tiempo del equipo, o si surge un requisito de transacción fuerte entre dominios que no se pueda resolver con eventos.
