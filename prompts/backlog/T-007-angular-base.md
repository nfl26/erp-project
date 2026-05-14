# T-007 · Proyecto Angular 17 base con standalone, NgRx Signals y ag-grid

**Ticket Jira:** https://tu-org.atlassian.net/browse/T-007
**Agente asignado:** A4 (UI Angular)
**Supervisor humano:** S3 (Supervisor frontend)
**Sprint:** Semana 1 — Fundamentos
**Estimación:** 2 puntos
**Prioridad:** crítica
**Rama:** `feat/T-007-angular-base`

---

## ⚠️ Nota sobre el número del ticket

> El número T-007 fue usado previamente para un ticket de schema PostgreSQL que quedó archivado (ver `prompts/archived/T-007-schema-postgresql-v1.md`). El backlog actual del dashboard (`dashboard/erp_agentes_ia.html`) reasigna T-007 a **"Proyecto Angular 17 base"**. Este ticket es la versión vigente.
>
> Si surge confusión, `prompts/backlog/T-007-angular-base.md` (este archivo) es la fuente de verdad y `prompts/archived/T-007-schema-postgresql-v1.md` se preserva solo como historia.

---

## Contexto de negocio

El **backoffice del ERP** es la herramienta de trabajo diaria de las personas internas del cliente: bodegueros validando movimientos, jefes de producción revisando OPs, vendedores cerrando cotizaciones, administradores ajustando catálogos. Sus dos requerimientos dominantes son:

1. **Listados densos con miles de filas** que se filtran, ordenan, agrupan y exportan sin renderizar todo el DOM. Un bodeguero filtra 1500 insumos por categoría en menos de 100ms sin esperar paginación servidor.
2. **Formularios complejos** con validación cruzada (crear una OP exige seleccionar receta + variante + cantidad + máquina + asignación de trabajadores, con reglas que cambian según la combinación).

Esto define el stack: **Angular 17 standalone** (sin NgModules legacy), **NgRx Signals** para estado fino-granulado sin boilerplate de RxJS antiguo, **ag-grid community** para tablas potentes, **Reactive Forms** para formularios con validación tipada.

Diferencia con el portal Next.js (T-006): este backoffice **siempre requiere autenticación**, no se expone a clientes externos, y prioriza densidad de información sobre estética minimalista. Comparte solo los **design tokens CSS** con el portal — no hay código TypeScript compartido entre frontends.

Este ticket entrega el **scaffolding base**. Los tickets de feature (T-018 listado bodega, T-031 detalle OP, T-040 cotizaciones backoffice) construyen encima.

---

## Alcance técnico

### Crear

```
web/backoffice/
├── src/
│   ├── app/
│   │   ├── app.component.ts            ← shell raíz standalone
│   │   ├── app.config.ts                ← providers globales (router, http, ngrx)
│   │   ├── app.routes.ts                ← rutas raíz con lazy loading
│   │   ├── core/                        ← servicios singleton transversales
│   │   │   ├── http/
│   │   │   │   ├── api.interceptor.ts   ← auth header + error handling
│   │   │   │   └── api.types.ts         ← ApiError, Page<T> (igual que A3)
│   │   │   ├── config/
│   │   │   │   └── env.ts                ← validación de env con zod
│   │   │   └── README.md
│   │   ├── shared/                      ← componentes reutilizables
│   │   │   ├── ui/
│   │   │   │   ├── button.component.ts
│   │   │   │   ├── card.component.ts
│   │   │   │   └── input.component.ts
│   │   │   ├── grid/
│   │   │   │   └── grid.component.ts    ← wrapper de ag-grid con tokens
│   │   │   └── README.md
│   │   ├── layout/                      ← shell visual (sidebar, header, footer)
│   │   │   ├── shell.component.ts
│   │   │   ├── sidebar.component.ts
│   │   │   └── header.component.ts
│   │   ├── features/                    ← módulos de negocio (placeholders)
│   │   │   ├── home/
│   │   │   │   ├── home.component.ts    ← landing post-login
│   │   │   │   └── home.routes.ts
│   │   │   └── README.md                 ← cómo agregar una feature
│   │   └── pages/
│   │       ├── not-found.component.ts
│   │       └── error.component.ts
│   ├── styles/
│   │   ├── tokens.css                   ← MISMO archivo que web/public (ver criterios)
│   │   ├── globals.css
│   │   └── ag-grid-theme.css            ← override de ag-grid con tokens propios
│   ├── assets/
│   │   └── favicon.ico
│   ├── environments/                    ← evitamos; usamos env.ts (ver criterios)
│   ├── index.html
│   ├── main.ts
│   └── styles.css
├── tests/
│   └── cypress/
│       ├── e2e/
│       │   └── smoke.cy.ts
│       └── cypress.config.ts
├── .eslintrc.json
├── angular.json
├── package.json
├── tsconfig.json
├── tsconfig.app.json
├── tsconfig.spec.json
├── .env.example
└── README.md
```

