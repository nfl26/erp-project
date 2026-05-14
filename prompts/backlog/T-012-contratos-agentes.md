# T-012 · Contratos de los 7 agentes IA finalizados y firmados

**Ticket Jira:** https://tu-org.atlassian.net/browse/T-012
**Agente asignado:** — (tarea humana)
**Supervisor humano:** TL (Tech Lead) con revisión de cada supervisor de agente (S1, S2, S3, PO, DO, QA)
**Sprint:** Semana 1 — Fundamentos
**Estimación:** 3 puntos
**Prioridad:** crítica
**Rama:** `docs/T-012-contratos-agentes`

---

## ⚠️ Ticket humano (no se delega a agentes IA)

Este ticket lo conduce el **Tech Lead** con revisión obligatoria de cada supervisor de agente. **No se delega a agentes IA** por una razón fundamental: pedirle a un agente IA que redacte el contrato que rige a otro (o a sí mismo) crea un conflicto de jurisdicción imposible de auditar. El contrato es un instrumento humano para gobernar lo que la IA produce, no un producto de la IA misma.

Los borradores actuales de los 7 contratos (en `agents/A1-nestjs.md` ... `agents/A7-devops.md`) ya existen y son funcionales: el equipo los ha estado usando informalmente durante los tickets T-001 a T-011. Este ticket cierra el ciclo: convierte esos borradores en **contratos firmados versionados** que no se modifican sin ceremonia formal.

A partir del merge de este ticket:
- Cualquier modificación a un contrato exige aprobación en "Prompt review" mensual.
- Los PRs de agentes se revisan contra el contrato vigente; desviaciones se documentan o se rechazan.
- Si la realidad del trabajo demuestra que un contrato no encaja, no se "interpreta" — se redacta una nueva versión.

---

## Contexto de negocio

El proyecto opera bajo una premisa arriesgada: **7 agentes IA generan ~80% del código** bajo supervisión humana de 7 personas. Sin reglas claras de jurisdicción, este modelo se desmorona en 2 semanas:

- Dos agentes modifican el mismo archivo en PRs paralelos y se sobreescriben.
- Un agente "ayuda" arreglando algo en el dominio de otro y rompe invariantes que no conocía.
- Un supervisor revisa un PR sin tener forma de saber qué *debería* haber producido el agente.
- El día que cambiemos de modelo de IA, no hay forma de preservar la coherencia porque está toda en la cabeza de las personas.

**Los contratos resuelven los 4 problemas.** Por eso son contenido del repo, versionados como código, y por eso este ticket es **crítico** y vive en el Sprint 0.

Hoy los contratos existen como borradores funcionales (A1 y A2 ya están en v2.0 tras la decisión de ADR-010; el resto en v1.0). Falta:

1. **Validación cruzada entre supervisores** — que cada uno lea no solo el suyo sino los adyacentes, para detectar conflictos de borde.
2. **Validación contra la realidad de los primeros tickets** — los aprendizajes de T-001 a T-011 deben reflejarse antes de "firmar".
3. **Firma formal** — checksum + acta de revisión que congele la versión 1.0/2.0 oficial.
4. **Documentación del proceso de cambio** — qué hace falta para modificar un contrato.

---

## Estado actual de los 7 contratos

Inventario al inicio del ticket (versiones encontradas en `agents/`):

| ID | Archivo | Versión actual | Estado | Cambios pendientes detectados |
|---|---|---|---|---|
| A1 | `A1-nestjs.md` | **v2.0** | Borrador funcional | Validar que sección "Dominio propio" lista `modules/produccion` tras ADR-010 |
| A2 | `A2-springboot.md` | **v2.0** | Borrador funcional, EN ESPERA | Validar coherencia con ADR-010 y T-005 reinterpretado |
| A3 | `A3-nextjs.md` | **v1.0** | Borrador funcional | Validar tras experiencia de T-006 |
| A4 | `A4-angular.md` | **v1.0** | Borrador funcional | Validar tras experiencia de T-007 |
| A5 | `A5-etl.md` | **v1.0** | Borrador funcional | Validar tras experiencia de T-011 (inventario Excel) |
| A6 | `A6-qa.md` | **v1.0** | Borrador funcional | Sin ejecuciones reales aún — más expuesto a ajustes futuros |
| A7 | `A7-devops.md` | **v1.0** | Borrador funcional | Validar tras experiencia de T-001, T-002, T-003, T-010 |

