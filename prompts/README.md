# `prompts/` — Prompts versionados del proyecto

Este directorio contiene los prompts que el equipo usa para orquestar a los agentes IA. **Cada tarea del backlog tiene un archivo de prompt asociado, commiteado al repo, antes de ser ejecutada.**

---

## Por qué commiteamos los prompts

Un prompt no es una instrucción efímera de chat. Es un **artefacto de ingeniería**:

- **Auditable:** el cliente y el equipo pueden revisar qué se le pidió al agente.
- **Reproducible:** si hay un bug, volvemos a correr el prompt mejorado sin empezar de cero.
- **Versionable:** los prompts evolucionan. Queremos ver su historia con `git log`.
- **Compartible:** un prompt que funciona para un módulo se convierte en base para el siguiente.
- **Cumplimiento:** la empresa necesita distinguir qué código fue generado por IA y bajo qué instrucciones.

---

## Estructura

```
prompts/
├── README.md                  ← estás aquí
├── templates/
│   └── ticket-template.md     ← plantilla base que se copia para cada ticket
├── backlog/
│   ├── T-016-categorias-insumos.md
│   ├── T-029-motor-costos.md
│   └── T-XXX-*.md             ← un archivo por ticket del backlog
└── history/
    └── (iteraciones de prompts que fallaron, para aprendizaje)
```

---

## Cómo se relacionan los 3 niveles de contexto

Cuando un agente IA ejecuta una tarea, **recibe tres capas de contexto combinadas**:

```
┌─────────────────────────────────────────────────────┐
│ 1. CLAUDE.md (raíz del repo)                        │ ← Contexto global
│    Se lee AUTOMÁTICAMENTE por Claude Code.          │   Siempre activo.
│    Define: stack, reglas del repo, invariantes.     │   Cambia raramente.
└─────────────────────────────────────────────────────┘
                         +
┌─────────────────────────────────────────────────────┐
│ 2. agents/A<N>-*.md (contrato del agente)           │ ← Identidad del agente
│    Se referencia explícitamente con --skill o -f.   │   Define: dominio propio,
│    Es el "quién eres tú" del agente.                │   qué puede/no puede, invariantes
└─────────────────────────────────────────────────────┘
                         +
┌─────────────────────────────────────────────────────┐
│ 3. prompts/backlog/T-XXX-*.md (tarea específica)    │ ← Qué hacer ahora
│    El supervisor humano lo pasa al agente.          │   Criterios de aceptación,
│    Es el "qué tienes que hacer ahora".              │   casos de prueba, alcance.
└─────────────────────────────────────────────────────┘
                         =
                  Instrucción completa
```

El **comando de shell** (`cd erp-project && claude`) sólo **inicia una sesión** de Claude Code. Después del comando, el supervisor **sí debe dar un prompt** — pero ese prompt es breve porque el contexto real vive en los archivos versionados.

---

## Flujo completo: de ticket a PR

Ejemplo real con el ticket T-016 (CRUD categorías de insumos).

### Paso 1 — El supervisor prepara el prompt del ticket

```bash
cd erp-project

# Copiar plantilla al directorio de backlog
cp prompts/templates/ticket-template.md prompts/backlog/T-016-categorias-insumos.md

# Abrir y rellenar con los detalles del ticket de Jira
vim prompts/backlog/T-016-categorias-insumos.md

# Commitear ANTES de invocar al agente
git add prompts/backlog/T-016-categorias-insumos.md
git commit -m "docs(prompts): prepare T-016 prompt for agent A1"
```

El prompt commiteado es ahora auditable. Si el agente falla y hay que mejorarlo, el `git diff` mostrará qué cambió.

### Paso 2 — El supervisor crea la rama de trabajo

```bash
git checkout -b feat/T-016-categorias-insumos
```

Convención de nombres: `feat/T-<numero>-<slug-corto>`. La rama refleja el ID del ticket, igual que el archivo de prompt.

### Paso 3 — El supervisor invoca a Claude Code

Aquí es donde se conecta todo:

```bash
# Opción A: sesión interactiva
claude

# Claude Code arranca, lee CLAUDE.md automáticamente.
# El supervisor escribe ENTONCES su prompt real en la sesión:
```

> Ejecuta el ticket T-016. Lee el prompt detallado en
> `prompts/backlog/T-016-categorias-insumos.md` y el contrato
> del agente en `agents/A1-nestjs.md`. Sigue todos los
> criterios de aceptación antes de proponer un commit.

