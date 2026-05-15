import {
  Component,
  ChangeDetectionStrategy,
  forwardRef,
  signal,
  input,
} from '@angular/core';
import { ControlValueAccessor, NG_VALUE_ACCESSOR, ReactiveFormsModule } from '@angular/forms';
import { NgClass } from '@angular/common';

/**
 * Input integrado con Reactive Forms vía ControlValueAccessor.
 *
 * @example
 * <erp-input
 *   label="Nombre"
 *   [formControl]="nameControl"
 *   hint="Máx. 100 caracteres"
 * />
 * <!-- Con error externo -->
 * <erp-input label="Email" [formControl]="emailCtrl" [errorMessage]="emailError()" />
 */
@Component({
  selector: 'erp-input',
  standalone: true,
  changeDetection: ChangeDetectionStrategy.OnPush,
  imports: [NgClass, ReactiveFormsModule],
  providers: [
    {
      provide: NG_VALUE_ACCESSOR,
      useExisting: forwardRef(() => InputComponent),
      multi: true,
    },
  ],
  template: `
    <div class="field" [ngClass]="{ 'field-error': errorMessage() }">
      @if (label()) {
        <label class="field-label" [for]="inputId">{{ label() }}</label>
      }
      <input
        [id]="inputId"
        class="field-input"
        [type]="type()"
        [placeholder]="placeholder()"
        [disabled]="isDisabled()"
        [value]="value()"
        [attr.aria-describedby]="errorMessage() ? inputId + '-err' : hint() ? inputId + '-hint' : null"
        [attr.aria-invalid]="!!errorMessage()"
        (input)="onInput($event)"
        (blur)="onTouched()"
      />
      @if (errorMessage()) {
        <span class="field-error-msg" [id]="inputId + '-err'" role="alert">
          {{ errorMessage() }}
        </span>
      } @else if (hint()) {
        <span class="field-hint" [id]="inputId + '-hint'">{{ hint() }}</span>
      }
    </div>
  `,
  styles: [`
    .field { display: flex; flex-direction: column; gap: var(--space-1); }
    .field-label {
      font-size: var(--font-size-sm);
      font-weight: 500;
      color: #374151;
    }
    .field-input {
      padding: var(--space-2) var(--space-3);
      border: 1px solid #d1d5db;
      border-radius: var(--radius-md);
      font-size: var(--font-size-sm);
      font-family: var(--font-sans);
      transition: border-color 0.15s, box-shadow 0.15s;
      outline: none;
    }
    .field-input:focus {
      border-color: rgb(var(--color-primary));
      box-shadow: 0 0 0 3px rgb(var(--color-primary) / 0.15);
    }
    .field-input:disabled { background: #f9fafb; cursor: not-allowed; }
    .field-error .field-input { border-color: rgb(var(--color-danger)); }
    .field-error-msg {
      font-size: var(--font-size-xs);
      color: rgb(var(--color-danger));
    }
    .field-hint {
      font-size: var(--font-size-xs);
      color: rgb(var(--color-neutral));
    }
  `],
})
export class InputComponent implements ControlValueAccessor {
  readonly label = input('');
  readonly placeholder = input('');
  readonly hint = input('');
  readonly errorMessage = input('');
  readonly type = input<string>('text');

  readonly value = signal('');
  readonly isDisabled = signal(false);

  // eslint-disable-next-line @typescript-eslint/no-empty-function
  private _onChange: (v: string) => void = () => {};
  onTouched: () => void = () => {};

  readonly inputId = `erp-input-${Math.random().toString(36).slice(2, 8)}`;

  writeValue(val: string): void {
    this.value.set(val ?? '');
  }

  registerOnChange(fn: (v: string) => void): void {
    this._onChange = fn;
  }

  registerOnTouched(fn: () => void): void {
    this.onTouched = fn;
  }

  setDisabledState(disabled: boolean): void {
    this.isDisabled.set(disabled);
  }

  onInput(event: Event): void {
    const val = (event.target as HTMLInputElement).value;
    this.value.set(val);
    this._onChange(val);
  }
}
