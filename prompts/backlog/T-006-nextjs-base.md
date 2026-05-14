# T-006 · Proyecto Next.js 14 base con App Router, Tailwind y design tokens

**Ticket Jira:** https://tu-org.atlassian.net/browse/T-006
**Agente asignado:** A3 (UI Next.js)
**Supervisor humano:** S3 (Supervisor frontend)
**Sprint:** Semana 1 — Fundamentos
**Estimación:** 2 puntos
**Prioridad:** crítica
**Rama:** `feat/T-006-nextjs-base`

---

## Contexto de negocio

El **portal público del ERP** es la cara visible del sistema hacia afuera. Lo usan dos tipos de personas:

1. **Equipo comercial del cliente** que ve cotizaciones y órdenes de venta — eventualmente puede compartir links con clientes finales para que vean el estado de su pedido.
2. **Gerencia del cliente** que entra al dashboard de KPIs (producción del mes, top 5 productos, stock crítico).

Es la diferencia más importante con el backoffice Angular (T-007): el portal Next.js puede estar expuesto a personas fuera de la empresa con credenciales limitadas, así que necesita un stack pensado para **rendimiento percibido** (SSR/SSG, code splitting agresivo, Core Web Vitals) y **experiencia más pulida** que la operación interna.

Este ticket no entrega ninguna página de negocio. Entrega el **scaffolding base** sobre el que todos los tickets posteriores (T-015 login, T-042 portal ventas, T-043 dashboard KPIs) construyen sus features. Las decisiones que se toman aquí (routing, estilos, manejo de errores, cliente HTTP, tokens compartidos) son difíciles de cambiar después y afectan a todo lo que viene.

---

## Alcance técnico

### Crear

```
web/public/
├── app/
│   ├── layout.tsx                     ← layout raíz (HTML, fonts, providers globales)
│   ├── page.tsx                       ← landing placeholder ("ERP — en construcción")
│   ├── loading.tsx                    ← skeleton global por defecto
│   ├── error.tsx                      ← error boundary global
│   ├── not-found.tsx                  ← 404 personalizado
│   ├── (marketing)/                   ← grupo de rutas públicas sin auth
│   │   └── .gitkeep
│   ├── (app)/                         ← grupo de rutas que requerirán auth (T-015)
│   │   └── .gitkeep
│   └── api/
│       └── health/route.ts            ← endpoint de health para K8s y monitoring
├── components/
│   ├── ui/                            ← primitivos de UI (Button, Card, Input)
│   │   ├── button.tsx
│   │   ├── card.tsx
│   │   └── input.tsx
│   └── .gitkeep
├── lib/
│   ├── api/
│   │   ├── client.ts                  ← cliente HTTP base con TanStack Query
│   │   └── types.ts                   ← tipos compartidos del API
│   ├── env.ts                         ← validación de env vars con zod
│   ├── providers.tsx                  ← QueryClientProvider y otros providers globales
│   └── utils.ts                       ← cn() helper, formatters
├── styles/
│   ├── globals.css                    ← Tailwind base + custom CSS
│   └── tokens.css                     ← design tokens compartidos con backoffice
├── public/
│   └── favicon.ico
├── tests/
│   └── smoke.spec.ts                  ← Playwright smoke test
├── .env.example
├── .env.local                         ← NO commitear (gitignore lo cubre)
├── next.config.js
├── tailwind.config.ts
├── postcss.config.js
├── tsconfig.json
├── package.json
├── package-lock.json
├── playwright.config.ts
└── README.md                          ← cómo arrancar, estructura, convenciones
```

### Modificar

- `.gitignore` raíz — verificar que `web/public/.next/`, `web/public/node_modules/`, y `.env.local` están cubiertos.
- `README.md` raíz — agregar referencia al portal en la sección de servicios.
- `docs/architecture.md` — actualizar el diagrama de despliegue para mostrar el portal en su puerto.

### No tocar