El TL valida que esta tabla es correcta al iniciar el ticket. Si hay versión distinta a la registrada, ajustar.

---

## Alcance técnico

### Crear

```
agents/
├── REGISTRO-FIRMAS.md                    ← acta de firmas de los 7 contratos v1.0/v2.0
├── PROCESO-MODIFICACION.md               ← cómo se modifica un contrato
└── CHANGELOG.md                          ← cambios por contrato y por versión

docs/sessions/
└── 2026-04-XX-firma-contratos-agentes.md ← acta de la(s) sesión(es) de revisión
```

### Modificar

- `agents/A1-nestjs.md` ... `agents/A7-devops.md` — ajustes finales por revisión cruzada y por aprendizajes de tickets ya ejecutados.
- `agents/README.md` — agregar referencias a `REGISTRO-FIRMAS.md`, `PROCESO-MODIFICACION.md`, `CHANGELOG.md`.
- `CLAUDE.md` raíz — verificar que la sección "Agentes" está alineada con los contratos firmados (puede haber discrepancias menores en stack o territorio).
- `docs/architecture.md` — verificar que el diagrama de agentes coincide con la tabla del README de `agents/`.

### No tocar

- **Estructura común de los contratos.** Las 11 secciones (Identidad, Misión, Dominio propio, etc.) son canónicas. Si un contrato necesita una sección nueva, se discute en la sesión y se aplica a TODOS, no solo a uno.
- **ADRs vigentes.** Si la revisión revela que un ADR está desalineado con un contrato, el ADR gana (los ADRs son decisiones arquitectónicas formales). El contrato se ajusta, no el ADR.
- **Contratos de roles humanos** (TL, PO, supervisores). Este ticket es solo para agentes IA. Los roles humanos se documentan en `docs/team.md` o equivalente, pero no en `agents/`.

---

## Criterios de aceptación

### Validación cruzada entre supervisores

- [ ] Cada supervisor lee **el contrato de su agente + los dos adyacentes en su línea de trabajo**:
  - S1 (A1) lee también A2, A6 (porque QA toca código de A1).
  - S2 (A2) lee también A1, A5 (porque ETL alimenta producción).
  - S3 (A3 y A4) lee también A6.
  - PO (A5) lee también A1, A2 (porque ETL desemboca en estos dominios).
  - DO (A7) lee A1, A2, A3, A4, A5 (porque infra toca todo).
  - QA (A6) lee A1, A2, A3, A4, A5 (porque escribe tests para todos).
- [ ] Cada supervisor anota en el acta:
  - Qué borde con otro agente NO está claro y necesita ajuste.
  - Qué capacidad o restricción del contrato adyacente le sorprendió.
  - Qué invariante del agente vecino debería ser obvia y no lo es.

### Validación contra la realidad de Sprint 0

- [ ] Para cada contrato, el supervisor responde: *"En los tickets ya ejecutados de este agente, ¿el contrato describió correctamente lo que el agente debía hacer?"*
- [ ] Casos específicos a validar:
  - **A1**: contrato vs ejecución de T-004 (NestJS base) y T-005 (módulo producción).
  - **A3**: contrato vs ejecución de T-006 (Next.js base).
  - **A4**: contrato vs ejecución de T-007 (Angular base).
  - **A5**: contrato vs ejecución de T-011 (inventario Excel).
  - **A7**: contrato vs ejecuciones de T-001, T-002, T-003, T-010.
- [ ] Para A2 y A6 (sin ejecuciones aún): el supervisor proyecta. *"Si mañana asigno este ticket a este agente, ¿el contrato lo guía bien?"* — al menos 3 tickets futuros de su backlog.

### Conflictos de borde resueltos

