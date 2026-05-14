# T-008 · Schema PostgreSQL v1 — Diseño de entidades core con JSONB para variantes

**Ticket Jira:** https://tu-org.atlassian.net/browse/T-008
**Agente asignado:** — (tarea humana)
**Supervisor humano:** TL (Tech Lead) con revisión obligatoria de PO, S1 y S2
**Sprint:** Semana 1 — Fundamentos
**Estimación:** 4 puntos
**Prioridad:** alta
**Rama:** `docs/T-008-schema-postgresql-v1`

---

## ⚠️ Ticket humano (no se delega a agentes IA)

Este ticket lo ejecuta el **Tech Lead** acompañado por el PO, S1 y S2. **No se asigna a ningún agente IA** porque:

1. **Decisiones de modelado de BD son irreversibles a costo bajo.** Una vez que hay datos productivos sobre un schema, cambiarlo es costoso. Estas decisiones requieren juicio humano sobre el negocio y consenso entre supervisores.
2. **Requiere interpretar los Excel del cliente** y traducirlos a un modelo relacional. La interpretación tiene ambigüedad — el PO es quien valida la semántica del negocio.
3. **Conecta con ADRs ya tomados** (ADR-003 multi-tenancy, ADR-004 JSONB, ADR-005 stock calculado, ADR-007 tarifas temporales). La consistencia entre ADRs y schema es responsabilidad del TL.

El entregable de este ticket es **documentación + un primer esqueleto de `schema.prisma`** que después los agentes A1 (T-016, T-017, T-026, etc.) usan como punto de partida.

---

## Contexto de negocio

El ERP reemplaza un ecosistema de Excel con 8 años de historia. El cliente tiene:

- **Tabla principal de insumos** (`insumos.xlsx`): 1500+ filas, 47 categorías, atributos heterogéneos (algunos insumos tienen "espesor", otros "color", otros "grado de pureza" — depende de la categoría).
- **Tabla de productos con recetas**: cada producto tiene una receta = lista de insumos + cantidades, y varía en **variantes** (color, tamaño, especificaciones custom) cuyos atributos también dependen de la categoría del producto.
- **Tabla de máquinas**: 12 máquinas, cada una con un costo/min que cambia con el tiempo (ADR-007).
- **Tipos de trabajador**: 6 tipos, cada uno con tarifa h/h, también temporal.
- **Tabla de clientes frecuentes**: 50 clientes con condiciones comerciales preferenciales.
- **Cotizaciones y órdenes de venta** (esto está en otro archivo Excel).

La decisión clave que este ticket toma:

> **¿Modelamos los atributos heterogéneos con columnas por entidad, EAV (Entity-Attribute-Value), o JSONB?**

ADR-004 ya respondió: **JSONB con validación por JSON Schema**. Este ticket lo aterriza en el modelo concreto.

---

## Alcance técnico

### Crear / actualizar

```
docs/
├── schema-v1.md                       ← documento principal del ticket
│                                       (modelo conceptual + decisiones)
├── schema-v1-erd.png                  ← diagrama ER exportado
├── schema-v1-erd.dbml                 ← fuente del diagrama (dbml.io)
└── adrs/
    └── ADR-011-modelo-de-recetas-y-variantes.md  ← nuevo ADR si aplica

services/erp-api/prisma/
└── schema.prisma                       ← primer borrador de modelos
                                         (no se aplica todavía si T-004 ya
                                          generó uno desde la BD; este ticket
                                          documenta la versión "objetivo" que
                                          los tickets posteriores convergen)
```

### Modificar

- `docs/architecture.md` — agregar sección "Modelo de datos v1" con resumen.
- `docs/glossary.md` — verificar que todas las entidades del schema están definidas.
- `docs/events.md` — verificar que los eventos referenciales (ej: `bodega.movimiento.registrado.v1`) usan los nombres de entidades correctos.

### No tocar

- **Lógica de aplicación**. Este ticket es solo modelo de datos y documentación.
- **Migraciones**. No se generan migraciones aún. Cuando los tickets de cada módulo se ejecuten (T-016 categorías, T-017 movimientos, T-026 recetas, etc.) cada uno aplica su parte del schema con `prisma migrate dev`.
- **schema.prisma productivo**. El de T-004 viene de `prisma db pull` de la BD Arteo existente. Este ticket produce un **schema "objetivo"** documentado al que los tickets futuros van convirgiendo. No se sustituye el de T-004 en este ticket.