- **`web/backoffice/`** — territorio de A4 (T-007).
- **`services/`** — dominio de A1.
- **`infra/`** — dominio de A7.
- **`.github/workflows/`** — dominio de A7. Si el portal necesita un job de CI específico, A3 deja una nota en el PR y A7 lo agrega en T-003 (o lo agrega un ticket de seguimiento).

---

## Criterios de aceptación

### Setup del proyecto

- [ ] **Next.js 14.2.x** o superior, instalado con `npx create-next-app@latest`.
- [ ] **TypeScript** estricto activado (`"strict": true` en `tsconfig.json`).
- [ ] **App Router** habilitado (no Pages Router).
- [ ] **Turbopack** habilitado para desarrollo local (`next dev --turbo`).
- [ ] **React 18.x** (no React 19 hasta que NestJS y el resto del stack lo soporten oficialmente).
- [ ] **Node.js 20 LTS** especificado en `engines` de `package.json` y en `.nvmrc`.

### Dependencias principales

- [ ] **Tailwind CSS 3.4.x** con `tailwind-merge` y `clsx` (helper `cn()`).
- [ ] **TanStack Query v5** (`@tanstack/react-query`) para data fetching y caching.
- [ ] **Zod** para validación de inputs y env vars en runtime.
- [ ] **react-hook-form** con `@hookform/resolvers/zod` para formularios.
- [ ] **lucide-react** para íconos (consistente con backoffice).
- [ ] **date-fns** para fechas (locale `es` por defecto).
- [ ] **Playwright** para E2E (`@playwright/test`).
- [ ] **eslint-config-next** + `eslint-plugin-tailwindcss` + `prettier-plugin-tailwindcss`.

> **Justificación de elecciones clave**
> - **Tailwind** (no CSS-in-JS): consistente con el backoffice Angular y mejor para SSR.
> - **TanStack Query** (no SWR): el equipo ya lo conoce, mejor devtools, mejor manejo de mutaciones complejas.
> - **react-hook-form** (no Formik): rendimiento superior en formularios grandes (cotizaciones).
> - **Zod** (no Yup ni Joi): se comparte schemas con el backend NestJS.

### Configuración de Tailwind

- [ ] `tailwind.config.ts` con TypeScript (no JS).
- [ ] Importa los **design tokens compartidos** de `styles/tokens.css` (variables CSS).
- [ ] El campo `content` cubre `app/**/*.{ts,tsx}` y `components/**/*.{ts,tsx}`.
- [ ] Tema extendido con colores semánticos (no hardcodeados):
  ```typescript
  theme: {
    extend: {
      colors: {
        primary: 'rgb(var(--color-primary) / <alpha-value>)',
        success: 'rgb(var(--color-success) / <alpha-value>)',
        warning: 'rgb(var(--color-warning) / <alpha-value>)',
        danger: 'rgb(var(--color-danger) / <alpha-value>)',
        surface: 'rgb(var(--color-surface) / <alpha-value>)',
        // ...
      },
      fontFamily: {
        sans: ['var(--font-inter)', 'system-ui', 'sans-serif'],
      },
    },
  }
  ```

### Design tokens compartidos

- [ ] `styles/tokens.css` define todas las variables CSS de la paleta, tipografía, spacing y border radius.
- [ ] El mismo archivo (o uno equivalente) debe poder ser consumido por el backoffice Angular de T-007 sin duplicación. **Coordinar con A4** antes de finalizar la paleta — si A4 ya escribió tokens en su rama, alinearse; si no, A3 define y A4 los importa.
- [ ] Documentar la paleta y tipografía en `web/public/README.md` con bloque visual (puede ser un comentario).
- [ ] Soporte de **modo oscuro** habilitado a nivel de tokens (variables `--color-*-dark`), aunque el toggle de UI se implementa en otro ticket. Tailwind config con `darkMode: 'class'`.

### Layout raíz y providers