Hay 6 conflictos de borde conocidos a validar específicamente. Para cada uno, el contrato debe ser explícito sobre quién decide:

- [ ] **A1 ↔ A2**: ¿quién toca `modules/produccion/` mientras A2 está en ESPERA? → contrato A1 dice "A1, hasta extracción"; contrato A2 dice "EN ESPERA". Coherente.
- [ ] **A1 ↔ A6**: ¿quién escribe tests unitarios de NestJS? → contrato A6 dice "QA escribe los tests, A1 no los borra". Validar que A1 lo refleja en sus restricciones.
- [ ] **A3 ↔ A4**: ¿quién define los tokens CSS compartidos? → coordinación obligatoria. Validar que ambos contratos lo mencionan.
- [ ] **A3/A4 ↔ A1**: ¿quién define los DTOs del API? → A1 con OpenAPI; A3/A4 los consumen. Validar.
- [ ] **A5 ↔ A1**: ¿A5 puede insertar en BD directamente o pasa por endpoints de A1? → contrato A5 debe ser explícito.
- [ ] **A7 ↔ todos**: A7 toca Dockerfiles dentro de `services/erp-api/`. ¿Es invasión? → contrato A7 lo aclara: A7 toca Dockerfiles, no `src/`.

### Coherencia con ADRs vigentes

Validar cada contrato contra ADRs:

- [ ] **A1 y A2 ↔ ADR-010 (monolito modular):** los dos contratos deben reflejar v2.0 (A1 dueño de producción, A2 en espera).
- [ ] **A1 ↔ ADR-003 (multi-tenancy por schema):** debe mencionar el tenant middleware y `search_path`.
- [ ] **A1 ↔ ADR-004 (JSONB para variantes):** debe mencionar la validación con JSON Schema.
- [ ] **A1 ↔ ADR-005 (stock calculado):** debe prohibir tablas materializadas no documentadas.
- [ ] **A1 (y futuro A2) ↔ ADR-007 (tarifas temporales):** debe listar la invariante "tarifa cerrada inmutable".
- [ ] **A1 ↔ ADR-008 (Excel como guardrail):** debe mencionar el fixture de 50+ casos y el ≥99% match.
- [ ] **A5 ↔ ADR-008:** A5 produce los fixtures, debe estar listado.
- [ ] **A7 ↔ ADRs operativos** (002 docker-compose, 006 gitops, 009 observabilidad si existe): coherente.

### Sección "Métricas" en cada contrato

Cada contrato debe tener una sección **Métricas** con al menos 3 métricas medibles del agente. Esto permite evaluar si el agente está cumpliendo. Ejemplos por agente:

- **A1**: % cobertura módulos críticos, # PRs con violación de invariantes detectadas en QA, tiempo medio de ejecución por ticket.
- **A3 / A4**: tamaño First Load JS / initial bundle, # bugs visuales reportados post-merge, # PRs con cambios de tokens no coordinados.
- **A5**: % filas migradas sin error, # fórmulas Excel correctamente traducidas a backend, tiempo de ejecución de pipeline.
- **A6**: cobertura global, # tests rotos por commits del propio agente que los escribió, tiempo de ejecución de suite completa.
- **A7**: tiempo de `dev-up.sh`, # rollbacks de deploy, # PRs con secretos commiteados (debe ser 0).

Si algún contrato no tiene métricas, agregar al menos 3.

### `agents/REGISTRO-FIRMAS.md`

Documento con la siguiente estructura para cada contrato:

```markdown
## A<N> — <Nombre del agente>

- **Versión firmada:** 1.0 (o 2.0)
- **Fecha de firma:** 2026-04-XX
- **Archivo:** `agents/A<N>-<stack>.md`
- **Hash SHA-256:** `<hash del archivo al momento de firmar>`
- **Firmado por:**
  - <Supervisor>: <iniciales + fecha>
  - TL: <iniciales + fecha>
- **Cambios futuros:** registrar en `agents/CHANGELOG.md` con bump de versión.
```

