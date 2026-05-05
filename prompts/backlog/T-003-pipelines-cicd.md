# T-003 · Pipelines CI/CD completos (GitHub Actions)

**Ticket Jira:** https://tu-org.atlassian.net/browse/T-003
**Agente asignado:** A7 (DevOps & Infra)
**Supervisor humano:** DO
**Sprint:** Semana 1 — Fundamentos
**Estimación:** 3 puntos
**Prioridad:** crítica
**Rama:** `feat/T-003-pipelines-cicd`

---

## Contexto de negocio

Sin CI/CD, el modelo híbrido humanos + IA no funciona. El pipeline es el guardrail automático que verifica cada PR antes de que el supervisor humano lo revise. Si el pipeline no existe, los agentes IA pueden mergear código roto, y el supervisor no tiene señal objetiva de calidad.

Este ticket crea los pipelines que correrán en **cada PR** del proyecto durante los próximos 6 meses. La calidad y velocidad del pipeline impacta directamente la productividad diaria del equipo.

---

## Alcance técnico

### Crear

```
.github/
├── workflows/
│   ├── ci.yml                  ← pipeline principal (corre en cada PR)
│   ├── cd-staging.yml          ← deploy a staging (merge a main)
│   └── excel-validation.yml    ← validación fixture Excel (PRs con label)
└── CODEOWNERS                  ← ya existe, verificar que esté correcto
```

### No tocar

- `docker-compose.yml` — eso es T-002.
- Kubernetes/Helm/ArgoCD — eso es T-018 (staging real).
- Secrets de producción — los configura DO manualmente en GitHub Settings.

---

## Criterios de aceptación

### Pipeline CI (`ci.yml`)

Corre en **todo PR** hacia `main` o `staging`.

**Jobs que debe tener:**

#### Job 1: `lint-and-typecheck`
- [ ] Checkout del código.
- [ ] Setup Node.js 20 LTS con cache de npm.
- [ ] `cd services/erp-api && npm ci`.
- [ ] `npm run lint` (ESLint).
- [ ] `npm run typecheck` (tsc --noEmit).
- [ ] Falla si hay errores de lint o tipos.

#### Job 2: `test-unit`
- [ ] Depende de `lint-and-typecheck`.
- [ ] `npm run test` con Jest.
- [ ] Genera reporte de cobertura.
- [ ] Sube cobertura como artefacto (no bloquea si cobertura < umbral todavía — se activa en Sprint 2).
- [ ] Falla si algún test falla.

#### Job 3: `test-integration`
- [ ] Depende de `lint-and-typecheck`.
- [ ] Levanta PostgreSQL 15 y Redis 7 como services de GitHub Actions.
- [ ] Corre migraciones Prisma (`npx prisma migrate deploy`).
- [ ] `npm run test:integration`.
- [ ] Falla si algún test de integración falla.

#### Job 4: `build`
- [ ] Depende de `test-unit` y `test-integration`.
- [ ] `npm run build` (compila TypeScript).
- [ ] Falla si no compila.

#### Job 5: `validate-docs`
- [ ] Corre en paralelo (no depende de otros jobs).
- [ ] Verifica que `CLAUDE.md` existe en raíz.
- [ ] Verifica que `docs/prisma-workflow.md` existe.
- [ ] Verifica que `docs/architecture.md` existe.
- [ ] Lintea archivos Markdown con `markdownlint-cli2`.
- [ ] Valida scripts `.sh` con `shellcheck`.
- [ ] **No bloquea** el merge (warning only) — los docs pueden estar en progreso.

#### Job 6: `security-scan`
- [ ] Corre `npm audit --audit-level=high` en `services/erp-api`.
- [ ] Corre `trufflesecurity/trufflehog` para detectar secretos commiteados.
- [ ] **Bloquea** el merge si encuentra secretos o vulnerabilidades críticas.

**Status check obligatorio:** el status check llamado `ci` debe estar verde para poder mergear. Este status lo emite el job `build` al completarse.

---

### Pipeline Excel Validation (`excel-validation.yml`)

Corre **solo** en PRs que tienen el label `needs:excel-validation`.

- [ ] Checkout del código.
- [ ] Setup Node.js 20.
- [ ] `npm ci` en `services/erp-api`.
- [ ] Levanta PostgreSQL como service.
- [ ] Corre migraciones.
- [ ] `npm run test -- --testPathPattern=costo-calculator`.
- [ ] **Bloquea el merge** si menos de 49 de 50 casos del fixture pasan.
- [ ] Genera un comentario automático en el PR con el resultado (cuántos casos pasaron, cuántos fallaron, y cuáles).

