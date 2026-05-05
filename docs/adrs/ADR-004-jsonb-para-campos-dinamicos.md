# ADR-004: JSONB para campos dinámicos

- **Status:** accepted
- **Date:** 2026-04-16
- **Deciders:** TL, S2, PO
- **Tags:** datos, postgresql, dominio, schema

---

## Contexto

El cliente tiene productos con **variantes y recetas de estructura flexible**. Algunos productos necesitan campos que otros no:

- Un producto "Estante metálico" tiene: color, tamaño, acabado, peso soportado.
- Un producto "Servicio de corte láser" tiene: material, espesor, tiempo por corte, complejidad geométrica.
- Un producto "Kit de repuestos" tiene: marca compatible, modelos compatibles, certificación.

Forzar todos los atributos a columnas fijas produce tablas gigantescas con columnas casi siempre en NULL, o peor, fuerza a crear una tabla por tipo de producto rompiendo la uniformidad del sistema.

Por otro lado, el ERP tiene requisitos estrictos de integridad relacional: una O/P referencia una receta, una receta referencia insumos, los insumos están en bodega, etc. Perder integridad referencial para ganar flexibilidad **no es aceptable** en un sistema de costos monetarios.

El dilema histórico entre SQL rígido y NoSQL flexible se resuelve hoy con **JSONB en PostgreSQL**, pero necesitamos decidirlo formalmente y marcar reglas claras para que ni humanos ni agentes IA caigan en la tentación de rearquitecturar hacia MongoDB.

---

## Decisión

Los **campos dinámicos de variantes de productos y líneas de receta** se almacenarán en columnas `JSONB` de PostgreSQL. Cada categoría de producto tiene un **JSON Schema** asociado que valida qué atributos son válidos para esa categoría.

### Implementación

```sql
-- Variantes de producto
CREATE TABLE variantes_producto (
  id uuid PRIMARY KEY,
  producto_id uuid NOT NULL REFERENCES productos(id),
  codigo_derivado text UNIQUE NOT NULL,
  atributos jsonb NOT NULL DEFAULT '{}',
  created_at timestamptz NOT NULL DEFAULT now()
);

-- Índice GIN para búsquedas eficientes en JSONB
CREATE INDEX idx_variantes_atributos ON variantes_producto USING GIN (atributos);
```

### JSON Schema por categoría

```json
{
  "$schema": "http://json-schema.org/draft-07/schema#",
  "title": "AtributosEstanteMetalico",
  "type": "object",
  "properties": {
    "color": { "enum": ["gris", "verde", "negro", "blanco"] },
    "tamaño": { "enum": ["2x1m", "2x0.5m", "3x1m"] },
    "acabado": { "enum": ["pintado", "galvanizado", "antióxido"] },
    "peso_soportado_kg": { "type": "integer", "minimum": 10 }
  },
  "required": ["color", "tamaño"],
  "additionalProperties": false
}
```

### Validación

- En escritura: el servicio valida `atributos` contra el JSON Schema de la categoría antes de insertar.
- En lectura: no se re-valida, pero un test de integración periódico detecta variantes con `atributos` que violan su schema (migración inconsistente).

---

## Alternativas consideradas

### A) Columnas fijas con NULLs

Todas las posibles columnas en una sola tabla `variantes_producto`.

**Pros:**
- Tipos fuertes en BD.
- Queries SQL estándar.

**Cons:**
- Tabla con 30+ columnas, mayoría NULL.
- Agregar un atributo nuevo requiere migración.
- Cada categoría de producto fuerza columnas que otras categorías no usan.
- **Descartada.**

### B) EAV (Entity-Attribute-Value)

Tabla `atributos_variante` con columnas `variante_id`, `nombre_atributo`, `valor`.

**Pros:**
- Flexibilidad total.
- Sin migraciones para nuevos atributos.

**Cons:**
- Queries brutales con múltiples JOINs (pivot de filas a columnas).
- Sin tipado de valores (todo es text).
- Validación imposible a nivel de BD.
- Patrón anti-SQL clásico, conocido por problemas de rendimiento.
- **Descartada.**

### C) MongoDB u otra NoSQL documental

Migrar el dominio de productos/variantes a una BD documental.

**Pros:**
- Flexibilidad nativa para documentos.
- Schema-less real.