- [ ] `app/layout.tsx` define `<html lang="es">` con `suppressHydrationWarning` para el toggle de tema futuro.
- [ ] Carga fuente **Inter** vía `next/font/google` con `display: 'swap'` y subset `latin`.
- [ ] Importa `globals.css` (que importa `tokens.css` y Tailwind).
- [ ] Envuelve `children` en `<Providers>` (TanStack QueryClient + futuros providers).
- [ ] Define metadata global (title, description, OG tags) con `Metadata` de Next.

### Cliente API base

- [ ] `lib/api/client.ts` exporta un fetcher HTTP que:
  - Lee la URL base desde `process.env.NEXT_PUBLIC_API_URL` (validada con zod en `lib/env.ts`).
  - Agrega header `Content-Type: application/json` y `Accept: application/json`.
  - Maneja errores formateados RFC 7807 (que vienen de NestJS, T-004) y los re-lanza con un tipo `ApiError` propio.
  - Soporta cancelación con `AbortController`.
  - **No hace autenticación todavía** — eso se agrega en T-015. Hay un comentario `// TODO T-015: agregar Authorization header desde cookie httpOnly`.
- [ ] Tipos de `lib/api/types.ts`:
  - `ApiError` con campos `type`, `title`, `status`, `detail`, `instance`, `traceId`.
  - `Page<T>` para respuestas paginadas (estructura debe coincidir con la del backend, ver T-016).
- [ ] Hook `useApi()` o helpers para uso con TanStack Query.

### Validación de variables de entorno

- [ ] `lib/env.ts` valida con zod las env vars al arranque:
  ```typescript
  // NEXT_PUBLIC_API_URL: string url, obligatorio
  // NEXT_PUBLIC_APP_ENV: 'development' | 'staging' | 'production'
  // NEXT_PUBLIC_SENTRY_DSN: string opcional
  ```
- [ ] Si una env var requerida falta, el proceso falla con mensaje claro al arrancar.

### Rutas iniciales

- [ ] `app/page.tsx` — landing placeholder con texto "ERP — Portal en construcción" y enlace al estado del proyecto (puede ser un anchor a `#desarrollo`). Sirve para verificar que el routing funciona.
- [ ] `app/loading.tsx` — skeleton genérico que aparece durante navegaciones (uso del Suspense de Next).
- [ ] `app/error.tsx` — error boundary global que muestra mensaje amigable y botón de "Intentar de nuevo" (debe ser Client Component).
- [ ] `app/not-found.tsx` — 404 personalizado con enlace al home.
- [ ] `app/api/health/route.ts` — handler GET que retorna `{ status: 'ok', timestamp, version }` (versión leída de `package.json`).

### Componentes UI primitivos

Solo 3 placeholders **mínimos** para que los tickets siguientes tengan de dónde partir:

- [ ] `<Button variant="primary|secondary|ghost" size="sm|md|lg" />` con variantes Tailwind.
- [ ] `<Card>` con header, body y footer composables.
- [ ] `<Input>` con label, error message y forward ref (compatible con react-hook-form).
- [ ] Cada componente tiene historia mínima en un comentario JSDoc con ejemplo de uso.
- [ ] **No incluir** primitivos avanzados (Dialog, Combobox, Toast). Esos se agregan según los tickets de feature los necesiten.

### Scripts en package.json

- [ ] `dev` — `next dev --turbo`
- [ ] `build` — `next build`
- [ ] `start` — `next start`
- [ ] `lint` — `next lint`
- [ ] `typecheck` — `tsc --noEmit`
- [ ] `test:e2e` — `playwright test`
- [ ] `test:e2e:ui` — `playwright test --ui`
- [ ] `format` — `prettier --write .`

### Tests E2E mínimos

- [ ] Playwright configurado para correr contra `http://localhost:3001` (puerto del portal — verificar que no choca con backoffice ni con erp-api).
- [ ] `tests/smoke.spec.ts` con tres assertions:
  - El home (`/`) carga con status 200.
  - Hay un `<h1>` visible.
  - El endpoint `/api/health` retorna `{ status: 'ok', ... }`.
