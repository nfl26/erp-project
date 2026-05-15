# core/

Servicios singleton transversales. Todo lo que vive aquí se provee una sola vez en `app.config.ts`.

## Estructura

```
core/
├── config/
│   └── env.ts            ← validación de variables de entorno con zod (corre antes del bootstrap)
└── http/
    ├── api.interceptor.ts ← agrega base URL + headers + mapea errores RFC 7807
    └── api.types.ts       ← ApiError, Page<T> — contratos compartidos con el backend
```

## Reglas

- No agregar lógica de negocio aquí.
- Servicios de feature van en `features/<nombre>/<nombre>.service.ts`.
- El interceptor **no** agrega Authorization header hasta T-015 (Keycloak).
