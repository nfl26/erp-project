# shared/

Componentes reutilizables sin lógica de negocio.

## ui/

| Componente | Selector | Descripción |
|---|---|---|
| `ButtonComponent` | `<erp-button>` | Botón con variantes, loading, disabled |
| `CardComponent` | `<erp-card>` | Contenedor con header/body/footer |
| `InputComponent` | `<erp-input>` | ControlValueAccessor para Reactive Forms |

## grid/

| Componente | Selector | Descripción |
|---|---|---|
| `GridComponent` | `<erp-grid>` | Wrapper de ag-grid — **única puerta de entrada** |

## Cómo agregar un componente shared

1. Crear `shared/<categoria>/<nombre>.component.ts` (standalone, OnPush)
2. Exportar el componente
3. En el feature que lo usa, importarlo directamente en `imports: [...]`
4. No hace falta barrel — Angular standalone no requiere index.ts

## Reglas

- Sin lógica de negocio. Sin llamadas HTTP.
- Prefijo `erp-` en selector.
- `ChangeDetectionStrategy.OnPush` obligatorio.
- `<erp-grid>` es la única puerta de entrada a ag-grid. Otros componentes no importan `AgGridAngular`.
