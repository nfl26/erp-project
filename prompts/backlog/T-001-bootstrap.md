# T-001 · Crear organización GitHub, monorepo, branch protection, PR templates

**Ticket Jira:** https://tu-org.atlassian.net/browse/T-001
**Agente asignado:** A7 (DevOps & Infra)
**Supervisor humano:** DO (DevOps / Plataforma)
**Sprint:** Semana 1 — Fundamentos
**Estimación:** 3 puntos
**Prioridad:** crítica
**Rama:** `main` (bootstrap, sin rama feature; se trabaja directamente en la rama inicial del repo)

---

## ⚠️ Ticket de bootstrap

Este es el **primer ticket del proyecto**. Tiene particularidades respecto al flujo normal:

- **No hay repositorio todavía.** Todo el contexto que el agente necesita (CLAUDE.md, contratos de agentes, ADRs, documentación) debe ser provisto manualmente por el supervisor en la sesión de Claude Code.
- **No hay rama feature.** Se trabaja directamente en la rama `main` inicial. Los siguientes tickets sí usarán ramas feature.
- **El `pre-pr-check.sh` no aplica aún.** Se valida manualmente con los comandos listados al final.
- **El entregable principal no es código sino estructura e infraestructura de colaboración.**

El supervisor DO debe leer la sección "Guía de ejecución para el supervisor" al final de este documento antes de invocar al agente.

---

## Contexto de negocio

El proyecto arranca con 7 supervisores humanos + 7 agentes IA. Para que todos puedan trabajar coordinadamente desde el sprint 1, necesitamos que **la infraestructura de colaboración exista antes del primer commit de código**:

- Un repositorio donde el equipo trabaja.
- Reglas de protección que impidan hacer merge sin revisión humana (principio inviolable del modelo híbrido).
- Templates de PR e Issue que guíen a humanos y agentes en qué información aportar.
- Un primer pipeline básico de CI que valide cualquier cambio antes del merge.

Sin estos cimientos, los agentes no pueden trabajar de forma segura y rastreable.

---

## Alcance técnico

Crear y configurar:

### En GitHub

- Organización GitHub (si no existe): `tu-org` (nombre real a confirmar con el cliente).
- Repositorio privado: `tu-org/erp-project`.
- Branch protection rules para `main` y `staging`.
- Teams y permisos por squad (supervisores + agentes).
- Templates de PR e Issue.
- Labels estándar del proyecto.
- Primer workflow de GitHub Actions básico (lint + test placeholder).

### En el repositorio (estructura inicial)

Crear los archivos/directorios base que luego se poblarán con otros tickets:

```
erp-project/
├── .github/
│   ├── workflows/
│   │   └── ci.yml                   ← pipeline inicial
│   ├── CODEOWNERS
│   ├── pull_request_template.md
│   └── ISSUE_TEMPLATE/
│       ├── bug_report.md
│       ├── feature_request.md
│       └── config.yml
├── README.md                         ← (ya existe en el bundle, incorporarlo)
├── CLAUDE.md                         ← (ya existe, incorporarlo)
├── .gitignore
├── .editorconfig
├── .gitattributes
├── LICENSE                           ← verificar con cliente qué licencia usar
├── agents/                           ← (ya existe, incorporar 7 contratos + README)
├── docs/                             ← (ya existe, incorporar stack/glossary/adrs/architecture/events/rbac/prisma-workflow/arquitectura-decision/roadmap-microservicios)
├── prompts/                          ← (ya existe, incorporar plantilla + 2 ejemplos + README)
├── dashboard/                        ← (ya existe, incorporar HTML)
├── scripts/
│   └── pre-pr-check.sh               ← (ya existe, incorporar)
├── services/
│   └── erp-api/                      ← vacío, con .gitkeep (monolito NestJS)
├── web/                              ← vacío, con .gitkeep
├── etl/                              ← vacío, con .gitkeep
├── infra/                            ← vacío, con .gitkeep
└── tests/                            ← vacío, con .gitkeep
```

### No tocar

- No crear el cluster de Kubernetes (eso es T-018).
- No configurar Keycloak (eso es T-010).
- No levantar BD local (eso es T-002).
- No implementar ningún servicio de negocio.

