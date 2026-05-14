# T-009 · Glosario de negocio firmado con el cliente

**Ticket Jira:** https://tu-org.atlassian.net/browse/T-009
**Agente asignado:** — (tarea humana)
**Supervisor humano:** PO (Product Owner)
**Sprint:** Semana 1 — Fundamentos
**Estimación:** 2 puntos
**Prioridad:** alta
**Rama:** `docs/T-009-glosario-firmado`

---

## ⚠️ Ticket humano (no se delega a agentes IA)

Este ticket lo lleva el **Product Owner**. **No se asigna a ningún agente IA** porque:

1. **El glosario es un contrato semántico con el cliente.** Una palabra que el cliente usa puede tener un significado específico en su industria que no aparece en diccionarios ni en código. Solo una persona puede sentarse con el cliente y validarlo.
2. **Firmar implica acuerdo legal-comercial.** Si después aparece una disputa por la interpretación de un término ("¿qué cuenta como h/h trabajada?"), el glosario firmado es la referencia.
3. **El resultado alimenta a todos los agentes**. El `CLAUDE.md` ya referencia a `docs/glossary.md` como "lectura obligatoria antes de tocar dominio". Un glosario equivocado contamina silenciosamente todo lo que los agentes IA produzcan después.

El PO conduce este ticket, pero TL y los supervisores S1, S2 revisan y firman como co-responsables técnicos.

---

## Contexto de negocio

El proyecto reemplaza un ecosistema Excel con jerga propia del cliente acumulada durante 8 años. Esa jerga tiene tres tipos de problemas:

1. **Palabras propias de la industria** que el equipo de desarrollo no conoce con precisión (h/h, tipo de cobro mixto, costo/min máquina, leasing, OP, OV, receta, variante).
2. **Palabras comunes con significado específico**. Por ejemplo "cierre" puede significar (a) cerrar una OP, (b) cerrar contablemente un mes, (c) cerrar una cotización pasándola a OV. Sin contexto, los agentes IA inventan.
3. **Palabras que el cliente usa de forma inconsistente** entre departamentos. Bodega llama "ajuste de stock" a lo que producción llama "mermas". Documentar la divergencia es parte del trabajo.

El glosario actual (`docs/glossary.md`) ya tiene ~30 términos. Este ticket lo **completa, contrasta con el cliente y obtiene firma formal**.

---

## Alcance técnico

### Crear / actualizar

```
docs/
├── glossary.md                          ← documento principal del ticket
└── sessions/
    └── 2026-04-XX-firma-glosario.md     ← acta de la sesión con el cliente
```

### Modificar

- `CLAUDE.md` — verificar que la sección "Glosario rápido" refleja al menos los 10 términos más críticos del glosario completo.
- `docs/events.md` — si algún evento usa un nombre distinto del término oficial, alinear.
- `docs/architecture.md` — pasada de revisión por consistencia de términos.

### No tocar

- **Schema de BD**. Si el glosario revela que una entidad debería llamarse distinto, se anota en `docs/schema-v1.md` (T-008) como descubrimiento, pero el rename de BD lo hace un ticket técnico aparte si llega a hacerse.
- **Código fuente**. Renombrar variables/funciones por hallazgos de glosario es un ticket de refactor aparte.

---

## Criterios de aceptación

### Cobertura mínima del glosario

- [ ] **Bodega:** insumo, categoría de insumo, movimiento, entrada, salida, ajuste, merma, stock crítico, stock mínimo, lote (si aplica), unidad de medida.
- [ ] **Producción:** producto, receta, versión de receta, variante, atributos dinámicos, máquina, tipo de trabajador, horas-hombre (h/h), minutos máquina, tarifa, tarifa por minuto, costo/min máquina, costo unitario, OP (orden de producción), fase, estado de OP, cierre de OP, costo total de OP.
- [ ] **Ventas:** cotización, línea de cotización, vigencia de cotización, OV (orden de venta), conversión cotización→OV, condiciones comerciales, cliente frecuente, descuento global, plazo de pago, confirmación de OV.
- [ ] **Cobros:** tipo de cobro por minuto, por unidad, mixto, ajuste de cobro.
- [ ] **Operación interna:** bodeguero, jefe de producción, vendedor, gerencia, administrador, tenant, schema (tenant), rol, permiso.
- [ ] **Decisiones del cliente fuera del MVP** (aclaratorias para no asumir): RR.HH., leasing, marketing, proyecciones. Listadas como "fuera de MVP" para evitar que aparezcan accidentalmente en una conversación o ticket.

### Estructura de cada entrada

Cada término sigue esta estructura:

