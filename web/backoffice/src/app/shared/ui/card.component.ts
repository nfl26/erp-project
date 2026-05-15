import { Component, ChangeDetectionStrategy } from '@angular/core';

/**
 * Card contenedora con slots para header, body y footer.
 *
 * @example
 * <erp-card>
 *   <ng-container slot="header">Título</ng-container>
 *   Contenido del body
 *   <ng-container slot="footer"><erp-button>Guardar</erp-button></ng-container>
 * </erp-card>
 */
@Component({
  selector: 'erp-card',
  standalone: true,
  changeDetection: ChangeDetectionStrategy.OnPush,
  template: `
    <article class="card">
      <div class="card-header">
        <ng-content select="[slot=header]" />
      </div>
      <div class="card-body">
        <ng-content />
      </div>
      <div class="card-footer">
        <ng-content select="[slot=footer]" />
      </div>
    </article>
  `,
  styles: [`
    .card {
      background: #fff;
      border-radius: var(--radius-lg);
      box-shadow: var(--shadow-sm);
      overflow: hidden;
    }
    .card-header {
      padding: var(--space-4) var(--space-6);
      border-bottom: 1px solid #e2e8f0;
      font-weight: 600;
      font-size: var(--font-size-base);
    }
    .card-header:empty { display: none; }
    .card-body {
      padding: var(--space-6);
    }
    .card-footer {
      padding: var(--space-4) var(--space-6);
      border-top: 1px solid #e2e8f0;
      display: flex;
      justify-content: flex-end;
      gap: var(--space-3);
    }
    .card-footer:empty { display: none; }
  `],
})
export class CardComponent {}