---

## Criterios de aceptación

### Organización y repositorio

- [ ] Existe la organización en GitHub con los 7 supervisores humanos como miembros.
- [ ] Existe el repositorio `tu-org/erp-project` como **privado**.
- [ ] El repositorio tiene descripción clara y tags relevantes (`erp`, `typescript`, `nestjs`, `monolith`, `prisma`, `ai-agents`).
- [ ] El repositorio tiene la estructura inicial lista según la sección anterior.
- [ ] El bundle de documentación inicial del proyecto (README, CLAUDE.md, agents/, docs/, prompts/, dashboard/, scripts/) está commiteado en el primer commit.

### Branch protection en `main`

- [ ] Requiere al menos 1 aprobación humana en PR antes de merge.
- [ ] Requiere CI verde antes de merge (status check `ci` obligatorio).
- [ ] Prohíbe force push a `main`.
- [ ] Prohíbe eliminación de la rama.
- [ ] Require branches to be up to date antes de merge (evita race conditions de merge).
- [ ] "Include administrators" activado — nadie, ni el admin, puede saltarse la protección.

### Branch protection en `staging`

Idéntica a `main` pero permite auto-merge si CI pasa (para deploys automáticos desde `main` a `staging`).

### Teams y permisos

- [ ] Team `core-squad`: supervisores S1, S2.
- [ ] Team `frontend-squad`: supervisor S3.
- [ ] Team `devops-squad`: supervisor DO.
- [ ] Team `qa-squad`: supervisor QA.
- [ ] Team `product`: PO y Tech Lead.
- [ ] Permisos: `admin` solo para Tech Lead y DO. El resto `maintain` o `write`.

### Templates

- [ ] Existe `.github/pull_request_template.md` con checklist obligatorio (descripción, ticket, tests, invariantes, etc.).
- [ ] Existen plantillas de Issue: `bug_report.md`, `feature_request.md` y un `config.yml` con la configuración de issue templates.
- [ ] Existe `.github/CODEOWNERS` que asigna supervisores automáticamente como reviewers según los archivos modificados.

### Labels

- [ ] Existen labels de agente: `agent:A1`, `agent:A2`, `agent:A3`, `agent:A4`, `agent:A5`, `agent:A6`, `agent:A7`.
- [ ] Existen labels de supervisor: `supervisor:TL`, `supervisor:PO`, `supervisor:S1`, `supervisor:S2`, `supervisor:S3`, `supervisor:DO`, `supervisor:QA`.
- [ ] Existen labels de sprint: `sprint:semana-1`, `sprint:1`, `sprint:2`, `sprint:3`.
- [ ] Existen labels de prioridad: `priority:critical`, `priority:high`, `priority:medium`, `priority:low`.
- [ ] Existen labels de tipo: `type:feature`, `type:bug`, `type:docs`, `type:infra`, `type:test`.
- [ ] Existe label especial: `needs:excel-validation` para cambios que tocan el motor de costos (ver ADR-008).

### CI/CD inicial

- [ ] Existe workflow `.github/workflows/ci.yml` que corre en cada PR.
- [ ] El workflow valida formatting de archivos markdown con un linter (ej: `markdownlint`).
- [ ] El workflow valida shell scripts con `shellcheck`.
- [ ] El workflow verifica que exista `CLAUDE.md` en la raíz (guardrail del modelo híbrido).
- [ ] El workflow corre `./scripts/pre-pr-check.sh` (aunque en este sprint detectará pocos archivos).
- [ ] El workflow agrega un status check obligatorio llamado `ci`.

### Configuración del repositorio

- [ ] `.gitignore` incluye los patrones típicos de Node.js, Java, Python, IDEs, OS.
- [ ] `.editorconfig` define convenciones (LF line endings, UTF-8, 2 espacios para TS/JSON/YAML, 4 espacios para Python/Java).
- [ ] `.gitattributes` fuerza LF para archivos de código (evita problemas entre macOS/Linux/Windows).
- [ ] `LICENSE` con la licencia que el cliente autorice (por default, propietario — **confirmar con PO antes de poner MIT o Apache**).

---

