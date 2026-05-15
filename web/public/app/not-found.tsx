import Link from 'next/link'

export default function NotFound() {
  return (
    <div className="flex min-h-screen flex-col items-center justify-center p-8">
      <div className="text-center">
        <p className="text-6xl font-bold text-primary">404</p>
        <h2 className="mt-4 text-2xl font-bold text-slate-900 dark:text-slate-100">
          Página no encontrada
        </h2>
        <p className="mt-2 text-muted">La página que buscas no existe o fue movida.</p>
        <Link
          href="/"
          className="mt-6 inline-block rounded-md bg-primary px-4 py-2 text-sm font-medium text-white hover:bg-primary/90"
        >
          Volver al inicio
        </Link>
      </div>
    </div>
  )
}