- [ ] Las 7 entradas existen.
- [ ] Cada hash SHA-256 se calcula al cierre del ticket y se registra (script: `sha256sum agents/A1-nestjs.md`).
- [ ] Cada entrada tiene **al menos 2 firmas**: el supervisor del agente + el TL.
- [ ] Si un contrato cambia en futuras versiones, este documento NO se sobrescribe — se agrega una entrada nueva por versión.

### `agents/PROCESO-MODIFICACION.md`

Documento que define **cómo se modifica un contrato firmado**. Cubre:

- [ ] **Triggers que justifican modificar un contrato:**
  - Un ADR nuevo cambia el dominio del agente (ej: ADR-010 cambió A1 y A2).
  - El agente sistemáticamente no puede cumplir una capacidad listada → reducir scope.
  - El agente sistemáticamente termina haciendo algo que no estaba listado → agregar al contrato o agregar restricción explícita.
  - Cambio de stack (ej: A4 migra de Angular 17 a 18) que cambia patrones.
- [ ] **Triggers que NO justifican modificar un contrato:**
  - Un ticket puntual donde el agente "necesitó" salirse del contrato (eso se documenta como excepción en el PR, no se cambia el contrato).
  - Preferencias estéticas de código.
  - Conveniencia para acelerar un sprint.
- [ ] **Proceso de modificación:**
  1. Quien propone el cambio abre un PR con `agents/A<N>-*.md` modificado y bump de versión menor o mayor según corresponda.
  2. El PR se discute en la próxima ceremonia "Prompt review" (mensual).
  3. Para aprobar: firma del supervisor del agente + TL.
  4. Si afecta a otros agentes (ej: redefinir un borde), firma del supervisor afectado también.
  5. Al merge: actualizar `REGISTRO-FIRMAS.md` (nueva entrada) y `CHANGELOG.md`.
- [ ] **Semántica de versionado:**
  - **MAYOR** (1.0 → 2.0): cambia el stack, el territorio, o invariantes críticas. Requiere migración deliberada (como pasó con A1 v1→v2).
  - **MENOR** (1.0 → 1.1): agrega capacidad, aclara restricción, ajusta métrica. No invalida tickets en curso.
  - **PARCHE** (1.0 → 1.0.1): typo, ejemplo, mejora de redacción. No requiere ceremonia, basta con aprobación del supervisor.

### `agents/CHANGELOG.md`

- [ ] Entrada por contrato listando cambios desde su creación.
- [ ] Para los 7 contratos, registrar el estado inicial al cierre del ticket:
  ```markdown
  ## A1 — Arquitecto NestJS
  - **2026-04-XX (v2.0):** Firmado. A1 absorbe módulo producción tras ADR-010.
  - **2026-04-XX (v1.0):** Borrador inicial.

  ## A2 — Ingeniero Producción
  - **2026-04-XX (v2.0):** Firmado. Estado EN ESPERA hasta extracción del monolito.
  - **2026-04-XX (v1.0):** Borrador inicial (Spring Boot).

  ... (y así con A3 a A7)
  ```
- [ ] El changelog menciona los **PRs** que introdujeron cada cambio (links a Jira o GitHub).

### Coherencia con `CLAUDE.md`

- [ ] Verificar que la sección "Agentes IA" de `CLAUDE.md` (raíz) lista los 7 con stack, territorio y supervisor coincidentes con los contratos firmados.
- [ ] Si hay discrepancia, ganan los contratos firmados (son la fuente de verdad), y se ajusta `CLAUDE.md` en este mismo PR.

### Sesión(es) de revisión

- [ ] **Sesión 1 (90 min):** TL + S1 + S2 + S3 + PO + DO + QA.
  - 10 min: TL presenta el ticket y la dinámica.
  - 60 min: revisión cruzada — cada supervisor expone 5 minutos sobre su contrato (qué firma, dónde tiene dudas, qué cambió respecto al borrador).
  - 20 min: discusión de los 6 conflictos de borde.
- [ ] **Sesión 2 (45 min, asíncrona o presencial):** ajustes posteriores y firma.
- [ ] Acta en `docs/sessions/2026-04-XX-firma-contratos-agentes.md` con asistentes, decisiones, hashes registrados.

