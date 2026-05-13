import path from 'node:path';
import { defineConfig } from 'prisma/config';

// URL sin ?schema= porque multiSchema resuelve los schemas via @@schema() en los modelos.
// El search_path por request lo maneja TenantMiddleware (T-007).
// Prisma CLI carga .env DESPUÉS de ejecutar este archivo, por lo que process.env.DATABASE_URL
// puede estar undefined en este contexto; se usa el valor de dev como fallback.
export default defineConfig({
  schema: path.join(__dirname, 'prisma', 'schema.prisma'),
  datasource: {
    url: process.env.DATABASE_URL ?? 'postgresql://erp_admin:changeme123@localhost:5433/erp_db',
  },
});