### Modificar

- `.gitignore` raíz — verificar que `web/backoffice/node_modules/`, `web/backoffice/dist/`, `web/backoffice/.angular/`, `.env.local` están cubiertos.
- `README.md` raíz — agregar referencia al backoffice en la lista de servicios.
- `docs/architecture.md` — actualizar diagrama de despliegue con el backoffice en puerto 4200.

### No tocar

- **`web/public/`** — territorio de A3 (T-006). Excepción coordinada: los tokens CSS (`styles/tokens.css`) son **compartidos** — ver criterios.
- **`services/`** — dominio de A1.
- **`infra/`** — dominio de A7.
- **`.github/workflows/`** — dominio de A7. Si necesita job de CI, A4 deja nota en el PR.

---

## Criterios de aceptación

### Setup del proyecto

- [ ] **Angular 17.3.x** (LTS) instalado con `ng new backoffice --standalone --routing --style=css --skip-tests=false --strict`.
- [ ] **TypeScript estricto** (`"strict": true`, `"noImplicitOverride": true`, `"noFallthroughCasesInSwitch": true`).
- [ ] **Standalone components** por defecto (sin NgModules legacy). Si el agente cae en `app.module.ts`, está mal.
- [ ] **Node.js 20 LTS** especificado en `engines` de `package.json` y en `.nvmrc`.
- [ ] **Zone.js** o **zoneless** — usar **zone.js por ahora** (zoneless en Angular 17 todavía es experimental para ag-grid).

### Dependencias principales

- [ ] **`@ngrx/signals`** para estado (no NgRx Store clásico).
- [ ] **`ag-grid-angular` + `ag-grid-community`** (community, no enterprise — el cliente no pagará licencia inicialmente).
- [ ] **`@angular/forms`** (Reactive Forms).
- [ ] **`zod`** para validación (de env vars y de respuestas del API).
- [ ] **`lucide-angular`** para íconos (consistente con portal Next.js que usa `lucide-react`).
- [ ] **`date-fns`** para fechas (locale `es` por defecto).
- [ ] **`@playwright/test` o `cypress`** para E2E. **Decisión: cypress** (consistente con el contrato A4 v1.0). Si A4 prefiere Playwright por consistencia con A3, abrir conversación con S3 ANTES de implementar.

> **Por qué NgRx Signals y no NgRx Store clásico**
> NgRx Signals nació con Angular 17 y elimina el boilerplate de actions/reducers/effects para el 80% de los casos. Stores granulares por feature, sin acoplar todo a una mega-store global. Para casos complejos (efectos asíncronos en cascada) aún se puede usar `@ngrx/effects` puntualmente.
>
> **Por qué ag-grid community y no PrimeNG / Material**
> Las dos requisitos dominantes del backoffice (listados con miles de filas + filtros densos) son justamente lo que ag-grid hace mejor que cualquier alternativa gratuita. PrimeNG y Material Table caen en rendimiento con > 1000 filas y filtros múltiples.