- [ ] `playwright.config.ts` con `webServer` que arranca `npm run build && npm start` para los tests.

### Variables de entorno

- [ ] `.env.example` documenta todas las variables:
  ```bash
  # API
  NEXT_PUBLIC_API_URL=http://localhost:3000/api/v1

  # Environment
  NEXT_PUBLIC_APP_ENV=development

  # Observability (opcional en dev)
  NEXT_PUBLIC_SENTRY_DSN=

  # Auth (placeholder hasta T-015 — Keycloak)
  # NEXTAUTH_URL=http://localhost:3001
  # KEYCLOAK_ISSUER=
  # KEYCLOAK_CLIENT_ID=
  # KEYCLOAK_CLIENT_SECRET=
  ```
- [ ] `.env.local` NO se commitea (verificar `.gitignore`).
- [ ] El portal **no falla** si `NEXT_PUBLIC_SENTRY_DSN` no está; sí falla si `NEXT_PUBLIC_API_URL` falta.

### Integración con CI

- [ ] El workflow `ci.yml` (de T-003) debe tener un job para el portal, que corre:
  - `npm ci` en `web/public/`
  - `npm run lint`
  - `npm run typecheck`
  - `npm run build`
- [ ] Si A3 detecta que ese job no existe en `ci.yml`, deja un comentario en el PR pidiendo a A7 que lo agregue (no lo agrega A3 directamente, está fuera de dominio).

### README del portal

- [ ] `web/public/README.md` con:
  - Cómo arrancar localmente (3 pasos máximo).
  - Estructura del proyecto (un párrafo + diagrama).
  - Convenciones de componentes (Server vs Client Components, naming).
  - Cómo agregar una nueva ruta.
  - Cómo agregar un nuevo componente UI.
  - Variables de entorno requeridas.
  - Comandos disponibles.
  - Enlace al contrato del agente A3 y a los ADRs relevantes.

### Performance baseline

- [ ] `npm run build` reporta los tamaños de bundle. Para la landing actual deben ser:
  - First Load JS: **< 100 kB** (objetivo, no bloqueante en este ticket).
  - Static pages: la landing es estática (sin `dynamic = 'force-dynamic'`).
- [ ] Si A3 detecta que algún paquete está inflando el bundle (>50 kB), reportarlo en el PR.

---

## Invariantes que el agente DEBE respetar

1. **App Router, no Pages Router.** Esta es la forma soportada por Vercel y donde van todas las features futuras.
2. **Server Components por defecto, Client Components solo cuando sea necesario.** Marcar `'use client'` solo cuando se use estado local, hooks de React, o eventos del navegador.
3. **No hardcodear URLs ni textos.** URL del API viene de env. Textos en español (los traducibles, si en algún momento hay i18n, se centralizan después).
4. **No instalar dependencias sin necesidad.** Si A3 propone una librería que no está en la lista del ticket, justifica en el PR y espera aprobación de S3.
5. **Tokens CSS son la fuente de verdad de estilos.** No hex codes regados por componentes. Si necesitas un color que no está en tokens, agrégalo al archivo de tokens primero.
6. **No autenticación todavía.** Si A3 implementa auth aquí, se salió del scope (eso es T-015 con Keycloak).
7. **Cualquier llamada al backend pasa por `lib/api/client.ts`**. No usar `fetch()` directamente en componentes.

---

## Casos de prueba obligatorios

### Caso 1 — Arranque limpio en dev

```bash
cd web/public
cp .env.example .env.local
npm ci
npm run dev
# Esperado: arranca en puerto 3001 sin warnings. Abre http://localhost:3001 y ve la landing.
```

### Caso 2 — Build de producción

```bash
npm run build
# Esperado: sin errores. Reporta tamaños de bundle.

npm start
curl http://localhost:3001/api/health
# Esperado: { "status": "ok", "timestamp": "...", "version": "0.1.0" }
```

