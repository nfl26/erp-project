import { Component, ChangeDetectionStrategy, output } from '@angular/core';

@Component({
  selector: 'erp-header',
  standalone: true,
  changeDetection: ChangeDetectionStrategy.OnPush,
  template: `
    <header class="header" role="banner">
      <div class="header-left">
        <h1 class="header-title">ERP Backoffice</h1>
      </div>
      <div class="header-right">
        <!-- Placeholder usuario: se cablea en T-015 con Keycloak -->
        <span class="user-placeholder" aria-label="Usuario">👤</span>

        <!-- Toggle dark mode: se cablea cuando haya estado global de tema -->
        <button
          class="theme-toggle"
          type="button"
          aria-label="Alternar modo oscuro"
          (click)="toggleTheme.emit()"
        >🌙</button>
      </div>
    </header>
  `,
  styles: [`
    .header {
      display: flex;
      align-items: center;
      justify-content: space-between;
      padding: 0 var(--space-6);
      height: 56px;
      background: #fff;
      border-bottom: 1px solid #e2e8f0;
      box-shadow: var(--shadow-sm);
    }
    .header-title {
      font-size: var(--font-size-base);
      font-weight: 600;
      margin: 0;
      color: rgb(var(--color-neutral));
    }
    .header-right {
      display: flex;
      align-items: center;
      gap: var(--space-4);
    }
    .theme-toggle {
      background: none;
      border: none;
      cursor: pointer;
      font-size: 1.1rem;
      padding: var(--space-1);
      border-radius: var(--radius-sm);
    }
  `],
})
export class HeaderComponent {
  readonly toggleTheme = output<void>();
}
