import { Component, ChangeDetectionStrategy, input, output } from '@angular/core';
import { NgClass } from '@angular/common';

export type ButtonVariant = 'primary' | 'secondary' | 'danger' | 'ghost';
export type ButtonSize = 'sm' | 'md' | 'lg';

/**
 * Botón base del backoffice.
 *
 * @example
 * <erp-button variant="primary" size="md" (clicked)="onSave()">Guardar</erp-button>
 * <erp-button variant="danger" [loading]="saving">Eliminar</erp-button>
 */
@Component({
  selector: 'erp-button',
  standalone: true,
  changeDetection: ChangeDetectionStrategy.OnPush,
  imports: [NgClass],
  template: `
    <button
      [type]="type()"
      [disabled]="disabled() || loading()"
      [ngClass]="['btn', 'btn-' + variant(), 'btn-' + size()]"
      [attr.aria-busy]="loading()"
      (click)="!disabled() && !loading() && clicked.emit()"
    >
      @if (loading()) {
        <span class="btn-spinner" aria-hidden="true">⟳</span>
      }
      <ng-content />
    </button>
  `,
  styles: [`
    .btn {
      display: inline-flex;
      align-items: center;
      gap: var(--space-2);
      border: none;
      border-radius: var(--radius-md);
      font-family: var(--font-sans);
      font-weight: 500;
      cursor: pointer;
      transition: opacity 0.15s, background 0.15s;
    }
    .btn:disabled { opacity: 0.5; cursor: not-allowed; }
    .btn-sm { padding: var(--space-1) var(--space-3); font-size: var(--font-size-xs); }
    .btn-md { padding: var(--space-2) var(--space-4); font-size: var(--font-size-sm); }
    .btn-lg { padding: var(--space-3) var(--space-6); font-size: var(--font-size-base); }
    .btn-primary {
      background: rgb(var(--color-primary));
      color: #fff;
    }
    .btn-primary:not(:disabled):hover { opacity: 0.9; }
    .btn-secondary {
      background: #f1f5f9;
      color: rgb(var(--color-neutral));
    }
    .btn-secondary:not(:disabled):hover { background: #e2e8f0; }
    .btn-danger {
      background: rgb(var(--color-danger));
      color: #fff;
    }
    .btn-danger:not(:disabled):hover { opacity: 0.9; }
    .btn-ghost {
      background: transparent;
      color: rgb(var(--color-primary));
    }
    .btn-ghost:not(:disabled):hover { background: #eff6ff; }
    .btn-spinner { animation: spin 0.7s linear infinite; display: inline-block; }
    @keyframes spin { to { transform: rotate(360deg); } }
  `],
})
export class ButtonComponent {
  readonly variant = input<ButtonVariant>('primary');
  readonly size = input<ButtonSize>('md');
  readonly disabled = input(false);
  readonly loading = input(false);
  readonly type = input<'button' | 'submit' | 'reset'>('button');
  readonly clicked = output<void>();
}