### Tokens CSS compartidos con A3

- [ ] El archivo `web/backoffice/src/styles/tokens.css` debe ser **idéntico (byte a byte)** al de `web/public/styles/tokens.css` (T-006).
- [ ] **Estrategia de sincronización** (elegir UNA y documentar):
  - **Opción A — Symlink desde un directorio compartido `web/shared-tokens/tokens.css`** que ambos proyectos referencian. Limpia, pero algunos sistemas (Windows sin developer mode) no manejan bien symlinks. Si A4 elige esta opción, validar con DO.
  - **Opción B — Script `scripts/sync-tokens.sh`** que copia desde una fuente única (`web/shared-tokens/tokens.css`) hacia los dos consumidores, ejecutado como pre-commit hook o en CI.
  - **Opción C — Copia manual con regla obligatoria** documentada en CONTRIBUTING.md y verificada por un test de CI que hace diff entre los dos archivos.
- [ ] **Recomendación: Opción B.** A4 implementa el script y A7 lo integra con husky o en el job de CI en otro ticket si es necesario.
- [ ] **Coordinación obligatoria con A3** antes de finalizar paleta. Si T-006 todavía no está mergeado, A4 propone tokens y A3 los adopta; si T-006 ya está mergeado, A4 importa los tokens existentes sin tocarlos.

### Configuración del shell

- [ ] `app.config.ts` registra providers en orden:
  - `provideRouter(routes, withComponentInputBinding())`
  - `provideHttpClient(withInterceptors([apiInterceptor]))`
  - `provideAnimationsAsync()` (Angular 17 lazy animations)
  - Cualquier provider de NgRx Signals que sea global (la mayoría son por-feature).
- [ ] `app.component.ts` es el shell de la app: monta `<app-shell>` con sidebar + header + `<router-outlet>`.
- [ ] `app.routes.ts` define las rutas raíz con **lazy loading por feature**:
  ```typescript
  export const routes: Routes = [
    { path: '', redirectTo: 'home', pathMatch: 'full' },
    { path: 'home', loadChildren: () => import('./features/home/home.routes').then(r => r.routes) },
    { path: '**', component: NotFoundComponent },
  ];
  ```
- [ ] Después de T-015 (login con Keycloak), se agregarán guards de auth. Hoy no.

### Layout / shell visual

- [ ] **Sidebar** con navegación principal (placeholders para Bodega, Producción, Ventas, Configuración) que aparecerán pobladas por sus tickets.
- [ ] **Header** con espacio para usuario logueado (vacío hoy) y botón de toggle modo oscuro (toggle se cablea cuando haya estado global de tema — placeholder por ahora).
- [ ] **Área principal** con `<router-outlet>`.
- [ ] El layout es **responsive básico**: sidebar colapsable en pantallas < 1024px. No mobile-first agresivo — el backoffice se opera desde desktop.
- [ ] Usar **CSS Grid** para el layout principal. Nada de tablas o flexbox anidados.

### Componentes UI primitivos

Mínimo viable (3 componentes, igual que el portal):

- [ ] `<app-button>` con inputs `variant`, `size`, `disabled`, `loading`, `(clicked)` output.
- [ ] `<app-card>` con `ng-content` para header, body, footer.
- [ ] `<app-input>` con `ControlValueAccessor` para integrar con Reactive Forms, label, error message, hint.
- [ ] Cada componente es **standalone** con su propia `imports: [...]`.
- [ ] Cada componente tiene comentario JSDoc con ejemplo de uso.

### Wrapper de ag-grid

- [ ] `<app-grid>` que abstrae ag-grid con:
  - Tema CSS aplicado desde `tokens.css` (no `ag-theme-alpine` puro).
  - Configuración por defecto: paginación, filtros por columna, ordenamiento, animación de filas, locale `es`.
  - Inputs tipados: `rowData<T>`, `columnDefs: ColDef<T>[]`.
  - Sin lógica de negocio hardcodeada (filtros, formatters específicos).
