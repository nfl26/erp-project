# Plantilla de prompt por ticket

> Esta plantilla se copia para cada tarea del backlog. Vive en
> `prompts/backlog/T-XXX-short-slug.md` y se commitea al repo junto
> con el código que el agente genera.
>
> **Por qué commiteamos los prompts al repo:**
> 1. Auditoría — cualquiera puede revisar qué se le pidió al agente.
> 2. Reproducibilidad — si el código tiene un bug, volvemos a correr el prompt mejorado.
> 3. Aprendizaje — los prompts que funcionan se convierten en plantillas.
> 4. Cumplimiento — el cliente puede verificar qué hizo IA y qué hizo un humano.

---

## Cómo usar esta plantilla

1. Copia este archivo a `prompts/backlog/T-XXX-slug.md` (usa el ID del ticket).
2. Rellena todas las secciones marcadas con `<...>`.
3. Guarda y commitea antes de invocar al agente.
4. Invoca al agente desde terminal apuntando a este archivo.
5. Si el agente falla, itera el prompt, commitea la versión corregida.

---

# T-XXX · <Título corto de la tarea>

**Ticket Jira:** <link>
**Agente asignado:** A<N>
**Supervisor humano:** S<X>
**Sprint:** <Sprint 1 | Sprint 2 | Sprint 3>
**Estimación:** <N> puntos
**Prioridad:** <crítica | alta | media>
**Rama:** `feat/T-XXX-slug`

---

## Contexto de negocio

<Qué problema real del negocio resuelve esta tarea. 2-3 frases.
Ejemplo: "El bodeguero hoy registra entradas de insumos en un Excel.
Necesitamos reemplazar ese flujo con un endpoint transaccional que
actualice stock atómicamente y emita un evento para notificaciones.">

## Alcance técnico

<Qué archivos y módulos se tocan. Qué se crea, modifica, elimina.
Ejemplo:
- Crear: services/erp-api/src/modules/bodega/src/modules/movimientos/
- Modificar: services/erp-api/src/modules/bodega/prisma/schema.prisma (agregar tabla movimientos)
- No tocar: services/erp-api/src/modules/bodega/src/modules/insumos/ (ya existe, solo consumir)>

## Criterios de aceptación

<Lista verificable. Cada criterio debe poder ser validado por un test
o por inspección directa. No usar verbos vagos como "funciona" o "correcto".>

- [ ] Criterio 1 concreto
- [ ] Criterio 2 concreto
- [ ] Criterio N concreto

## Contratos y referencias

- **Contrato del agente:** [agents/A<N>-<nombre>.md](../../agents/A<N>-xxx.md)
- **OpenAPI del servicio:** [docs/api/<servicio>.yaml](../../docs/api/xxx.yaml)
- **ADRs relevantes:** [docs/adrs/ADR-NNN-xxx.md](../../docs/adrs/)
- **Glosario de términos:** [docs/glossary.md](../../docs/glossary.md)

## Invariantes de dominio a preservar

<Reglas de negocio que NO se pueden romper. El agente debe escribir
tests explícitos para cada una.>

1. <Invariante 1>
2. <Invariante 2>

## Casos de prueba obligatorios

<Casos borde, no solo el happy path. Si hay casos del Excel del
cliente, listarlos aquí con valores esperados.>

- **Caso 1:** <descripción, input esperado, output esperado>
- **Caso 2:** <descripción, input esperado, output esperado>

## Lo que NO se debe hacer en esta tarea

<Expectativas negativas. Ayuda a evitar que el agente se vaya de scope.>

- No tocar el módulo de producción.
- No agregar librerías nuevas.
- No modificar el schema de tablas existentes.

## Entregables

- [ ] Código implementado en la rama
- [ ] Tests unitarios con cobertura ≥ 80%
- [ ] OpenAPI actualizado
- [ ] Migraciones generadas (si aplica)
- [ ] README del módulo actualizado
- [ ] Commit con formato `<tipo>(<scope>): <desc> [A<N>]`
- [ ] PR abierto con labels `agent:A<N>` y `supervisor:S<X>`

---

## Validación post-ejecución (lo llena el supervisor humano)

- **Fecha de ejecución:** <YYYY-MM-DD>
- **Iteraciones necesarias:** <N>
- **Tiempo total de supervisión humana:** <minutos>
- **Resultado:** <aprobado | requiere cambios | descartado>
- **Notas:** <observaciones para mejorar la plantilla o el contrato>

---

**Plantilla versión:** 1.0 — abril 2026
