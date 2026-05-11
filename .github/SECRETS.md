# GitHub Actions — Secrets requeridos

Este archivo documenta los secrets que DO debe configurar manualmente en
**GitHub → Settings → Secrets and variables → Actions** antes de que los
pipelines puedan correr correctamente.

**IMPORTANTE:** No commitear valores reales en este archivo ni en ningún YAML.
Solo se documenta el nombre y propósito de cada secret.

---

## Secrets requeridos

| Secret | Usado en | Propósito |
|---|---|---|
| `POSTGRES_PASSWORD` | `ci.yml`, `excel-validation.yml` | Password del usuario `erp_admin` en los services de PostgreSQL que levanta GitHub Actions para tests de integración. |
| `REDIS_URL` | `ci.yml` | URL completa de Redis para tests de integración (ej: `redis://localhost:6379`). En CI, Redis corre como service en localhost — este secret permite parametrizar si se usa auth o no. |
| `GHCR_TOKEN` | _(reservado)_ | Token con permisos `write:packages` para publicar imágenes en GHCR. **Actualmente `cd-staging.yml` usa `GITHUB_TOKEN` automático** — este secret solo será necesario si se configura un bot de CI separado. |

---

## Secrets automáticos (no hay que configurar)

| Secret | Provisto por | Propósito |
|---|---|---|
| `GITHUB_TOKEN` | GitHub Actions (automático) | Usado en `cd-staging.yml` para `docker/login-action` hacia GHCR y en `excel-validation.yml` para comentar en PRs. |

---

## Branch protection — configuración requerida

El pipeline CI emite un commit status con contexto exacto `ci` via la GitHub
Statuses API. Para que branch protection lo requiera:

1. Ir a **GitHub → Settings → Branches → main → Edit rule**.
2. En "Require status checks to pass before merging", buscar y agregar: `ci`
3. Repetir para la rama `staging`.

El check `ci` es emitido por el job `set-ci-status` en `ci.yml`, que siempre
corre (incluso si jobs anteriores fallaron) y refleja el resultado de `build`
+ `security-scan`.

---

## Configuración de label para Excel validation

El workflow `excel-validation.yml` solo corre en PRs con el label
`needs:excel-validation`. Crear el label en:
**GitHub → Issues → Labels → New label**

- Nombre: `needs:excel-validation`
- Color sugerido: `#e4e669`
- Descripción: `Activa la validación del fixture Excel de costos de producción`

---

_Mantenido por: A7 (DevOps & Infra) | Supervisor: DO_
