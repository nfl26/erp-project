# ERP Backoffice — Angular 17

Backoffice operativo del ERP para uso interno: bodegueros, jefes de producción, vendedores.

## Arranque local (3 pasos)

```bash
cp .env.example .env.local   # completa NG_APP_API_URL
npm ci
npm start                    # http://localhost:4200
```

## Estructura del proyecto

```
src/app/
├── core/           ← config de env (zod) + interceptor HTTP
├── layout/         ← shell visual: sidebar, header, área principal
├── shared/
│   ├── ui/         ← button, card, input (ControlValueAccessor)
│   └── grid/       ← wrapper ag-grid (única puerta de entrada)
├── features/       ← módulos de negocio con lazy loading
│   └── home/
└── pages/          ← not-found, error
```

## Convenciones

- **Standalone components** en todo el proyecto — sin NgModules.
- **NgRx Signals** para estado de feature — no BehaviorSubject ni Store clásico.
- **Lazy loading** por feature en `app.routes.ts`.
- **Selector prefix `erp-`** en todos los componentes.
- **`ChangeDetectionStrategy.OnPush`** por defecto.
- **`<erp-grid>`** es la única forma de usar ag-grid. No importar `AgGridAngular` directamente.
- Llamadas HTTP **siempre** a través de servicios de feature — nunca `HttpClient` en componentes.

## Cómo agregar una nueva feature

Ver [src/app/features/README.md](src/app/features/README.md).

## Cómo agregar un componente shared

Ver [src/app/shared/README.md](src/app/shared/README.md).

## Comandos disponibles

| Comando | Descripción |
|---|---|
| `npm start` | Dev server en `http://localhost:4200` |
| `npm run build` | Build de desarrollo |
| `npm run build:prod` | Build de producción |
| `npm test` | Tests unitarios (Karma/Jasmine) |
| `npm run test:e2e` | Tests E2E con Cypress (requiere app corriendo) |
| `npm run test:e2e:open` | Abre Cypress UI |
| `npm run lint` | ESLint |
| `npm run typecheck` | TypeScript sin emitir |
| `npm run format` | Prettier |

## Variables de entorno

| Variable | Obligatoria | Descripción |
|---|---|---|
| `NG_APP_API_URL` | ✅ | URL base del backend NestJS |
| `NG_APP_ENV` | — | `development` / `staging` / `production` |
| `NG_APP_SENTRY_DSN` | — | DSN de Sentry para errores en producción |
| `NG_APP_KEYCLOAK_URL` | — | Placeholder hasta T-015 |
| `NG_APP_KEYCLOAK_REALM` | — | Placeholder hasta T-015 |
| `NG_APP_KEYCLOAK_CLIENT_ID` | — | Placeholder hasta T-015 |

## Referencias

- [Contrato del agente A4](../../agents/A4-angular.md)
- [Stack tecnológico](../../docs/stack.md)
- [Arquitectura general](../../docs/architecture.md)
- [ADR-010 Monolito modular](../../docs/adrs/ADR-010-monolito-modular.md)

## Tickets sucesores

- **T-015** — Login con Keycloak (agrega guards + Bearer token al interceptor)
- **T-018** — Listado de bodega (primer feature real con `<app-grid>`)
- **T-031** — Detalle de Orden de Producción
- **T-040** — Cotizaciones en backoffice
