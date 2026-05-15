# ERP — Portal Público (`web/public`)

Portal Next.js 14 del ERP. Accesible por equipo comercial, gerencia y —en tickets futuros— clientes externos con credenciales limitadas.

---

## Arranque local

```bash
# 1. Variables de entorno
cp .env.example .env.local
# Editar .env.local con la URL real del backend

# 2. Dependencias
npm install

# 3. Dev server (Turbopack, puerto 3001)
npm run dev
# → http://localhost:3001
```

---

## Estructura

```
web/public/
├── app/                  App Router de Next.js 14
│   ├── (app)/            Rutas que requerirán auth (T-015)
│   ├── (marketing)/      Rutas públicas sin auth
│   ├── api/health/       Endpoint de health para K8s
│   ├── layout.tsx        Layout raíz — providers, fuente, metadata
│   ├── page.tsx          Landing placeholder
│   ├── loading.tsx       Skeleton global (Suspense)
│   ├── error.tsx         Error boundary global (Client Component)
│   └── not-found.tsx     404 personalizado
├── components/
│   └── ui/               Primitivos de UI (Button, Card, Input)
├── lib/
│   ├── api/
│   │   ├── client.ts     Cliente HTTP base — todas las llamadas pasan por aquí
│   │   └── types.ts      Tipos ApiError, Page<T>
│   ├── env.ts            Validación de env vars con Zod
│   ├── providers.tsx     QueryClientProvider y futuros providers
│   └── utils.ts          cn() helper (clsx + tailwind-merge)
├── styles/
│   ├── tokens.css        Design tokens compartidos con backoffice Angular
│   └── globals.css       Tailwind base + import de tokens
└── tests/
    └── smoke.spec.ts     Playwright smoke tests
```

---

## Convenciones de componentes

**Server Components por defecto.** Solo añadir `'use client'` cuando el componente use:
- Estado local (`useState`, `useReducer`)
- Efectos (`useEffect`)
- Event handlers del navegador (`onClick`, `onChange`, etc.)
- Hooks de React o librerías de cliente

**Naming:**
- Archivos de rutas: `kebab-case` (`page.tsx`, `loading.tsx`)
- Componentes React: `PascalCase.tsx`
- Hooks: prefijo `use`, en `lib/hooks/`

**Estructura de una ruta nueva:**
```
app/(app)/mi-seccion/
├── page.tsx       ← Server Component, datos
├── loading.tsx    ← Skeleton
├── error.tsx      ← Error boundary
└── [id]/
    └── page.tsx
```

---

## Agregar una nueva ruta

1. Crear carpeta en `app/(app)/` (requiere auth) o `app/(marketing)/` (pública).
2. Crear `page.tsx` como Server Component.
3. Crear `loading.tsx` con skeleton apropiado.
4. Crear `error.tsx` si la ruta tiene manejo especial de errores.
5. Las llamadas al backend van siempre por `lib/api/client.ts`.

---

## Agregar un componente UI

1. Crear en `components/ui/PascalCase.tsx`.
2. Usar `cn()` de `lib/utils.ts` para clases condicionales.
3. Exportar como named export.
4. Agregar JSDoc `@example` con uso mínimo.
5. No incluir lógica de negocio: solo presentación y props.

---

## Variables de entorno

| Variable | Tipo | Requerida | Descripción |
|---|---|---|---|
| `NEXT_PUBLIC_API_URL` | URL | Sí | Base URL del backend NestJS |
| `NEXT_PUBLIC_APP_ENV` | enum | No | `development` \| `staging` \| `production` |
| `NEXT_PUBLIC_SENTRY_DSN` | string | No | DSN de Sentry (vacío en dev) |

El build falla con mensaje claro si `NEXT_PUBLIC_API_URL` no está definida.

---

## Comandos

| Comando | Descripción |
|---|---|
| `npm run dev` | Dev server con Turbopack en puerto 3001 |
| `npm run build` | Build de producción |
| `npm start` | Inicia build de producción en puerto 3001 |
| `npm run lint` | ESLint (Next.js + Tailwind plugin) |
| `npm run typecheck` | TypeScript sin emitir archivos |
| `npm run test:e2e` | Playwright E2E |
| `npm run test:e2e:ui` | Playwright con UI interactiva |
| `npm run format` | Prettier sobre todos los archivos |

---

## Design tokens

`styles/tokens.css` define las variables CSS de paleta, tipografía, spacing y radii.
Este archivo es la fuente de verdad compartida con el backoffice Angular (A4/T-007).

| Token | Valor | Rol |
|---|---|---|
| `--color-primary` | blue-500 | Acciones principales |
| `--color-success` | green-500 | Confirmaciones, stock OK |
| `--color-warning` | yellow-500 | Alertas, stock bajo |
| `--color-danger` | red-500 | Errores, stock crítico |
| `--color-surface` | slate-50 | Fondos de cards/tablas |
| `--color-neutral` | slate-500 | Texto secundario (clase Tailwind: `text-muted`) |

Modo oscuro habilitado en infraestructura CSS (`class="dark"` en `<html>`). Toggle de UI en ticket posterior.

---

## Referencias

- Contrato del agente: [`agents/A3-nextjs.md`](../../agents/A3-nextjs.md)
- ADR-010 — monolito modular: [`docs/adrs/ADR-010-monolito-modular.md`](../../docs/adrs/ADR-010-monolito-modular.md)
- Stack tecnológico: [`docs/stack.md`](../../docs/stack.md)
- Arquitectura general: [`docs/architecture.md`](../../docs/architecture.md)