```markdown
### <Término>

**Categoría:** bodega | produccion | ventas | cobros | operacion | fuera-de-mvp
**Sinónimos:** <otras formas en que el cliente lo dice>
**No confundir con:** <términos parecidos pero distintos>

<Definición de 1-3 frases en lenguaje del cliente, no técnico.>

**Ejemplo concreto:**
<Caso real del cliente. Idealmente extraído de su Excel.>

**Cómo aparece en el sistema:**
- En la BD: tabla `<nombre>` / columna `<nombre>`
- En el API: endpoint `<path>`
- En la UI: módulo "<nombre que ve el usuario>"
- En eventos: `<dominio>.<entidad>.<accion>.v1` (si aplica)

**Aprobado por:** <iniciales del cliente> el <fecha>
```

### Validación con el cliente

- [ ] Reunión presencial o por video con al menos **3 personas del cliente**:
  - Una de operaciones (bodega o producción).
  - Una del área comercial/ventas.
  - Una de gerencia/administración.
- [ ] Cada término crítico (mínimo 30) revisado uno por uno con los 3 representantes.
- [ ] Cuando hay desacuerdo entre departamentos del cliente, se **documenta el desacuerdo** y se elige la versión que el ERP usará (con justificación). El cliente firma esa elección, aunque internamente no haya consenso total.
- [ ] Cuando el cliente usa un término que tiene un sinónimo común en la industria, ambos se listan y el PO elige el canónico (el otro queda como sinónimo).

### Firma formal

- [ ] El cliente firma una copia impresa o digital del documento al cierre de la reunión.
- [ ] La firma se materializa como:
  - **PDF firmado** (si hay firma digital) guardado en `docs/sessions/2026-04-XX-firma-glosario.pdf`.
  - O **acta de sesión con nombres + fecha** en `docs/sessions/2026-04-XX-firma-glosario.md` con texto: "Las personas listadas firman que el contenido de `docs/glossary.md` (commit hash <sha>) representa fielmente la terminología del negocio."
- [ ] El sha del commit del glosario queda registrado en el acta.

### Coherencia con el resto del proyecto

- [ ] **Cero términos del glosario están en inglés** salvo los técnicos transversales del stack (API, JSON, SQL, etc.). Si el cliente dice "cliente" en español, el glosario dice "cliente", no "customer".
- [ ] **Los nombres de entidades del schema-v1 (T-008) usan los términos canónicos del glosario.** Si el glosario dice "insumo" pero el schema dice "supply" en inglés, hay que alinear.
- [ ] **Los nombres de eventos en `docs/events.md` usan los términos canónicos.** `bodega.movimiento.registrado.v1` es coherente con que el cliente diga "movimiento" (no "transaction" ni "moviment").
- [ ] **Los textos en la UI (a futuro)** deben usar los términos canónicos.

### Sección "Términos NO aprobados"

- [ ] Al final del glosario, una sección lista términos que el cliente **explícitamente pidió evitar**:
  - Términos en inglés mezclados ("vamos a hacer un check-in" → no).
  - Términos de versiones anteriores del software del cliente que ya no usan.
  - Términos de otros sistemas (Oracle, SAP) que pueden generar confusión.

### Versionado del glosario

- [ ] El glosario tiene un campo **`Versión: 1.0`** y **`Fecha: 2026-04-XX`** al inicio.
- [ ] Cada vez que cambie significativamente, se incrementa versión y se documenta el cambio en una sección "Changelog" al final.
- [ ] Cambios menores (typo, ejemplo nuevo) no incrementan versión.

---

## Invariantes que el PO DEBE respetar

1. **Ningún término se agrega sin validación del cliente.** Si el PO inventa una definición para acelerar, contamina el sistema.
2. **No se "traducen" términos del cliente al lenguaje del equipo de desarrollo.** Si el cliente dice "marcador de máquina", el glosario dice "marcador de máquina", aunque para un desarrollador "marker" suene mejor.
3. **Términos sin acuerdo no se "deciden" técnicamente.** Si bodega y producción usan dos significados distintos y ninguno cede, se elige uno y se anota explícitamente el conflicto sin resolver. NO se inventa un término nuevo "neutro".
4. **El acta de la sesión es obligatoria.** Aunque haya whatsapp del cliente diciendo "ok todo perfecto", se necesita el acta formal con nombres y fecha.
5. **El glosario es la fuente de verdad sobre terminología.** Si después aparece conflicto con un documento más antiguo, gana el glosario.

---

## Casos de uso obligatorios que el glosario debe resolver

Para cada caso, ilustrar **cómo el glosario resuelve la ambigüedad**:

### Caso 1 — Diferencia entre "cerrar OP" y "cerrar mes"

```
El bodeguero dice: "cerramos el día"
El jefe de producción dice: "cerramos la OP"
El contador dice: "cerramos el mes"

Glosario debe distinguir:
- cierre operativo de turno (sin entidad de BD, es un acto operativo)
- cierre de OP (entidad `ordenes_produccion`, columna `cerrada_en`)
- cierre contable (no es MVP)
```