- [ ] Documentar en JSDoc cómo se usará en T-018 (listado bodega) — ese ticket es el primer consumidor real.

### Cliente HTTP base

- [ ] `core/http/api.interceptor.ts`:
  - Lee URL base desde env validada.
  - Agrega headers `Content-Type: application/json`, `Accept: application/json`.
  - Pasa errores RFC 7807 a `ApiError` tipado.
  - **Sin Authorization header todavía** — comentario `// TODO T-015: agregar Bearer token de Keycloak`.
- [ ] `core/http/api.types.ts`:
  - `ApiError` con campos `type`, `title`, `status`, `detail`, `instance`, `traceId` (idéntico al de T-006).
  - `Page<T>` con `items`, `total`, `page`, `pageSize` (idéntico al de T-006 y al que devuelve T-016).

### Validación de variables de entorno

- [ ] **No usar** `environments/environment.ts` clásico de Angular (es estático y no valida).
- [ ] Usar `core/config/env.ts` con zod, llamado desde `main.ts` antes del bootstrap.
- [ ] Variables:
  - `NG_APP_API_URL` (string url, obligatorio)
  - `NG_APP_ENV` (`'development' | 'staging' | 'production'`)
  - `NG_APP_SENTRY_DSN` (opcional)
  - `NG_APP_KEYCLOAK_URL` (placeholder hasta T-015)
  - `NG_APP_KEYCLOAK_REALM` (placeholder hasta T-015)
  - `NG_APP_KEYCLOAK_CLIENT_ID` (placeholder hasta T-015)
- [ ] Variables se inyectan en build time vía `@ngx-env/builder` (recomendado) o equivalente que A4 elija si tiene mejor alternativa.

### Scripts en package.json

- [ ] `start` — `ng serve --port 4200`
- [ ] `build` — `ng build`
- [ ] `build:prod` — `ng build --configuration production`
- [ ] `test` — `ng test --watch=false --browsers=ChromeHeadless`
- [ ] `test:e2e` — `cypress run`
- [ ] `test:e2e:open` — `cypress open`
- [ ] `lint` — `ng lint`
- [ ] `typecheck` — `tsc --noEmit -p tsconfig.app.json`
- [ ] `format` — `prettier --write src/`

### Tests E2E mínimos (Cypress)

- [ ] Cypress configurado contra `http://localhost:4200`.
- [ ] `tests/cypress/e2e/smoke.cy.ts` con assertions:
  - El home (`/`) carga sin errores de consola.
  - Hay un `<h1>` o equivalente visible.
  - La sidebar se renderiza con sus items placeholder.
- [ ] `cypress.config.ts` con `baseUrl`, `viewportWidth: 1440`, `viewportHeight: 900` (desktop-first).

### Variables de entorno

- [ ] `.env.example`:
  ```bash
  NG_APP_API_URL=http://localhost:3000/api/v1
  NG_APP_ENV=development
  NG_APP_SENTRY_DSN=

  # Keycloak (placeholders hasta T-015)
  NG_APP_KEYCLOAK_URL=http://localhost:8080
  NG_APP_KEYCLOAK_REALM=erp
  NG_APP_KEYCLOAK_CLIENT_ID=erp-frontend
  ```
- [ ] `.env.local` no se commitea.

### Integración con CI

- [ ] El workflow `ci.yml` debe tener job para el backoffice:
  - `npm ci`
  - `npm run lint`
  - `npm run typecheck`
  - `npm run build:prod`
  - `npm run test`
- [ ] Si no existe ese job, A4 deja comentario en el PR para A7. **No agregar el job directamente** (fuera de dominio A4).

### README del backoffice