```bash
# Opción B: one-shot no interactivo (útil para dejar corriendo)
claude -p "$(cat <<'EOF'
Ejecuta el ticket T-016.

Prompt detallado: @prompts/backlog/T-016-categorias-insumos.md
Contrato del agente: @agents/A1-nestjs.md

Sigue todos los criterios de aceptación antes de proponer un commit.
No hagas git push. Solo commits locales en la rama actual.
EOF
)"
```

El `@` le indica a Claude Code que lea el archivo completo como contexto. Así no hay que pegar el texto entero.

### Paso 4 — El agente trabaja

Claude Code ahora tiene todo el contexto:
- Reglas globales (`CLAUDE.md` — automático)
- Identidad del agente (`agents/A1-nestjs.md` — vía `@`)
- Tarea específica (`prompts/backlog/T-016-categorias-insumos.md` — vía `@`)

Genera código, ejecuta tests localmente, hace commits incrementales. El supervisor observa.

### Paso 5 — Validación del supervisor humano

```bash
# Revisar lo que hizo el agente
git log --oneline
git diff main...HEAD

# Correr el pre-check
./scripts/pre-pr-check.sh

# Si hay que iterar, ajustar el prompt y volver
vim prompts/backlog/T-016-categorias-insumos.md
# ... mejoras al prompt ...
git add prompts/ && git commit -m "docs(prompts): refine T-016 with edge case for case-insensitive name"
claude -p "El prompt fue actualizado. Ajusta la implementación según los nuevos criterios."
```

### Paso 6 — PR

```bash
# Solo cuando todo está OK
git push origin feat/T-016-categorias-insumos

gh pr create \
  --title "feat(bodega): add categorias crud with events [A1]" \
  --label "agent:A1" \
  --label "supervisor:S1" \
  --label "sprint:1" \
  --body "$(cat prompts/backlog/T-016-categorias-insumos.md)"
```

El PR incluye el prompt original como descripción. Otro supervisor hace code review humano antes del merge.

---

## Entonces, ¿el comando es el prompt?

**No.** Aclaremos:

| Elemento | Qué es | Ejemplo |
|----------|--------|---------|
| **Comando de shell** | Inicia la sesión | `cd erp-project && claude` |
| **Referencia a archivo** | Carga contexto versionado | `@prompts/backlog/T-016-*.md` |
| **Prompt del supervisor** | La instrucción específica del momento | "Ejecuta T-016 siguiendo..." |
| **CLAUDE.md** | Contexto global automático | (se lee solo) |
| **Contrato del agente** | Identidad reutilizable | `agents/A1-nestjs.md` |

El supervisor **siempre** debe escribir un prompt después del comando. Pero ese prompt es corto y **referencia a los archivos commiteados** en lugar de repetir toda la información cada vez.

---

## Reglas para escribir prompts

1. **Nunca al vuelo en el chat.** Siempre commitear primero.
2. **Un prompt por ticket.** No mezclar múltiples tickets en un prompt.
3. **Criterios verificables.** Nada de "que funcione bien" — siempre tests o inspecciones concretas.
4. **Expectativas negativas explícitas.** "No hacer X, Y, Z" evita que el agente se vaya de scope.
5. **Referenciar contratos e invariantes.** Nunca repetir lo que ya está en `CLAUDE.md` o `agents/`.
6. **Casos de prueba reales del negocio.** Si el cliente tiene Excel, extraer casos del Excel.
7. **Iterar en Git.** Si el prompt falla, mejóralo en el archivo y commit — no empezar de cero cada vez.

---

## Cuándo reusar un prompt

Muchos tickets son similares (ej: CRUD de entidad X es muy parecido a CRUD de entidad Y). En esos casos:

- Crear una **plantilla semi-llena** en `prompts/templates/` con lo común.
- El ticket específico sólo llena lo diferente.
- Ejemplo: `prompts/templates/crud-entity-template.md` para todos los CRUDs básicos.

---

## El prompt como contrato de calidad

Un prompt bien escrito **predice la calidad del output**. Si después de ejecutar una tarea encuentras que el código tiene un defecto, pregúntate:

- ¿El prompt incluía el criterio que faltó?
- ¿El caso de prueba estaba explícito?
- ¿El agente podría haberlo inferido del contrato?

Si la respuesta es "no", **el arreglo va en el prompt, no en el código**. Mejora el prompt, commítealo, y la próxima vez que se ejecute tareas similares no volverá a fallar.

Esto se revisa cada semana en la ceremonia **Prompt review**.

---

**Última actualización:** abril 2026
**Mantenedor:** Tech Lead