### Estado final del repo

Al cerrar el ticket:

- [ ] Los 7 archivos `agents/A<N>-*.md` están en versión firmada con el header actualizado:
  ```markdown
  > Contrato versionado del agente A<N>. **Firmado: 2026-04-XX (v1.0/v2.0).**
  > Modificar este archivo requiere el proceso documentado en `PROCESO-MODIFICACION.md`.
  ```
- [ ] `agents/REGISTRO-FIRMAS.md` existe y completo.
- [ ] `agents/PROCESO-MODIFICACION.md` existe y completo.
- [ ] `agents/CHANGELOG.md` existe y completo.
- [ ] `agents/README.md` referencia los 3 nuevos documentos.
- [ ] `CLAUDE.md` y `docs/architecture.md` coherentes con los contratos firmados.

---

## Invariantes que el TL DEBE respetar

1. **Ningún contrato se firma sin la firma del supervisor del agente.** Si el supervisor no está disponible esta semana, se posterga la firma de ese contrato (los demás sí pueden cerrarse).
2. **Los contratos no se "negocian" en la sesión para acelerar el cierre.** Si surge un conflicto real, se anota como pendiente y se resuelve antes de firmar — no se inventa una redacción ambigua para evitar conversación.
3. **Las firmas son sobre el contenido exacto del archivo en ese commit.** Por eso el SHA-256. Si después alguien edita el contrato sin pasar por el proceso, el hash deja de coincidir y es evidencia de violación.
4. **Los hashes se calculan después de que TODOS los ajustes están aplicados.** Calcular hash, ver que después alguien cambió un typo, y "actualizar el hash silenciosamente" anula el sistema. Si hay un typo después de firmar, se vuelve a firmar.
5. **Conflictos entre ADR y contrato → gana el ADR.** El contrato se ajusta al ADR. Si un contrato refleja una decisión arquitectónica que el ADR no contempla, se redacta nuevo ADR primero, luego se firma el contrato.
6. **No mergear con desacuerdos sin resolver.** Si dos supervisores discrepan sobre el borde A1↔A6, ese conflicto se resuelve antes del merge. Mergear con "ya lo arreglamos después" tiene 0% de tasa de éxito.

---

## Casos de uso obligatorios que el proceso debe cubrir

Para validar que el sistema funciona, simular los siguientes escenarios:

### Caso 1 — Un agente quiere hacer algo no listado en su contrato

```
Escenario: A3 (Next.js) recibe un ticket que pide "agregar un campo computed
en una tabla de la BD". Eso es dominio de A1.

Resolución correcta según el contrato:
- A3 detecta que está fuera de su dominio.
- A3 NO modifica el schema.
- A3 deja nota en el ticket: "esto requiere coordinación con A1".

El contrato A3 debe ser claro sobre esto. Validar.
```

### Caso 2 — Dos agentes editan el mismo archivo

```
Escenario: A1 y A6 modifican el mismo archivo de tests
(services/erp-api/src/modules/bodega/__tests__/movimientos.spec.ts).

Resolución correcta:
- A6 es dueño de los tests, A1 es dueño del código.
- Si A1 cambia el código y rompe un test, A1 NO edita el test "para que pase".
- A1 documenta el cambio de comportamiento, A6 actualiza el test.

Validar que los contratos A1 y A6 lo dicen explícitamente.
```

### Caso 3 — Cambio de stack

```
Escenario: en 6 meses, decidimos migrar de Angular 17 a Angular 18 (cambio menor).

Resolución correcta:
- Cambio menor en stack → bump 1.0 → 1.1.
- PR sobre A4-angular.md con la versión nueva, firmas de S3 + TL.
- CHANGELOG actualizado.
- Si hay tickets en curso con A4, se completan con el contrato vigente al momento
  de su asignación (registrado en el ticket).

Validar que PROCESO-MODIFICACION.md lo cubre.
```

### Caso 4 — Disputa entre supervisores