- [ ] `web/backoffice/README.md` con:
  - Cómo arrancar localmente (3 pasos máximo).
  - Estructura del proyecto.
  - Convenciones: standalone components, signals, lazy loading por feature.
  - Cómo agregar una nueva feature (template/receta).
  - Cómo agregar un componente shared.
  - Variables de entorno requeridas.
  - Comandos disponibles.
  - Enlace al contrato del agente A4 y a ADRs relevantes.

### Performance baseline

- [ ] `npm run build:prod` reporta tamaños de chunks. Objetivos no bloqueantes pero registrados en el PR:
  - **Initial bundle**: < 500 kB gzipped (ag-grid pesa, asumimos algo de holgura).
  - **Lazy chunks**: < 100 kB gzipped por feature.
- [ ] Si A4 detecta un paquete que infla el bundle desproporcionadamente, reportar en el PR.

---

## Invariantes que el agente DEBE respetar

1. **Standalone components, no NgModules**. Si el agente cae en `app.module.ts`, está mal y pierde el espíritu de Angular 17.
2. **Signals para estado, no `Subject` global por defecto**. RxJS sigue disponible para flujos asíncronos, pero el estado local de componentes y stores de feature usa Signals.
3. **Lazy loading por feature.** El bundle inicial solo carga el shell y la feature home. Bodega, producción y ventas son lazy.
4. **Sin estado compartido global "todo en una store".** Cada feature tiene su store NgRx Signals propio. La comunicación entre features pasa por el router o por el backend.
5. **Tokens CSS son la fuente de verdad de estilos.** No hex hardcodeados en componentes. Si necesitas un color que no está en tokens, agrégalo al archivo (en coordinación con A3).
6. **No autenticación todavía.** Si A4 implementa Keycloak login, se salió del scope (T-015).
7. **Cualquier llamada al backend pasa por el `apiInterceptor`**. No `HttpClient.get()` puro en componentes — usar servicios de feature que internamente usen `HttpClient`.
8. **El wrapper `<app-grid>` es la única manera de usar ag-grid en componentes de feature.** No importar `AgGridAngular` directamente en otros componentes.

---

## Casos de prueba obligatorios

### Caso 1 — Arranque limpio en dev

```bash
cd web/backoffice
cp .env.example .env.local
npm ci
npm start
# Esperado: arranca en puerto 4200 sin warnings. Abre http://localhost:4200 y ve el shell.
```

### Caso 2 — Build de producción

```bash
npm run build:prod
# Esperado: sin errores, sin warnings de TS, sin warnings de Angular sobre uso incorrecto.
# Reporta tamaños de chunks.
```

### Caso 3 — Falta de env var requerida

```bash
unset NG_APP_API_URL
npm run build
# Esperado: falla con mensaje claro indicando qué variable falta y qué tipo debe tener.
```

### Caso 4 — Smoke test E2E pasa

```bash
npm run test:e2e
# Esperado: 3 assertions verdes en < 60 segundos.
```

### Caso 5 — Tokens CSS son idénticos entre frontends

```bash
diff web/public/styles/tokens.css web/backoffice/src/styles/tokens.css
# Esperado: sin diferencias (o solo whitespace).

# Si A4 eligió Opción B (script sync-tokens.sh):
./scripts/sync-tokens.sh
diff web/public/styles/tokens.css web/backoffice/src/styles/tokens.css
# Esperado: 0 diferencias.
```

### Caso 6 — ag-grid renderiza dentro del wrapper

```bash
# Test unitario o e2e: montar <app-grid [rowData]="mockData" [columnDefs]="mockCols">
# Verificar que renderiza, los filtros funcionan, el theme es el correcto.
```

### Caso 7 — Lint y typecheck pasan

```bash
npm run lint     # 0 errores
npm run typecheck # 0 errores
```

### Caso 8 — Lazy chunks se generan correctamente

```bash
npm run build:prod
ls dist/backoffice/browser/chunk-*.js | wc -l
# Esperado: al menos 2 chunks (main + home). Cuando haya más features, crecerá.
```