### Caso 3 — Falta de env var requerida

```bash
unset NEXT_PUBLIC_API_URL
npm run build
# Esperado: falla con mensaje claro indicando qué variable falta y qué tipo debe tener.
```

### Caso 4 — Smoke test E2E pasa

```bash
npm run test:e2e
# Esperado: 3 tests verdes en < 30 segundos.
```

### Caso 5 — Modo oscuro a nivel CSS (sin UI todavía)

```bash
# En DevTools del navegador, agregar manualmente class="dark" al <html>
# Verificar que los tokens cambian (al menos la paleta base)
# El toggle UI no existe todavía; lo importante es que la infraestructura CSS está lista.
```

### Caso 6 — Lint y typecheck

```bash
npm run lint     # 0 errores, 0 warnings
npm run typecheck # 0 errores
```

### Caso 7 — Tailwind funciona en componentes

```bash
# Visualmente: la landing y los componentes <Button> placeholder se renderizan con estilos.
# Si Tailwind no procesa los archivos, los elementos no tendrán estilos y el caso falla.
```

### Caso 8 — Cliente API se compila pero no se llama todavía

```bash
# El archivo lib/api/client.ts compila. No hay error en tipos.
# Cuando T-013 (auth NestJS) y T-015 (login frontend) se ejecuten, se le agregará Authorization.
# Verificar el comentario TODO T-015 en el código.
grep "TODO T-015" lib/api/client.ts
# Esperado: encuentra al menos una ocurrencia.
```

---

## Lo que NO se debe hacer en esta tarea

- **No implementar login ni autenticación.** Es T-015.
- **No crear páginas de cotizaciones, OVs, dashboards.** Esos tickets son T-042, T-043 (sprint 3).
- **No instalar `next-auth`, `iron-session` ni similares.** Decisión de librería de auth se toma en T-015 con S3 y DO.
- **No instalar shadcn/ui en bloque.** Si A3 quiere shadcn, pide aprobación a S3 antes. Por ahora, primitivos a mano para mantener el bundle delgado.
- **No agregar i18n.** El cliente habla solo español. Si en el futuro hay multi-tenant con otro idioma, se evaluará entonces.
- **No tocar configuración de CI/CD.** Si falta job para el portal, A3 deja nota en el PR para A7.
- **No subir secretos**, ni siquiera "de prueba", al repo. `.env.local` queda local.
- **No exportar nada de `web/public/`** que `web/backoffice/` pretenda importar. Los frontends no comparten código TypeScript (solo tokens CSS). Si A3 detecta presión para compartir TS, escalarlo a S3.

---

## Contratos y referencias

- **Contrato del agente:** [`agents/A3-nextjs.md`](../../agents/A3-nextjs.md)
- **Contrato A4 (coordinación de tokens):** [`agents/A4-angular.md`](../../agents/A4-angular.md)
- **Stack tecnológico:** [`docs/stack.md`](../../docs/stack.md)
- **Arquitectura general:** [`docs/architecture.md`](../../docs/architecture.md)
- **ADRs relevantes:**
  - [ADR-010 Monolito modular](../../docs/adrs/ADR-010-monolito-modular.md) (por qué el portal habla con un solo backend)
- **Documentación Next.js:** https://nextjs.org/docs (App Router, no Pages)
- **TanStack Query:** https://tanstack.com/query/latest/docs
- **Playwright:** https://playwright.dev/docs/intro

---

## Entregables

- [ ] Proyecto Next.js 14 funcionando en `web/public/` según estructura del alcance.
- [ ] Landing placeholder renderizada correctamente en `http://localhost:3001`.
- [ ] `/api/health` retorna JSON válido.
- [ ] Smoke test Playwright pasa.
- [ ] Build de producción genera bundle de tamaño razonable y sin errores.
- [ ] `web/public/README.md` completo.
- [ ] Design tokens (`styles/tokens.css`) listos para reusar en backoffice.
- [ ] `.env.example` con todas las variables documentadas.
- [ ] Commit: `feat(web-public): bootstrap next.js 14 with app router and tailwind [A3]`
- [ ] PR con labels: `agent:A3`, `supervisor:S3`, `sprint:semana-1`, `priority:critical`, `type:feature`