### Caso 2 — Diferencia entre "ajuste", "merma" y "diferencia de inventario"

```
Bodega tiene 3 conceptos parecidos:
- "ajuste de stock": corrección manual sin causa de negocio (error de tipeo)
- "merma": pérdida real (rotura, vencimiento)
- "diferencia de inventario": resultado de un conteo físico vs sistema

Glosario debe definir los 3 + mapear a `tipo` del modelo `movimientos`.
```

### Caso 3 — Tipo de cobro mixto

```
El cliente vende un servicio que se cobra:
- $X por minuto de operación de máquina
- + $Y por unidad producida
- + a veces un fijo por setup

El glosario debe definir qué exactamente compone un "cobro mixto" para
que el motor de costos (T-029) lo refleje sin ambigüedad.
```

### Caso 4 — Cliente vs cliente final

```
"Cliente" del proyecto = la empresa que paga el ERP.
"Cliente final" = a quién le vende esa empresa.

En el glosario, "cliente" siempre se refiere al cliente FINAL
(el de la empresa). El "cliente del proyecto" se llama "empresa"
o "tenant" según contexto.
```

### Caso 5 — Variante vs versión de receta

```
Una receta puede tener varias VERSIONES en el tiempo (cambia un insumo, sube un porcentaje).
Una variante de PRODUCTO puede tener su propia receta.

Glosario debe distinguir:
- versión de receta (eje temporal)
- variante de producto (eje atributos)
- Y la combinación: cada variante puede tener varias versiones de su receta.
```

### Caso 6 — h/h vs horas reales trabajadas

```
"h/h" (horas-hombre) es una unidad de medida del costo: 1 trabajador × 1 hora.
"horas trabajadas" puede sonar igual pero a veces el cliente lo usa para
el reloj registrador (entrada/salida) sin importar productividad.

Glosario debe distinguir los dos y aclarar que el motor de costos usa h/h.
```

### Caso 7 — Bodeguero vs administrador de bodega

```
El cliente a veces dice "bodeguero" y a veces "encargado de bodega"
para referirse a la misma persona/rol.

¿Hay diferencia? Si sí, glosario los distingue. Si no, define el canónico
y lista el otro como sinónimo.
```

---

## Lo que NO se debe hacer en esta tarea

- **No incluir términos que no aparezcan en el MVP.** Si "leasing" o "RR.HH." están fuera de MVP, listarlos como tal pero no profundizar definiciones — eso vendrá en su propio glosario futuro.
- **No incluir terminología puramente técnica** (API, JSON, REST, JWT, etc.). El glosario es de **negocio**. La técnica está en otros documentos.
- **No traducir el glosario a otros idiomas**. El cliente trabaja en español. Si en el futuro hay tenants en otro idioma, se traducirá entonces.
- **No "completar" el glosario con definiciones inventadas para acelerar el ticket.** Vale más entregar un glosario de 25 términos sólidos que uno de 60 con la mitad inventada.
- **No mergear sin firma del cliente.** Si la reunión no se puede cerrar en esta semana, se mueve el ticket al siguiente sprint. Sin firma, no cuenta.
- **No mezclar este ticket con el de schema (T-008).** Aunque están relacionados, el glosario lo firma el cliente y el schema lo firma el equipo técnico. Mezclarlos diluye ambas responsabilidades.

---

## Contratos y referencias

- **Glosario actual:** [`docs/glossary.md`](../../docs/glossary.md) — punto de partida del ticket.
- **Sucesor inmediato:** [T-008 Schema PostgreSQL v1](T-008-schema-postgresql-v1.md) — el schema se redacta usando los términos del glosario.
- **Documentación relacionada que usa los términos:**
  - [`docs/events.md`](../../docs/events.md)
  - [`docs/architecture.md`](../../docs/architecture.md)
  - [`docs/rbac-matrix.md`](../../docs/rbac-matrix.md)
- **Excel del cliente:** acceso a confirmar con el cliente — al menos al archivo de insumos, productos y cotizaciones.

---

## Entregables

- [ ] `docs/glossary.md` actualizado con cobertura completa, ejemplos, sinónimos y categorías.
- [ ] `docs/sessions/2026-04-XX-firma-glosario.md` con acta de la sesión.
- [ ] Si hay firma digital: `docs/sessions/2026-04-XX-firma-glosario.pdf` adjunto.
- [ ] Anuncio en `#erp-build` con resumen para que todos los supervisores actualicen su lenguaje.
- [ ] Si se descubren incoherencias en otros documentos, lista de ajustes pendientes para tickets de seguimiento.
- [ ] Versión 1.0 etiquetada en el header del documento.
- [ ] Commit: `docs(glossary): firma cliente — terminología v1.0 [PO]`
- [ ] PR con labels: `supervisor:PO`, `sprint:semana-1`, `priority:high`, `type:docs`

