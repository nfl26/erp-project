# Catálogo de eventos

> Contrato autoritativo de todos los eventos del sistema.
>
> **Estado actual (monolito modular):** los eventos viajan **internamente** vía `EventEmitter2` (NestJS nativo) entre módulos del mismo proceso. Los schemas y nombres documentados aquí son los mismos que se usarán cuando un módulo se extraiga como microservicio y los eventos viajen por **RabbitMQ**.
>
> Esta separación es deliberada: cuando llegue el momento de extraer un servicio (ver `docs/roadmap-microservicios.md`), solo cambia el transporte, no la lógica del publisher ni del consumer.

---

## Tabla de contenidos

- [Convenciones generales](#convenciones-generales)
- [Estructura estándar de un evento](#estructura-estándar-de-un-evento)
- [Reglas de versionado](#reglas-de-versionado)
- [Catálogo detallado por dominio](#catálogo-detallado-por-dominio)
  - [Dominio: bodega](#dominio-bodega)
  - [Dominio: ventas](#dominio-ventas)
  - [Dominio: producción](#dominio-producción)
  - [Dominio: auth](#dominio-auth)
- [Referencia rápida (todos los eventos)](#referencia-rápida-todos-los-eventos)
- [Mapa de consumers](#mapa-de-consumers)
- [Patrones para consumers](#patrones-para-consumers)
- [Operación de eventos](#operación-de-eventos)

---

## Convenciones generales

### Nombres

```
{dominio}.{entidad}.{accion}.v{version}
```

Ejemplos:
- `bodega.movimiento.registrado.v1`
- `ventas.cotizacion.aprobada.v1`
- `produccion.op.cerrada.v1`

**Reglas:**
- Todo en minúsculas, separado por puntos.
- `dominio` coincide con el nombre del servicio (`bodega`, `ventas`, `produccion`, `auth`).
- `entidad` es un sustantivo singular (`movimiento`, `cotizacion`, `op`).
- `accion` es un verbo en participio pasado (`creado`, `registrado`, `cerrado`).
- Versionado `v{N}` es obligatorio.

### Exchanges y routing

Un **exchange tipo topic** por dominio:

```
bodega.events
ventas.events
produccion.events
auth.events
```

La **routing key** del mensaje es el nombre completo del evento. Los consumers se bindean con patrones:

- Binding específico: `bodega.movimiento.registrado.v1`
- Binding por entidad: `bodega.movimiento.*`
- Binding por dominio: `bodega.#`

### Colas

Los consumers tienen colas durables con el patrón:

```
{consumidor}.consume.{productor}.{entidad}
```

Ejemplos:
- `produccion.consume.bodega.movimiento`
- `notificaciones.consume.produccion.op`

Ver [ADR-006](adrs/ADR-006-rabbitmq-para-mensajeria.md) para la decisión base.

---

## Estructura estándar de un evento

Todos los eventos siguen la misma estructura de sobre (**envelope**) + payload.

```json
{
  "envelope": {
    "eventId": "550e8400-e29b-41d4-a716-446655440000",
    "eventType": "bodega.movimiento.registrado.v1",
    "occurredAt": "2026-04-22T14:30:12.453Z",
    "producedBy": "bodega@2026.04.22-a1b2c3d",
    "tenantId": "acme",
    "correlationId": "req-9f8e7d6c5b4a",
    "causationId": "cmd-7a6b5c4d3e2f"
  },
  "payload": {
    ...
  }
}
```

### Campos del envelope

| Campo | Tipo | Obligatorio | Descripción |
|---|---|---|---|
| `eventId` | UUID | sí | Identificador único del evento. Los consumers lo usan para idempotencia. |
| `eventType` | string | sí | Nombre completo del evento, debe coincidir con la routing key. |
| `occurredAt` | ISO 8601 UTC | sí | Cuándo ocurrió el hecho de negocio (no cuándo se publicó). |
| `producedBy` | string | sí | Servicio + versión del build. Formato: `{servicio}@{build-tag}`. |
| `tenantId` | string | sí | Tenant al que pertenece el evento. Ver [ADR-003](adrs/ADR-003-multi-tenancy-por-schema.md). |
| `correlationId` | string | opcional | Para trazar el flujo completo de un request. Propagado de upstream. |
| `causationId` | string | opcional | ID del comando o evento que causó este. Útil para debugging. |

### Reglas del payload

- El payload contiene **solo los datos del hecho de negocio**.
- No duplicar datos del envelope en el payload.
- Usar `camelCase` para campos (alineado con JSON estándar).
- Fechas en ISO 8601 UTC.
- Montos en string decimal para evitar precisión flotante: `"1234.50"`, no `1234.5`.
- Nunca incluir datos sensibles (passwords, tokens, PII completa).

---

## Reglas de versionado

**Esta es la sección más importante del documento.** Cambiar un evento mal ha roto más sistemas que cualquier otro patrón en arquitecturas event-driven.

### Cambios compatibles (pueden hacerse sin nueva versión)

Se pueden hacer directamente sobre la versión existente:

- **Agregar campos opcionales** al payload. Los consumers viejos los ignoran.
- **Ampliar enums** agregando nuevos valores. Los consumers deben tolerar valores desconocidos (usar `default` o loggear y continuar).
- **Ampliar rangos permitidos** (ej: permitir strings más largas).
- **Corregir descripción o documentación** del schema.

### Cambios incompatibles (requieren nueva versión)

Cualquiera de estos cambios obliga a publicar `vN+1`:

- **Eliminar un campo** existente.
- **Renombrar un campo**.
- **Cambiar el tipo** de un campo (ej: `string` a `number`).
- **Cambiar semántica** de un campo existente.
- **Hacer obligatorio** un campo que era opcional.
- **Estrechar rangos** permitidos.
- **Remover valores** de un enum.

### Cómo publicar una versión nueva

Cuando se necesita `v2` de un evento existente:

1. **Ambas versiones coexisten.** El publisher publica `v1` Y `v2` durante un período.
2. **Los consumers migran uno por uno** a `v2`, sin apuro coordinado.
3. **Cuando todos los consumers migraron**, se deprecia `v1` con deadline.
4. **Pasado el deadline**, el publisher deja de publicar `v1`.

```
T+0 días:   Publisher empieza a publicar v1 y v2.
T+30 días:  Todos los consumers migraron a v2.
T+60 días:  v1 deprecada oficialmente, deadline de eliminación anunciado.
T+90 días:  v1 eliminada del publisher.
```

### Proceso formal

Publicar una nueva versión de un evento requiere:

1. **PR con el nuevo schema** en este documento.
2. **PR con la implementación** del publisher (publica ambas versiones).
3. **Tickets separados** para cada consumer, para migrar a la versión nueva.
4. **Aprobación** del Tech Lead y del supervisor del servicio publisher.
5. **Anuncio en `#erp-agents`** de Slack al liberar la versión nueva.

Ningún agente IA puede publicar una versión nueva sin pasar este proceso.

---

## Catálogo detallado por dominio

### Dominio: bodega

Todos los eventos de este dominio son publicados por el servicio `bodega`.

#### `bodega.movimiento.registrado.v1`

**El evento más importante del sistema.** Dispara actualización de precios de insumos en producción y evaluación de alertas de stock crítico en notificaciones.

**Cuándo se emite:** cuando se persiste un movimiento de bodega (entrada, salida, ajuste), dentro de la misma transacción que el INSERT.

**Productor:** `bodega`

**Consumers:**
- `produccion`: actualiza último precio conocido del insumo.
- `notificaciones`: evalúa si el stock cayó por debajo del mínimo y dispara alerta.

**Schema JSON:**

```json
{
  "$schema": "http://json-schema.org/draft-07/schema#",
  "title": "bodega.movimiento.registrado.v1",
  "type": "object",
  "required": ["envelope", "payload"],
  "properties": {
    "envelope": { "$ref": "#/definitions/Envelope" },
    "payload": {
      "type": "object",
      "required": [
        "movimientoId",
        "insumoId",
        "codigoInsumo",
        "tipo",
        "cantidad",
        "unidadMedida",
        "stockAnterior",
        "stockResultante",
        "motivo",
        "usuarioId"
      ],
      "properties": {
        "movimientoId": { "type": "string", "format": "uuid" },
        "insumoId": { "type": "string", "format": "uuid" },
        "codigoInsumo": { "type": "string" },
        "tipo": {
          "type": "string",
          "enum": ["ENTRADA", "SALIDA", "AJUSTE_POSITIVO", "AJUSTE_NEGATIVO"]
        },
        "cantidad": { "type": "string", "description": "Decimal positivo como string, escala 4" },
        "unidadMedida": {
          "type": "string",
          "enum": ["UNIDAD", "KG", "GR", "LITRO", "ML", "METRO", "M2", "M3"]
        },
        "precioUnitario": {
          "type": ["string", "null"],
          "description": "Decimal como string. Obligatorio para ENTRADA, null para ajustes."
        },
        "stockAnterior": { "type": "string" },
        "stockResultante": { "type": "string" },
        "motivo": { "type": "string", "minLength": 1 },
        "referenciaExterna": { "type": ["string", "null"] },
        "usuarioId": { "type": "string", "format": "uuid" }
      }
    }
  }
}
```

**Ejemplo completo:**

```json
{
  "envelope": {
    "eventId": "550e8400-e29b-41d4-a716-446655440000",
    "eventType": "bodega.movimiento.registrado.v1",
    "occurredAt": "2026-04-22T14:30:12.453Z",
    "producedBy": "bodega@2026.04.22-a1b2c3d",
    "tenantId": "acme",
    "correlationId": "req-9f8e7d6c5b4a"
  },
  "payload": {
    "movimientoId": "7c9e6679-7425-40de-944b-e07fc1f90ae7",
    "insumoId": "3f2504e0-4f89-11d3-9a0c-0305e82c3301",
    "codigoInsumo": "ACE-3MM-1200",
    "tipo": "ENTRADA",
    "cantidad": "100.0000",
    "unidadMedida": "M2",
    "precioUnitario": "8500.0000",
    "stockAnterior": "48.0000",
    "stockResultante": "148.0000",
    "motivo": "Compra OC #4521 a Acerolatam SPA",
    "referenciaExterna": "OC-4521",
    "usuarioId": "a1b2c3d4-e5f6-7890-abcd-ef0123456789"
  }
}
```

**Notas de implementación para consumers:**
- Usar `movimientoId` como clave de idempotencia.
- El evento incluye `stockAnterior` y `stockResultante` para que los consumers no tengan que consultar bodega.
- Para `ENTRADA`, `precioUnitario` es obligatorio y debe usarse para actualizar último precio conocido.

---

#### `bodega.stock_critico.alcanzado.v1`

**Cuándo se emite:** cuando un movimiento deja el stock de un insumo por debajo de su mínimo configurado (y no estaba ya por debajo antes del movimiento). Es decir, se emite **al cruzar el umbral**, no repetidamente mientras el stock siga bajo.

**Productor:** `bodega`

**Consumers:**
- `notificaciones`: envía alerta al rol `encargado-compras` y `admin-bodega`.

**Schema JSON:**

```json
{
  "payload": {
    "type": "object",
    "required": ["insumoId", "codigoInsumo", "nombre", "stockActual", "stockMinimo", "categoriaId"],
    "properties": {
      "insumoId": { "type": "string", "format": "uuid" },
      "codigoInsumo": { "type": "string" },
      "nombre": { "type": "string" },
      "stockActual": { "type": "string" },
      "stockMinimo": { "type": "string" },
      "unidadMedida": { "type": "string" },
      "categoriaId": { "type": "string", "format": "uuid" },
      "categoriaNombre": { "type": "string" },
      "movimientoIdCausante": {
        "type": "string",
        "format": "uuid",
        "description": "ID del movimiento que cruzó el umbral"
      }
    }
  }
}
```

**Ejemplo de payload:**

```json
{
  "insumoId": "3f2504e0-4f89-11d3-9a0c-0305e82c3301",
  "codigoInsumo": "ACE-3MM-1200",
  "nombre": "Lámina acero 3mm 1x2m",
  "stockActual": "18.0000",
  "stockMinimo": "20.0000",
  "unidadMedida": "UNIDAD",
  "categoriaId": "aa11bb22-cc33-dd44-ee55-ff6677889900",
  "categoriaNombre": "Materias primas metálicas",
  "movimientoIdCausante": "7c9e6679-7425-40de-944b-e07fc1f90ae7"
}
```

---

### Dominio: ventas

Todos los eventos de este dominio son publicados por el servicio `ventas`.

#### `ventas.cotizacion.aprobada.v1`

**Cuándo se emite:** cuando el cliente aprueba una cotización (sea por acción directa del cliente en el portal, o cuando el vendedor marca la cotización como aprobada tras confirmación externa).

**Productor:** `ventas`

**Consumers:**
- `notificaciones`: notifica al vendedor responsable.
- `analytics` (futuro): métricas de conversión.

**Schema JSON:**

```json
{
  "payload": {
    "type": "object",
    "required": ["cotizacionId", "codigo", "clienteId", "montoTotal", "aprobadaPor"],
    "properties": {
      "cotizacionId": { "type": "string", "format": "uuid" },
      "codigo": { "type": "string", "description": "ej: COT-2026-0912" },
      "clienteId": { "type": "string", "format": "uuid" },
      "clienteNombre": { "type": "string" },
      "montoTotal": { "type": "string" },
      "moneda": { "type": "string", "enum": ["CLP", "USD"], "default": "CLP" },
      "vendedorId": { "type": "string", "format": "uuid" },
      "aprobadaPor": {
        "type": "string",
        "enum": ["CLIENTE_PORTAL", "VENDEDOR_MARCO", "SISTEMA_AUTO"]
      },
      "fechaAprobacion": { "type": "string", "format": "date-time" }
    }
  }
}
```

---

#### `venta.confirmada.v1`

**Evento crítico del flujo ventas→producción.** Cuando se emite, el servicio de producción genera automáticamente la O/P correspondiente si aplica.

**Cuándo se emite:** cuando una cotización aprobada se convierte en Orden de Venta confirmada (el vendedor la confirma, no el cliente).

**Productor:** `ventas`

**Consumers:**
- `produccion`: crea O/P automática si hay productos que requieren fabricación.
- `notificaciones`: notifica al jefe de producción.
- `analytics` (futuro).

**Schema JSON:**

```json
{
  "payload": {
    "type": "object",
    "required": ["ordenVentaId", "codigo", "clienteId", "lineas", "montoTotal"],
    "properties": {
      "ordenVentaId": { "type": "string", "format": "uuid" },
      "codigo": { "type": "string", "description": "ej: OV-2026-0512" },
      "cotizacionId": {
        "type": ["string", "null"],
        "format": "uuid",
        "description": "Null si la OV se creó sin cotización previa"
      },
      "clienteId": { "type": "string", "format": "uuid" },
      "lineas": {
        "type": "array",
        "minItems": 1,
        "items": {
          "type": "object",
          "required": ["productoId", "varianteId", "cantidad", "requiereProduccion"],
          "properties": {
            "productoId": { "type": "string", "format": "uuid" },
            "varianteId": { "type": "string", "format": "uuid" },
            "cantidad": { "type": "integer", "minimum": 1 },
            "precioUnitario": { "type": "string" },
            "requiereProduccion": { "type": "boolean" }
          }
        }
      },
      "montoTotal": { "type": "string" },
      "moneda": { "type": "string", "default": "CLP" },
      "fechaConfirmacion": { "type": "string", "format": "date-time" },
      "fechaEntregaEsperada": { "type": "string", "format": "date" }
    }
  }
}
```

**Notas para consumers:**
- `produccion` solo crea O/P para líneas con `requiereProduccion = true`.
- Usar `ordenVentaId` como clave de idempotencia.

---

### Dominio: producción

Todos los eventos de este dominio son publicados por el servicio `produccion`.

#### `produccion.op.cerrada.v1`

**El evento más crítico monetariamente del sistema.** Contiene el breakdown completo de costos calculados. Los clientes finales se facturan en base a esta información.

**Cuándo se emite:** cuando una O/P cambia de estado `FINALIZADA` a `CERRADA`, después de ejecutar el motor de cálculo de costos y persistir el breakdown.

**Productor:** `produccion`

**Consumers:**
- `ventas`: actualiza estado de O/V a `LISTA`.
- `notificaciones`: notifica al vendedor y al cliente.
- `analytics` (futuro).

**Schema JSON:**

```json
{
  "payload": {
    "type": "object",
    "required": [
      "ordenId",
      "codigo",
      "productoId",
      "cantidad",
      "breakdown",
      "fechaCierre"
    ],
    "properties": {
      "ordenId": { "type": "string", "format": "uuid" },
      "codigo": { "type": "string", "description": "ej: OP-2026-0481" },
      "ordenVentaId": {
        "type": ["string", "null"],
        "format": "uuid"
      },
      "productoId": { "type": "string", "format": "uuid" },
      "varianteId": { "type": "string", "format": "uuid" },
      "recetaVersion": { "type": "integer", "minimum": 1 },
      "cantidad": { "type": "integer", "minimum": 1 },
      "breakdown": {
        "type": "object",
        "required": ["costoInsumos", "costoMaquina", "costoHorasHombre", "costoTotal"],
        "properties": {
          "costoInsumos": { "type": "string" },
          "costoMaquina": { "type": "string" },
          "costoHorasHombre": { "type": "string" },
          "costoTotal": { "type": "string" },
          "detalleInsumos": {
            "type": "array",
            "items": {
              "type": "object",
              "required": ["insumoId", "cantidad", "precioUnitario", "subtotal"],
              "properties": {
                "insumoId": { "type": "string", "format": "uuid" },
                "cantidad": { "type": "string" },
                "precioUnitario": { "type": "string" },
                "subtotal": { "type": "string" }
              }
            }
          }
        }
      },
      "fechaCierre": { "type": "string", "format": "date-time" },
      "cerradaPor": { "type": "string", "format": "uuid" }
    }
  }
}
```

**Ejemplo de payload:**

```json
{
  "ordenId": "b1c2d3e4-f5a6-4789-9abc-def012345678",
  "codigo": "OP-2026-0481",
  "ordenVentaId": "c2d3e4f5-a6b7-4890-9bcd-ef0123456789",
  "productoId": "d3e4f5a6-b7c8-4901-9cde-f01234567890",
  "varianteId": "e4f5a6b7-c8d9-4012-9def-012345678901",
  "recetaVersion": 3,
  "cantidad": 50,
  "breakdown": {
    "costoInsumos": "3120000.00",
    "costoMaquina": "890000.00",
    "costoHorasHombre": "417500.00",
    "costoTotal": "4427500.00",
    "detalleInsumos": [
      {
        "insumoId": "3f2504e0-4f89-11d3-9a0c-0305e82c3301",
        "cantidad": "120.0000",
        "precioUnitario": "8500.0000",
        "subtotal": "1020000.00"
      }
    ]
  },
  "fechaCierre": "2026-04-22T16:45:00Z",
  "cerradaPor": "a1b2c3d4-e5f6-7890-abcd-ef0123456789"
}
```

**Notas críticas:**
- El breakdown es inmutable. Si hay que corregir, se emite un evento nuevo `produccion.op.recalculada.v2` (pendiente de diseño).
- El total calculado DEBE coincidir con el Excel del cliente. Ver [ADR-008](adrs/ADR-008-excel-validation-como-guardrail.md).

---

#### `produccion.tarifa.cambiada.v1`

**Cuándo se emite:** cuando se registra una tarifa nueva (creando una nueva y cerrando la anterior con `valid_to`). Ver [ADR-007](adrs/ADR-007-tarifas-temporales.md).

**Productor:** `produccion`

**Consumers:**
- `notificaciones`: notifica a gerencia sobre cambio de tarifa.
- `analytics` (futuro): tracking de evolución de tarifas.

**Schema JSON:**

```json
{
  "payload": {
    "type": "object",
    "required": [
      "tarifaAnteriorId",
      "tarifaNuevaId",
      "entidadTipo",
      "entidadId",
      "valorAnterior",
      "valorNuevo",
      "validFrom",
      "motivo",
      "cambiadaPor"
    ],
    "properties": {
      "tarifaAnteriorId": { "type": ["string", "null"], "format": "uuid" },
      "tarifaNuevaId": { "type": "string", "format": "uuid" },
      "entidadTipo": { "type": "string", "enum": ["MAQUINA", "TIPO_TRABAJADOR"] },
      "entidadId": { "type": "string" },
      "valorAnterior": { "type": ["string", "null"] },
      "valorNuevo": { "type": "string" },
      "validFrom": { "type": "string", "format": "date-time" },
      "motivo": { "type": "string", "minLength": 1 },
      "cambiadaPor": { "type": "string", "format": "uuid" }
    }
  }
}
```

---

### Dominio: auth

Todos los eventos de este dominio son publicados por el servicio `core`.

#### `auth.login.v1`

**Cuándo se emite:** cada login exitoso.

**Productor:** `core`

**Consumers:**
- Auditoría global (en schema `public`).

**Schema JSON (payload):**

```json
{
  "type": "object",
  "required": ["usuarioId", "email", "rol", "ip", "userAgent"],
  "properties": {
    "usuarioId": { "type": "string", "format": "uuid" },
    "email": { "type": "string", "format": "email" },
    "rol": { "type": "string" },
    "ip": { "type": "string" },
    "userAgent": { "type": "string" }
  }
}
```

---

## Referencia rápida (todos los eventos)

Tabla resumen de todos los eventos del MVP. Los eventos marcados con ⚡ están detallados arriba.

| Evento | Productor | Consumers | Criticidad |
|---|---|---|---|
| ⚡ `bodega.movimiento.registrado.v1` | bodega | produccion, notificaciones | crítica |
| ⚡ `bodega.stock_critico.alcanzado.v1` | bodega | notificaciones | alta |
| `bodega.insumo.creado.v1` | bodega | — (disponible para futuros) | baja |
| `bodega.insumo.modificado.v1` | bodega | — | baja |
| `bodega.insumo.eliminado.v1` | bodega | — | baja |
| `bodega.categoria.creada.v1` | bodega | — | baja |
| `bodega.categoria.modificada.v1` | bodega | — | baja |
| `bodega.categoria.eliminada.v1` | bodega | — | baja |
| `ventas.cotizacion.creada.v1` | ventas | notificaciones | media |
| ⚡ `ventas.cotizacion.aprobada.v1` | ventas | notificaciones | alta |
| `ventas.cotizacion.rechazada.v1` | ventas | notificaciones | media |
| `ventas.cotizacion.vencida.v1` | ventas | notificaciones | media |
| ⚡ `venta.confirmada.v1` | ventas | produccion, notificaciones | crítica |
| `venta.cancelada.v1` | ventas | produccion, notificaciones | alta |
| `produccion.op.creada.v1` | produccion | notificaciones | media |
| `produccion.op.iniciada.v1` | produccion | notificaciones | media |
| ⚡ `produccion.op.cerrada.v1` | produccion | ventas, notificaciones | crítica |
| `produccion.op.cancelada.v1` | produccion | ventas, notificaciones | alta |
| ⚡ `produccion.tarifa.cambiada.v1` | produccion | notificaciones | alta |
| ⚡ `auth.login.v1` | core | auditoria | baja |
| `auth.logout.v1` | core | auditoria | baja |

---

## Mapa de consumers

Visto desde el otro ángulo: qué eventos consume cada servicio.

### produccion consume

- `bodega.movimiento.registrado.v1` — para actualizar último precio de insumo.
- `venta.confirmada.v1` — para crear O/P automática.
- `venta.cancelada.v1` — para cancelar O/P asociada.

### ventas consume

- `produccion.op.cerrada.v1` — para actualizar estado de O/V a LISTA.
- `produccion.op.cancelada.v1` — para revisar estado de O/V.

### notificaciones consume

**Casi todos los eventos.** Es el consumidor más promiscuo del sistema. Usa bindings con wildcards:

- `bodega.#`
- `ventas.#`
- `produccion.#`
- `auth.#`

Filtra internamente qué notificación enviar y a quién.

---

## Patrones para consumers

Todos los consumers deben implementar estos patrones sin excepción. Los agentes IA que generen consumers los respetan.

### Idempotencia

```typescript
// ✅ Correcto: verificar eventId antes de procesar
async consume(event: Event) {
  if (await this.eventRepository.existsByEventId(event.envelope.eventId)) {
    this.logger.info(`Event ${event.envelope.eventId} already processed, skipping`);
    return; // ACK implícito, no reprocesar
  }

  await this.process(event);
  await this.eventRepository.markProcessed(event.envelope.eventId);
}

// ❌ Incorrecto: procesar sin verificar
async consume(event: Event) {
  await this.process(event); // puede ejecutarse 2+ veces
}
```

### Validación de schema

```typescript
// ✅ Correcto
async consume(event: unknown) {
  const validated = this.schemaValidator.validate(event, 'bodega.movimiento.registrado.v1');
  if (!validated.ok) {
    this.logger.error('Invalid event schema', validated.errors);
    // NACK sin requeue → va a DLQ
    throw new InvalidEventException();
  }
  await this.process(validated.data);
}
```

### ACK manual

```typescript
// ✅ Correcto: ACK después de procesar
async handle(event: Event, ctx: RmqContext) {
  try {
    await this.process(event);
    ctx.ack(); // después del éxito
  } catch (error) {
    if (this.isRetryable(error)) {
      ctx.nack(true); // requeue
    } else {
      ctx.nack(false); // a DLQ
    }
  }
}
```

### Backoff exponencial para retries

RabbitMQ se configura con:
- Primer retry: 10 segundos
- Segundo retry: 1 minuto
- Tercer retry: 10 minutos
- Cuarto intento → DLQ

Configuración en el Helm chart del servicio.

---

## Operación de eventos

### Observabilidad

Métricas clave expuestas por cada servicio:

- `event_published_total{event_type}` — contador de eventos publicados.
- `event_consumed_total{event_type,status}` — procesados/fallidos.
- `event_processing_duration_seconds` — histograma de latencia.
- `event_dlq_messages{queue}` — mensajes en DLQ (alerta si > 0 sostenido).

Dashboards en Grafana: `erp-events` (transversal) + uno por servicio.

### Dead letter queues

Cada cola tiene su DLQ asociada:

```
produccion.consume.bodega.movimiento      → dlq.produccion.consume.bodega.movimiento
notificaciones.consume.produccion.op      → dlq.notificaciones.consume.produccion.op
```

Los mensajes en DLQ **se revisan manualmente**. No hay reproceso automático — si un evento falló 3 veces, probablemente hay un bug que arreglar antes de reprocesar.

### Alertas

Disparan notificación a `#erp-alerts`:

- Profundidad de cualquier cola > 1000 por más de 5 minutos.
- Cualquier mensaje en DLQ.
- Latencia p95 de consumption > 5 segundos sostenido.
- Tasa de error de consumption > 1% en 5 minutos.

### Replay histórico

**No soportado por RabbitMQ directamente.** Ver [ADR-006](adrs/ADR-006-rabbitmq-para-mensajeria.md).

Si se necesita reprocesar eventos históricos, los servicios pueden publicarlos nuevamente consultando su BD. Protocolo:

1. Ticket específico aprobado por Tech Lead.
2. Script del servicio productor lee su tabla de eventos persistidos.
3. Republica con `eventId` **nuevo** (para no violar idempotencia) pero con `correlationId = original_event_id` para trazabilidad.
4. Los consumers procesan normalmente.

---

## Modificación de este documento

Cambios en este documento requieren:

1. **PR con el schema actualizado.**
2. **Aprobación del Tech Lead** + supervisor del servicio productor.
3. **Si agrega un consumer nuevo:** aprobación también del supervisor del servicio consumidor.
4. **Si publica versión nueva de un evento:** seguir el proceso de versionado descrito arriba.

Los agentes IA no pueden modificar este documento directamente. Pueden proponer cambios en PR para que un humano los apruebe.

---

## Referencias

- [ADR-001](adrs/ADR-001-microservicios-por-dominio.md) — microservicios que dependen de eventos.
- [ADR-006](adrs/ADR-006-rabbitmq-para-mensajeria.md) — decisión de RabbitMQ.
- [architecture.md](architecture.md) — vistas de runtime con flujos de eventos.
- JSON Schema spec: https://json-schema.org/draft-07/schema
- [Contratos de agentes](../agents/README.md) — cada contrato incluye qué eventos puede publicar y consumir.

---

**Versión:** 1.0
**Mantenedor:** Tech Lead
**Última actualización:** abril 2026
**Frecuencia de revisión:** cada sprint planning
