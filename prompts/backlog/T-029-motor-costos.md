# T-029 · Motor de cálculo de costos de producción

**Ticket Jira:** https://tu-org.atlassian.net/browse/T-029
**Agente asignado:** A1 (Arquitecto NestJS)
**Supervisor humano:** S2 (con coordinación de S1)
**Sprint:** Sprint 2 — Producción
**Estimación:** 8 puntos
**Prioridad:** crítica
**Rama:** `feat/T-029-motor-costos`

---

## Contexto de negocio

El motor de cálculo de costos es **el componente más crítico monetariamente del sistema**. Cada Orden de Producción (O/P) que se cierra ejecuta este cálculo y el resultado es lo que el cliente factura. Un error de $1 por O/P puede acumular miles de pérdida al mes.

Hoy el cliente calcula costos manualmente en Excel. Tenemos 50+ casos reales del Excel original como fixture. **El motor debe coincidir con esos casos en al menos 49 de 50** con tolerancia de $0.01.

Esta es una invariante reforzada por CI: si el fixture falla, el merge se bloquea automáticamente. Ver [ADR-008](../../docs/adrs/ADR-008-excel-validation-como-guardrail.md).

---

## Alcance técnico

### Crear

```
services/erp-api/src/modules/produccion/
├── services/
│   ├── costo-calculator.service.ts        ← motor principal (PURE FUNCTION)
│   ├── tarifa-resolver.service.ts         ← resuelve tarifa vigente al cierre
│   └── precio-insumo-resolver.service.ts  ← resuelve precio de insumo al cierre
├── dto/
│   ├── costo-breakdown.dto.ts             ← respuesta del motor
│   └── input-calculo.dto.ts               ← input al motor
├── domain/
│   ├── orden-cierre.types.ts              ← tipos de dominio
│   └── tarifa-vigente.types.ts
└── __tests__/
    ├── costo-calculator.spec.ts           ← 50+ casos del fixture Excel
    ├── tarifa-resolver.spec.ts
    └── precio-insumo-resolver.spec.ts
```

### Modificar

- `prisma/schema.prisma` — verificar que el modelo de tarifas tenga `valid_from` y `valid_to`.
- `services/erp-api/package.json` — agregar `decimal.js` a dependencias.

### No tocar

- Otros módulos (bodega, ventas) — el motor solo recibe datos por parámetros.
- El módulo `produccion/services/ordenes.service.ts` (existente) — solo invocará al motor.

---

## Especificación funcional

El motor recibe los datos de una O/P al momento de cierre y retorna un breakdown completo de costos.

### Input

```typescript
interface InputCalculoCosto {
  ordenProduccionId: string;
  fechaCierre: Date;
  cantidadProducida: number;
  receta: {
    versionId: string;
    insumos: Array<{
      insumoId: string;
      cantidadPorUnidad: Decimal;  // unidades del insumo por unidad producida
    }>;
  };
  tiempos: {
    minutosMaquina: Decimal;       // minutos totales de máquina
    minutosHorasHombre: Decimal;   // minutos totales h/h (puede ser mixto)
    maquinaId?: string;
    tipoTrabajadorId?: string;
  };
  preciosInsumos: Map<string, PrecioInsumoVigente>;
  tarifas: {
    maquina?: TarifaVigente;
    horasHombre?: TarifaVigente;
  };
}
```

### Output

```typescript
interface CostoBreakdown {
  costoInsumos: Decimal;          // 2 decimales
  costoMaquina: Decimal;          // 2 decimales
  costoHorasHombre: Decimal;      // 2 decimales
  costoTotal: Decimal;            // 2 decimales
  detalleInsumos: Array<{
    insumoId: string;
    cantidad: Decimal;            // 4 decimales
    precioUnitario: Decimal;      // 4 decimales
    subtotal: Decimal;            // 2 decimales
  }>;
  metadata: {
    fechaCalculo: Date;
    fechaCierre: Date;
    tarifaMaquinaUsada?: { id: string; valor: Decimal; validFrom: Date };
    tarifaHorasHombreUsada?: { id: string; valor: Decimal; validFrom: Date };
  };
}
```

### Fórmula

```
costoInsumos = SUMA por insumo de (cantidadProducida × cantidadPorUnidad × precioUnitario)
costoMaquina = minutosMaquina × tarifa.maquina.valorPorMinuto
costoHorasHombre = minutosHorasHombre × tarifa.horasHombre.valorPorMinuto
costoTotal = costoInsumos + costoMaquina + costoHorasHombre
```

Todas las operaciones con `Decimal.js` en `ROUND_HALF_UP`.

---

## Criterios de aceptación

### Pure function

