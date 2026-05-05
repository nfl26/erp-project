# ADR-009: Claude Code como herramienta estándar de agentes IA

- **Status:** accepted
- **Date:** 2026-04-18
- **Deciders:** TL, PO, Dirección del cliente
- **Tags:** proceso, herramientas, ia, gobernanza

---

## Contexto

Este proyecto adopta un modelo híbrido: 7 supervisores humanos + 7 agentes IA especializados (ver `dashboard/erp_agentes_ia.html` y catálogo de contratos en `agents/`). La decisión de **qué herramienta concreta usan los supervisores humanos para invocar a los agentes** es crítica porque:

1. **Consistencia del output.** Distintas herramientas generan código con distintos patrones, incluso con el mismo prompt.
2. **Auditoría ante el cliente.** El cliente va a querer saber qué IA se usó, bajo qué versión, con qué configuración, para cumplimiento regulatorio y de procurement.
3. **Costos.** Cada herramienta tiene un modelo de cobro distinto y un presupuesto asignado.
4. **Seguridad.** Las herramientas difieren en cómo manejan el código del cliente (algunas lo envían a servidores propios, otras pueden correr localmente).
5. **Productividad del equipo.** Cambiar de herramienta a mitad del proyecto rompe el flujo.

El mercado en abril 2026 tiene varias opciones viables: Claude Code (Anthropic), GitHub Copilot y Copilot Workspace (Microsoft), Cursor (IDE con IA integrada), Cody (Sourcegraph), Aider (open source), entre otras.

El equipo y el cliente necesitan un estándar — no una opción libre — porque cada supervisor humano trabajando con herramientas distintas produce código con inconsistencias sutiles que son difíciles de detectar.

---

## Decisión

**Claude Code (Anthropic) es la herramienta estándar para todos los supervisores humanos** que invocan agentes IA en este proyecto. Todos los tickets del backlog se ejecutan con Claude Code salvo excepciones explícitamente autorizadas.

### Razones específicas para este proyecto

1. **Integración nativa con contratos en Markdown.** Claude Code lee automáticamente `CLAUDE.md` al iniciar, y soporta la sintaxis `@archivo` para cargar contexto adicional. Esto encaja naturalmente con nuestro modelo de `agents/A{N}-*.md` y `prompts/backlog/T-XXX-*.md`.

2. **Trabaja en terminal.** Cada supervisor abre `claude` en su proyecto local. No requiere IDE específico. No depende de extensión de editor. Funciona igual en macOS, Linux y Windows.

3. **Manejo de contexto largo.** Los contratos de agentes + prompts de ticket + ADRs + glosario suman bastante contexto. Las herramientas que se limitan a autocompletar en el editor no alcanzan.

4. **Agente ejecutor, no solo generador.** Claude Code puede ejecutar comandos (tests, builds, linters), leer el diff de git, interactuar con la terminal. No genera "archivos sueltos", trabaja dentro del flujo real del supervisor.

5. **Modelo directo del proveedor.** Sin capas intermedias que puedan modificar prompts o filtrar respuestas.

6. **Política de datos explícita.** Anthropic publica qué hace con el código enviado. El cliente puede auditar la política antes de autorizar el uso.

### Cowork como excepción autorizada

**Cowork** (también de Anthropic) se usa **exclusivamente por el Product Owner** para tareas de automatización sobre los Excel del cliente: limpieza, extracción de fórmulas, preparación de fixtures. No lo usan los supervisores técnicos. Ver contrato del agente A5 (ETL) donde se documenta esta relación.

### Otras herramientas autorizadas caso a caso

Con aprobación del Tech Lead, pueden usarse otras herramientas para tareas **no productivas** que no generan código commiteado:

- **Exploración:** cualquier asistente para brainstorming o investigación.
- **Documentación:** cualquier asistente para pulir documentación ya aprobada en contenido.
- **Aprendizaje individual:** los supervisores pueden usar cualquier herramienta para su propio estudio, sin que eso afecte los PRs del proyecto.

Lo que **no** es negociable: los PRs que entran a `main` deben venir de trabajo ejecutado con Claude Code.

---

## Alternativas consideradas

### A) Libertad de herramienta por supervisor

Cada supervisor elige su herramienta preferida.

**Pros:**
- Cada persona usa lo que conoce y le es productivo.
- Sin costo de onboarding adicional.

**Cons:**
- **Inconsistencia del código generado.** Patrones distintos, convenciones distintas.
- **Imposible auditar** uniformemente qué IA generó qué código.
- **Imposible comparar métricas** entre agentes (ver sección "Métricas" en contratos).
- **Imposible estandarizar contratos** — cada herramienta maneja contexto de forma distinta.
- El costo operativo de soportar N herramientas es mayor que el beneficio de flexibilidad individual.
- **Descartada.**

### B) GitHub Copilot (+ Copilot Workspace)

Asistente integrado a editores y GitHub.

**Pros:**
- Ubicua (casi todos los desarrolladores lo conocen).
- Integración profunda con GitHub (issues, PRs).
- Licenciamiento empresarial estándar.

**Cons:**
- **Más orientado a autocompletar** que a ejecutar tareas completas desde un prompt de ticket.
- Copilot Workspace es más prometedor pero menos maduro para el modelo de "un agente por ticket con contrato versionado".
- Dependencia de GitHub (lock-in moderado).
- Menos control sobre el modelo subyacente.
- **No es la mejor opción para este modelo híbrido específico.**

