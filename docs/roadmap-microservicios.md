# Roadmap: Migración a Microservicios

> Guía de implementación para cuando el monolito modular necesite evolucionar. No ejecutar antes de que se cumplan los criterios definidos en `docs/arquitectura-decision.md`.

---

## Principio de extracción

**No extraer un módulo como microservicio por arquitectura. Extraerlo cuando el negocio lo fuerce.**

Cada extracción sigue el mismo patrón:

```
1. El módulo ya tiene interfaces claras (obligatorio desde hoy)
2. Se identifica el criterio que justifica la extracción
3. Se crea el nuevo servicio con el stack apropiado
4. Se migra el transporte: EventEmitter2 → RabbitMQ
5. Se despliega en paralelo (strangler fig pattern)
6. Se valida durante 2 semanas
7. Se retira el módulo del monolito
```

---

## Stack futuro completo por servicio

Cuando se extraigan todos los módulos, el stack final será:

### `erp-core` — Auth, usuarios, tenants

```
Stack:         NestJS 10 + Prisma + Keycloak
BD:            PostgreSQL (schema: auth.*)
Cache:         Redis (sesiones, JWT blacklist)
Puerto:        3000
Dependencias:  ninguna (todos dependen de él)
```

### `erp-bodega` — Insumos, stock, movimientos

```
Stack:         NestJS 10 + Prisma
BD:            PostgreSQL (schema: bodega.*)
Cache:         Redis (stock en tiempo real)
Eventos emite: bodega.movimiento.registrado.v1
               bodega.stock_critico.alcanzado.v1
Puerto:        3001
Dependencias:  erp-core (auth)
```

### `erp-ventas` — Clientes, cotizaciones, OVs

```
Stack:         NestJS 10 + Prisma
BD:            PostgreSQL (schema: ventas.*)
Eventos emite: ventas.cotizacion.aprobada.v1
               venta.confirmada.v1
Eventos recibe: bodega.stock_critico.alcanzado.v1
                produccion.op.cerrada.v1
Puerto:        3002
Dependencias:  erp-core, erp-bodega (consulta stock)
```

### `erp-produccion` — Recetas, OPs, costos

```
Stack:         Python 3.12 + FastAPI + SQLAlchemy  (*)
               o NestJS 10 + Prisma (si no hay ML)
BD:            PostgreSQL (schema: produccion.*)
Eventos emite: produccion.op.creada.v1
               produccion.op.cerrada.v1
               produccion.tarifa.cambiada.v1
Eventos recibe: bodega.movimiento.registrado.v1
                venta.confirmada.v1
Puerto:        3003
Dependencias:  erp-core, erp-bodega (precios insumos)
```

> (*) Si producción incorpora optimización de corte con algoritmos de nesting/packing, Python es el stack correcto. Si no, NestJS es suficiente.

### `erp-notificaciones` — Alertas, emails, push

```
Stack:         NestJS 10 + BullMQ + Redis
BD:            PostgreSQL (schema: notificaciones.*)
Eventos recibe: todos los demás servicios
Puerto:        3004
Dependencias:  erp-core + todos (consume eventos)
```

### `erp-etl` — Migración Excel, integración Oracle

```
Stack:         Python 3.12 + pandas + Airflow
BD:            PostgreSQL (escritura directa)
Tipo:          Job/worker, no HTTP server
Dependencias:  Acceso directo a BD + APIs de servicios
```

### `erp-gateway` — API Gateway unificado

```
Stack:         Kong + plugins custom, o NestJS como BFF
Función:       Rate limiting, auth, routing, transformación
Puerto:        80/443 (público)
Dependencias:  todos los servicios internos
```

---

## Infraestructura futura completa