---

## Proceso recomendado

### Pre-sesión (PO solo, 90 minutos)

1. Releer el glosario actual y marcar los términos con dudas.
2. Releer notas de descubrimiento del proyecto (entrevistas iniciales con el cliente).
3. Identificar los **3 representantes del cliente** y agendar una sesión de 2 horas.
4. Preparar **ejemplos concretos** de cada término ambiguo extraídos del Excel real del cliente.
5. Imprimir o tener listo el documento en una pantalla compartida para anotar en vivo.

### Sesión con el cliente (2 horas presencial o video)

1. **Apertura (10 min):** explicar al cliente por qué este ejercicio importa para que el sistema se construya bien.
2. **Revisión término por término (90 min):** PO lee la definición propuesta, los representantes confirman / corrigen / agregan ejemplos. PO anota en vivo.
3. **Resolución de ambigüedades (15 min):** los 7 casos obligatorios anteriores se discuten explícitamente, aunque en la revisión anterior no surgieron.
4. **Cierre y firma (5 min):** PO resume cambios, los representantes confirman, se firma.

### Post-sesión (PO solo, 60 minutos)

1. Limpiar y formatear el documento.
2. Revisar coherencia entre el glosario y `docs/events.md`, `docs/architecture.md`, `docs/rbac-matrix.md`.
3. Listar incoherencias detectadas para tickets de seguimiento.
4. Abrir el PR y mencionar a TL, S1, S2 para revisión cruzada (no para que cambien definiciones del cliente, sino para que las reflejen en sus áreas).

---

## Validación post-ejecución (lo llena el PO)

```bash
# 1. Conteo de términos
grep -c "^### " docs/glossary.md
# Esperado: al menos 30, idealmente 40+

# 2. Categorías cubiertas
for cat in bodega produccion ventas cobros operacion fuera-de-mvp; do
  count=$(grep -c "Categoría:.*$cat" docs/glossary.md || echo 0)
  echo "$cat: $count términos"
done

# 3. Cada término tiene ejemplo y aprobación
grep -c "Aprobado por:" docs/glossary.md
# Esperado: igual al número total de términos críticos

# 4. Acta firmada existe
ls -la docs/sessions/2026-*-firma-glosario.*

# 5. CLAUDE.md "Glosario rápido" tiene al menos 10 términos críticos
grep -A 30 "Glosario rápido" CLAUDE.md | grep -c "^- \*\*"
# Esperado: >= 10
```

- **Fecha de la sesión:** _pendiente_
- **Asistentes del cliente:** _pendiente_
- **Asistentes del equipo:** _pendiente (PO + opcional TL)_
- **Términos revisados:** _pendiente_
- **Ambigüedades resueltas:** _pendiente_
- **Cliente firmó:** _sí/no — pendiente_
- **Incoherencias detectadas para tickets de seguimiento:** _pendiente_
- **Resultado:** _pendiente_

---

## Notas para el PO

**Cómo manejar conflictos en la sesión:**

- Si bodega y producción discrepan sobre el significado de "merma", **no resuelvas tú la disputa.** Documenta ambas posiciones, propon una resolución técnica (ej: "en el sistema lo llamamos así con campo `tipo` que distingue"), y pide al cliente que valide.
- Si el cliente quiere agregar un término que no parece de MVP, anótalo como "fuera de MVP — revisar en módulo 2".
- Si el cliente desconoce un término que aparece en su propio Excel ("¿qué es 'fee de re-trabajo'?"), eso es información muy valiosa — significa que es legado y probablemente se puede eliminar. Anótalo aparte para próxima conversación.

**Cómo conectar con T-008 y T-011:**

- T-008 (schema v1) **depende** de que este glosario esté firmado. Aunque T-008 puede empezar en paralelo, no se firma hasta que el glosario esté listo.
- T-011 (inventario Excel) lo ejecuta A5 con tu supervisión. El glosario lo guía: A5 marca términos del Excel que NO están en el glosario y los reporta para que tú los agregues.

**Prerrequisitos:**

- T-001 completado (repo existe con `docs/glossary.md` inicial).
- Acceso a representantes del cliente (al menos 2 horas en su agenda).
- Acceso al Excel del cliente para extraer ejemplos.

**Sucesores:**

- T-008 (schema v1) usa el glosario para nombrar entidades.
- T-011 (inventario Excel) usa el glosario para clasificar columnas.
- T-022 (OpenAPI bodega) usa el glosario para nombrar campos del API.
- Todos los tickets de implementación posteriores usan el glosario como referencia.

---

**Creado:** 2026-04-28 por PO
**Plantilla base:** `prompts/templates/ticket-template.md` v1.0 con adaptaciones para ticket humano
**Tipo:** contrato semántico con el cliente
