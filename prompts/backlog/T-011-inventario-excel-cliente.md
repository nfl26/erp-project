# T-011 · Inventario completo de los Excel del cliente

**Ticket Jira:** https://tu-org.atlassian.net/browse/T-011
**Agente asignado:** A5 (ETL & Migración)
**Supervisor humano:** PO (Product Owner)
**Sprint:** Semana 1 — Fundamentos
**Estimación:** 3 puntos
**Prioridad:** alta
**Rama:** `feat/T-011-inventario-excel-cliente`

---

## Contexto de negocio

El cliente opera hace 8 años con un ecosistema de Excel. Sabemos a grandes rasgos qué archivos hay (insumos, productos, recetas, máquinas, tarifas, clientes, cotizaciones, ventas históricas, etc.), pero **no tenemos una vista detallada y consolidada** de:

- Cuántas pestañas tiene cada archivo.
- Cuántas filas y columnas activas.
- Qué fórmulas viven en cada columna calculada.
- Qué relaciones implícitas existen entre archivos (un insumo en `productos.xlsx` referenciado por código en `insumos.xlsx`, sin foreign key real).
- Qué tantas filas malformadas, valores nulos, duplicados o inconsistencias hay.

Sin este inventario, los tickets de ETL posteriores (T-021 insumos, T-033 productos+recetas, T-044 clientes) **trabajan a ciegas**. El costo de adivinar es alto: el cliente ya tiene poca paciencia para sesiones de aclaración interminables.

Este ticket entrega:

1. Un **inventario tabular** de todos los archivos Excel del cliente, en formato consumible (Markdown + CSV).
2. Un **reporte de calidad de datos** que cuantifica problemas (nulos, duplicados, formatos inconsistentes).
3. Un **mapa de fórmulas críticas** que el motor de costos (T-029, T-034) debe replicar.
4. Un **mapa de relaciones inferidas** entre archivos para diseñar el schema (T-008).

Es trabajo de **descubrimiento y análisis**, no de migración. La migración real se hace en tickets posteriores, ya con datos limpios sobre qué se está migrando.

---

## Alcance técnico

### Crear

```
etl/
├── analysis/
│   ├── scripts/
│   │   ├── 01-inventario-archivos.py     ← inventario alto nivel
│   │   ├── 02-perfil-tabla.py             ← perfilamiento por pestaña
│   │   ├── 03-extraer-formulas.py         ← extracción de fórmulas Excel
│   │   ├── 04-detectar-relaciones.py      ← inferencia de FKs implícitas
│   │   └── README.md
│   ├── reports/
│   │   ├── inventario.md                  ← reporte principal (humano)
│   │   ├── inventario.csv                 ← versión tabular
│   │   ├── perfil-{archivo}.md            ← uno por cada Excel
│   │   ├── formulas-criticas.md           ← fórmulas que el sistema debe replicar
│   │   ├── relaciones-inferidas.md        ← mapa de FKs implícitas
│   │   └── calidad-datos.md               ← problemas detectados
│   └── fixtures/
│       └── README.md                      ← cómo se obtienen los Excel del cliente

etl/
├── requirements.txt                       ← agregar/verificar pandas, openpyxl, etc.
├── pyproject.toml                         ← config de ruff y pytest
└── README.md                              ← cómo correr los scripts
```

### Modificar

- `docs/glossary.md` (T-009) — A5 reporta términos del Excel que no están en el glosario para que PO los agregue. **A5 no edita el glosario directamente** — solo abre un comentario en el PR con la lista.
- `docs/schema-v1.md` (T-008) — el inventario alimenta las decisiones de schema; A5 deja comentario en el PR de T-008 si descubre algo que cambia el modelo.

### No tocar

- **Los archivos Excel originales del cliente.** Solo lectura, nunca escribir. Si A5 necesita probar transformaciones, copia el archivo a una carpeta de trabajo (`etl/analysis/fixtures/work/`) que **no se commitea**.
- **El schema de BD productivo.** Este ticket no inserta nada en PostgreSQL. Solo analiza Excel.
- **Código de aplicación** (NestJS, frontends). Dominio de otros agentes.

---

## Criterios de aceptación

### Cobertura

