import { Component, ChangeDetectionStrategy } from '@angular/core';
import { ShellComponent } from './layout/shell.component';

@Component({
  selector: 'erp-root',
  standalone: true,
  imports: [ShellComponent],
  template: '<erp-shell />',
  changeDetection: ChangeDetectionStrategy.OnPush,
})
export class AppComponent {}
