# Módulo: Producción

Bounded context de Órdenes de Producción (O/P), recetas, tarifas y costos.

**Ticket de scaffolding:** T-005  
**Responsable:** A1 (supervisado por S1 + S2)

---

## Estructura

```
produccion/
├── produccion.module.ts      ← Módulo NestJS (raíz del bounded context)
├── public/                   ← Contrato público: todo lo que otros módulos pueden usar
│   ├── produccion.facade.ts  ← Única puerta de entrada al módulo
│   ├── types.ts              ← Interfaces exportadas (CostoBreakdown, etc.)
│   └── index.ts              ← Re-exports del public/
├── events/                   ← Schemas Zod de eventos internos/externos
│   └── produccion.events.ts
├── internal/                 ← Submódulos internos — NUNCA importar desde fuera
│   ├── recetas/              ← T-026: CRUD de recetas y variantes
│   ├── variantes/            ← T-027: variantes de producto
│   ├── ordenes/              ← T-028: ciclo de vida de O/Ps
│   ├── tarifas/              ← T-030: tarifas con vigencia temporal
│   └── costos/               ← T-029: motor de cálculo de costos
└── __tests__/
    └── produccion.module.spec.ts
```

---

## Regla de oro

> **Solo `public/` es visible para el resto del monolito.**  
> Ningún módulo externo puede importar desde `internal/`.  
> El test `test/architecture.spec.ts` falla el CI si se detecta esta violación.

```
✅  import { ProduccionFacade } from '../produccion/public';
❌  import { OrdenesService } from '../produccion/internal/ordenes/ordenes.service';
```

---

## Submódulos internos

| Directorio    | Responsabilidad                              | Ticket |
|---------------|----------------------------------------------|--------|
| `recetas/`    | CRUD de recetas y versiones de insumos       | T-026  |
| `variantes/`  | Variantes dinámicas de productos (JSONB)     | T-027  |
| `ordenes/`    | Ciclo de vida O/P (CREADA→CERRADA)           | T-028  |
| `costos/`     | Motor de cálculo: pure function, Decimal.js  | T-029  |
| `tarifas/`    | Tarifas con vigencia temporal (ADR-007)      | T-030  |

---

## Eventos publicados

| Nombre del evento               | Cuándo se emite              | Schema Zod          |
|---------------------------------|------------------------------|---------------------|
| `produccion.op.creada.v1`       | Al crear una O/P             | `OpCreadaSchema`    |
| `produccion.op.cerrada.v1`      | Al cerrar una O/P con costos | `OpCerradaSchema`   |
| `produccion.tarifa.cambiada.v1` | Al registrar nueva tarifa    | `TarifaCambiadaSchema` |

Transporte actual: `EventEmitter2` (interno al monolito).  
Cuando se extraiga como microservicio, el transporte cambia a RabbitMQ — mismo schema de payload.

---

## Invariantes críticas

1. Al cerrar una O/P, el breakdown de costos es **inmutable**.
2. Las tarifas **nunca se modifican** una vez que tienen `valid_to` fijado (ADR-007).
3. El motor de costos (`costos/`) es una **pure function** sin efectos secundarios.
4. El cálculo de costos debe coincidir con el Excel del cliente en ≥99% de los casos (ADR-008).