---

## Cómo invocar al agente en Claude Code

```bash
cd erp-project
git checkout -b feat/T-006-nextjs-base
claude
```

Prompt:

```
Ejecuta T-006 (portal Next.js 14 base).

Actúas como agente A3. Lee en orden:
1. @CLAUDE.md
2. @agents/A3-nextjs.md
3. @prompts/backlog/T-006-nextjs-base.md (este ticket)
4. @docs/stack.md
5. @docs/architecture.md

Antes de empezar, pregúntame:
1. ¿Hay alguna preferencia de paleta de colores o branding del cliente?
   Si no, propón una paleta neutra y pásamela para aprobación antes de hardcodearla.
2. ¿El backoffice de A4 ya tiene tokens CSS escritos? Si sí, alineamos.
   Si no, A3 los define primero.
3. ¿Confirmas que el puerto 3001 está libre? El docker-compose de T-002 no lo usa,
   pero S3 confirma.

NO implementes login, NO crees páginas de negocio, NO instales shadcn/ui sin
aprobación. Solo el scaffolding.
```

---

## Validación post-ejecución (lo llena S3)

```bash
cd web/public

# 1. Pre-check automático
../../scripts/pre-pr-check.sh

# 2. Instalación limpia
rm -rf node_modules package-lock.json
npm install

# 3. Lint y typecheck
npm run lint
npm run typecheck

# 4. Build
npm run build

# 5. Arranque en dev
npm run dev &
sleep 5
curl http://localhost:3001/  # debe retornar HTML
curl http://localhost:3001/api/health  # debe retornar {"status":"ok",...}

# 6. E2E
npm run test:e2e

# 7. Tamaño del bundle
npm run build 2>&1 | grep "First Load"
# Anotar el resultado en las notas
```

- **Fecha de ejecución:** _pendiente_
- **Tamaño First Load JS:** _pendiente (objetivo <100kB)_
- **Tiempo de build:** _pendiente_
- **Tests E2E pasan:** _pendiente_
- **Paleta de tokens revisada con A4:** _pendiente_
- **Resultado:** _pendiente_
- **Notas para tickets posteriores (T-015, T-042, T-043):** _pendiente_

---

## Notas para el supervisor S3

**Antes de aprobar el merge:**

- Verifica que `tailwind.config.ts` esté bien configurado (Tailwind suele dar problemas con `content` mal escrito; el síntoma es que los estilos no se aplican en producción).
- Pide al agente que muestre el output de `npm run build` con tamaños de bundle.
- Si el agente propone instalar una librería extra (Radix UI, shadcn, headlessui), discútelo antes de aprobar — define el rumbo de cómo se construirán los componentes durante 6 meses.

**Coordinación con A4 (frontend Angular):**

- Los tokens CSS de `styles/tokens.css` deben ser **idénticos** a los del backoffice.
- Acordar antes del ticket de A4 (T-007) si los tokens viven en `web/public/styles/` o en una carpeta compartida `web/shared-tokens/`. Esta última opción es más limpia pero requiere ajustar `tailwind.config.ts` de ambos proyectos.

**Prerrequisitos:**

- T-001 (estructura inicial del repo) ✅
- T-002 (docker-compose) ✅ — no afecta directamente, pero el portal espera hablar con un backend que existe.
- T-003 (CI/CD) ✅ — el job para el portal puede agregarse después (no bloquea el merge).
- T-004 (NestJS base) — no es bloqueante: el portal puede arrancar sin backend, solo el endpoint `/api/health` propio funciona.

---

**Creado:** 2026-04-28 por S3 + TL
**Plantilla base:** `prompts/templates/ticket-template.md` v1.0