```
┌──────────────────────────────────────────────────────────────────┐
│                        Internet                                  │
└──────────────────────────┬───────────────────────────────────────┘
                           │
                    ┌──────▼──────┐
                    │   Kong      │
                    │  Gateway    │
                    └──────┬──────┘
                           │
        ┌──────────────────┼──────────────────┐
        │                  │                  │
   ┌────▼────┐        ┌────▼────┐       ┌────▼────┐
   │ Next.js │        │Angular  │       │  REST   │
   │ Portal  │        │Backoffice│      │  API    │
   └────┬────┘        └────┬────┘       └────┬────┘
        │                  │                  │
        └──────────────────┼──────────────────┘
                           │
        ┌──────────────────┼──────────────────┐
        ▼                  ▼                  ▼
   ┌─────────┐       ┌─────────┐       ┌─────────┐
   │erp-core │       │erp-bodega│      │erp-ventas│
   │  :3000  │       │  :3001  │       │  :3002  │
   └────┬────┘       └────┬────┘       └────┬────┘
        │                  │                  │
        └──────────────────┼──────────────────┘
                           │
              ┌────────────┼────────────┐
              ▼            ▼            ▼
        ┌──────────┐ ┌──────────┐ ┌──────────┐
        │erp-prod  │ │erp-notif │ │ erp-etl  │
        │  :3003   │ │  :3004   │ │  (job)   │
        └────┬─────┘ └────┬─────┘ └──────────┘
             │             │
             └──────┬──────┘
                    ▼
            ┌───────────────┐
            │   RabbitMQ    │
            │  (mensajería) │
            └───────┬───────┘
                    │
        ┌───────────┼───────────┐
        ▼           ▼           ▼
  ┌──────────┐ ┌─────────┐ ┌─────────┐
  │PostgreSQL│ │  Redis  │ │Keycloak │
  │(multi-   │ │ (cache) │ │  (auth) │
  │ schema)  │ └─────────┘ └─────────┘
  └──────────┘
```

### Kubernetes (cuando llegue)

```
Namespace: erp-prod
├── Deployment: erp-core          (2 replicas min)
├── Deployment: erp-bodega        (2 replicas min)
├── Deployment: erp-ventas        (2 replicas min)
├── Deployment: erp-produccion    (3 replicas — más carga)
├── Deployment: erp-notificaciones (2 replicas min)
├── CronJob:    erp-etl            (según schedule)
├── StatefulSet: rabbitmq          (3 nodos)
├── StatefulSet: redis             (cluster)
└── Ingress: kong-gateway

Namespace: erp-infra
├── Deployment: keycloak
├── Deployment: prometheus
├── Deployment: grafana
├── Deployment: loki
└── Deployment: argocd
```

---

## Orden de extracción y criterios

### Extracción 1: `erp-produccion` (primera en extraer)

**Por qué primero:**
- Es el módulo más intensivo computacionalmente (cálculo de costos).
- Es el candidato a incorporar Python/ML para optimización de corte.
- Tiene la lógica más compleja e independiente.
- Una vez extraído, puede escalar sin afectar al resto.

**Cuándo extraer:**
- Cuando el cálculo de costos empiece a tomar >500ms por solicitud.
- Cuando se quiera incorporar algoritmos de optimización (nesting, packing).
- Cuando haya más de 50 O/Ps diarias concurrentes.

**Stack en extracción:**
```
Si no hay ML:    NestJS 10 + Prisma (mismo que el monolito)
Si hay ML:       Python 3.12 + FastAPI + SQLAlchemy + numpy/scipy
```

**Proceso:**

```bash
# 1. Crear nuevo repositorio o subdirectorio
mkdir services/erp-produccion
cd services/erp-produccion

# 2. Copiar el módulo de produccion del monolito
cp -r ../erp-api/src/modules/produccion/* src/

# 3. Reemplazar EventEmitter2 por RabbitMQ
# ANTES (monolito):
this.eventEmitter.emit('produccion.op.cerrada', payload)
# DESPUÉS (microservicio):
this.rabbitMQService.publish('produccion.events', 'produccion.op.cerrada.v1', payload)

# 4. Agregar health checks, Dockerfile, helm chart
# 5. Desplegar en paralelo al monolito (strangler fig)
# 6. Migrar tráfico gradualmente (10% → 50% → 100%)
# 7. Retirar módulo del monolito
```

---

### Extracción 2: `erp-bodega` (segunda)

**Por qué segundo:**
- Volumen de movimientos puede crecer mucho en operación real.
- Stock en tiempo real puede necesitar Redis dedicado.
- Es el módulo más consultado por otros (ventas, producción necesitan el stock).

**Cuándo extraer:**
- Cuando haya más de 1000 movimientos de bodega por día.
- Cuando la consulta de stock se vuelva el bottleneck.
- Cuando se quiera cache distribuido de stock por tenant.