---

## Decisiones que este ticket debe tomar y documentar

### Decisión 1 — Modelado de variantes y atributos dinámicos

ADR-004 dice "JSONB". Este ticket aterriza:

- **Granularidad del JSONB**: ¿una columna `atributos jsonb` por entidad, o varias columnas (`atributos_visuales`, `atributos_tecnicos`)?
- **Validación**: ¿JSON Schema por categoría almacenado en BD (tabla `categoria_schemas`) o en código (constantes TypeScript)?
- **Indexación**: ¿qué campos del JSONB se indexan con GIN, qué campos no?
- **Migración de datos cuando el schema cambia**: ¿cómo se evolucionan los JSON Schemas sin romper datos existentes?

**Entregable de la decisión:**

- Ejemplo concreto de JSONB para 3 categorías: "metalmecánica", "químicos", "embalajes".
- Tabla `categoria_schemas` con su DDL.
- Índices propuestos y justificación de cuáles.

### Decisión 2 — Stock: calculado vs almacenado

ADR-005 dice "calculado desde movimientos". Aterrizar:

- ¿Hay una vista materializada `stock_actual` que se refresca con cada movimiento, o se calcula on-the-fly cada vez?
- ¿Cuál es el caché en Redis y cuál su política de invalidación?
- Performance esperado: ¿cuánto tarda calcular el stock de 1500 insumos?

**Entregable:**

- DDL de la vista (si se decide vista) o función SQL (si se decide función).
- Diseño de la clave Redis (`stock:{tenantId}:{insumoId}` o equivalente).
- Pseudocódigo del flujo "registrar movimiento → invalidar caché → recalcular bajo demanda".

### Decisión 3 — Tarifas temporales (refinamiento de ADR-007)

ADR-007 ya tiene el DDL básico. Refinar:

- ¿La tabla `tarifas` es polimorfa (entidad_tipo + entidad_id) como propone el ADR, o son dos tablas separadas (`tarifas_maquina`, `tarifas_tipo_trabajador`)?
- ¿Cómo se relacionan con las filas históricas de movimientos / OPs? (Es decir, ¿una OP guarda el `tarifa_id` que usó para su cálculo, o solo la `fecha_cierre` desde la que se infiere la tarifa cada vez que se reconsulta?)

**Entregable:**

- DDL final de tarifas en `schema.prisma`.
- Decisión documentada: foreign key explícita (tarifa_id en OP) o inferencia por fecha.

### Decisión 4 — Multi-tenancy: implementación concreta

ADR-003 dice "schema por tenant". Aterrizar:

- ¿Cómo se conecta esto con el `multiSchema` de Prisma (que ya usa T-004)?
- ¿Hay un schema `public` con `tenants` y `usuarios`, y cada tenant tiene su propio schema con `bodega.*`, `produccion.*`, etc.?
- ¿O hay un solo schema por tenant que contiene todo (`tenant_erp.insumos`, `tenant_erp.recetas`, `tenant_erp.ops`, etc.)?

**Entregable:**

- Diagrama claro de schemas y sus tablas.
- Estrategia de routing: cómo Prisma resuelve el schema correcto por request (referencia al `TenantMiddleware` que se implementará en T-013/T-014).

### Decisión 5 — Auditoría y soft delete

- ¿Cada tabla tiene `created_at`, `updated_at`, `created_by`, `updated_by`, `deleted_at`?
- ¿Hay tabla de auditoría centralizada (`audit_log`) con cambios fila a fila?
- ¿Soft delete o hard delete? (T-MVP-004 ya tiene una propuesta — alinear con eso).

**Entregable:**

- Campos estándar que toda tabla incluye.
- Política de soft delete: qué tablas la usan, cuáles no.
- Estrategia de auditoría: trigger BD vs interceptor de NestJS (referencia a T-MVP-003 si existe).

### Decisión 6 — Convención de naming