## Invariantes que el agente DEBE respetar

**⚠️ Críticas:**

1. **Ningún bypass de branch protection.** Ni siquiera el admin puede mergear sin aprobación y CI verde.
2. **No exponer secretos.** Los tokens de GitHub se manejan en variables de entorno del supervisor DO, nunca commiteados.
3. **Repositorio privado obligatorio.** Durante el desarrollo, sin excepción.
4. **El primer commit del repo incluye TODA la documentación base** (README, CLAUDE.md, contratos, docs completos). Es la foto fundacional del proyecto. No hacer un commit por archivo ni fragmentar.
5. **Nadie, ni siquiera agentes IA, puede hacer push directo a main después de este ticket.** Todo cambio pasa por PR.

---

## Entregables

- [ ] Organización GitHub configurada (manual por DO, el agente genera los scripts/comandos).
- [ ] Repositorio creado con primer commit fundacional.
- [ ] Archivos de configuración del repo commiteados: `.gitignore`, `.editorconfig`, `.gitattributes`, `LICENSE`.
- [ ] Directorios `.github/` con workflows, CODEOWNERS, templates.
- [ ] Branch protection aplicada y verificada con test (intento manual de push directo debe fallar).
- [ ] Teams y permisos creados.
- [ ] Labels creados vía script.
- [ ] Workflow de CI ejecutándose (aunque sea verde trivial en este primer PR).
- [ ] README del proyecto visible con toda la estructura inicial funcionando.
- [ ] Documento `docs/runbooks/bootstrap-T001.md` que describe qué quedó configurado y cómo auditarlo (sirve de base para re-ejecutar en otro tenant futuro).

### Commit fundacional

```
Autor: DO (no un agente — este commit es manual por ser el primero)
Mensaje: chore(bootstrap): initial project structure with AI agents framework [T-001]

Co-autor registrado: A7 (el agente que generó los scripts y configuraciones)
```

A partir del segundo PR, se retoma el flujo normal (ramas feature, mención de agente en commit).

### PR

No aplica. Este ticket comitea directo a `main` porque la protección todavía se está configurando. **El siguiente ticket (T-002) ya debe seguir el flujo de PR normal.**

---

## Validación post-ejecución

**Manual por DO (no hay `pre-pr-check.sh` todavía operativo):**

```bash
# 1. Verificar que el repo es privado
gh repo view tu-org/erp-project --json visibility

# 2. Verificar branch protection
gh api repos/tu-org/erp-project/branches/main/protection

# 3. Intentar push directo (debe fallar)
git checkout main
echo "test" > test-bypass.txt
git add . && git commit -m "should fail"
git push origin main  # esperado: rechazado por protection

# 4. Verificar labels creados
gh label list --repo tu-org/erp-project

# 5. Verificar teams
gh api orgs/tu-org/teams

# 6. Abrir PR de prueba y verificar que CI corre
git checkout -b test/verify-ci
echo "test" > docs/verify.md
git add . && git commit -m "test: verify CI runs"
git push origin test/verify-ci
gh pr create --title "test CI" --body "prueba"
# Verificar en GitHub que el workflow 'ci' está marcado como required
```

Si todo lo anterior pasa: ticket aprobado.

---

## Guía de ejecución para el supervisor DO

Esta sección es **exclusivamente para el supervisor humano**. Explica cómo invocar al agente A7 cuando aún no hay `CLAUDE.md` leíble por Claude Code.

### Paso 1: Preparar el workspace local

```bash
# En la máquina del supervisor
mkdir -p ~/proyectos/erp-bootstrap
cd ~/proyectos/erp-bootstrap

# Copiar el bundle de documentación inicial (entregado al iniciar el proyecto)
unzip /ruta/al/erp-project-bundle.zip
cd erp-project

# Verificar estructura
ls -la
```

### Paso 2: Configurar variables de entorno para GitHub

```bash
# Token con permisos de admin sobre la organización
export GH_TOKEN="ghp_xxxxxxxxxxxxx"

# Autenticar gh CLI
gh auth login
gh auth status
```

### Paso 3: Invocar Claude Code con contexto explícito

