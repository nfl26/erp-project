# internal/costos

Submódulo del motor de cálculo de costos de producción.

**Ticket que lo implementa:** T-029 (motor) + T-034 (validación fixture Excel)
**Responsable:** A1, supervisado por S1 + S2 (S2 revisa toda regla de cálculo)

## Qué va aquí

- `costo-calculator.service.ts` — pure function sin efectos secundarios
  - `calcular(op, tarifas, precios, fechaCierre): CostoBreakdown`
  - Usa Decimal.js, NUNCA number nativo para operaciones monetarias

## Invariantes críticas (contrato A1)

1. `CostoCalculator.calcular()` es pure function: no escribe a BD.
2. Decimal.js con ROUND_HALF_UP: 4 decimales para tarifas, 2 para totales.
3. El resultado debe coincidir con el Excel del cliente en ≥99% de los casos.
   Fixture de 50+ casos reales: `tests/fixtures/excel-costos.json` (T-034).
4. CI bloquea el merge si menos de 49/50 casos pasan (ADR-008).
