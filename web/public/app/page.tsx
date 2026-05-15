export default function HomePage() {
  return (
    <main className="flex min-h-screen flex-col items-center justify-center p-8">
      <div className="w-full max-w-md text-center">
        <h1 className="text-4xl font-bold tracking-tight text-slate-900 dark:text-slate-100">
          ERP — Portal en construcción
        </h1>
        <p className="mt-4 text-lg text-muted">El portal estará disponible próximamente.</p>

        <div
          id="desarrollo"
          className="mt-8 rounded-lg border border-slate-200 bg-white p-6 text-left text-sm text-slate-600 dark:border-slate-700 dark:bg-slate-800 dark:text-slate-400"
        >
          <p className="font-semibold text-slate-900 dark:text-slate-100">Módulos en desarrollo</p>
          <ul className="mt-2 list-inside list-disc space-y-1">
            <li>Cotizaciones y órdenes de venta</li>
            <li>Dashboard de KPIs gerenciales</li>
            <li>Gestión de clientes</li>
          </ul>
        </div>
      </div>
    </main>
  )
}
