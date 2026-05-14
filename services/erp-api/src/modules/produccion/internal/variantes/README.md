# internal/variantes

Submódulo de variantes de producto.

**Ticket que lo implementa:** T-027
**Responsable:** A1, supervisado por S1 + S2

## Qué va aquí

- `variantes.service.ts` — gestión de variantes y sus atributos JSONB
- Validación de atributos contra JSON Schema definido por categoría de producto

## Invariante clave

Los atributos de variante se almacenan en una columna JSONB y se validan contra
el JSON Schema de la categoría del producto (ver ADR-004).