- `snake_case` en BD, `camelCase` en código TypeScript (Prisma maneja la traducción con `@map`).
- Singular o plural en tablas: `insumo` vs `insumos`.
- Claves primarias: ¿`id` autoincrementable, UUID v4, UUID v7, ULID?
- Foreign keys: ¿`<tabla>_id` o `id_<tabla>`?

**Entregable:**

- Sección "Convenciones" en `docs/schema-v1.md` con ejemplo aplicado.

---

## Criterios de aceptación

### Documento `docs/schema-v1.md`

- [ ] Contiene la **lista completa de entidades v1** del MVP:
  - `tenants`, `usuarios`, `roles`, `permisos`
  - `categorias`, `insumos`, `movimientos`, `lotes` (si aplica)
  - `productos`, `variantes_producto`, `recetas`, `lineas_receta`
  - `maquinas`, `tipos_trabajador`, `tarifas`
  - `ordenes_produccion`, `op_fases`, `op_consumos`
  - `clientes`, `condiciones_comerciales`
  - `cotizaciones`, `lineas_cotizacion`, `ordenes_venta`, `lineas_ov`
  - `categoria_schemas` (para validación de JSONB)
  - `audit_log` (si la decisión 5 lo decide)
- [ ] Para cada entidad: propósito, columnas con tipo y restricciones, índices, relaciones, política de soft-delete, eventos que emite (o que recibe).
- [ ] Las 6 decisiones listadas arriba están documentadas con sus alternativas, criterio elegido y justificación.
- [ ] Cada decisión apunta al ADR que la soporta (ADR-003, 004, 005, 007) o, si introduce un patrón nuevo, propone un ADR-011 nuevo.

### Diagrama ER

