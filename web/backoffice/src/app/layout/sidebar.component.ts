import { Component, ChangeDetectionStrategy, input, output } from '@angular/core';
import { RouterLink, RouterLinkActive } from '@angular/router';

interface NavItem {
  label: string;
  path: string;
  icon: string;
}

@Component({
  selector: 'erp-sidebar',
  standalone: true,
  changeDetection: ChangeDetectionStrategy.OnPush,
  imports: [RouterLink, RouterLinkActive],
  template: `
    <nav class="sidebar" [class.collapsed]="collapsed()">
      <div class="sidebar-header">
        <span class="sidebar-logo" aria-label="ERP Backoffice">ERP</span>
        <button
          class="sidebar-toggle"
          (click)="toggleCollapsed.emit()"
          [attr.aria-expanded]="!collapsed()"
          aria-label="Toggle navigation"
          type="button"
        >☰</button>
      </div>

      <ul class="nav-list" role="list">
        @for (item of navItems; track item.path) {
          <li>
            <a
              [routerLink]="item.path"
              routerLinkActive="active"
              class="nav-item"
              [attr.title]="collapsed() ? item.label : null"
            >
              <span class="nav-icon" aria-hidden="true">{{ item.icon }}</span>
              @if (!collapsed()) {
                <span class="nav-label">{{ item.label }}</span>
              }
            </a>
          </li>
        }
      </ul>
    </nav>
  `,
  styles: [`
    .sidebar {
      display: flex;
      flex-direction: column;
      background: rgb(var(--color-surface));
      border-right: 1px solid #e2e8f0;
      width: 240px;
      min-height: 100vh;
      transition: width 0.2s ease;
    }
    .sidebar.collapsed { width: 56px; }
    .sidebar-header {
      display: flex;
      align-items: center;
      justify-content: space-between;
      padding: var(--space-4);
      border-bottom: 1px solid #e2e8f0;
    }
    .sidebar-logo {
      font-weight: 700;
      font-size: var(--font-size-lg);
      color: rgb(var(--color-primary));
    }
    .sidebar-toggle {
      background: none;
      border: none;
      cursor: pointer;
      padding: var(--space-1);
      border-radius: var(--radius-sm);
    }
    .nav-list {
      list-style: none;
      padding: var(--space-2);
      margin: 0;
    }
    .nav-item {
      display: flex;
      align-items: center;
      gap: var(--space-3);
      padding: var(--space-3) var(--space-2);
      border-radius: var(--radius-md);
      text-decoration: none;
      color: rgb(var(--color-neutral));
      font-size: var(--font-size-sm);
      transition: background 0.15s;
    }
    .nav-item:hover { background: #f1f5f9; color: rgb(var(--color-primary)); }
    .nav-item.active { background: #eff6ff; color: rgb(var(--color-primary)); font-weight: 600; }
    .nav-icon { font-size: 1.1rem; flex-shrink: 0; }
  `],
})
export class SidebarComponent {
  readonly collapsed = input(false);
  readonly toggleCollapsed = output<void>();

  readonly navItems: NavItem[] = [
    { label: 'Inicio', path: '/home', icon: '⌂' },
    { label: 'Bodega', path: '/bodega', icon: '📦' },
    { label: 'Producción', path: '/produccion', icon: '⚙️' },
    { label: 'Ventas', path: '/ventas', icon: '📋' },
    { label: 'Configuración', path: '/config', icon: '⚙' },
  ];
}