### C) Cursor (IDE con IA)

IDE con IA integrada nativamente.

**Pros:**
- Experiencia integrada excelente.
- Adoptado por muchos equipos de desarrollo.

**Cons:**
- **Obliga a todos a usar Cursor como IDE.** Algunos supervisores prefieren VS Code, JetBrains, Vim.
- Lock-in al IDE.
- Menos adecuado para tareas ejecutadas en batch o de noche (el IDE tiene que estar abierto).
- **Descartada.**

### D) Aider (open source)

Herramienta de terminal open source.

**Pros:**
- Gratuito.
- Open source.
- Funciona con múltiples backends (Claude, GPT, Gemini).

**Cons:**
- Menor polish y soporte que Claude Code.
- Requiere más configuración por supervisor.
- **Se considera como plan B** si Claude Code tiene un outage prolongado.

### E) Claude Code **(elegida)**

Herramienta oficial de Anthropic para terminal.

Ya cubierta arriba con las razones.

---

## Consecuencias

### Positivas

- **Consistencia del código** entre supervisores y entre tickets.
- **Auditoría simple ante el cliente:** toda respuesta se atribuye a Claude Code + versión + modelo.
- **Métricas comparables** entre agentes (tasa de aceptación, iteraciones) porque la herramienta es la misma.
- **Contratos y prompts funcionan predeciblemente** con la misma herramienta.
- **Onboarding simple:** un único tutorial, una única configuración, un único flujo.
- **Soporte único:** si hay un issue, sabemos a quién acudir.
- **Modelo de costos claro:** suscripciones Claude Pro/Max para supervisores, presupuesto asignado por el proyecto.

### Negativas aceptadas

- **Dependencia de un proveedor.** Mitigación: los contratos de agentes y prompts son independientes de la herramienta — si mañana cambiamos de proveedor, el contenido se mantiene.
- **Costo mensual fijo** por supervisor. Mitigación: asumido en el presupuesto del proyecto.
- **Curva de aprendizaje inicial** para supervisores no familiarizados. Mitigación: sesión de onboarding de 2h en la semana 1.
- **Outages del proveedor** bloquean el flujo temporalmente. Mitigación: plan B con Aider + Claude API directa documentado en `docs/runbooks/claude-code-outage.md`.

---

## Reglas derivadas

### Para los supervisores humanos

1. **Instalar Claude Code** en la máquina de trabajo durante el onboarding.
2. **Usar Claude Code para todos los tickets** que generan código que va a `main`.
3. **Commitear prompts a `prompts/backlog/`** antes de invocar al agente (ver `prompts/README.md`).
4. **Mencionar el agente en los commits:** `feat(bodega): add categorias crud [A1]`.
5. **Reportar problemas con la herramienta** en `#erp-agents` de Slack.

### Para el Product Owner

1. **Usar Cowork** para automatización de Excel cuando aplique (ver contrato A5).
2. **Usar Claude Code** cuando trabaje con el agente A5 para scripts de ETL.

### Para el Tech Lead

1. **Aprobar excepciones** caso a caso si aparecen.
2. **Mantener `docs/runbooks/claude-code-outage.md`** actualizado.
3. **Revisar en la ceremonia "Prompt Review"** si hay patrones de falla de la herramienta que ameritan nuevos prompts o ajustes.

### Para todos (auditoría ante cliente)

1. **Los PRs tienen la etiqueta `agent:A{N}`** que identifica qué agente los generó.
2. **La mención `[A{N}]` en el commit** es obligatoria.
3. **El prompt commiteado** provee trazabilidad de qué se pidió exactamente al agente.
4. **El supervisor humano figura como author** del PR, porque la responsabilidad final es humana.

---

## Métricas para revisitar esta decisión

Se reevaluará esta decisión cada tres meses con las siguientes métricas:

| Métrica | Umbral para cambio |
|---|---|
| Tasa de aceptación promedio de agentes | < 80% sostenido |
| Outages de Claude Code | > 4 horas al mes |
| Costos por supervisor | > $200/mes sostenido |
| Quejas de supervisores | > 3 sobre bloqueos de herramienta por sprint |

Si algún umbral se cruza, se abre ADR nuevo proponiendo alternativa.

---

## Plan de contingencia

Si Claude Code tiene un outage prolongado (>4 horas):

1. Los supervisores pueden usar **Aider** contra la API de Claude directamente como plan B.
2. El prompt commiteado sigue siendo la misma fuente de verdad — Aider también puede leer archivos con `/add`.
3. El commit menciona el agente normalmente (`[A1]`), pero agrega nota en la descripción del PR: "Generado con Aider por outage de Claude Code".
4. Al volver Claude Code, se retoma el flujo normal.

Documentado en `docs/runbooks/claude-code-outage.md`.

---

## Referencias

- Documentación de Claude Code: https://docs.claude.com
- Dashboard visual del modelo híbrido: `dashboard/erp_agentes_ia.html`
- Catálogo de agentes: `agents/README.md`
- Flujo de prompts: `prompts/README.md`
- `CLAUDE.md` en la raíz — leído automáticamente por Claude Code.

---

**Revisitar esta decisión si:**

- Alguna de las métricas listadas cruza su umbral.
- Aparece una herramienta con ventajas claras y sostenibles.
- El cliente solicita auditar o limitar el uso de IA de forma incompatible con Claude Code.
- Anthropic cambia sus políticas de datos de forma incompatible con nuestros requisitos.