---

### Pipeline CD Staging (`cd-staging.yml`)

Corre cuando se hace **merge a `main`**.

Por ahora (sin K8s todavía), solo:
- [ ] Hace `docker build` de `services/erp-api`.
- [ ] Verifica que la imagen buildea sin errores.
- [ ] Registra la imagen en GitHub Container Registry (GHCR) con tag `latest` y tag del commit SHA.
- [ ] Crea un release en GitHub con el SHA y la fecha.

> El deploy real a staging viene en T-018. Este pipeline deja todo listo para cuando llegue.

---

### Configuración de secrets necesarios

El agente genera un archivo `.github/SECRETS.md` (no commitear valores reales) que documenta qué secrets debe configurar DO en GitHub Settings:

```
POSTGRES_PASSWORD       → password de PostgreSQL para CI
REDIS_URL               → URL de Redis para CI  
GHCR_TOKEN              → token para publicar imágenes en GHCR
```

---

### Performance del pipeline

- [ ] El pipeline completo (jobs paralelos) termina en **menos de 5 minutos** en un PR típico.
- [ ] Usa caché de npm agresivo (`actions/cache` con `~/.npm`).
- [ ] Usa caché de Docker layers si es posible.

---

## Invariantes que el agente DEBE respetar

1. **Los secrets nunca van en el YAML.** Solo referencias a `${{ secrets.X }}`.
2. **El job `build` emite el status check `ci`.** Si no hay status check `ci`, branch protection no funciona.
3. **El pipeline de Excel validation solo corre con el label correcto.** No corre en todos los PRs — es costoso.
4. **Versiones fijas en las actions.** No usar `@main` ni `@latest`. Usar `@v4`, `@v3`, etc.

---

## Casos de prueba

### Caso 1 — PR limpio pasa
```
Crear PR con cambio trivial en docs/
→ CI corre → todos los jobs pasan → merge permitido
```

### Caso 2 — PR con error de lint falla
```
Crear PR con código TypeScript con lint error
→ job lint-and-typecheck falla → merge bloqueado
→ El error está visible en el PR como check fallido
```

### Caso 3 — PR con secreto commiteado falla
```
Crear PR que añade API_KEY="sk-xxx" en un .env.example mal
→ job security-scan falla → merge bloqueado
```

### Caso 4 — PR con label excel-validation
```
Crear PR con label needs:excel-validation
→ Pipeline excel-validation corre además del CI normal
→ Comentario automático en el PR con resultado del fixture
```

### Caso 5 — Merge a main genera imagen Docker
```
Mergear PR a main
→ cd-staging.yml corre
→ Imagen aparece en GHCR bajo ghcr.io/{owner}/erp-api:{sha}
```

---

## Entregables

- [ ] `.github/workflows/ci.yml`
- [ ] `.github/workflows/cd-staging.yml`
- [ ] `.github/workflows/excel-validation.yml`
- [ ] `.github/SECRETS.md` (documenta qué secrets configurar, sin valores reales)
- [ ] `services/erp-api/package.json` actualizado con scripts: `lint`, `typecheck`, `test`, `test:integration`, `build`
- [ ] Commit: `ci: add github actions pipelines for ci/cd and excel validation [A7]`
- [ ] PR con labels `agent:A7`, `supervisor:DO`, `sprint:semana-1`, `priority:critical`, `type:infra`

---

## Validación post-ejecución (lo llena DO)

```bash
# 1. Crear un PR de prueba y verificar que CI corre
git checkout -b test/verify-ci
echo "# test" >> docs/verify-ci.md
git add . && git commit -m "test: verify ci pipeline"
git push origin test/verify-ci
gh pr create --title "test: verify ci" --body "prueba de pipeline"

# 2. Verificar en GitHub que aparecen los checks
gh pr checks

# 3. Verificar que branch protection requiere el check 'ci'
gh api repos/{OWNER}/{REPO}/branches/main/protection
```

- **Fecha:** _pendiente_
- **Tiempo total del pipeline:** _pendiente (objetivo <5 min)_
- **Resultado:** _pendiente_

---

**Creado:** 2026-04-27 por DO + TL
**Plantilla base:** `prompts/templates/ticket-template.md` v1.0