- [ ] **Todos los archivos Excel del cliente** están inventariados. La lista canónica la confirma el PO al inicio del ticket. Esperar al menos:
  - `insumos.xlsx`
  - `productos.xlsx` (con recetas en pestañas separadas)
  - `cotizaciones.xlsx`
  - `clientes.xlsx`
  - `maquinas.xlsx`
  - `tarifas.xlsx`
  - `ventas-historicas.xlsx`
  - Posiblemente otros archivos auxiliares.
- [ ] Cada archivo tiene un reporte de perfil (`perfil-{archivo}.md`).
- [ ] Si el PO menciona un archivo que **no aparece** en lo que entregó, A5 lo lista en el inventario como "FALTANTE — solicitar al cliente" y continúa con el resto.

### Inventario alto nivel (`inventario.md` + `.csv`)

Para cada **pestaña** de cada archivo:

- [ ] Nombre del archivo.
- [ ] Nombre de la pestaña.
- [ ] Número de filas con datos (excluyendo encabezados y filas vacías).
- [ ] Número de columnas con encabezado.
- [ ] Tipo aparente de la pestaña: `datos` | `lookup` | `cálculo` | `formato` | `notas` | `desconocido`.
- [ ] Existencia de fórmulas (sí/no, cuántas).
- [ ] Filas con todos los campos nulos.
- [ ] Filas duplicadas (por todos los campos).
- [ ] Comentarios/observaciones del cliente embebidos en celdas (si los hay).

El CSV permite filtros rápidos en una pivot. El Markdown es legible.

### Perfilamiento por pestaña (`perfil-{archivo}.md`)

Para cada pestaña relevante (las marcadas como `datos`):

- [ ] Lista de columnas con: nombre, tipo inferido (`int`, `float`, `string`, `date`, `bool`, `formula`, `mixed`), % de nulos, distintos únicos, rango de valores.
- [ ] **Columnas con valores mixtos** (ej: una columna donde algunos valores son números y otros texto "N/A") — flagged como problema.
- [ ] **Columnas con formato inconsistente** (fechas con varios formatos, números con coma o punto decimal mezclados) — flagged.
- [ ] **Top 5 valores más frecuentes** por columna categórica.
- [ ] **Distribución** (min, max, media, p50, p95) por columna numérica.
- [ ] **Filas atípicas** (outliers que merecen revisión humana).
- [ ] Encabezado original de cada columna (a veces son frases largas con typos del cliente — preservarlo).

### Fórmulas críticas (`formulas-criticas.md`)

A5 abre cada archivo con `openpyxl` (modo `data_only=False`) y extrae **todas las celdas con fórmulas**, agrupadas por archivo + pestaña.

Para fórmulas relevantes al motor de costos (T-029):

- [ ] Lista cada fórmula encontrada en la pestaña/columna donde aparece.
- [ ] Traduce la fórmula a **pseudocódigo legible en español**:
  ```
  =SUMPRODUCT(B2:B100, C2:C100) → "suma del producto entre columna B y C"
  ```
- [ ] Identifica **dependencias** entre celdas (qué cuenta usa qué).
- [ ] Marca fórmulas **circulares**, **rotas** o **con referencias externas**.
- [ ] Apunta a tickets que las implementarán (T-029 motor de costos, T-034 validación contra Excel, T-043 dashboard KPIs).

Si el cliente tiene macros VBA:

- [ ] Listar cada macro con su nombre y un resumen de qué hace (sin transcribir el código).
- [ ] Las macros no se migran a Python automáticamente — se documentan para que el equipo decida tícket a ticket.

### Relaciones inferidas (`relaciones-inferidas.md`)

A5 detecta **foreign keys implícitas**:

- [ ] Columnas con nombres similares entre archivos (`insumo_id` en `productos.xlsx` que coincide con `id` o `codigo` en `insumos.xlsx`).
- [ ] Validación: ¿los valores coinciden? ¿qué % de la columna padre referencian valores que NO existen en la columna hija? (datos huérfanos).
- [ ] Cardinalidad inferida: 1:1, 1:N, N:M.
- [ ] Para cada relación, recomendación al schema-v1 (T-008): qué FK declarar, qué `ON DELETE` aplicar.

### Calidad de datos (`calidad-datos.md`)

Resumen ejecutivo de problemas:

