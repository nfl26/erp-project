import { Component, ChangeDetectionStrategy } from '@angular/core';
import { RouterLink } from '@angular/router';

@Component({
  selector: 'erp-not-found',
  standalone: true,
  changeDetection: ChangeDetectionStrategy.OnPush,
  imports: [RouterLink],
  template: `
    <div class="not-found">
      <h1>404</h1>
      <p>Página no encontrada.</p>
      <a routerLink="/home">Volver al inicio</a>
    </div>
  `,
  styles: [`
    .not-found {
      display: flex;
      flex-direction: column;
      align-items: center;
      justify-content: center;
      min-height: 60vh;
      gap: var(--space-4);
      text-align: center;
    }
    h1 { font-size: 4rem; color: rgb(var(--color-neutral)); margin: 0; }
    a { color: rgb(var(--color-primary)); text-decoration: none; }
    a:hover { text-decoration: underline; }
  `],
})
export class NotFoundComponent {}