```
Escenario: S1 y S2 discrepan sobre dónde modelar las tarifas. S1 dice que tarifas
es del módulo producción (A1). S2 dice que tarifas debería ser un módulo propio
con borde claro hacia producción.

Resolución correcta según el proceso:
- No se modifica ningún contrato unilateralmente.
- Se abre conversación en la próxima ceremonia "Prompt review".
- Si hay decisión, se redacta o ajusta un ADR.
- Después se ajustan los contratos al ADR resultante.
- Firmas de S1 + S2 + TL.

Validar que PROCESO-MODIFICACION.md lo cubre.
```

### Caso 5 — Agente nuevo (futuro)

```
Escenario: en sprint 5 decidimos agregar A8 (BI / dashboards avanzados).

Resolución correcta:
- Nuevo archivo agents/A8-*.md.
- Versión inicial 1.0.
- Pasa por el mismo proceso de revisión cruzada (al menos los supervisores
  adyacentes leen y firman).
- Se registra en REGISTRO-FIRMAS.md y en README.md.

Validar que el proceso es replicable.
```

### Caso 6 — Modelo de IA cambia

```
Escenario: el equipo migra de modelo X a modelo Y para todos los agentes.

Resolución correcta:
- Los contratos NO cambian (no son específicos al modelo).
- Solo se documenta en CHANGELOG global del proyecto (no en contratos).
- Si un agente, con el nuevo modelo, sistemáticamente viola un invariante,
  ese invariante puede necesitar ser más explícito → ajuste menor del contrato.

Validar que los contratos no asumen un modelo concreto.
```

---

## Lo que NO se debe hacer en esta tarea

- **No reescribir los contratos desde cero.** Los borradores existentes son funcionales. Este ticket valida, ajusta marginalmente y firma.
- **No agregar capacidades nuevas que no se hayan demostrado** en tickets ya ejecutados. Si A3 nunca ha generado PDFs, no listamos "puede generar PDFs" sin algún ticket de evidencia.
- **No definir métricas que no se puedan medir.** "Calidad del código" no es métrica. "% de cobertura en módulos críticos" sí.
- **No firmar contratos en ausencia de su supervisor.** El TL no puede firmar el contrato de A5 si el PO no estuvo presente. Eso anula el sistema.
- **No mezclar este ticket con redefinición de roles humanos.** Los roles humanos (TL, PO, supervisores) son organizacionales y van en otro lado. Aquí solo agentes IA.
- **No hacer "tabla rasa" si encontramos un problema grande.** Si se descubre que A1 tiene 4 capacidades superpuestas con A6, eso es un caso para una segunda ronda con ADR si hace falta, no para reescribir todo en este ticket.
- **No commitear los cambios sin firmas.** Si al final del ticket no están las 7 firmas, no se mergea — se mueve al siguiente sprint con las que sí están.

---

## Contratos y referencias

- **Contratos vigentes (borradores funcionales):**
  - [A1 NestJS](../../agents/A1-nestjs.md) v2.0
  - [A2 Springboot/Python](../../agents/A2-springboot.md) v2.0
  - [A3 Next.js](../../agents/A3-nextjs.md) v1.0
  - [A4 Angular](../../agents/A4-angular.md) v1.0
  - [A5 ETL](../../agents/A5-etl.md) v1.0
  - [A6 QA](../../agents/A6-qa.md) v1.0
  - [A7 DevOps](../../agents/A7-devops.md) v1.0
- **README de agentes:** [`agents/README.md`](../../agents/README.md)
- **CLAUDE.md raíz:** [`CLAUDE.md`](../../CLAUDE.md) — debe ser coherente.
- **ADRs vigentes** (lista completa en `docs/adrs/`):
  - ADR-001 (microservicios — supersedido por ADR-010)
  - ADR-002 (docker-compose)
  - ADR-003 (multi-tenancy)
  - ADR-004 (JSONB)
  - ADR-005 (stock calculado)
  - ADR-006 (gitops si existe)
  - ADR-007 (tarifas temporales)
  - ADR-008 (Excel validation)
  - ADR-009 (observabilidad si existe)
  - ADR-010 (monolito modular — vigente)
