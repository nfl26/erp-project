import { z } from 'zod'

const envSchema = z.object({
  NEXT_PUBLIC_API_URL: z
    .string({ required_error: 'NEXT_PUBLIC_API_URL es requerida' })
    .url('NEXT_PUBLIC_API_URL debe ser una URL válida (ej: http://localhost:3000/api/v1)'),
  NEXT_PUBLIC_APP_ENV: z
    .enum(['development', 'staging', 'production'], {
      errorMap: () => ({
        message: 'NEXT_PUBLIC_APP_ENV debe ser development | staging | production',
      }),
    })
    .default('development'),
  NEXT_PUBLIC_SENTRY_DSN: z.string().optional(),
})

function validateEnv() {
  const result = envSchema.safeParse({
    NEXT_PUBLIC_API_URL: process.env.NEXT_PUBLIC_API_URL,
    NEXT_PUBLIC_APP_ENV: process.env.NEXT_PUBLIC_APP_ENV,
    NEXT_PUBLIC_SENTRY_DSN: process.env.NEXT_PUBLIC_SENTRY_DSN,
  })

  if (!result.success) {
    const issues = result.error.errors
      .map((e) => `  • ${e.path.join('.')}: ${e.message}`)
      .join('\n')
    throw new Error(
      `Variables de entorno inválidas o faltantes:\n${issues}\n\nRevisa .env.example para la lista completa.`
    )
  }

  return result.data
}

export const env = validateEnv()
