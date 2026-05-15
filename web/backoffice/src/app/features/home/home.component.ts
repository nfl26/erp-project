import { Component, ChangeDetectionStrategy } from '@angular/core';

@Component({
  selector: 'erp-home',
  standalone: true,
  changeDetection: ChangeDetectionStrategy.OnPush,
  template: `
    <section class="home">
      <h1>Bienvenido al ERP Backoffice</h1>
      <p>Selecciona un módulo en el menú lateral para comenzar.</p>
    </section>
  `,
  styles: [`
    .home {
      padding: var(--space-8);
    }
    h1 {
      font-size: var(--font-size-2xl);
      font-weight: 700;
      margin: 0 0 var(--space-4);
    }
    p {
      color: rgb(var(--color-neutral));
      font-size: var(--font-size-base);
    }
  `],
})
export class HomeComponent {}