- **Documentación arquitectura:** [`docs/architecture.md`](../../docs/architecture.md)
- **Roadmap microservicios:** [`docs/roadmap-microservicios.md`](../../docs/roadmap-microservicios.md)
- **Tickets ya ejecutados que sirven de evidencia:**
  - T-001 a T-004 (bootstrap) — evidencia para A7 y A1.
  - T-006 (Next.js base) — evidencia para A3.
  - T-007 (Angular base) — evidencia para A4.
  - T-010 (Keycloak) — evidencia para A7.
  - T-011 (inventario Excel) — evidencia para A5.

---

## Entregables

- [ ] 7 contratos firmados (`agents/A1-nestjs.md` ... `agents/A7-devops.md`) con header actualizado.
- [ ] `agents/REGISTRO-FIRMAS.md` con las 7 entradas + hashes SHA-256 + firmas.
- [ ] `agents/PROCESO-MODIFICACION.md` completo.
- [ ] `agents/CHANGELOG.md` con estado inicial.
- [ ] `agents/README.md` actualizado con referencias.
- [ ] `CLAUDE.md` raíz coherente con contratos firmados.
- [ ] `docs/architecture.md` coherente.
- [ ] `docs/sessions/2026-04-XX-firma-contratos-agentes.md` con acta(s) de sesión(es).
- [ ] Commit: `docs(agents): contratos firmados v1.0/v2.0 con proceso de modificación [TL]`
- [ ] PR con labels: `supervisor:TL`, `sprint:semana-1`, `priority:critical`, `type:docs`

---

## Proceso recomendado (~4-5 horas de trabajo distribuido)

### Pre-sesión (TL solo, 90 minutos)

1. Leer los 7 contratos completos.
2. Releer ADR-010 y notas de tickets ejecutados (T-001 a T-011).
3. Identificar los 6 bordes-conflicto explícitos y preparar la posición tentativa de cada uno.
4. Redactar borradores v0 de `REGISTRO-FIRMAS.md`, `PROCESO-MODIFICACION.md`, `CHANGELOG.md`.
5. Distribuir a los supervisores con 48h de anticipación para que lleguen leídos a la sesión.

### Sesión 1 con el equipo (90 minutos, TL + 6 supervisores)

1. **Apertura (10 min):** TL presenta dinámica, recuerda que los contratos son inversión de gobernanza, no burocracia.
2. **Round robin (60 min):** cada supervisor expone 5-7 minutos sobre su contrato:
   - Qué le funcionó en los tickets ya ejecutados.
   - Qué borde le incomoda.
   - Qué ajuste propone antes de firmar.
3. **Conflictos de borde (15 min):** discusión de los 6 conflictos. Resolución o "documento como pendiente" si no hay acuerdo.
4. **Métricas (5 min):** cada supervisor confirma las 3 métricas mínimas de su agente.

### Trabajo asíncrono entre sesiones (cada supervisor, 30 min c/u)

1. Ajustar el contrato según conversación de la sesión.
2. Verificar coherencia con ADRs.
3. Marcar el contrato como "listo para firmar".

### Sesión 2 (45 minutos, TL + supervisores que tengan ajustes pendientes)

1. Revisar contratos ajustados.
2. Resolver pendientes de Sesión 1.
3. **Calcular hashes SHA-256 y firmar formalmente.**
4. Actualizar `REGISTRO-FIRMAS.md` con los hashes.
5. TL hace el commit final con todas las firmas.

### Post-cierre (TL solo, 30 minutos)

1. Verificar coherencia con `CLAUDE.md` y `docs/architecture.md`.
2. Abrir PR y solicitar aprobación final asíncrona.
3. Anunciar en `#erp-build`: contratos firmados, link a `REGISTRO-FIRMAS.md`.

---

## Validación post-ejecución (lo llena el TL)

