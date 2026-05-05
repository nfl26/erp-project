# Decisión Arquitectónica: Monolito Modular → Microservicios

> Documento de referencia ejecutiva. Explica la decisión tomada, por qué se tomó, y cuál es el camino hacia microservicios cuando el negocio lo justifique.

---

## Resumen en una línea

**Empezamos con un monolito modular en NestJS para entregar valor rápido y mantener costos bajos, con los módulos ya diseñados como bounded contexts listos para extraerse como microservicios cuando el volumen o el negocio lo justifique.**

---

## El contexto que llevó a esta decisión

| Factor | Detalle |
|---|---|
| Plazo de entrega | 6 meses |
| Equipo | 7 personas (supervisores humanos + agentes IA) |
| Mantenimiento post-entrega | El mismo equipo (no hay equipo técnico del cliente) |
| Prioridad declarada | Escalabilidad a múltiples rubros y clientes |
| Base de datos | PostgreSQL existente con schema Arteo |
| Presupuesto operativo | No definido, asumir conservador |

---

## Por qué NO microservicios desde el día 1

Microservicios resuelven problemas de **escala organizacional y de carga**. En el punto de partida, ninguno de esos problemas existe todavía.

### El costo real de microservicios en fase 1

```
Sprint 1 con microservicios:
├── Semana 1: Setup de 5 repositorios o monorepo
├── Semana 1: Configurar K8s, Helm, ArgoCD
├── Semana 1: Configurar RabbitMQ + exchanges
├── Semana 2: API Gateway (Kong) + routing
├── Semana 2: Service discovery + health checks
├── Semana 2: Distributed tracing (Jaeger)
├── Semana 3: Primer endpoint de negocio
└── Semana 4: Primer flujo completo funcionando

→ 3 semanas de plomería antes de ver negocio
```

```
Sprint 1 con monolito modular:
├── Día 1: Setup del proyecto NestJS
├── Día 2: Prisma + schema existente conectado
├── Día 3: Primer módulo de bodega funcionando
├── Día 4: Auth + RBAC
└── Semana 2: Primer flujo completo (bodega + ventas)

→ 3 días de setup, negocio desde el día 3
```

### Los mitos que no aplican aquí

| Mito | Realidad en este proyecto |
|---|---|
| "Microservicios escalan mejor" | Escala cuando hay carga real. Hoy no hay carga. |
| "Microservicios son más resilientes" | Solo si los operas bien. Un K8s mal configurado es peor que un monolito. |
| "Microservicios permiten tecnologías mixtas" | Teníamos NestJS + Spring Boot. Ahora solo NestJS. Menos complejidad. |
| "Es difícil migrar un monolito después" | Solo si el monolito está mal modularizado. El nuestro no lo estará. |

---

## Qué es un Monolito Modular (y qué no es)

### Lo que NO es

```
❌ Monolito espagueti (todo mezclado)

src/
├── usuarios.controller.ts
├── insumos.controller.ts
├── recetas.service.ts
├── helpers.ts
└── todo-mezclado.ts
```

### Lo que SÍ es

```
✅ Monolito modular (bounded contexts dentro de un proceso)

src/
├── modules/
│   ├── auth/                 ← bounded context: autenticación
│   │   ├── auth.module.ts
│   │   ├── auth.service.ts
│   │   └── auth.controller.ts
│   │
│   ├── bodega/               ← bounded context: bodega e insumos
│   │   ├── bodega.module.ts
│   │   ├── insumos.service.ts
│   │   ├── movimientos.service.ts
│   │   └── bodega.controller.ts
│   │
│   ├── ventas/               ← bounded context: ventas y cotizaciones
│   │   ├── ventas.module.ts
│   │   ├── cotizaciones.service.ts
│   │   └── ventas.controller.ts
│   │
│   ├── produccion/           ← bounded context: producción y costos
│   │   ├── produccion.module.ts
│   │   ├── recetas.service.ts
│   │   ├── ordenes.service.ts
│   │   └── costos.service.ts
│   │
│   └── notificaciones/       ← bounded context: alertas y emails
│       ├── notificaciones.module.ts
│       └── notificaciones.service.ts
│
└── shared/                   ← código verdaderamente compartido
    ├── prisma/
    ├── guards/
    └── pipes/
```

