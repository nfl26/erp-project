import { Component, ChangeDetectionStrategy, signal } from '@angular/core';
import { RouterOutlet } from '@angular/router';
import { SidebarComponent } from './sidebar.component';
import { HeaderComponent } from './header.component';

@Component({
  selector: 'erp-shell',
  standalone: true,
  changeDetection: ChangeDetectionStrategy.OnPush,
  imports: [RouterOutlet, SidebarComponent, HeaderComponent],
  template: `
    <div class="shell" [class.sidebar-collapsed]="sidebarCollapsed()">
      <erp-sidebar
        [collapsed]="sidebarCollapsed()"
        (toggleCollapsed)="sidebarCollapsed.set(!sidebarCollapsed())"
      />
      <div class="shell-main">
        <erp-header (toggleTheme)="onToggleTheme()" />
        <main class="shell-content" id="main-content" role="main">
          <router-outlet />
        </main>
      </div>
    </div>
  `,
  styles: [`
    .shell {
      display: grid;
      grid-template-columns: 240px 1fr;
      min-height: 100vh;
      transition: grid-template-columns 0.2s ease;
    }
    .shell.sidebar-collapsed {
      grid-template-columns: 56px 1fr;
    }
    @media (max-width: 1024px) {
      .shell { grid-template-columns: 56px 1fr; }
    }
    .shell-main {
      display: grid;
      grid-template-rows: 56px 1fr;
      min-height: 100vh;
      overflow: hidden;
    }
    .shell-content {
      padding: var(--space-6);
      overflow-y: auto;
      background: #f8fafc;
    }
  `],
})
export class ShellComponent {
  readonly sidebarCollapsed = signal(false);

  onToggleTheme(): void {
    // TODO: implementar estado global de tema
    document.documentElement.classList.toggle('dark');
  }
}