```bash
# 1. Los 7 archivos existen y tienen header de firma
for n in 1 2 3 4 5 6 7; do
  file=$(ls agents/A${n}-*.md)
  echo "==== $file ===="
  head -5 "$file"
  echo
done

# 2. Los hashes SHA-256 coinciden con REGISTRO-FIRMAS.md
for f in agents/A?-*.md; do
  echo "Hash actual:    $(sha256sum "$f")"
  registrado=$(grep -A 1 "Archivo: \`$f\`" agents/REGISTRO-FIRMAS.md | grep "Hash" | awk '{print $NF}')
  echo "Hash registrado: $registrado"
  echo
done

# 3. Todos tienen al menos 2 firmas en REGISTRO-FIRMAS.md
grep -c "Firmado por:" agents/REGISTRO-FIRMAS.md
# Esperado: 7 (una sección por contrato)

# 4. CLAUDE.md coherente
grep -E "^\| A[1-7]" CLAUDE.md  # tabla de agentes
# Comparar stacks y supervisores con agents/README.md

# 5. Acta de sesión existe
ls -la docs/sessions/2026-*-firma-contratos-agentes.md

# 6. PROCESO-MODIFICACION.md cubre los 6 casos de uso
for caso in "fuera de contrato" "edición conjunta" "cambio de stack" "disputa" "agente nuevo" "modelo cambia"; do
  grep -qi "$caso" agents/PROCESO-MODIFICACION.md \
    && echo "OK: $caso" \
    || echo "FALTA: $caso"
done

# 7. CHANGELOG tiene 7 entradas
grep -c "^## A" agents/CHANGELOG.md
# Esperado: 7
```

- **Fecha de Sesión 1:** _pendiente_
- **Asistentes Sesión 1:** _pendiente (esperado: TL + 6 supervisores)_
- **Fecha de Sesión 2:** _pendiente_
- **Contratos firmados:** _pendiente (objetivo: 7/7)_
- **Conflictos de borde resueltos:** _pendiente_
- **Conflictos no resueltos al cierre:** _pendiente (idealmente: 0)_
- **Hashes registrados:** _pendiente_
- **Resultado:** _pendiente_

---

## Notas para el TL

**Si un supervisor no llega a la sesión:**

- No firmes su contrato en su ausencia. Mueve esa firma a un PR asíncrono posterior.
- Los otros 6 contratos pueden cerrarse mientras tanto.
- Si el supervisor faltante es PO o DO, considera posponer la sesión completa: tienen ramificaciones cruzadas con varios contratos.

**Si surge un conflicto irresoluble en la sesión:**

- No fuerces redacción ambigua. Documenta las 2 posiciones, asigna un dueño para resolverlas (probablemente con un ADR nuevo), y firma los 6 contratos que sí tienen acuerdo.
- El contrato pendiente se firma cuando el ADR esté listo.

**Conexión con tickets futuros:**

- Una vez firmados, los PRs de agentes referencian al contrato vigente. Ej: en el PR de T-013, el supervisor S1 dice "validado contra A1-nestjs.md v2.0 hash X".
- Si en el futuro un PR viola un contrato, hay 2 caminos:
  1. Rechazar el PR y pedirle al agente que respete el contrato.
  2. Si el contrato está mal, abrir PR de modificación según `PROCESO-MODIFICACION.md`.
- NUNCA mergear un PR violando un contrato firmado sin pasar por (2).

**Sobre las métricas:**

- Las métricas listadas en cada contrato no se miden hoy automáticamente. Eso requeriría dashboards específicos.
- En Sprint 2 o 3, abrir ticket para integrar métricas con observabilidad (Grafana?). Por ahora, métricas se levantan manualmente al cierre de cada sprint.

**Prerrequisitos:**

- T-001 a T-004 completados ✅ (evidencia para varios contratos).
- T-006 y T-007 idealmente mergeados (evidencia para A3 y A4); si no, los borradores actuales sirven.
- T-010, T-011 idealmente mergeados (evidencia para A7 y A5); si no, igual.

**Sucesores:**

- **Todos los tickets siguientes** del proyecto referencian los contratos firmados al asignar agente.
- "Prompt review" mensual: ceremonia para discutir cambios propuestos a contratos.

---

**Creado:** 2026-04-29 por TL
**Plantilla base:** `prompts/templates/ticket-template.md` v1.0 con adaptaciones para ticket humano
**Tipo:** gobernanza de agentes IA