- [ ] **Filas duplicadas** por archivo+pestaña.
- [ ] **Códigos inconsistentes** (mismo insumo con códigos distintos en archivos distintos).
- [ ] **Categorías huérfanas** (insumos referenciando categorías inexistentes).
- [ ] **Fechas inválidas** (1900-01-01 que aparece como placeholder, fechas futuras imposibles, fechas con formato distinto entre celdas).
- [ ] **Números con formato distinto** entre celdas (`1.500,50` vs `1500.50` vs `1500,50`).
- [ ] **Casos especiales del cliente** documentados en celdas con notas (color amarillo, comentario): listarlos para que el PO los discuta.
- [ ] **Estimación cuantitativa**: ¿qué % de filas tienen al menos un problema? Si es > 10%, alertar al PO porque el ETL tendrá iteraciones largas.

### Scripts reproducibles

- [ ] Cada uno de los 4 scripts (`01-`, `02-`, `03-`, `04-`) corre con un comando simple:
  ```bash
  cd etl/analysis
  python scripts/01-inventario-archivos.py --input ../fixtures/cliente/ --output reports/inventario.md
  ```
- [ ] Argumentos explícitos (no rutas hardcodeadas).
- [ ] Logs claros de qué está procesando y cuántos errores encontró.
- [ ] Idempotentes: correr dos veces produce el mismo output (excepto timestamps).
- [ ] Tests unitarios mínimos en `etl/analysis/tests/` con fixtures sintéticas (no usar Excel real del cliente como fixture commiteable).

### Stack y dependencias

- [ ] Python 3.12 (definido en `etl/pyproject.toml` o `.python-version`).
- [ ] Dependencias principales:
  - `pandas` (manipulación tabular)
  - `openpyxl` (lectura de Excel, incluyendo fórmulas)
  - `great_expectations` o `pandera` (validación de datos — opcional en este ticket, obligatorio en T-021+)
  - `pytest`, `ruff` (testing y linting)
- [ ] `requirements.txt` actualizado.
- [ ] `pyproject.toml` con config de ruff.

### Privacidad y manejo de datos del cliente

- [ ] **Los Excel reales del cliente NO se commitean al repo.** Se guardan en una ubicación acordada (S3 privado, carpeta segura compartida).
- [ ] `etl/analysis/fixtures/cliente/` está en `.gitignore`.
- [ ] `etl/analysis/fixtures/README.md` explica:
  - Cómo obtener los Excel del cliente.
  - Dónde guardarlos localmente.
  - Que están bajo confidencialidad (no compartir fuera del equipo).
- [ ] Los reportes generados (`reports/`) **sí** se commitean, pero **sin datos personales** (nombres de clientes, RUTs, montos específicos). Los scripts deben **anonimizar** antes de escribir al reporte:
  - Nombres de clientes finales → `cliente-1`, `cliente-2`, ...
  - RUTs / IDs → hash determinístico.
  - Montos individuales → omitidos en reportes, solo agregados (totales, promedios).
- [ ] Si A5 dudas si un dato es "personal", alertar al PO antes de incluirlo.

### Comunicación con PO

- [ ] **Sesión de kick-off** (30 min) al inicio: PO entrega lista de archivos, A5 confirma alcance.
- [ ] **Reportes intermedios cada 1-2 días** en `#erp-build` con avance (1 archivo procesado, X fórmulas descubiertas, etc.).
- [ ] **Sesión de cierre** (45 min) al final: A5 presenta los hallazgos críticos al PO y a TL.
- [ ] El PO valida que el inventario refleja la realidad del cliente antes de mergear.

---

## Invariantes que el agente DEBE respetar

1. **Solo lectura sobre los Excel del cliente.** Nunca modificar el archivo original.
2. **Sin datos personales en reportes commiteados.** Anonimización es obligatoria.
3. **Sin asumir significado de columnas.** Si una columna se llama `tipo_x` y A5 no entiende qué significa, anotarlo como "DESCONOCIDO — preguntar a PO". NO inventar.
4. **Reproducibilidad.** Cualquier supervisor debe poder correr los scripts y obtener el mismo output con los mismos inputs.
5. **No "limpiar" datos en este ticket.** Si A5 detecta que una fila está mal, la reporta. La limpieza es decisión del PO y se ejecuta en los tickets de ETL real (T-021+).
6. **Idempotencia y trazabilidad.** Cada reporte incluye en su header: fecha de ejecución, hash del archivo de entrada, versión del script.
7. **Glosario es referencia.** Si A5 ve un término del Excel que no aparece en el glosario (T-009), lo reporta en el PR para que PO lo agregue.