- [ ] `CostoCalculator.calcular(input: InputCalculoCosto): CostoBreakdown` es **pure function**:
  - No accede a BD.
  - No accede a servicios externos.
  - Sin efectos secundarios (logging incluido).
  - Mismo input → mismo output, siempre.
- [ ] La función no tiene `await` — es síncrona.

### Precisión decimal

- [ ] Usa `Decimal.js` (NO `number`, NO `parseFloat`).
- [ ] Tarifas y precios unitarios: 4 decimales internos.
- [ ] Subtotales y totales: 2 decimales finales.
- [ ] Modo de redondeo: `Decimal.ROUND_HALF_UP` siempre.

### Resolución temporal de tarifas

- [ ] Antes del cálculo, `TarifaResolver` busca la tarifa vigente al `fechaCierre`:
  - `valid_from <= fechaCierre`
  - `valid_to IS NULL OR valid_to > fechaCierre`
- [ ] Si no hay tarifa vigente al cierre: lanzar error explícito (no usar tarifa actual).
- [ ] Si hay múltiples tarifas vigentes en ese rango: lanzar error (no debería ocurrir, valida invariante).

### Validación contra fixture Excel

- [ ] Existe `tests/fixtures/excel-costos.json` con al menos 50 casos reales (ya entregado por PO).
- [ ] Test `costo-calculator.spec.ts` itera sobre todos los casos del fixture.
- [ ] El test pasa si **al menos 49 de 50 casos** coinciden con el resultado esperado del Excel con tolerancia de $0.01 en el `costoTotal`.
- [ ] Si fallan 2 o más casos, el test falla y el merge se bloquea.
- [ ] Cobertura de unit tests del archivo `costo-calculator.service.ts` ≥95%.

### Eventos

- [ ] Cuando una O/P se cierra y el motor calcula el costo, el módulo `ordenes.service.ts` emite `produccion.op.cerrada` con el breakdown completo.
- [ ] El evento usa `EventEmitter2` (interno al monolito) con el mismo schema documentado en `docs/events.md`.
- [ ] El payload incluye el breakdown sin transformaciones.

### RBAC

- [ ] Solo roles `jefe-produccion` y `admin-sistema` pueden invocar el endpoint que cierra una O/P (que es lo que dispara el motor).
- [ ] Ver `docs/rbac-matrix.md` permiso `produccion:op:cerrar`.

---

## Invariantes que el agente DEBE respetar

**⚠️ Críticas (verificadas por CI):**

1. **NUNCA usar `number` o `parseFloat`** para cálculos monetarios. Solo `Decimal.js`.
2. **NUNCA modificar tarifas históricas** (las que tienen `valid_to` no nulo).
3. **NUNCA usar tarifa "actual" en lugar de "vigente al cierre".** El test del fixture Excel falla si esto ocurre.
4. **El cálculo es determinístico:** misma O/P + mismo timestamp = mismo costo, siempre.
5. **El motor es pure function:** sin acceso a BD ni efectos secundarios.

---

## Casos de prueba obligatorios

### Caso 1 — Cálculo simple sin h/h

```
Input:
  cantidad: 100 unidades
  receta: 1 insumo (precio $50/unidad, 0.5u por producto)
  tiempo máquina: 60 minutos
  tarifa máquina: $200/min vigente al cierre

Output esperado:
  costoInsumos: 100 × 0.5 × $50 = $2,500.00
  costoMaquina: 60 × $200 = $12,000.00
  costoHorasHombre: $0.00
  costoTotal: $14,500.00
```

### Caso 2 — Cálculo con cobro mixto (máquina + h/h)

```
Input:
  cantidad: 50 unidades
  receta: 2 insumos
  tiempo máquina: 30 minutos a $300/min
  tiempo h/h: 45 minutos a $80/min

Output esperado:
  costoMaquina: 30 × $300 = $9,000.00
  costoHorasHombre: 45 × $80 = $3,600.00
```

### Caso 3 — Cambio de tarifa entre creación y cierre

```
Setup:
  Tarifa máquina vigente 2026-01-01: $200/min (valid_to: 2026-03-15)
  Tarifa máquina vigente 2026-03-15: $250/min (valid_to: null)

Input:
  fechaCierre: 2026-02-20

Esperado:
  Usa tarifa de $200/min (la vigente al 2026-02-20)
  NO usa $250 (que sería la "actual" al momento del cálculo)
```

### Caso 4 — Sin tarifa vigente al cierre

```
Setup:
  Solo existe tarifa con valid_from: 2026-04-01

Input:
  fechaCierre: 2026-03-15

Esperado:
  Lanzar TarifaNoVigenteException con mensaje claro
```