---

### Extracción 3: `erp-ventas` (tercera)

**Cuándo extraer:**
- Cuando haya múltiples canales de venta (web, app móvil, API B2B).
- Cuando el volumen de cotizaciones supere 500/día.
- Cuando se quiera escalar ventas independientemente de producción.

---

### Extracción 4: `erp-core` (última)

**Por qué última:**
- Todos dependen de core (auth, usuarios, RBAC).
- Extraerlo requiere que todos los demás ya sean microservicios.
- Es el servicio más crítico — su downtime afecta todo.

**Cuándo extraer:**
- Solo cuando todos los demás ya sean microservicios.
- Nunca antes de tener observabilidad completa y circuit breakers.

---

## Migración del transporte: EventEmitter2 → RabbitMQ

Este es el cambio más crítico en cada extracción. La lógica de negocio no cambia — solo el transporte.

### En el monolito (hoy)

```typescript
// Publisher (dentro del monolito)
@Injectable()
export class BodegaService {
  constructor(private eventEmitter: EventEmitter2) {}

  async registrarMovimiento(dto: MovimientoDto) {
    const movimiento = await this.repo.create(dto);

    // Evento interno - mismo proceso
    this.eventEmitter.emit('bodega.movimiento.registrado', {
      movimientoId: movimiento.id,
      insumoId: movimiento.insumoId,
      tipo: movimiento.tipo,
      cantidad: movimiento.cantidad,
    });

    return movimiento;
  }
}

// Consumer (dentro del monolito)
@Injectable()
export class ProduccionService {
  @OnEvent('bodega.movimiento.registrado')
  handleMovimiento(payload: MovimientoEvent) {
    // actualizar último precio conocido
  }
}
```

### Después de extraer (microservicios)

```typescript
// Publisher (erp-bodega, servicio separado)
@Injectable()
export class BodegaService {
  constructor(
    @Inject('RABBITMQ_SERVICE') private rmq: ClientProxy
  ) {}

  async registrarMovimiento(dto: MovimientoDto) {
    const movimiento = await this.repo.create(dto);

    // Evento externo - RabbitMQ
    this.rmq.emit('bodega.movimiento.registrado.v1', {
      envelope: { eventId: uuid(), tenantId: dto.tenantId, ... },
      payload: {
        movimientoId: movimiento.id,
        insumoId: movimiento.insumoId,
        tipo: movimiento.tipo,
        cantidad: movimiento.cantidad,
      }
    });

    return movimiento;
  }
}

// Consumer (erp-produccion, servicio separado)
@Controller()
export class ProduccionConsumer {
  @MessagePattern('bodega.movimiento.registrado.v1')
  handleMovimiento(@Payload() event: MovimientoEvent) {
    // exactamente la misma lógica que antes
  }
}
```

**La lógica de negocio no cambia. Solo el transporte.**

---

## Checklist antes de cada extracción

Antes de extraer cualquier módulo como microservicio, verificar:

### Prerequisitos técnicos

- [ ] El módulo tiene interfaces públicas bien definidas (no hay acceso directo a repositorios desde afuera)
- [ ] Todos los eventos están documentados en `docs/events.md` con schemas JSON
- [ ] Los eventos internos (EventEmitter2) tienen el mismo formato que los externos (RabbitMQ) — solo cambia el transporte
- [ ] Hay tests de integración que cubren el comportamiento del módulo
- [ ] RabbitMQ está configurado y funcionando en el ambiente de destino
- [ ] Hay observabilidad (Prometheus, Loki, Sentry) funcionando

### Prerequisitos de negocio

- [ ] Se cumple al menos uno de los criterios de extracción definidos en `docs/arquitectura-decision.md`
- [ ] El Tech Lead y el PO aprueban la extracción
- [ ] Hay capacidad en el sprint para hacerlo (no mezclar con features nuevas)
- [ ] Hay un plan de rollback claro

### Prerequisitos operativos

- [ ] Hay un Dockerfile para el nuevo servicio
- [ ] Hay un Helm chart para el nuevo servicio
- [ ] El CI/CD está configurado para el nuevo repositorio/servicio
- [ ] Los health checks están implementados

---