**La diferencia clave:** los módulos tienen **interfaces definidas**. Un módulo solo puede llamar a otro módulo a través de su interfaz pública (servicios exportados), nunca accediendo directamente a sus repositorios internos. Esta regla es lo que hace posible extraerlos después como microservicios.

---

## Reglas de modularidad (obligatorias desde el día 1)

Estas reglas son las que garantizan que el monolito sea "extractable" en el futuro:

### Regla 1: Interfaces públicas explícitas

```typescript
// ✅ Correcto: bodega expone solo lo que otros necesitan
@Module({
  exports: [BodegaService],  // solo esto es visible desde afuera
})
export class BodegaModule {}

// Ventas solo puede llamar a BodegaService, nunca a InsumoRepository directamente
```

### Regla 2: Comunicación por eventos internos

Los módulos se comunican por eventos usando `EventEmitter2` de NestJS, no por llamadas directas entre servicios. Esto replica el patrón de RabbitMQ a nivel interno, y cuando se extraigan como microservicios, solo cambia el transporte (de EventEmitter2 a RabbitMQ), no la lógica.

```typescript
// bodega emite un evento cuando hay un movimiento
this.eventEmitter.emit('bodega.movimiento.registrado', payload);

// produccion escucha ese evento (igual que haría con RabbitMQ)
@OnEvent('bodega.movimiento.registrado')
handleMovimiento(payload: MovimientoEvent) { ... }
```

### Regla 3: Schemas de BD por módulo

Aunque comparten la misma instancia de PostgreSQL, cada módulo tiene sus tablas bien delimitadas. Ningún módulo hace queries a tablas de otro módulo.

```
schema: tenant_acme
├── bodega.*       → solo BodegaModule puede leer/escribir
├── ventas.*       → solo VentasModule puede leer/escribir
├── produccion.*   → solo ProduccionModule puede leer/escribir
└── auth.*         → solo AuthModule puede leer/escribir
```

### Regla 4: Sin dependencias circulares

```
auth ←── todos (dependen de auth para RBAC)
bodega ←── ventas, produccion (consultan stock)
ventas ←── produccion (para crear OPs desde OVs)
produccion ←── (no depende de ventas directamente, recibe eventos)
notificaciones ←── todos (recibe eventos de todos)
```

---

## Stack del Monolito Modular

### Lo que cambia respecto al diseño anterior

| Componente | Antes | Ahora | Razón |
|---|---|---|---|
| Backend | NestJS + Spring Boot | Solo NestJS | Eliminar complejidad de dos lenguajes |
| ORM | Prisma + JPA/Flyway | Solo Prisma | Consistencia, menos configuración |
| Mensajería interna | RabbitMQ | EventEmitter2 (nativo NestJS) | No necesitamos broker para comunicación interna |
| API Gateway | Kong | NestJS Guards + módulo gateway | NestJS puede manejarlo nativamente |
| Orquestación | K8s desde día 1 | Docker Compose → K8s al escalar | K8s cuando haya más de 1 servicio real |

### Lo que no cambia

| Componente | Tecnología | Por qué se mantiene |
|---|---|---|
| Base de datos | PostgreSQL 15 + Prisma | Schema existente, decisión validada |
| Multi-tenancy | Por schema PostgreSQL | ADR-003 sigue vigente |
| Frontend público | Next.js 14 | Sin cambios |
| Backoffice | Angular 17 | Sin cambios |
| Cache | Redis | Necesario para sesiones y jobs |
| Auth | Keycloak | SSO y OAuth2 requeridos |
| ETL | Python + pandas | Migración de Excel |
| Tests | Jest + Playwright + Cypress | Sin cambios |
| Observabilidad | Prometheus + Grafana + Sentry | Sin cambios |
| CI/CD | GitHub Actions | Sin cambios |