### Caso 5 — Fixture Excel completo

```
Iterar sobre tests/fixtures/excel-costos.json
Para cada caso:
  - Construir input desde el fixture
  - Ejecutar CostoCalculator.calcular(input)
  - Comparar costoTotal con expected.costoTotal
  - Tolerancia: $0.01
Pasar si: ≥49 de 50 casos coinciden
```

---

## Estructura del código (referencia)

```typescript
// costo-calculator.service.ts
import { Injectable } from '@nestjs/common';
import Decimal from 'decimal.js';

Decimal.set({ precision: 20, rounding: Decimal.ROUND_HALF_UP });

@Injectable()
export class CostoCalculatorService {
  /**
   * Pure function. No accede a BD ni servicios externos.
   * Calcula el breakdown de costo para una O/P al momento de cierre.
   */
  calcular(input: InputCalculoCosto): CostoBreakdown {
    const costoInsumos = this.calcularCostoInsumos(input);
    const costoMaquina = this.calcularCostoMaquina(input);
    const costoHorasHombre = this.calcularCostoHorasHombre(input);

    const costoTotal = costoInsumos
      .plus(costoMaquina)
      .plus(costoHorasHombre)
      .toDecimalPlaces(2, Decimal.ROUND_HALF_UP);

    return {
      costoInsumos: costoInsumos.toDecimalPlaces(2, Decimal.ROUND_HALF_UP),
      costoMaquina: costoMaquina.toDecimalPlaces(2, Decimal.ROUND_HALF_UP),
      costoHorasHombre: costoHorasHombre.toDecimalPlaces(2, Decimal.ROUND_HALF_UP),
      costoTotal,
      detalleInsumos: this.armarDetalleInsumos(input),
      metadata: {
        fechaCalculo: new Date(),
        fechaCierre: input.fechaCierre,
        tarifaMaquinaUsada: input.tarifas.maquina,
        tarifaHorasHombreUsada: input.tarifas.horasHombre,
      },
    };
  }

  private calcularCostoInsumos(input: InputCalculoCosto): Decimal {
    return input.receta.insumos.reduce((acc, item) => {
      const precio = input.preciosInsumos.get(item.insumoId);
      if (!precio) {
        throw new Error(`Sin precio vigente para insumo ${item.insumoId}`);
      }
      const subtotal = new Decimal(input.cantidadProducida)
        .mul(item.cantidadPorUnidad)
        .mul(precio.valor);
      return acc.plus(subtotal);
    }, new Decimal(0));
  }

  // ... resto de métodos privados
}
```

---

## Validación post-ejecución

```bash
# 1. Tests unitarios del módulo
cd services/erp-api
npm test -- --testPathPattern=produccion

# 2. Test del fixture Excel específicamente
npm test -- --testPathPattern=costo-calculator

# 3. Cobertura
npm test -- --coverage --testPathPattern=produccion
# costo-calculator.service.ts debe estar ≥95%

# 4. Lint y build
npm run lint
npm run build

# 5. Pre-PR check
cd ../..
./scripts/pre-pr-check.sh
```

El PR debe llevar el label `needs:excel-validation`. El CI ejecuta el fixture Excel y bloquea el merge si fallan más de 1 de 50 casos.

---

## Contratos y referencias

- **Contrato del agente:** [agents/A1-nestjs.md](../../agents/A1-nestjs.md) (sección "Módulo producción")
- **ADRs relevantes:**
  - [ADR-007 Tarifas temporales](../../docs/adrs/ADR-007-tarifas-temporales.md)
  - [ADR-008 Validación Excel](../../docs/adrs/ADR-008-excel-validation-como-guardrail.md)
  - [ADR-010 Monolito modular](../../docs/adrs/ADR-010-monolito-modular.md)
- **Documentos:**
  - [docs/events.md](../../docs/events.md) — schema del evento `produccion.op.cerrada`
  - [docs/glossary.md](../../docs/glossary.md) — términos: O/P, h/h, costo mixto, tarifa
  - [docs/prisma-workflow.md](../../docs/prisma-workflow.md) — si se modifica el schema

---

## Validación post-ejecución (lo llena el supervisor)

- **Fecha:** _pendiente_
- **Iteraciones:** _pendiente_
- **Casos del fixture que pasan:** _pendiente (objetivo ≥49/50)_
- **Cobertura del motor:** _pendiente (objetivo ≥95%)_
- **Resultado:** _pendiente_

---

**Creado:** 2026-04-22 por S2 + TL
**Actualizado:** 2026-04-27 (migración de Spring Boot a NestJS Decimal.js — ADR-010)
**Plantilla base:** `prompts/templates/ticket-template.md` v1.0