**Cons:**
- Pérdida de integridad referencial con el resto del sistema (insumos en PostgreSQL).
- Transacciones cross-DB complejas.
- Agrega una tecnología nueva al stack solo para resolver un subproblema.
- Costo operativo (otra BD que mantener, backup, observabilidad).
- El cliente tiene requisitos de reportería (joins complejos) que en Mongo son costosos.
- **Descartada.**

### D) PostgreSQL + JSONB **(elegida)**

Columnas JSONB en PostgreSQL, validadas contra JSON Schema a nivel de aplicación.

**Pros:**
- Flexibilidad documental + integridad referencial en la misma tecnología.
- Queries eficientes con índices GIN.
- PostgreSQL permite queries con operadores JSONB (`->`, `->>`, `@>`) que cubren la mayoría de casos.
- Sin agregar nuevas tecnologías al stack.
- Validación con JSON Schema permite cambios sin migración.

**Cons:**
- Queries complejas sobre JSONB pueden ser más lentas que columnas fijas.
- La validación vive en código de aplicación, no en BD.
- Requiere disciplina para no abusar de JSONB (ver reglas abajo).

---

## Consecuencias

### Positivas

- Agregar un atributo nuevo a una categoría existente **no requiere migración SQL**, solo actualizar el JSON Schema.
- El código de producción puede tratar las variantes uniformemente, sin saber de cada tipo específico.
- Queries analíticas sobre atributos funcionan bien con índices GIN.
- Todo sigue siendo PostgreSQL — un solo backup, un solo punto de observabilidad.

### Negativas aceptadas

- Los atributos dentro de JSONB no tienen tipos garantizados a nivel de BD (lo garantiza el schema de aplicación).
- Queries MUY complejas sobre atributos pueden requerir índices funcionales específicos.
- Los agentes deben respetar las reglas de uso (ver abajo).

---

## Reglas derivadas que los agentes deben respetar

**⚠️ Críticas — hay tests que verifican esto:**

1. **JSONB solo para lo dinámico.** Atributos que existen en toda categoría (nombre, código, precio) van en columnas fijas. Solo los atributos que varían por categoría van en JSONB.

2. **Nunca JSONB para relaciones.** Si necesitas referenciar otra entidad, usa foreign key. Nunca guardes IDs dentro de JSONB pretendiendo que es una relación.

3. **Nunca JSONB para datos monetarios.** Precios, costos, tarifas siempre en columnas `DECIMAL` con escala explícita. Nunca en JSONB.

4. **Siempre validar con JSON Schema antes de insertar.** Las inserciones sin validación están prohibidas. Hay un test que falla si encuentra variantes con atributos inválidos.

5. **Siempre crear índice GIN** si se va a hacer búsqueda sobre el JSONB.

6. **No "aplanar" JSONB a columnas materializadas**. Si necesitas rendimiento, agrega un índice funcional; no dupliques datos en columnas regulares.

7. **Los JSON Schemas viven en el repo**, en `services/produccion/src/schemas/`. Versionados con Git, revisados en PRs.

---

## Cuándo NO usar JSONB

Los agentes deben **rechazar** propuestas de usar JSONB cuando:

- El campo es obligatorio en **todas** las instancias → columna fija.
- El campo es una relación → foreign key.
- El campo es monetario → `DECIMAL`.
- Se van a hacer agregaciones pesadas sobre él → columna fija o tabla separada.
- Se necesita enforcing a nivel de BD (UNIQUE, NOT NULL) → columna fija.

---

## Referencias

- PostgreSQL JSONB docs: https://www.postgresql.org/docs/15/datatype-json.html
- JSON Schema: https://json-schema.org/
- `services/produccion/src/schemas/categorias/` — schemas reales por categoría.
- [Glosario](../glossary.md) — definición de [Variante](../glossary.md#variante).
- Ticket T-027 — implementación inicial de variantes con JSONB.

---

**Revisitar esta decisión si:**

- Las queries sobre JSONB se vuelven el cuello de botella sostenido de rendimiento.
- Aparece un dominio cuya flexibilidad supera lo que JSONB + JSON Schema puede expresar razonablemente.
- PostgreSQL deja de soportar JSONB adecuadamente (improbable).