### Caso 9 — El interceptor no llama al backend si no hay backend

```bash
# Con erp-api apagado, abrir el backoffice.
# Esperado: la app NO se rompe. El home se renderiza. Si hay una llamada al API
# fallida, se muestra estado de error pero la UI sigue viva.
```

---

## Lo que NO se debe hacer en esta tarea

- **No implementar login con Keycloak.** Es T-015. Hoy: placeholders en env, sin código.
- **No crear features de negocio** (Bodega, Producción, Ventas). Esos tickets son T-018, T-031, T-040.
- **No usar NgModules**. Standalone es obligatorio.
- **No instalar ag-grid enterprise**. Solo community.
- **No agregar Material o PrimeNG**. Se descartaron por performance en listados densos.
- **No agregar i18n**. El cliente habla español.
- **No tocar configuración de CI/CD**. Si falta job, A4 deja nota.
- **No subir secretos**, ni siquiera "de prueba", al repo.
- **No exportar nada de `web/backoffice/`** que `web/public/` pretenda importar. Los frontends no comparten código TypeScript. Si A4 detecta presión para compartir TS, escalarlo a S3.
- **No usar SSR (Angular Universal).** El backoffice es SPA pura — los usuarios siempre están autenticados y no necesitamos SEO.

---

## Contratos y referencias

- **Contrato del agente:** [`agents/A4-angular.md`](../../agents/A4-angular.md)
- **Contrato A3 (coordinación de tokens):** [`agents/A3-nextjs.md`](../../agents/A3-nextjs.md)
- **Stack tecnológico:** [`docs/stack.md`](../../docs/stack.md)
- **Arquitectura general:** [`docs/architecture.md`](../../docs/architecture.md)
- **ADRs relevantes:**
  - [ADR-010 Monolito modular](../../docs/adrs/ADR-010-monolito-modular.md)
- **Documentación Angular 17:** https://angular.dev (no la docs vieja en angular.io)
- **NgRx Signals:** https://ngrx.io/guide/signals
- **ag-grid Angular:** https://www.ag-grid.com/angular-data-grid/getting-started/

---

## Entregables

- [ ] Proyecto Angular 17 funcionando en `web/backoffice/` según estructura del alcance.
- [ ] Shell con sidebar + header + área principal renderizado en `http://localhost:4200`.
- [ ] Wrapper `<app-grid>` funcional (testeable con datos mock).
- [ ] Smoke test Cypress pasa.
- [ ] Build de producción genera bundle con tamaño razonable.
- [ ] `web/backoffice/README.md` completo.
- [ ] Tokens CSS sincronizados con `web/public/styles/tokens.css` (opción B: script `sync-tokens.sh` incluido).
- [ ] `.env.example` con todas las variables documentadas.
- [ ] Commit: `feat(backoffice): bootstrap angular 17 standalone with ngrx signals and ag-grid [A4]`
- [ ] PR con labels: `agent:A4`, `supervisor:S3`, `sprint:semana-1`, `priority:critical`, `type:feature`

---

## Cómo invocar al agente en Claude Code

```bash
cd erp-project
git checkout -b feat/T-007-angular-base
claude
```

Prompt:

```
Ejecuta T-007 (backoffice Angular 17 base).

Actúas como agente A4. Lee en orden:
1. @CLAUDE.md
2. @agents/A4-angular.md
3. @prompts/backlog/T-007-angular-base.md (este ticket)
4. @docs/stack.md
5. @docs/architecture.md
6. @web/public/styles/tokens.css (si T-006 ya está mergeado — para importar paleta)

Antes de empezar, pregúntame:
1. ¿T-006 (portal Next.js) ya está mergeado? Si sí, los tokens CSS son los de allá.
   Si no, definimos juntos con A3 y dejamos coordinada la actualización.
2. ¿E2E con Cypress o con Playwright? Mi contrato dice Cypress, pero si S3 prefiere
   alineación con A3 (Playwright), confirmo.
3. ¿Estrategia de sincronización de tokens: Opción A (symlink), B (script), C (manual)?
   Mi recomendación es B.

NO implementes login, NO crees features de negocio, NO uses NgModules,
NO uses ag-grid enterprise. Solo el scaffolding.
```

