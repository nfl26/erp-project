-- ============================================================
-- 02-create-tenants.sql — Multi-tenancy por schema (ADR-003)
-- Crea la tabla de control en public, los schemas de tenant
-- y establece el search_path por defecto de la base de datos.
--
-- IMPORTANTE: El ALTER DATABASE al final de este script hace que
-- todos los scripts siguientes (03, 04, ...) y las conexiones
-- de la aplicación sin search_path explícito usen tenant_erp
-- como schema por defecto. Los servicios NestJS siempre
-- establecen SET search_path = tenant_<id> por conexión,
-- por lo que este default solo aplica a herramientas de dev.
-- ============================================================

-- ── Tabla de control de tenants ───────────────────────────────────────────
CREATE TABLE IF NOT EXISTS public.tenants (
    id         VARCHAR(50)  PRIMARY KEY,
    nombre     VARCHAR(200) NOT NULL,
    active     BOOLEAN      NOT NULL DEFAULT TRUE,
    created_at TIMESTAMPTZ  NOT NULL DEFAULT NOW()
);

-- ── Schemas de tenant ─────────────────────────────────────────────────────
-- Cada schema es un namespace aislado con las mismas tablas (ADR-003).
-- Las migraciones de Prisma se aplicarán por schema cuando se ejecute
-- prisma migrate deploy con la variable SCHEMA=tenant_<id>.

CREATE SCHEMA IF NOT EXISTS tenant_acme;
CREATE SCHEMA IF NOT EXISTS tenant_beta;
CREATE SCHEMA IF NOT EXISTS tenant_erp;

-- ── Registrar tenants en public ──────────────────────────────────────────
INSERT INTO public.tenants (id, nombre, active) VALUES
    ('acme', 'ACME Industrial SA',  TRUE),
    ('beta', 'Beta Industrial SPA', TRUE),
    ('demo', 'Taller Arteo — Demo', TRUE)
ON CONFLICT (id) DO NOTHING;

-- ── Default search_path de la BD ──────────────────────────────────────────
-- Hace que los scripts 03 y 04 (y psql sin -c "SET search_path")
-- operen en tenant_erp. La aplicación lo sobreescribe por conexión.
ALTER DATABASE erp_db SET search_path TO tenant_erp, public;
