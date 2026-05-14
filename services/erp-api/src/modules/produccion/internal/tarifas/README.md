# internal/tarifas

Submódulo de tarifas de producción (costo por minuto de máquina y de trabajador).

**Ticket que lo implementa:** T-030
**Responsable:** A1, supervisado por S1 + S2

## Qué va aquí

- `tarifas.service.ts` — gestión de tarifas con vigencia temporal
- Emite `produccion.tarifa.cambiada.v1` al registrar una nueva tarifa

## Invariante clave (ADR-007)

Las tarifas tienen `valid_from` y `valid_to`. Al registrar una nueva tarifa,
se cierra la anterior con `valid_to = now`. NUNCA se modifica una tarifa
con `valid_to` ya fijado. Esto preserva los cálculos históricos de O/Ps cerradas.
