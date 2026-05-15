'use client'

import { useEffect } from 'react'

export default function Error({
  error,
  reset,
}: {
  error: Error & { digest?: string }
  reset: () => void
}) {
  useEffect(() => {
    console.error('Error de aplicación:', error)
  }, [error])

  return (
    <div className="flex min-h-screen flex-col items-center justify-center p-8">
      <div className="max-w-md text-center">
        <h2 className="text-2xl font-bold text-slate-900 dark:text-slate-100">
          Algo salió mal
        </h2>
        <p className="mt-2 text-muted">
          {error.message || 'Ocurrió un error inesperado. Por favor intenta nuevamente.'}
        </p>
        {error.digest && (
          <p className="mt-1 text-xs text-slate-400">Referencia: {error.digest}</p>
        )}
        <button
          onClick={reset}
          className="mt-6 rounded-md bg-primary px-4 py-2 text-sm font-medium text-white hover:bg-primary/90 focus:outline-none focus:ring-2 focus:ring-primary focus:ring-offset-2"
        >
          Intentar de nuevo
        </button>
      </div>
    </div>
  )
}