Como es el primer ticket y Claude Code aún no tiene un repo inicializado con git, abrir la sesión apuntando al directorio preparado:

```bash
cd ~/proyectos/erp-bootstrap/erp-project
claude
```

### Paso 4: Primer prompt al agente A7

Una vez en la sesión de Claude Code, pegar el siguiente prompt:

```
Ejecuta el ticket T-001 (bootstrap del proyecto).

Actúas como agente A7 (DevOps & Infra). Lee estos archivos en orden antes de empezar:

1. @CLAUDE.md (instrucciones globales)
2. @agents/A7-devops.md (tu contrato como agente A7)
3. @prompts/backlog/T-001-bootstrap.md (este ticket)
4. @docs/stack.md (tecnologías permitidas)
5. @docs/adrs/ADR-009-claude-code-como-herramienta-estandar.md (contexto del modelo)
6. @docs/adrs/ADR-010-monolito-modular.md (arquitectura actual)

Después:

1. Genera todos los archivos de configuración listados en el ticket
   (.gitignore, .editorconfig, .gitattributes, CODEOWNERS, PR template,
   issue templates, workflows/ci.yml).
2. Genera un script bash `scripts/bootstrap-github.sh` que yo (DO) ejecutaré
   para crear la organización, el repo, teams, branch protection y labels
   usando `gh` CLI.
3. Genera el documento `docs/runbooks/bootstrap-T001.md` que describe paso
   a paso lo que el script hace y cómo auditar que se aplicó correctamente.

Reglas importantes:
- No hagas `git init` ni commits — eso lo haré yo manualmente como DO.
- No ejecutes el script de GitHub — lo revisaré y ejecutaré yo.
- Los secretos (tokens) se leen de variables de entorno, nunca hardcodeados.
- Pregunta antes de asumir cualquier valor (nombre de la organización, licencia, emails de los supervisores).
```

### Paso 5: Revisar la salida del agente

Antes de ejecutar cualquier script que el agente haya generado:

```bash
# Leer script línea por línea
cat scripts/bootstrap-github.sh

# Ejecutar con --dry-run si el script lo soporta, o correr solo la parte de verificación
bash -x scripts/bootstrap-github.sh --dry-run
```

### Paso 6: Ejecutar la creación real

```bash
# Ejecutar el script de bootstrap
bash scripts/bootstrap-github.sh

# Hacer el primer commit fundacional manualmente
git init
git add .
git commit -m "chore(bootstrap): initial project structure with AI agents framework [T-001]

Co-authored-by: Agent-A7 <a7-devops@erp-project.internal>"

# Conectar con el remote ya creado
git remote add origin git@github.com:tu-org/erp-project.git
git branch -M main
git push -u origin main

# Aplicar branch protection DESPUÉS del primer push (si no, no habría rama para proteger)
bash scripts/bootstrap-github.sh --apply-protection
```

### Paso 7: Validación final

Ejecutar los comandos de validación listados en la sección anterior del ticket. Si todo pasa, marcar T-001 como `done` en el backlog y avisar al equipo en `#erp-build` que el proyecto está listo para que arranque T-002.

### Qué hacer si algo falla

- **El agente propone configuraciones fuera del contrato A7:** pedirle que pare y revisar contra `agents/A7-devops.md`.
- **El script de bootstrap falla:** leer logs, corregir manualmente, y pedir al agente que actualice el script para que sea idempotente.
- **Branch protection no aplica correctamente:** puede ser que requiera que exista al menos un commit en `main` primero. Re-ejecutar solo la parte de protección después del primer push.

---

## Validación post-ejecución (lo llena el supervisor humano)

- **Fecha de ejecución:** _pendiente_
- **Tiempo real de supervisión:** _pendiente_
- **Iteraciones con el agente:** _pendiente_
- **Resultado:** _pendiente (aprobado | requiere cambios | bloqueado)_
- **Notas:** _pendiente_
- **Problemas encontrados y cómo resolverlos en T-002+:** _pendiente_

---

**Creado:** 2026-04-22 por TL + DO (revisión conjunta por ser bootstrap)
**Plantilla base:** `prompts/templates/ticket-template.md` v1.0 (con adaptaciones para bootstrap)
