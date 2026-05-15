import { Component, ChangeDetectionStrategy, input } from '@angular/core';
import { RouterLink } from '@angular/router';

@Component({
  selector: 'erp-error',
  standalone: true,
  changeDetection: ChangeDetectionStrategy.OnPush,
  imports: [RouterLink],
  template: `
    <div class="error-boundary" role="alert">
      <h2>Algo salió mal</h2>
      <p class="error-detail">{{ message() }}</p>
      <a routerLink="/home">Volver al inicio</a>
    </div>
  `,
  styles: [`
    .error-boundary {
      display: flex;
      flex-direction: column;
      align-items: center;
      gap: var(--space-4);
      padding: var(--space-8);
      text-align: center;
    }
    h2 { color: rgb(var(--color-danger)); margin: 0; }
    .error-detail { color: rgb(var(--color-neutral)); font-size: var(--font-size-sm); }
    a { color: rgb(var(--color-primary)); text-decoration: none; }
  `],
})
export class ErrorComponent {
  readonly message = input('Error inesperado. Por favor recarga la página.');
}