### Stack completo del Monolito Modular

```
┌─────────────────────────────────────────────────────────┐
│                   Clientes                              │
│        Next.js 14          Angular 17                   │
│     (Portal público)      (Backoffice)                  │
└──────────────────┬──────────────────┬───────────────────┘
                   │                  │
                   ▼                  ▼
┌─────────────────────────────────────────────────────────┐
│              NestJS 10 — erp-api                        │
│                                                         │
│  ┌──────────┐ ┌──────────┐ ┌────────────┐ ┌─────────┐  │
│  │   auth   │ │  bodega  │ │  ventas    │ │produccion│  │
│  │  module  │ │  module  │ │  module    │ │ module  │  │
│  └──────────┘ └──────────┘ └────────────┘ └─────────┘  │
│                                                         │
│  ┌──────────────────────────────────────────────────┐   │
│  │              notificaciones module               │   │
│  └──────────────────────────────────────────────────┘   │
│                                                         │
│  ┌──────────────────────────────────────────────────┐   │
│  │   shared: Prisma, Guards, Pipes, EventEmitter2   │   │
│  └──────────────────────────────────────────────────┘   │
└──────────────────┬──────────────────────────────────────┘
                   │
        ┌──────────┼──────────┐
        ▼          ▼          ▼
   PostgreSQL    Redis     Keycloak
   (Prisma)    (cache)     (auth)
```

---

## Criterios para migrar a microservicios

No migrar por moda. Migrar cuando ocurra al menos uno de estos:

| Criterio | Señal concreta |
|---|---|
| **Escala de carga** | Un módulo recibe 10x más tráfico que los demás y necesita escalar independientemente |
| **Escala de equipo** | Hay más de 8 personas trabajando en el mismo módulo simultáneamente |
| **Autonomía de despliegue** | Un módulo necesita desplegarse 10+ veces por día sin afectar al resto |
| **Stack diferente** | Producción necesita Python para ML/optimización de corte |
| **Nuevo rubro** | Se incorpora un rubro con dominio completamente diferente |
| **SLA diferente** | Un módulo necesita 99.99% de uptime mientras el resto acepta 99.9% |

Si ninguno de estos criterios se cumple, el monolito modular es la respuesta correcta.

---

## Hoja de ruta: de monolito a microservicios

Ver documento completo: [`docs/roadmap-microservicios.md`](roadmap-microservicios.md)

Orden de extracción cuando llegue el momento:

```
Fase 1 (hoy):       Monolito modular NestJS
                           │
Fase 2 (año 1-2):   Extracción de Producción
                    (primer módulo en escalar, candidato a Python/ML)
                           │
Fase 3 (año 2-3):   Extracción de Bodega
                    (volumen de movimientos puede crecer mucho)
                           │
Fase 4 (año 3+):    Extracción de Ventas
                    (si hay múltiples canales de venta)
                           │
Fase 5 (futuro):    Microservicios completos
                    (si el negocio lo justifica)
```

---

## Resumen de la decisión

```
✅ Monolito modular NestJS
   ├── Entrega en 6 meses ✓
   ├── Multi-tenancy escalable ✓
   ├── Módulos extractables cuando sea necesario ✓
   ├── Un lenguaje, un ORM, una BD ✓
   ├── Equipo pequeño puede mantenerlo ✓
   └── Costo operativo bajo ✓

❌ Microservicios desde el día 1
   ├── 3 semanas de setup sin negocio ✗
   ├── Dos lenguajes (NestJS + Spring Boot) ✗
   ├── K8s + RabbitMQ + Kong desde el inicio ✗
   └── Complejidad operativa alta para equipo de 7 ✗
```

---

**Versión:** 1.0
**Fecha:** Abril 2026
**Decisores:** Tech Lead + Product Owner
**Revisión:** cuando se cumpla algún criterio de extracción listado arriba