- [ ] Archivo `docs/schema-v1-erd.dbml` con la definición en dbml (https://dbml.dbdiagram.io/).
- [ ] Imagen exportada `docs/schema-v1-erd.png`.
- [ ] El diagrama muestra al menos:
  - Cardinalidad de relaciones (1:1, 1:N, N:M).
  - Foreign keys nombradas.
  - Schemas (`public.*`, `tenant_erp.*`) visualmente separados.

### Esqueleto `schema.prisma`

- [ ] Existe un **borrador** en `services/erp-api/prisma/schema.prisma` (o en `docs/schema-v1-prisma-target.prisma` si T-004 ya tiene un `schema.prisma` activo de `db pull`).
- [ ] Contiene todos los modelos listados arriba, con sus campos y relaciones.
- [ ] Usa `multiSchema` y `@@schema` por modelo.
- [ ] Comentarios en cada modelo apuntando al ticket que lo implementará completamente (`// implementado en T-016`, etc.).

### ADR-011 (si aplica)

- [ ] Si las decisiones 1-6 introducen patrones nuevos no cubiertos por ADRs existentes, se redacta un `docs/adrs/ADR-011-modelo-de-recetas-y-variantes.md`.
- [ ] El ADR sigue la plantilla estándar (Status, Context, Decision, Consequences, Alternativas).

### Revisión cruzada

- [ ] **PO** firma que la semántica del negocio está correctamente reflejada (especialmente recetas, variantes, tarifas).
- [ ] **S1** firma que el modelo es implementable en NestJS + Prisma sin contradicciones.
- [ ] **S2** firma que el modelo de producción (recetas, OPs, tarifas, costos) permite cumplir las invariantes críticas (≥99% match con Excel del cliente).
- [ ] **DO** (opcional) revisa que el modelo no introduce problemas operativos obvios (queries pesadas, ausencia de índices clave).

### Validación contra Excel del cliente

- [ ] Para al menos 3 entidades clave (`insumos`, `productos`, `cotizaciones`) se hace un ejercicio: tomar una fila real del Excel del cliente e ilustrar cómo se representaría en el modelo v1. Documentar en `docs/schema-v1.md` sección "Ejemplos con datos reales del cliente".
- [ ] Si en este ejercicio se descubre que el modelo no cubre algo del Excel real, **pausar y reabrir** las decisiones afectadas.

### Comunicación al equipo

- [ ] Sesión de revisión de 60 minutos con TL + PO + S1 + S2 + DO antes de mergear.
- [ ] Acta de la sesión guardada en `docs/sessions/2026-04-XX-revision-schema-v1.md` con:
  - Asistentes.
  - Decisiones tomadas.
  - Disputas no resueltas (si las hay) con responsable de resolverlas.
- [ ] Anuncio en `#erp-build` con un párrafo de resumen de la decisión.

---

## Invariantes que el TL DEBE respetar

1. **Las decisiones de ADRs ya aceptados no se contradicen.** Si una decisión nueva contradice un ADR vigente, el ADR vigente debe ser supersedido explícitamente con un ADR nuevo, no ignorado.
2. **Todo modelo nuevo respeta la convención de naming** acordada en este mismo ticket (decisión 6).
3. **Todas las entidades del MVP están en el modelo v1**. Si se descubre algo que no se modeló, este ticket no cierra hasta agregarlo.
4. **No introduce dependencias circulares de foreign keys**.
5. **No se mergea sin las 3 firmas obligatorias** (PO, S1, S2).
6. **Las invariantes críticas del proyecto deben ser expresables en el modelo**:
   - Stock nunca negativo → check en BD o trigger.
   - Tarifa con `valid_to` no nulo es inmutable → trigger de BD.
   - Categoría con insumos asociados no se puede borrar → FK con `ON DELETE RESTRICT`.
   - Una sola tarifa vigente por (entidad_tipo, entidad_id) → unique index parcial.

---

## Casos de uso obligatorios que el modelo debe soportar

Para cada caso, demostrar **en el documento** cómo el modelo lo resuelve:

### Caso 1 — Registrar entrada de bodega

```
Bodeguero registra ingreso de 100 unidades del insumo "Plancha acero 1.5mm" hoy.
→ Movimientos: 1 fila con tipo='ENTRADA', insumo_id, cantidad=100, fecha=now()
→ Stock se recalcula desde movimientos (ADR-005)
→ Evento `bodega.movimiento.registrado.v1` se emite
```

### Caso 2 — Variante de producto con atributos custom

```
Producto "Bandeja inox" tiene variantes:
  - Variante A: largo=30cm, ancho=20cm, espesor=1mm
  - Variante B: largo=40cm, ancho=30cm, espesor=1.5mm
  - Variante C: largo=30cm, ancho=20cm, espesor=1mm, perforada=true (sub-variante)

→ Tabla productos con id, nombre, categoría_id
→ Tabla variantes_producto con id, producto_id, atributos jsonb (validado por JSON Schema de la categoría)
→ Tabla categoria_schemas con el JSON Schema que valida los atributos
```

### Caso 3 — Cierre de O/P con tarifa histórica

```
O/P creada el 2026-01-15. Tarifa de la máquina SOLD-02 ese día era $750/min.
Tarifa cambió el 2026-02-01 a $850/min.
La O/P se cierra el 2026-02-10.
→ El costo de la O/P se calcula con la tarifa de $750/min (vigente al cierre, NO al cierre actual)
→ El modelo debe permitir resolver esa tarifa por (entidad_tipo, entidad_id, fecha_cierre)
→ La fecha que se usa para resolver: ¿es la fecha de creación o la de cierre? → documentar
```

### Caso 4 — Cliente con condiciones comerciales

```
Cliente "ACME S.A." es cliente frecuente con 15% de descuento global y 60 días de plazo de pago.
Cotización para ACME aplica esos términos automáticamente.
→ Tabla clientes
→ Tabla condiciones_comerciales (1:1 o 1:N si hay versiones históricas)
→ Las cotizaciones referencian las condiciones vigentes al momento de crear
```

### Caso 5 — Cotización con líneas y conversión a OV

```
Cotización tiene 3 líneas (productos, cantidades, precio unitario, subtotal).
Se aprueba → se convierte en OV.
La OV referencia la cotización origen.
La OV confirma → dispara evento `venta.confirmada.v1` que produce las O/Ps.
→ Tablas cotizaciones, lineas_cotizacion, ordenes_venta, lineas_ov.
→ Foreign key cotizacion_origen_id en ordenes_venta.
```

### Caso 6 — Multi-tenant: dos tenants no se ven datos

```
tenant_erp e tenant_acme coexisten en la misma BD.
Un bodeguero de tenant_erp consulta /insumos → solo ve insumos del schema tenant_erp.
→ El modelo + el TenantMiddleware aseguran este aislamiento.
→ Documentar dónde se controla (search_path por request o filtro implícito en queries).
```

### Caso 7 — Soft delete + auditoría

```
Admin borra el insumo I-123.
→ El registro NO se elimina físicamente: `deleted_at = now()`, `deleted_by = userId`.
→ Una fila en audit_log registra la acción (si la decisión 5 lo definió así).
→ Queries normales no devuelven I-123, pero el histórico de movimientos sigue referenciándolo.
```

---

## Lo que NO se debe hacer en esta tarea

- **No implementar nada en código.** El entregable es documentación + esqueleto de schema, no funcionalidad.
- **No aplicar migraciones**. No se corre `prisma migrate dev` en este ticket.
- **No reescribir el `schema.prisma` actual** (de T-004, que vino de `db pull`). El esqueleto que se produce aquí es la "versión objetivo" que los tickets de implementación irán acercando.
- **No tomar decisiones unilaterales sobre dominios sensibles** (recetas, costos, tarifas) sin la firma de S2 + PO.
- **No introducir tecnologías nuevas** (Hasura, PostgREST, Supabase, etc.). El stack está definido en `docs/stack.md`.
- **No usar EAV (Entity-Attribute-Value)** como alternativa a JSONB. ADR-004 ya descartó EAV.
- **No usar herencia de tablas de PostgreSQL** (`INHERITS`). Es no estándar y rompe portabilidad.

---

## Contratos y referencias

- **ADRs vigentes que el modelo debe respetar:**
  - [ADR-003 Multi-tenancy por schema](../../docs/adrs/ADR-003-multi-tenancy-por-schema.md)
  - [ADR-004 JSONB para campos dinámicos](../../docs/adrs/ADR-004-jsonb-para-campos-dinamicos.md)
  - [ADR-005 Stock calculado desde movimientos](../../docs/adrs/ADR-005-stock-calculado-desde-movimientos.md)
  - [ADR-007 Tarifas temporales](../../docs/adrs/ADR-007-tarifas-temporales.md)
  - [ADR-010 Monolito modular](../../docs/adrs/ADR-010-monolito-modular.md)
- **Documentos relacionados:**
  - [`docs/glossary.md`](../../docs/glossary.md) — todas las entidades deben estar definidas ahí
  - [`docs/events.md`](../../docs/events.md) — eventos referencian entidades, deben coincidir
  - [`docs/prisma-workflow.md`](../../docs/prisma-workflow.md) — flujo de schema.prisma
  - [`docs/architecture.md`](../../docs/architecture.md) — el modelo se incorpora a la arquitectura general
- **Excel del cliente:** ubicación a confirmar con PO; T-011 hace el inventario completo.
- **Schema actual (de T-004):** `services/erp-api/prisma/schema.prisma` (revisar antes de proponer cambios).

---

## Entregables

- [ ] `docs/schema-v1.md` — documento principal.
- [ ] `docs/schema-v1-erd.dbml` — fuente del diagrama ER.
- [ ] `docs/schema-v1-erd.png` — diagrama exportado.
- [ ] Esqueleto de `schema.prisma` (en `docs/schema-v1-prisma-target.prisma` para no chocar con el de T-004).
- [ ] `docs/adrs/ADR-011-*.md` — si aplica.
- [ ] `docs/sessions/2026-04-XX-revision-schema-v1.md` — acta de la sesión.
- [ ] Actualizaciones a `docs/glossary.md`, `docs/architecture.md`, `docs/events.md` si se descubren inconsistencias.
- [ ] Firmas (en el documento principal o en el PR): PO, S1, S2.
- [ ] Commit: `docs(schema): document v1 entities, jsonb model, and tenant strategy [TL]`
- [ ] PR con labels: `supervisor:TL`, `sprint:semana-1`, `priority:high`, `type:docs`

---

## Proceso recomendado (60-90 minutos de trabajo distribuido en 1-2 sesiones)

### Sesión 1 — Preparación individual (TL solo, 90 minutos)

1. Releer ADRs 003, 004, 005, 007, 010.
2. Releer el `schema.prisma` actual de T-004.
3. Releer el glosario y eventos.
4. Si el PO ya tiene el Excel del cliente accesible, abrir las pestañas críticas y tomar notas.
5. Redactar borrador v0 del documento principal con las 6 decisiones planteadas (sin resolverlas todavía).

### Sesión 2 — Revisión con el equipo (60 minutos, TL + PO + S1 + S2 + DO opcional)

1. TL presenta el borrador y las 6 decisiones (10 min).
2. Discusión de cada decisión, anotando alternativas y elegida (40 min).
3. Validación de los 7 casos de uso obligatorios contra el modelo propuesto (10 min).
4. Asignación de TL para terminar el documento y de PO, S1, S2 para firmar.

### Post-sesión — Cierre (TL solo, 60 minutos)

1. Actualizar el documento con lo discutido.
2. Generar el diagrama dbml + PNG.
3. Crear el esqueleto de schema.prisma.
4. Si la sesión introdujo patrón nuevo, redactar ADR-011.
5. Abrir el PR y solicitar revisión asíncrona.

---

## Validación post-ejecución (lo llena el TL)

```bash
# 1. Verificar que todas las entidades del MVP están listadas
grep -c "^### " docs/schema-v1.md
# Debe ser al menos 20 (una por entidad importante)

# 2. Verificar el diagrama
ls -la docs/schema-v1-erd.png
# Tamaño > 0 y abre correctamente

# 3. Verificar el schema.prisma propuesto compila (prisma format)
cd services/erp-api && npx prisma format --schema=../../../docs/schema-v1-prisma-target.prisma
# Sin errores

# 4. Verificar que el glosario tiene todas las entidades referenciadas
for entidad in tenant usuario insumo categoria movimiento producto receta variante tarifa op cotizacion ov cliente; do
  grep -qi "$entidad" docs/glossary.md || echo "FALTA en glosario: $entidad"
done

# 5. Firmas
grep "PO:" docs/schema-v1.md
grep "S1:" docs/schema-v1.md
grep "S2:" docs/schema-v1.md
```

- **Fecha de sesión:** _pendiente_
- **Asistentes:** _pendiente_
- **Decisiones tomadas:** _pendiente_
- **Disputas no resueltas:** _pendiente (idealmente: ninguna)_
- **ADR-011 creado:** _sí/no — pendiente_
- **Firmas:** _pendiente (PO, S1, S2)_
- **Resultado:** _pendiente_

---

## Notas para el TL

- **No te apresures en este ticket.** Es la base de los siguientes 3 sprints. 1 día de trabajo aquí ahorra 1 semana de refactor en sprint 2.
- **Si el PO no tiene tiempo para una sesión de 60 min** en esta semana, prioriza las decisiones que no requieren su input (3 y 6) y agenda con él solo las que sí lo requieren (1, 2, 5).
- **Si en la sesión surge una disputa fuerte** entre S1 y S2 sobre cómo modelar recetas/costos, **no la resuelvas en la sesión.** Documenta las dos posiciones, escala a la próxima ceremonia de arquitectura, y deja el ticket pendiente. Mergear con disputa interna es peor que demorar.
- **El "esqueleto de schema.prisma"** no necesita ser perfecto. Es una referencia para los tickets de implementación. Esos tickets pueden ajustar nombres de columnas y tipos finos al implementar — lo que NO pueden cambiar son las decisiones estructurales documentadas aquí.

**Prerrequisitos:**

- T-001 a T-004 completados (estructura del repo, infra base, NestJS con Prisma).
- ADRs 003, 004, 005, 007, 010 leídos y aceptados.
- Acceso (al menos parcial) al Excel del cliente para validación.

**Sucesores:**

- T-016 (CRUD categorías) implementa la parte del schema relativa a categorías.
- T-017 (movimientos bodega) implementa stock y movimientos.
- T-026, T-027, T-028, T-030 (producción) implementan recetas, variantes, OPs, tarifas.
- T-038, T-039, T-040 (ventas) implementan clientes, cotizaciones, OVs.

Todos esos tickets esperan que este (T-008) esté cerrado y firmado.

---

**Creado:** 2026-04-28 por TL
**Plantilla base:** `prompts/templates/ticket-template.md` v1.0 con adaptaciones para ticket humano
**Tipo:** decisión arquitectónica + documentación
