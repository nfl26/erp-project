# features/

Módulos de negocio del backoffice. Cada feature tiene lazy loading propio.

## Cómo agregar una nueva feature

1. Crear directorio `features/<nombre>/`
2. Crear `<nombre>.routes.ts` con `export const routes: Routes = [...]`
3. Crear `<nombre>.component.ts` (standalone, OnPush)
4. Agregar la ruta lazy en `app.routes.ts`:
   ```ts
   {
     path: '<nombre>',
     loadChildren: () =>
       import('./features/<nombre>/<nombre>.routes').then(r => r.routes),
   }
   ```

## Convenciones

- **Selector:** prefijo `erp-` (ej: `erp-bodega-list`)
- **Estado:** `<nombre>.state.ts` con NgRx Signals si el feature tiene estado compartido
- **Servicio:** `<nombre>.service.ts` — solo llama al backend vía `HttpClient`
- **No importar `AgGridAngular` directamente** — usar `<erp-grid>` del shared