## Herramientas que se incorporan al extraer

| Herramienta | Para qué | Cuándo incorporar |
|---|---|---|
| RabbitMQ 3.12 | Mensajería entre servicios | Primera extracción |
| Kong API Gateway | Routing, rate limiting, auth | Primera extracción |
| Jaeger / Tempo | Distributed tracing | Primera extracción |
| Kubernetes (EKS) | Orquestación | Primera extracción |
| Helm 3 | Packaging de K8s | Primera extracción |
| ArgoCD | GitOps deployments | Primera extracción |
| Istio (opcional) | Service mesh, mTLS | Si hay > 5 servicios |
| Kafka (opcional) | Si RabbitMQ no alcanza | Si hay > 10k eventos/seg |

---

## Decisiones de stack que se revisarán en cada extracción

### `erp-produccion`: ¿NestJS o Python?

```
Si el módulo de producción incorpora:
  ├─ Optimización de corte (nesting 2D/3D)     → Python + scipy/shapely
  ├─ Predicción de tiempos con ML               → Python + scikit-learn
  ├─ Análisis de eficiencia con datos históricos → Python + pandas
  └─ Solo lógica de negocio CRUD + costos        → NestJS (mismo stack)
```

### ¿Kafka o RabbitMQ?

```
Usar RabbitMQ si:
  ├─ Volumen < 10,000 eventos/segundo
  ├─ No se necesita replay histórico de eventos
  └─ El equipo ya lo conoce (costo de aprendizaje bajo)

Migrar a Kafka si:
  ├─ Volumen > 10,000 eventos/segundo
  ├─ Se necesita auditoría completa y replay
  └─ Hay múltiples sistemas externos consumiendo los mismos eventos
```

---

## ADR que se crearán en cada extracción

Cada extracción genera al menos un ADR nuevo que documenta:

- Por qué se extrajo ese módulo en ese momento.
- Qué stack se eligió y por qué.
- Cómo se migró el tráfico.
- Qué problemas se encontraron.

Esto construye el historial de decisiones del sistema para el equipo que lo mantenga.

---

## Resumen visual del camino completo

```
HOY (2026)
│
│  Monolito Modular NestJS
│  ├── auth module
│  ├── bodega module       } todos en un proceso
│  ├── ventas module       } una BD
│  ├── produccion module   } EventEmitter2 interno
│  └── notificaciones module
│
▼ Criterio: cálculo de costos es bottleneck o se incorpora ML

AÑO 1-2
│
│  Monolito NestJS  +  erp-produccion (separado)
│  ├── auth module             │
│  ├── bodega module     ←──── RabbitMQ ────→  produccion service
│  ├── ventas module                           (NestJS o Python)
│  └── notificaciones module
│
▼ Criterio: volumen de bodega crece, stock es bottleneck

AÑO 2-3
│
│  erp-core  +  erp-bodega  +  erp-ventas  +  erp-produccion
│                     └────────── RabbitMQ ──────────┘
│                     └────────── PostgreSQL ─────────┘
│
▼ Criterio: core necesita alta disponibilidad independiente

AÑO 3+
│
│  Arquitectura de microservicios completa
│  Kong Gateway → 5+ servicios → PostgreSQL multi-schema
│                              → Redis cluster
│                              → RabbitMQ cluster (o Kafka)
│  K8s (EKS) con ArgoCD + Helm
│  Observabilidad completa (Jaeger, Prometheus, Grafana, Loki)
```

---

## Referencias

- [`docs/arquitectura-decision.md`](arquitectura-decision.md) — por qué empezamos con monolito
- [`docs/events.md`](events.md) — catálogo de eventos (mismos en monolito y microservicios)
- [`docs/stack.md`](stack.md) — stack tecnológico actual
- [`docs/adrs/ADR-001-microservicios-por-dominio.md`](adrs/ADR-001-microservicios-por-dominio.md) — decisión original (ahora supersedada por ADR-010)
- [`docs/adrs/ADR-010-monolito-modular.md`](adrs/ADR-010-monolito-modular.md) — ADR que formaliza esta decisión

---

**Versión:** 1.0
**Fecha:** Abril 2026
**Mantenedor:** Tech Lead
**Revisión:** al cumplirse cualquier criterio de extracción
