import * as React from 'react'
import { cn } from '@/lib/utils'

/**
 * @example
 * <Input label="RUT cliente" placeholder="12.345.678-9" {...register('rut')} />
 * <Input label="Monto" error={errors.monto?.message} {...register('monto')} />
 */

interface InputProps extends React.InputHTMLAttributes<HTMLInputElement> {
  label?: string
  error?: string
}

export const Input = React.forwardRef<HTMLInputElement, InputProps>(
  ({ className, label, error, id, ...props }, ref) => {
    const inputId = id ?? label?.toLowerCase().replace(/\s+/g, '-')

    return (
      <div className="flex flex-col gap-1">
        {label && (
          <label
            htmlFor={inputId}
            className="text-sm font-medium text-slate-700 dark:text-slate-300"
          >
            {label}
          </label>
        )}
        <input
          ref={ref}
          id={inputId}
          className={cn(
            'h-10 w-full rounded-md border border-slate-300 bg-white px-3 text-sm text-slate-900',
            'placeholder:text-slate-400',
            'focus:border-primary focus:outline-none focus:ring-2 focus:ring-primary focus:ring-offset-0',
            'disabled:cursor-not-allowed disabled:bg-slate-50 disabled:text-slate-500',
            'dark:border-slate-600 dark:bg-slate-800 dark:text-slate-100 dark:placeholder:text-slate-500',
            error && 'border-danger focus:ring-danger',
            className
          )}
          aria-invalid={error ? 'true' : undefined}
          aria-describedby={error ? `${inputId}-error` : undefined}
          {...props}
        />
        {error && (
          <p id={`${inputId}-error`} role="alert" className="text-xs text-danger">
            {error}
          </p>
        )}
      </div>
    )
  }
)
Input.displayName = 'Input'
