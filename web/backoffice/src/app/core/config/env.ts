import { z } from 'zod';

const envSchema = z.object({
  NG_APP_API_URL: z.string().url('NG_APP_API_URL debe ser una URL válida'),
  NG_APP_ENV: z.enum(['development', 'staging', 'production']).default('development'),
  NG_APP_SENTRY_DSN: z.string().optional(),
  // Keycloak placeholders — se cablearán en T-015
  NG_APP_KEYCLOAK_URL: z.string().optional(),
  NG_APP_KEYCLOAK_REALM: z.string().optional(),
  NG_APP_KEYCLOAK_CLIENT_ID: z.string().optional(),
});

export type Env = z.infer<typeof envSchema>;

function validateEnv(): Env {
  const raw = {
    NG_APP_API_URL: import.meta.env['NG_APP_API_URL'],
    NG_APP_ENV: import.meta.env['NG_APP_ENV'],
    NG_APP_SENTRY_DSN: import.meta.env['NG_APP_SENTRY_DSN'],
    NG_APP_KEYCLOAK_URL: import.meta.env['NG_APP_KEYCLOAK_URL'],
    NG_APP_KEYCLOAK_REALM: import.meta.env['NG_APP_KEYCLOAK_REALM'],
    NG_APP_KEYCLOAK_CLIENT_ID: import.meta.env['NG_APP_KEYCLOAK_CLIENT_ID'],
  };

  const result = envSchema.safeParse(raw);

  if (!result.success) {
    const errors = result.error.errors
      .map(e => `  ${e.path.join('.')}: ${e.message}`)
      .join('\n');
    throw new Error(`Variables de entorno inválidas:\n${errors}\n\nCopia .env.example a .env.local y completa los valores.`);
  }

  return result.data;
}

export const env: Env = validateEnv();
