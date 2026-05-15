// Validate required env vars at build time — fails fast with a clear message.
// Runtime validation (with Zod) lives in lib/env.ts and runs when the API client is used.
const REQUIRED_VARS = [
  { key: 'NEXT_PUBLIC_API_URL', hint: 'string (URL). Ejemplo: http://localhost:3000/api/v1' },
]

for (const { key, hint } of REQUIRED_VARS) {
  if (!process.env[key]) {
    throw new Error(
      `\n❌  Variable de entorno requerida faltante: ${key}\n` +
        `    Tipo esperado: ${hint}\n` +
        `    Copia .env.example a .env.local y completa los valores.\n`
    )
  }
}

/** @type {import('next').NextConfig} */
const nextConfig = {
  async headers() {
    return [
      {
        source: '/(.*)',
        headers: [
          { key: 'X-Content-Type-Options', value: 'nosniff' },
          { key: 'X-Frame-Options', value: 'DENY' },
          { key: 'X-XSS-Protection', value: '1; mode=block' },
          { key: 'Referrer-Policy', value: 'strict-origin-when-cross-origin' },
        ],
      },
    ]
  },
}

module.exports = nextConfig