---

## Casos de uso obligatorios que el análisis debe resolver

### Caso 1 — Variantes de productos con atributos heterogéneos

```
El cliente tiene productos en categorías muy distintas (metalmecánica, químicos, embalaje).
Cada categoría tiene atributos propios.

A5 debe:
- Listar las categorías encontradas en `productos.xlsx`.
- Por categoría, listar las columnas que solo aplican a esa categoría
  (% de nulos > 80% en otras categorías = atributo específico).
- Esto alimenta directamente el JSON Schema por categoría que T-008 modela.
```

### Caso 2 — Fórmula de costo total de O/P

```
El cliente tiene en `productos.xlsx` (o `cotizaciones.xlsx`) una columna calculada
"Costo total" con una fórmula tipo:
=B5*C5*VLOOKUP(D5,Tarifas!A:B,2)+E5*F5+G5

A5 debe:
- Extraer esa fórmula tal cual.
- Traducirla a pseudocódigo:
  "costo_total = minutos_maquina × cantidad × tarifa(maquina_id) + h_h × tarifa_trabajador + extras"
- Documentar QUÉ celdas referencia (qué tabla origen).
- Marcarla como "fórmula crítica para T-029".
```

### Caso 3 — Códigos de insumo inconsistentes

```
Mismo insumo aparece en dos archivos con códigos distintos:
- En `insumos.xlsx`: código "I-001"
- En `recetas.xlsx`: código "INS-001" o "001" o el nombre completo

A5 debe:
- Detectar la inconsistencia.
- Estimar cuántas filas afecta.
- Recomendar al PO: ¿se normaliza al código de `insumos.xlsx` antes de migrar?
- Esto alimenta T-021 (ETL piloto de insumos) y T-033 (ETL recetas).
```

### Caso 4 — Tarifas con celdas sobrescritas (sin historia)

```
El cliente "actualizó" las tarifas el último año varias veces, sobrescribiendo
la celda cada vez. NO hay historia de tarifas en el Excel.

A5 debe:
- Confirmar esto (no asumirlo).
- Reportar que NO HAY DATOS HISTÓRICOS de tarifas.
- Recomendar al PO: el sistema iniciará con tarifas actuales únicas;
  el cliente debe entender que las O/Ps históricas se recalcularán con
  la tarifa actual (no la que aplicó en su día).
- Esto valida la implementación de ADR-007 desde el día uno.
```

### Caso 5 — Relación oculta: cotización → orden de producción

```
El cliente tiene `cotizaciones.xlsx` y por separado `ordenes-produccion.xlsx`.
Aparentemente la columna "Folio cotización" en OPs apunta a `cotizaciones.xlsx`.

A5 debe:
- Detectar la FK implícita.
- Validar que los valores cruzan (% de OPs que apuntan a cotizaciones existentes).
- Reportar OPs huérfanas (sin cotización).
- Alimenta el schema de T-008 para decidir la FK.
```

### Caso 6 — Fórmulas con referencias externas

```
Algunos archivos tienen referencias a OTRO archivo Excel
(=[insumos.xlsx]Hoja1!$B$5).

A5 debe:
- Detectar esto.
- Listar las dependencias entre archivos.
- Reportar al PO: si se migran los datos pero no se preservan estas
  referencias, las fórmulas se rompen. Eso es esperado y deseable
  (queremos romper Excel para forzar uso del sistema), pero hay que
  comunicarlo.
```

### Caso 7 — Macros VBA

```
El cliente puede tener macros VBA. A5:
- Lista las macros encontradas con nombre y resumen.
- NO traduce VBA a Python automáticamente.
- Pasa al PO la pregunta: "¿esta macro X qué hace? ¿es lógica crítica
  del negocio o solo formato?".
- Solo después de tener respuesta del PO, se decide si una macro
  se convierte en endpoint del backend o se descarta.
```

---

## Lo que NO se debe hacer en esta tarea

