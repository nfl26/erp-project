# Glosario de negocio

> **Lectura obligatoria antes de tocar código del ERP.**
>
> Este glosario traduce el idioma del cliente al idioma del sistema. Cada término incluye sinónimos, ejemplos concretos con números reales y referencias al código. Es la fuente única de verdad cuando hay ambigüedad.
>
> **Reglas de uso para agentes IA:**
> - Si encuentras un término en un ticket y no está aquí, **pausa y pregunta al Product Owner**. No inventes.
> - Si encuentras un término aquí pero el ticket lo usa distinto, **reporta la inconsistencia** en el PR.
> - No dupliques lógica de negocio que esté en ADRs — solo referencia el ADR.
>
> **Organización:** por dominio de negocio (no alfabético). Dentro de cada dominio, orden alfabético.

---

## Tabla de contenidos

- [Dominio: Bodega e insumos](#dominio-bodega-e-insumos)
- [Dominio: Producción y recetas](#dominio-producción-y-recetas)
- [Dominio: Costos y tarifas](#dominio-costos-y-tarifas)
- [Dominio: Ventas y clientes](#dominio-ventas-y-clientes)
- [Dominio: Recursos humanos y leasing](#dominio-recursos-humanos-y-leasing)
- [Dominio: Usuarios y roles](#dominio-usuarios-y-roles)
- [Estados y transiciones](#estados-y-transiciones)
- [Abreviaturas frecuentes](#abreviaturas-frecuentes)
- [Términos con ambigüedad resuelta](#términos-con-ambigüedad-resuelta)

---

## Dominio: Bodega e insumos

### Categoría de insumo

**Sinónimos del cliente:** "tipo de material", "familia", "rubro de insumo".

**Definición:** agrupación lógica de insumos con reglas comunes (mínimos de stock, proveedores habituales, responsable de compra). No confundir con "categoría de producto" (que no existe explícitamente en el sistema).

**Ejemplo concreto:** la empresa tiene 47 categorías activas hoy: "Materias primas metálicas", "Insumos químicos", "Embalajes", "Repuestos de máquina", etc.

**Código:** entidad `Categoria` en `services/erp-api/src/modules/bodega/prisma/schema.prisma`.

**Reglas clave:**
- Nombre único case-insensitive por tenant.
- No se puede eliminar si tiene insumos asociados activos.
- Soft-delete siempre (nunca `DELETE FROM`).

### Insumo

**Sinónimos del cliente:** "material", "ítem", "artículo de bodega".

**Definición:** cualquier elemento físico consumible que ingresa a bodega y puede ser utilizado en producción o vendido. No incluye productos terminados.

**Ejemplo concreto:** "Lámina acero 3mm 1x2m" (código `ACE-3MM-1200`), stock actual 48 unidades, mínimo 20, categoría "Materias primas metálicas".

**Código:** entidad `Insumo` en `services/erp-api/src/modules/bodega/`.

**Atributos obligatorios:**
- `codigo_interno` (único)
- `nombre`
- `unidad_medida` (ver siguiente término)
- `categoria_id`
- `stock_actual` (calculado a partir de movimientos, nunca editable directo)
- `stock_minimo`

**Relacionado con:** [Movimiento de bodega](#movimiento-de-bodega), [Receta](#receta).

### Movimiento de bodega

**Sinónimos del cliente:** "entrada", "salida", "ajuste de inventario".

**Definición:** registro transaccional de cambio de stock de un insumo. Es **la única forma** de modificar el stock — nunca se edita `stock_actual` directamente.

**Tipos:**
| Tipo | Signo | Causa típica |
|---|---|---|
| `ENTRADA` | `+` | Compra a proveedor, devolución de producción |
| `SALIDA` | `-` | Consumo en producción, venta directa |
| `AJUSTE_POSITIVO` | `+` | Corrección por inventario físico |
| `AJUSTE_NEGATIVO` | `-` | Mermas, robos, correcciones |

**Ejemplo concreto:** el 15/04/2026, el bodeguero registra entrada de 100 unidades de `ACE-3MM-1200` por compra al proveedor "Acerolatam SPA", OC #4521, precio unitario $8.500.

**Código:** entidad `MovimientoBodega` en `services/erp-api/src/modules/bodega/`.

**Invariantes críticos:**
- El stock nunca puede quedar negativo post-movimiento (ver [ADR-005](adrs/)).
- Toda mutación emite evento `bodega.movimiento.v1` a EventEmitter2.
- Los movimientos son inmutables — para corregir se genera otro movimiento, nunca se edita.

### Stock crítico

**Sinónimos del cliente:** "insumo en rojo", "bajo mínimo", "alerta de stock".

**Definición:** estado de un insumo cuando `stock_actual < stock_minimo`. Dispara alertas visuales en el dashboard y puede disparar notificaciones al encargado de compras.

**Ejemplo concreto:** `ACE-3MM-1200` tiene mínimo 20 unidades. Cuando el stock baja a 18, aparece en el widget "Stock crítico" del dashboard y se envía notificación al rol `encargado-compras`.

**Código:** computado dinámicamente, no almacenado. Query en servicio de dashboard.

### Unidad de medida

**Sinónimos del cliente:** "unidad", "formato", "cómo se mide".

**Definición:** la manera en que se cuantifica un insumo. Enum cerrado — no se pueden agregar unidades sin ADR.

**Unidades válidas actuales:**
- `UNIDAD` (piezas individuales)
- `KG` (kilogramos)
- `GR` (gramos)
- `LITRO`
- `ML` (mililitros)
- `METRO` (para materiales lineales)
- `M2` (metro cuadrado, para láminas)
- `M3` (metro cúbico)

**Código:** enum `UnidadMedida` en `services/erp-api/src/modules/bodega/`.

**Regla importante:** las conversiones entre unidades (ej: kg a gr) **no son automáticas**. Cada insumo tiene una única unidad de medida canónica y todos los movimientos la usan.

---

## Dominio: Producción y recetas

### Fase de producción

**Sinónimos del cliente:** "etapa", "paso del proceso".

**Definición:** subdivisión de una orden de producción en etapas secuenciales, cada una con máquina asignada, personal asignado y tiempo estimado.

**Ejemplo concreto:** Para producir un "Estante metálico industrial" la orden tiene 3 fases:
1. Corte de láminas — Máquina `CORTE-01`, 45 min
2. Doblado y soldadura — Máquina `SOLD-02` + Trabajador tipo `SOLDADOR_SENIOR`, 90 min
3. Pintura — Máquina `PINT-01`, 30 min

**Código:** entidad `FaseProduccion` en `services/erp-api/src/modules/produccion/`.

**Reglas clave:**
- Cada fase tiene estado propio (pendiente, en curso, finalizada).
- Una fase no empieza hasta que la anterior está finalizada (excepto si están marcadas como paralelas).
- Los tiempos reales se registran al finalizar cada fase para alimentar el cálculo de costos.

### Orden de producción

**Sinónimos del cliente:** "OP", "orden de trabajo", "OT".

**Abreviación oficial:** **O/P**.

**Definición:** documento que autoriza la fabricación de una cantidad específica de un producto, descuenta insumos de bodega según la receta, asigna máquinas y personal, y calcula costos al cierre.

**Ejemplo concreto:** O/P #2026-0481, producir 50 estantes metálicos, receta v3, inicio 20/04/2026, fin estimado 25/04/2026, costo estimado $4.350.000, costo real al cierre $4.427.500.

**Código:** entidad `OrdenProduccion` en `services/erp-api/src/modules/produccion/`.

**Estados válidos:** ver [Estados y transiciones](#estados-y-transiciones).

**Eventos emitidos:**
- `produccion.op.creada.v1`
- `produccion.op.iniciada.v1`
- `produccion.op.cerrada.v1` (incluye el costo breakdown)
- `produccion.op.cancelada.v1`

### Producto

**Sinónimos del cliente:** "artículo terminado", "SKU".

**Definición:** elemento final que la empresa fabrica y/o vende a clientes. Se compone de una o más recetas que definen qué insumos y procesos consume.

**Ejemplo concreto:** "Estante metálico industrial 2x1m" (código `EST-IND-2X1`), precio base $95.000, receta v3 activa.

**Código:** entidad `Producto` en `services/erp-api/src/modules/produccion/` (no en bodega — los productos terminados no están en el mismo dominio que los insumos).

**Atención:** un producto **no** tiene stock en bodega en el MVP. Si se fabrica para stock, está fuera del alcance del MVP.

### Receta

**Sinónimos del cliente:** "fórmula", "BOM" (Bill of Materials), "composición", "ficha técnica".

**Definición:** lista versionada de insumos con cantidades que componen un producto, más los requisitos de máquina y personal para fabricarlo. Es **el activo más crítico del sistema** porque determina cálculo de costos.

**Ejemplo concreto:** Receta v3 del "Estante metálico industrial":
- 2.4 m² de `ACE-3MM-1200` (lámina acero 3mm)
- 0.8 kg de `SOLD-6013` (electrodo soldadura)
- 0.2 litros de `PINT-EPOX-GRIS`
- Fase 1: 45 min máquina `CORTE-01`
- Fase 2: 90 min máquina `SOLD-02` + 90 min trabajador `SOLDADOR_SENIOR`
- Fase 3: 30 min máquina `PINT-01`

**Código:** entidad `Receta` en `services/erp-api/src/modules/produccion/`, con relación uno-a-muchos a `LineaReceta`.

**Reglas críticas:**
- Las recetas son **versionadas** (nunca se editan en caliente — se crea una nueva versión).
- Una O/P queda "pegada" a la versión de receta vigente al momento de su creación.
- Los campos dinámicos se guardan en JSONB (ver [Variante](#variante)).

**Ambigüedad conocida:** el cliente a veces dice "variante de receta" cuando quiere decir "versión de receta". Ver [Términos con ambigüedad resuelta](#términos-con-ambigüedad-resuelta).

### Variante

**Sinónimos del cliente:** "variación", "modelo", "versión del producto".

**Definición:** configuración específica de un producto que se diferencia por atributos dinámicos (color, tamaño, acabado, especificaciones custom). Los atributos se guardan como JSONB validados contra un schema por categoría.

**Ejemplo concreto:** Producto "Estante metálico industrial" tiene variantes:
- `{color: "gris", tamaño: "2x1m"}` → código derivado `EST-IND-2X1-GRIS`
- `{color: "verde", tamaño: "2x1m", acabado: "antióxido"}` → código `EST-IND-2X1-VRD-AOX`

**Código:** columna `atributos` de tipo JSONB en entidad `Variante` (`services/erp-api/src/modules/produccion/`).

**Schema de validación:** cada categoría de producto define un JSON Schema que valida los atributos permitidos. Ver [ADR-008-campos-dinamicos.md](adrs/).

**Importante:** "variante" **no** significa "variante de receta". Una variante puede usar la misma receta que la versión base, o puede tener receta propia si el acabado la cambia.

---

## Dominio: Costos y tarifas

### Costo de máquina

**Definición:** componente del costo de producción calculado como `minutos_operación × tarifa_por_minuto_de_la_máquina`. La tarifa es específica por máquina (no hay tarifa genérica).

**Ejemplo concreto:** Máquina `SOLD-02` opera 90 minutos en una fase, tarifa vigente $850/min. Costo máquina de la fase = $76.500.

**Código:** método `calcularCostoMaquina()` en `CostoCalculator` de `services/erp-api/src/modules/produccion/`.

### Costo total de O/P

**Definición:** suma de tres componentes: [costo de insumos](#costo-de-insumos) + [costo de máquina](#costo-de-máquina) + [costo de horas-hombre](#horas-hombre-hh).

**Ejemplo concreto:** O/P #2026-0481:
- Insumos: $3.120.000
- Máquina: $890.000
- h/h: $417.500
- **Total: $4.427.500**

**Código:** `CostoBreakdown.costoTotal` en `services/erp-api/src/modules/produccion/`.

**Regla crítica de validación:** el resultado debe coincidir con el Excel del cliente en ≥99% de los casos del fixture. Ver ticket T-029 y `tests/fixtures/excel-costos.json`.

### Costo de insumos

**Definición:** componente del costo de producción que refleja el valor de los insumos consumidos según la receta. Se calcula multiplicando cantidad consumida × precio unitario del último movimiento de entrada anterior al cierre de la O/P.

**Ejemplo concreto:** Para producir 50 estantes:
- 120 m² de `ACE-3MM-1200` × $8.500 (último precio de entrada) = $1.020.000
- 40 kg de `SOLD-6013` × $12.000 = $480.000
- Etc.

**Regla clave:** **no** se usa el precio actual del insumo, sino el precio al momento del cierre de la O/P. Esto permite recalcular costos históricos de forma consistente.

### Horas-hombre (h/h)

**Sinónimos del cliente:** "HH", "horas hombre", "tiempo de personal".

**Abreviación oficial:** **h/h**.

**Definición:** tiempo (en minutos para el cálculo interno, reportado en horas al cliente) de personal trabajando en una fase de producción, multiplicado por la tarifa por minuto del tipo de trabajador.

**Ejemplo concreto:** 90 minutos de `SOLDADOR_SENIOR` × $220/min = $19.800 de h/h para esa fase.

**Código:** `CostoCalculator.calcularCostoHorasHombre()` en `services/erp-api/src/modules/produccion/`.

**Diferencia con costo de máquina:** son independientes. En una misma fase, la máquina puede operar sin personal (ej: horno automatizado) o el personal puede trabajar sin máquina (ej: inspección manual). Ver [Tipo de cobro mixto](#tipo-de-cobro-mixto) para el caso combinado.

### Tarifa

**Sinónimos del cliente:** "precio por minuto", "costo/min", "valor hora" (aunque se calcula por minuto).

**Definición:** valor monetario por minuto de operación, específico por entidad (máquina o tipo de trabajador). Es **versionada temporalmente** — nunca se sobreescribe.

**Ejemplo concreto:** Tarifa de máquina `SOLD-02`:
- `valid_from: 2025-01-01, valid_to: 2025-12-31, valor: $780/min`
- `valid_from: 2026-01-01, valid_to: null, valor: $850/min`

**Código:** entidad `Tarifa` en `services/erp-api/src/modules/produccion/tarifas/`, con campos `validFrom` y `validTo`.

**Reglas críticas:**
- Las tarifas pasadas son **inmutables**. Modificar una tarifa con `validTo` no-nulo lanza excepción.
- Toda tarifa tiene vigencia definida por `validFrom`. Si `validTo` es `null`, se considera vigente hasta hoy.
- El cálculo de costo usa la tarifa vigente al **momento del cierre** de la O/P, no la actual.

Ver [ADR-007-tarifas-temporales.md](adrs/).

### Tipo de cobro mixto

**Sinónimos del cliente:** "cobro combinado", "precio mixto".

**Definición:** forma de facturación a cliente que combina un componente fijo por unidad producida más un componente variable por tiempo de máquina u h/h. **Se usa solo para cobro al cliente**, no para cálculo de costo interno.

**Ejemplo concreto:** Cliente "Industrias ABC" tiene condición mixta:
- $10.000 fijo por cada estante producido
- + $500 por minuto de máquina `CORTE-01` utilizado

No confundir con los tipos estándar:
- `POR_UNIDAD`: precio fijo por unidad entregada
- `POR_MINUTO`: precio por minuto de servicio (típico en mantención)
- `MIXTO`: combinación configurable de los anteriores

**Código:** entidad `TipoCobro` en `services/erp-api/src/modules/ventas/cobro/` (nota: vive en ventas, no en producción).

---

## Dominio: Ventas y clientes

### Cliente frecuente

**Sinónimos del cliente:** "cliente VIP", "cliente preferencial", "cliente recurrente".

**Definición:** cliente con condiciones comerciales preferenciales registradas en el sistema: descuentos estándar, tipos de cobro personalizados, crédito autorizado, vendedor asignado.

**Ejemplo concreto:** "Industrias ABC", vendedor asignado María González, descuento estándar 8%, tipo de cobro mixto, crédito 60 días.

**Código:** entidad `Cliente` con flag `esFrecuente` y tabla relacionada `CondicionComercial`.

**Scope del MVP:** los 50 clientes más activos del cliente, migrados vía ETL (ticket T-044).

### Cotización

**Sinónimos del cliente:** "cotización", "presupuesto", "oferta".

**Definición:** documento formal con precios propuestos para una posible orden de venta, con vigencia temporal definida. No descuenta insumos ni compromete producción.

**Ejemplo concreto:** Cotización #COT-2026-0912, cliente "Industrias ABC", 50 estantes metálicos, total $5.250.000, vigente hasta 30/04/2026, PDF exportable.

**Código:** entidad `Cotizacion` en `services/erp-api/src/modules/ventas/cotizaciones/`.

**Estados válidos:** ver [Estados y transiciones](#estados-y-transiciones).

**Eventos emitidos:**
- `ventas.cotizacion.creada.v1`
- `ventas.cotizacion.aprobada.v1` (cliente la aceptó)
- `ventas.cotizacion.vencida.v1` (expiró sin aprobación)

### Orden de venta

**Sinónimos del cliente:** "OV", "pedido", "nota de venta".

**Abreviación oficial:** **O/V**.

**Definición:** compromiso firme de venta a un cliente. Se genera a partir de una cotización aprobada. Al confirmarse puede disparar automáticamente una orden de producción.

**Ejemplo concreto:** O/V #2026-0512 generada desde cotización #COT-2026-0912, confirmada el 20/04/2026, dispara O/P #2026-0481 automáticamente.

**Código:** entidad `OrdenVenta` en `services/erp-api/src/modules/ventas/ordenes/`.

**Estados válidos:** ver [Estados y transiciones](#estados-y-transiciones).

**Regla crítica:** al confirmar una O/V con productos que requieren producción, se emite evento `venta.confirmada.v1` que el servicio de producción consume para crear la O/P asociada.

---

## Dominio: Recursos humanos y leasing

**⚠️ Nota de alcance:** este dominio está **fuera del MVP** (es módulo 2). Se incluye en el glosario porque aparece en discusiones con el cliente y los agentes deben reconocer los términos para saber cuándo una tarea está fuera de scope.

### Leasing

**Sinónimos del cliente:** "arriendo de maquinaria", "leasing operativo".

**Definición:** contrato de arriendo de máquinas propiedad de terceros utilizadas en producción. Afecta el cálculo de costos porque la máquina arrendada tiene una tarifa diferente (incluye el costo de arriendo prorrateado).

**Scope:** módulo 2. En el MVP las máquinas se tratan como propias y sus tarifas son fijas.

### Tipo de trabajador

**Sinónimos del cliente:** "categoría de personal", "nivel", "cargo".

**Definición:** clasificación del personal por nivel de especialización, que determina la tarifa h/h aplicable.

**Tipos actuales (5):**
- `OPERARIO_BASICO`
- `OPERARIO_CALIFICADO`
- `SOLDADOR_JUNIOR`
- `SOLDADOR_SENIOR`
- `SUPERVISOR_PRODUCCION`

**Scope:** los tipos y sus tarifas entran al MVP. La gestión completa de RR.HH. (nómina, vacaciones, evaluaciones) es módulo 2.

---

## Dominio: Usuarios y roles

### Rol

**Definición:** conjunto de permisos que un usuario del sistema puede tener. Un usuario puede tener múltiples roles.

**Roles del MVP:**

| Rol | Dominio | Permisos clave |
|---|---|---|
| `admin-sistema` | Transversal | Todo |
| `admin-bodega` | Bodega | CRUD insumos, categorías, movimientos |
| `bodeguero` | Bodega | Lectura insumos, registrar movimientos |
| `jefe-produccion` | Producción | Crear O/P, crear recetas, definir tarifas |
| `operario-produccion` | Producción | Actualizar estado de fases propias |
| `admin-ventas` | Ventas | CRUD clientes, crear cotizaciones y O/V |
| `vendedor` | Ventas | Crear cotizaciones, ver sus clientes |
| `encargado-compras` | Bodega + Proveedores | Crear OCs, ver stock crítico |
| `gerencia` | Transversal | Solo lectura de dashboards y reportes |

**Código:** enum `Rol` más tabla `usuario_roles` para relación muchos-a-muchos.

Ver matriz RBAC completa en [`docs/rbac-matrix.md`](rbac-matrix.md).

---

## Estados y transiciones

### Estados de O/P

```
CREADA → LIBERADA → EN_CURSO → FINALIZADA → CERRADA
                                     ↓
                                CANCELADA
```

| Estado | Significado | Transiciones válidas |
|---|---|---|
| `CREADA` | Registrada pero sin insumos reservados | → LIBERADA, → CANCELADA |
| `LIBERADA` | Insumos reservados en bodega | → EN_CURSO, → CANCELADA |
| `EN_CURSO` | Alguna fase está ejecutándose | → FINALIZADA, → CANCELADA |
| `FINALIZADA` | Todas las fases terminadas, pendiente cierre | → CERRADA |
| `CERRADA` | Costo calculado, evento emitido | (terminal) |
| `CANCELADA` | Cancelada antes de terminar | (terminal) |

**Regla crítica:** al pasar a `CERRADA` se ejecuta el motor de costos y se emite `produccion.op.cerrada.v1`.

### Estados de cotización

```
BORRADOR → ENVIADA → APROBADA → CONVERTIDA
                  ↓
               RECHAZADA / VENCIDA
```

### Estados de O/V

```
PENDIENTE → CONFIRMADA → EN_PRODUCCION → LISTA → ENTREGADA
                      ↓                       ↓
                  CANCELADA               FACTURADA
```

---

## Abreviaturas frecuentes

| Abreviatura | Significado |
|---|---|
| **O/P** | Orden de producción |
| **O/V** | Orden de venta |
| **OC** | Orden de compra (a proveedor) — fuera del MVP |
| **h/h** | Horas-hombre |
| **BOM** | Bill of Materials — sinónimo usado por el cliente para [Receta](#receta) |
| **ETL** | Extract, Transform, Load (migración de datos) |
| **ERP** | Enterprise Resource Planning (el sistema completo) |
| **OLTP** | Online Transaction Processing (PostgreSQL principal) |
| **OLAP** | Online Analytical Processing (ClickHouse/TimescaleDB para analytics) |
| **RBAC** | Role-Based Access Control |
| **SKU** | Stock Keeping Unit — en este proyecto usamos "producto" |
| **ADR** | Architecture Decision Record |

---

## Términos con ambigüedad resuelta

Esta sección documenta casos donde el cliente usa una palabra para dos cosas distintas. Los agentes deben tratarlos con especial cuidado.

### "Variante"

El cliente usa "variante" para dos conceptos distintos:

| Uso del cliente | Concepto real en el sistema |
|---|---|
| "Variante del producto" (color, tamaño) | [Variante](#variante) — entidad con atributos JSONB |
| "Variante de receta" | [Versión de receta](#receta) — número de versión incremental |

**Regla:** si el ticket dice "variante" sin más contexto, el agente debe preguntar al PO cuál de los dos es.

### "Stock"

| Uso del cliente | Concepto real |
|---|---|
| "Stock del insumo" | `Insumo.stock_actual` |
| "Stock del producto" | **No existe en el MVP.** Los productos se fabrican contra O/V, no para stock. |

**Regla:** si alguien pide un endpoint de "stock de productos", reportar que está fuera de scope del MVP y derivar a PO.

### "Precio"

| Uso del cliente | Concepto real |
|---|---|
| "Precio del insumo" | Último precio de entrada (derivado de movimientos) |
| "Precio del producto" | Precio base del producto más ajustes por cliente |
| "Precio por minuto" | [Tarifa](#tarifa) (de máquina o trabajador) |

### "Cálculo"

El cliente dice "cálculo" para varias cosas:

| Uso del cliente | Concepto real |
|---|---|
| "Cálculo del costo de la O/P" | Motor en `CostoCalculator` (`services/erp-api/src/modules/produccion/`) |
| "Cálculo del precio de venta" | Lógica de pricing con descuentos (`services/erp-api/src/modules/ventas/`) |
| "Cálculo del stock crítico" | Query dinámica, no almacenado |

**Regla:** siempre calificar con "costo", "precio" o "stock" para evitar ambigüedad en tickets.

---

## Mantenimiento de este documento

### Cuándo actualizar

- Al firmar el glosario con el cliente en el kickoff.
- Al resolver una ambigüedad detectada en sprint planning.
- Cuando se introduce un término nuevo en un ticket.
- Cuando un agente IA reporta una definición ausente.

### Cómo actualizar

1. Abrir PR modificando este archivo (`docs/glossary.md`).
2. Etiquetar al Product Owner para revisión.
3. Si el término afecta código, actualizar también los contratos de agentes relevantes.
4. El merge del PR dispara revisión en la ceremonia **Curación de contexto** de la siguiente semana.

### Responsable principal

**Product Owner / Analista de negocio**. Validación conjunta con cliente en cada kickoff de fase.

---

**Última actualización:** abril 2026
**Versión del documento:** 1.0
**Firmado con cliente:** pendiente kickoff
**Mantenedor:** Product Owner
**Frecuencia de revisión:** semanal en ceremonia "Curación de contexto"
