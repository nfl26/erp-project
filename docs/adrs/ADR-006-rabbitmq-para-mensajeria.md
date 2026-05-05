# ADR-006: RabbitMQ para mensajería entre servicios
> ⏸️ **Postergado por [ADR-010](ADR-010-monolito-modular.md)** (Abril 2026).
>
> RabbitMQ se incorpora cuando se extraiga el primer módulo del monolito como microservicio. Hoy los eventos del sistema viajan por `EventEmitter2` (NestJS nativo) con el mismo formato de payload documentado en `docs/events.md`. La transición es solo del transporte.


- **Status:** accepted
- **Date:** 2026-04-16
- **Deciders:** TL, S1, S2, DO
- **Tags:** infraestructura, mensajeria, arquitectura

---

## Contexto

La arquitectura de microservicios (ADR-001) requiere un mecanismo para comunicación asincrónica entre servicios. Los casos concretos del MVP son:

- Cuando bodega registra un movimiento, producción debe enterarse (para actualizar costos de insumos consumidos).
- Cuando ventas confirma una O/V, producción debe crear la O/P asociada.
- Cuando producción cierra una O/P, notificaciones debe enviar alertas al equipo comercial.
- Jobs asincrónicos: envío de emails, generación de PDFs, reportes pesados.

Históricamente hay dos opciones dominantes en este espacio:

1. **RabbitMQ:** message broker tradicional, patrones AMQP (queues, exchanges, routing).
2. **Kafka:** streaming distribuido, patrones pub/sub con logs persistentes y replay.

Otras opciones consideradas pero descartadas rápidamente: Redis pub/sub (no garantiza entrega), AWS SQS (lock-in innecesario para self-hosted), NATS (menos maduro ecosistema).

El equipo es pequeño (7 personas humanas) y el volumen esperado del MVP es moderado (decenas de miles de eventos/día, no millones). La decisión tiene que balancear capacidades actuales con evolución futura.

---

## Decisión

Usaremos **RabbitMQ 3.12** como message broker para toda comunicación asincrónica entre servicios y para colas de jobs.

### Arquitectura de colas y exchanges

```
RabbitMQ cluster
├── exchange: bodega.events (topic)
│   ├── queue: produccion.consume.bodega.movimiento
│   │   └── binding key: bodega.movimiento.v1
│   └── queue: analytics.consume.bodega.*
│       └── binding key: bodega.*.v1
├── exchange: ventas.events (topic)
│   ├── queue: produccion.consume.ventas.confirmada
│   │   └── binding key: venta.confirmada.v1
│   └── queue: notificaciones.consume.ventas.*
├── exchange: produccion.events (topic)
│   └── queue: notificaciones.consume.produccion.cerrada
│       └── binding key: produccion.op.cerrada.v1
└── queues de jobs (no usan exchange)
    ├── jobs.email.send
    ├── jobs.pdf.generate
    └── jobs.report.build
```

### Convenciones

**Nombres de eventos:**
- Formato: `{dominio}.{evento}.v{version}`
- Ejemplos: `bodega.movimiento.v1`, `venta.confirmada.v1`, `produccion.op.cerrada.v1`

**Nombres de colas:**
- Formato: `{servicio_consumidor}.consume.{origen}.{evento}`
- Ejemplos: `produccion.consume.bodega.movimiento`, `notificaciones.consume.ventas.confirmada`

**Versionado:**
- Los eventos tienen versión en el nombre (`.v1`, `.v2`).
- Una versión nueva no rompe consumers viejos — ambas coexisten hasta que todos los consumers migren.

**Schemas:**
- Todo evento publicado tiene un schema JSON versionado en `docs/events.md`.
- Los publishers validan contra el schema antes de publicar; los consumers validan al consumir.

### Garantías operacionales

- **At-least-once delivery:** los consumers deben ser idempotentes.
- **ACK manual:** el consumer debe confirmar explícitamente después de procesar con éxito.
- **Dead letter queues (DLQ):** mensajes fallidos 3 veces van a DLQ para análisis manual.
- **Persistencia:** mensajes marcados como persistent, colas durable.
- **Cluster:** 3 nodos en producción con replicación de colas críticas.

### Librerías cliente

- **NestJS:** `@nestjs/microservices` con transporte `RMQ` + `amqplib`.
- **Spring Boot:** `spring-amqp` y `spring-boot-starter-amqp`.
- **Python (ETL):** `pika` solo si aparece la necesidad; por ahora el ETL no publica eventos.

### Jobs asincrónicos

Para jobs dentro de un servicio (ej: BullMQ en NestJS con Redis), usamos Redis como backend ya decidido. RabbitMQ es solo para comunicación entre servicios.

---

## Alternativas consideradas

### A) Kafka

Streaming distribuido con logs persistentes.

**Pros:**
- Escalabilidad extrema (millones de eventos/segundo).
- Replay de eventos históricos (útil para nuevos consumers o reprocesamiento).
- Orden garantizado por partición.
- Estándar de facto en arquitecturas event-driven modernas.
- Integraciones con herramientas de analytics (Kafka Connect, Kafka Streams).

**Cons:**
- **Curva de aprendizaje alta** (particiones, consumer groups, offsets, compaction).
- **Complejidad operacional significativa** (Zookeeper hasta versiones recientes, ahora KRaft; tuning de brokers; monitoreo).
- **Sobredimensionado** para el volumen del MVP.
- **No apunta bien al patrón request/reply** ni a patrones de colas tradicionales (ej: jobs queue).
- Sin replay histórico necesario en el dominio (los eventos de bodega/producción no se reprocesan — se auditan).

### B) RabbitMQ **(elegida)**