- **No migrar datos a PostgreSQL todavía.** Solo análisis. La migración es T-021+.
- **No "limpiar" datos.** Reportar problemas, no corregirlos. El PO decide qué se limpia y cómo.
- **No commitear los Excel del cliente al repo.** Aunque sean los archivos de análisis (con datos reales), se mantienen fuera del repo. Ver "Privacidad" arriba.
- **No mostrar montos individuales ni nombres de clientes** en los reportes. Solo agregados.
- **No traducir macros VBA a Python.** Solo documentar.
- **No agregar dependencias innecesarias** (Polars, DuckDB, etc.). Pandas + openpyxl alcanza para análisis. Si en algún futuro ticket de migración hay performance issues, se evalúa.
- **No tocar el glosario directamente** — A5 sugiere a PO en el PR.
- **No tocar el schema.prisma** — A5 sugiere a TL en comentario del PR de T-008.
- **No prometer compatibilidad con macros**. Hablar de macros con PO para decidir caso por caso.

---

## Contratos y referencias

- **Contrato del agente:** [`agents/A5-etl.md`](../../agents/A5-etl.md)
- **Glosario:** [`docs/glossary.md`](../../docs/glossary.md) — T-009 lo está finalizando, A5 aporta términos descubiertos.
- **Schema v1:** [`docs/schema-v1.md`](../../docs/schema-v1.md) — T-008 lo está redactando, A5 aporta datos reales para validar.
- **ADRs relevantes:**
  - [ADR-004 JSONB para campos dinámicos](../../docs/adrs/ADR-004-jsonb-para-campos-dinamicos.md)
  - [ADR-007 Tarifas temporales](../../docs/adrs/ADR-007-tarifas-temporales.md)
  - [ADR-008 Excel validation como guardrail](../../docs/adrs/ADR-008-excel-validation-como-guardrail.md)
- **Sucesores ETL:** T-021 (insumos), T-033 (productos+recetas), T-044 (clientes).
- **Documentación pandas / openpyxl:** referenciar en `analysis/scripts/README.md`.

---

## Entregables

- [ ] 4 scripts Python ejecutables en `etl/analysis/scripts/`.
- [ ] `reports/inventario.md` + `reports/inventario.csv`.
- [ ] `reports/perfil-{archivo}.md` por cada archivo Excel.
- [ ] `reports/formulas-criticas.md`.
- [ ] `reports/relaciones-inferidas.md`.
- [ ] `reports/calidad-datos.md`.
- [ ] `etl/analysis/scripts/README.md` con instrucciones de uso.
- [ ] `etl/analysis/fixtures/README.md` con instrucciones de obtención de Excel.
- [ ] `etl/requirements.txt` actualizado.
- [ ] `etl/pyproject.toml` con config ruff/pytest.
- [ ] Tests mínimos en `etl/analysis/tests/`.
- [ ] Comentario en el PR con:
  - Lista de términos descubiertos que el PO debe agregar al glosario.
  - Lista de hallazgos que impactan el schema de T-008.
- [ ] Anuncio en `#erp-build` con resumen de hallazgos críticos.
- [ ] Commit: `feat(etl): inventario y perfilamiento de excel del cliente [A5]`
- [ ] PR con labels: `agent:A5`, `supervisor:PO`, `sprint:semana-1`, `priority:high`, `type:feature`

---

## Cómo invocar al agente en Claude Code

```bash
cd erp-project
git checkout -b feat/T-011-inventario-excel-cliente
claude
```

Prompt:

```
Ejecuta T-011 (inventario de Excel del cliente).

Actúas como agente A5. Lee en orden:
1. @CLAUDE.md
2. @agents/A5-etl.md
3. @prompts/backlog/T-011-inventario-excel-cliente.md (este ticket)
4. @docs/glossary.md (estado actual, T-009 lo está finalizando)
5. @docs/schema-v1.md (estado actual, T-008 lo está finalizando)
6. @docs/adrs/ADR-004-jsonb-para-campos-dinamicos.md
7. @docs/adrs/ADR-007-tarifas-temporales.md
8. @docs/adrs/ADR-008-excel-validation-como-guardrail.md

Antes de empezar, pregúntame:
1. ¿Dónde están los Excel del cliente? (ruta local, S3, drive)
2. ¿Confirmas la lista de archivos esperados? (espero ~7-8 archivos clave)
3. ¿Hay algún archivo confidencial que NO debo procesar? (nóminas, datos personales sueltos)
4. ¿Cuándo coordinamos la sesión de cierre? (necesito 45 min al final)

⚠️ Recordatorios:
- Solo lectura de Excel del cliente.
- Anonimizar antes de escribir a reports/.
- No subir Excel del cliente al repo.
- Si descubres macros VBA, NO traducirlas a Python — solo documentar.
- Si descubres términos no glosados, NO modificar el glosario — apunta al PO en el PR.
```