---

## Validación post-ejecución (lo llena S3)

```bash
cd web/backoffice

# 1. Pre-check automático
../../scripts/pre-pr-check.sh

# 2. Instalación limpia
rm -rf node_modules package-lock.json
npm install

# 3. Lint y typecheck
npm run lint
npm run typecheck

# 4. Tests unitarios
npm test

# 5. Build de producción
npm run build:prod
# Anotar tamaños de chunks

# 6. Arranque en dev
npm start &
sleep 10
curl http://localhost:4200/  # debe retornar HTML del shell

# 7. E2E
npm run test:e2e

# 8. Tokens compatibles con A3
diff src/styles/tokens.css ../public/styles/tokens.css
# Esperado: 0 diferencias

# 9. Verificar standalone components (no debe existir app.module.ts)
test ! -f src/app/app.module.ts && echo "OK: standalone" || echo "FAIL: hay NgModule"
```

- **Fecha de ejecución:** _pendiente_
- **Tamaño initial bundle:** _pendiente (objetivo <500kB gzip)_
- **Número de chunks lazy:** _pendiente_
- **Tiempo de build prod:** _pendiente_
- **Tests Cypress pasan:** _pendiente_
- **Tokens sincronizados con A3:** _pendiente_
- **Resultado:** _pendiente_
- **Notas para tickets posteriores (T-015, T-018, T-031, T-040):** _pendiente_

---

## Notas para el supervisor S3

**Antes de aprobar el merge:**

- Confirma que el agente usó `standalone: true` en TODOS los componentes (un solo NgModule olvidado contamina).
- Pide ver el output de `npm run build:prod` y revisa los tamaños. ag-grid pesa, pero el initial bundle no debería superar 500kB gzipped.
- Verifica que el shell es **visualmente coherente** con el portal Next.js (paleta, tipografía, spacing). No tienen que verse iguales — son productos distintos — pero la familia visual debe sentirse.

**Coordinación con A3:**

- Los tokens CSS son **el único activo compartido**. Si en este ticket A4 define la paleta y T-006 todavía no está mergeado, comunícaselo a S3 (que coincide entre A3 y A4 — tú).
- Decide al inicio del sprint cuál de las 3 opciones de sincronización usar y comunícalo a ambos agentes para evitar conflictos de merge.

**Conversación con DO sobre Cypress:**

- Cypress requiere Chrome en CI. A7 probablemente ya tiene Chrome en los runners de GitHub Actions (vienen por defecto), pero confírmalo antes de mergear este ticket. Si no, A4 deja un TODO para A7.

**Prerrequisitos:**

- T-001 (estructura repo) ✅
- T-002 (docker-compose) — no bloqueante. El backoffice arranca sin backend.
- T-003 (CI/CD) — no bloqueante. El job de CI para backoffice puede agregarse en otro ticket.
- T-004 (NestJS base) — no bloqueante. El backoffice puede arrancar sin backend; las llamadas fallan limpiamente.
- T-006 (portal Next.js) — **recomendado** pero no bloqueante. Si T-007 corre antes que T-006, A4 define los tokens y A3 los adopta.

**Sucesores que dependen de este ticket:**

- T-015 (login Keycloak en frontends) — agrega auth a los dos.
- T-018 (listado bodega backoffice) — primer feature real.
- T-031 (detalle OP backoffice) — feature de producción.
- T-040 (cotizaciones backoffice) — feature de ventas.

---

**Creado:** 2026-04-28 por S3 + TL
**Plantilla base:** `prompts/templates/ticket-template.md` v1.0
