# internal/ordenes

Submódulo de Órdenes de Producción (O/P).

**Ticket que lo implementa:** T-028
**Responsable:** A1, supervisado por S1 + S2

## Qué va aquí

- `ordenes.service.ts` — ciclo de vida de la O/P (CREADA → INICIADA → FINALIZADA → CERRADA)
- Escucha el evento `venta.confirmada.v1` para crear O/Ps automáticamente
- Emite `produccion.op.creada.v1` y `produccion.op.cerrada.v1`

## Invariante clave

Al cerrar una O/P se invoca el motor de costos (`costos/`) y se persiste el
breakdown. Una vez cerrada, el breakdown es inmutable.