---

## Validación post-ejecución (lo llena PO)

```bash
cd etl/analysis

# 1. Verificar reportes generados
ls reports/
# Esperado: inventario.md, inventario.csv, perfil-*.md, formulas-criticas.md,
#           relaciones-inferidas.md, calidad-datos.md

# 2. Re-correr los scripts y verificar idempotencia
python scripts/01-inventario-archivos.py --input fixtures/cliente/ --output /tmp/inv2.md
diff reports/inventario.md /tmp/inv2.md
# Esperado: solo difieren en timestamp del header

# 3. Verificar ausencia de datos personales en reports/
grep -E "[0-9]{8,9}-[0-9Kk]" reports/  # buscar RUTs
# Esperado: ningún resultado

grep -E "Cliente.*S\.?A\.?|Ltda" reports/  # buscar razones sociales
# Esperado: solo "cliente-1", "cliente-2", etc.

# 4. Verificar que ningún Excel del cliente quedó commiteado
git status
git ls-files | grep -E "\.xlsx$"
# Esperado: ningún archivo .xlsx en el repo

# 5. Lint y tests
ruff check etl/
pytest etl/analysis/tests/
```

- **Fecha de cierre:** _pendiente_
- **Archivos inventariados:** _pendiente (esperado: 7-8)_
- **Pestañas perfiladas:** _pendiente_
- **Fórmulas críticas extraídas:** _pendiente_
- **Relaciones inferidas:** _pendiente_
- **% de filas con problemas detectadas:** _pendiente_
- **Macros VBA encontradas:** _pendiente_
- **Términos para agregar al glosario:** _pendiente_
- **Hallazgos que impactan el schema:** _pendiente_
- **Resultado:** _pendiente_

---

## Notas para el PO

**Antes de aprobar el merge:**

- Pide a A5 que te muestre los **3 hallazgos más sorprendentes** del análisis. Si todos son obvios y conocidos, A5 no fue lo suficientemente profundo.
- Revisa que los reportes están **anonimizados** — abre uno con `grep` por patrones de RUTs, razones sociales, montos individuales. Cero ocurrencias.
- Pide a A5 que te muestre cuántas fórmulas críticas extrajo y cuáles son las top 5 más complejas. Esas son las que el motor de costos (T-029) tendrá que replicar.

**Comunicación con el cliente:**

- Después de mergear, agenda una reunión con el cliente (30 min) para presentar los hallazgos más relevantes. Esto:
  - Demuestra al cliente que estás tomando en serio sus datos.
  - Abre la conversación sobre limpieza pre-migración (algunos clientes prefieren limpiar el Excel antes que el equipo lo haga vía ETL).
  - Recoge feedback sobre fórmulas que A5 no entendió.

**Coordinación con otros tickets:**

- **T-008 (schema v1):** después de mergear T-011, abre comentario en el PR de T-008 con los hallazgos que afectan el modelo. El TL ajusta.
- **T-009 (glosario):** abre comentario en el PR con los términos nuevos. Tú los validas con el cliente y los agregas.
- **T-021, T-033, T-044 (ETLs reales):** estos tickets dependen del inventario. Si en T-011 descubrimos que los datos están peor de lo esperado, conversa con TL si hay que extender los puntos estimados de esos tickets.

**Prerrequisitos:**

- T-001 (estructura repo) ✅
- Acceso a los Excel del cliente.
- Glosario inicial (T-009 puede estar en progreso, no bloqueante).
- Schema v1 inicial (T-008 puede estar en progreso, no bloqueante).

**Sucesores:**

- T-021 (ETL piloto insumos).
- T-033 (ETL productos+recetas).
- T-044 (ETL clientes).
- T-034 (validación motor costos vs Excel — usa las fórmulas extraídas aquí).

---

**Creado:** 2026-04-28 por PO + A5 (kick-off conjunto)
**Plantilla base:** `prompts/templates/ticket-template.md` v1.0