Message broker tradicional con patrones AMQP maduros.

**Pros:**
- **Curva de aprendizaje baja.** Patrones intuitivos (queue, exchange, routing).
- **Operación sencilla.** UI de administración útil, métricas claras, cluster más simple.
- **Patrones ricos:** work queues, pub/sub, topic routing, RPC, delayed messages.
- **Casos de uso cubiertos:** el MVP no necesita replay de eventos; necesita colas con retry y DLQ.
- **Maduro y estable** (15+ años en producción en miles de empresas).
- **Librerías cliente sólidas** en todos nuestros stacks.

**Cons:**
- No escala a volúmenes que Kafka maneja naturalmente (millones/seg).
- Sin replay histórico nativo (hay extensiones pero son limitadas).
- Ordenación estricta requiere cuidado con quorum queues y prefetch.

### C) NATS JetStream

Sistema moderno de mensajería con streaming.

**Pros:**
- Muy rápido.
- API sencilla.

**Cons:**
- Ecosistema de librerías menos maduro en nuestros stacks.
- Menos personal con experiencia.
- Menos soporte enterprise.

---

## Consecuencias

### Positivas

- **Implementación del MVP sencilla.** El agente A7 (DevOps) levanta RabbitMQ con Helm chart oficial. Los agentes A1 y A2 usan librerías estándar con documentación excelente.
- **Patrones de retry y DLQ nativos** para manejar errores transitorios.
- **Observabilidad clara:** UI web, métricas Prometheus incluidas, logs legibles.
- **Jobs asincrónicos compartidos** con el mismo broker, evitando agregar otra tecnología.
- **Contratos de eventos versionados** permiten evolución sin romper consumers.

### Negativas aceptadas

- **Sin replay histórico.** Si necesitamos reprocesar eventos antiguos (ej: "recalcula todas las OPs del último mes"), no se hace con RabbitMQ — se hace con queries a la BD y trigger manual.
- **Escalabilidad con límite.** Si algún día hacemos IoT o integración con sistemas que generan millones de eventos/día, hay que migrar o complementar con Kafka.
- **Disciplina requerida** con los contratos de eventos (versionado, schemas). Mitigación: validación automática en CI.

---

## Reglas derivadas que los agentes deben respetar

**⚠️ Críticas — hay tests que las verifican:**

1. **Todo evento publicado tiene schema JSON versionado** en `docs/events.md`.
2. **Los consumers son idempotentes.** Procesar el mismo evento dos veces tiene el mismo efecto que procesarlo una sola vez.
3. **ACK solo después de procesar con éxito.** Nunca ACK-and-process; siempre process-then-ACK.
4. **Las colas son durable y los mensajes persistent.**
5. **DLQ obligatorio por cola:** tras N retries (default 3), el mensaje va a la DLQ correspondiente.
6. **Nombres según convención:** `{dominio}.{evento}.v{version}`. Violar la convención bloquea el merge.
7. **Tests de contrato con Pact** verifican que publishers cumplen el schema y que consumers manejan correctamente eventos reales.
8. **Un servicio NUNCA consume sus propios eventos.** Si necesitas reaccionar a tu propia acción, usa lógica local, no el bus.

---

## Patrones que adoptamos

### Publisher (Spring Boot ejemplo)

```java
@Component
public class EventPublisher {
    private final RabbitTemplate rabbitTemplate;

    public void publicarOrdenCerrada(OrdenCerradaEvent event) {
        // Validar contra schema
        schemaValidator.validate(event, "produccion.op.cerrada.v1");

        // Publicar
        rabbitTemplate.convertAndSend(
            "produccion.events",              // exchange
            "produccion.op.cerrada.v1",       // routing key
            event,
            message -> {
                message.getMessageProperties().setDeliveryMode(MessageDeliveryMode.PERSISTENT);
                return message;
            }
        );
    }
}
```

### Consumer (NestJS ejemplo)

```typescript
@EventPattern('bodega.movimiento.v1')
async onMovimientoBodega(@Payload() evento: MovimientoEvent, @Ctx() ctx: RmqContext) {
  try {
    await this.schemaValidator.validate(evento, 'bodega.movimiento.v1');
    await this.procesar(evento);                  // lógica idempotente
    this.ackMessage(ctx);
  } catch (error) {
    this.logger.error(error);
    this.nackMessage(ctx);                        // → retry, luego DLQ
  }
}
```

---

## Plan de migración a Kafka (si alguna vez hace falta)

Si el volumen o los requisitos cambian:

1. Correr ambos brokers en paralelo por un tiempo.
2. Los publishers escriben a ambos.
3. Migrar consumers uno por uno a Kafka.
4. Cuando todos los consumers migraron, apagar RabbitMQ.

Los contratos de eventos con schema versionado hacen que esta migración sea factible sin romper la lógica de dominio.

---

## Referencias

- [RabbitMQ patterns](https://www.rabbitmq.com/getstarted.html) — tutoriales oficiales.
- Libro _Enterprise Integration Patterns_ (Hohpe, Woolf) — patrones aplicados.
- [ADR-001](ADR-001-microservicios-por-dominio.md) — microservicios que dependen de este ADR.
- [Stack tecnológico](../stack.md) — RabbitMQ en la capa de infraestructura.
- [Contrato A7](../../agents/A7-devops.md) — responsable de operar RabbitMQ.
- `docs/events.md` — catálogo de eventos versionados (pendiente).

---

**Revisitar esta decisión si:**

- El volumen de eventos supera lo que RabbitMQ maneja cómodamente (~100k/seg sostenidos).
- Aparece la necesidad de replay histórico de eventos como patrón regular.
- Algún tenant grande requiere arquitectura event-sourced completa.
