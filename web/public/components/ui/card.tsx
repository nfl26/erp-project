import * as React from 'react'
import { cn } from '@/lib/utils'

/**
 * @example
 * <Card>
 *   <CardHeader><CardTitle>Cotización #2026-0091</CardTitle></CardHeader>
 *   <CardBody>Contenido de la card</CardBody>
 *   <CardFooter><Button size="sm">Ver detalle</Button></CardFooter>
 * </Card>
 */

export function Card({ className, ...props }: React.HTMLAttributes<HTMLDivElement>) {
  return (
    <div
      className={cn(
        'rounded-lg border border-slate-200 bg-white shadow-sm',
        'dark:border-slate-700 dark:bg-slate-900',
        className
      )}
      {...props}
    />
  )
}

export function CardHeader({ className, ...props }: React.HTMLAttributes<HTMLDivElement>) {
  return (
    <div
      className={cn(
        'border-b border-slate-200 px-6 py-4 dark:border-slate-700',
        className
      )}
      {...props}
    />
  )
}

export function CardTitle({ className, ...props }: React.HTMLAttributes<HTMLHeadingElement>) {
  return (
    <h3
      className={cn('text-base font-semibold text-slate-900 dark:text-slate-100', className)}
      {...props}
    />
  )
}

export function CardBody({ className, ...props }: React.HTMLAttributes<HTMLDivElement>) {
  return <div className={cn('px-6 py-4', className)} {...props} />
}

export function CardFooter({ className, ...props }: React.HTMLAttributes<HTMLDivElement>) {
  return (
    <div
      className={cn(
        'border-t border-slate-200 px-6 py-3 dark:border-slate-700',
        className
      )}
      {...props}
    />
  )
}
