-- ============================================================
-- 03-seed-demo-data.sql — Usuarios dev en tenant_demo
--
-- Ejecuta DESPUÉS de 02 (que establece search_path = tenant_demo)
-- y ANTES de 04 (que crea las tablas de negocio con IF NOT EXISTS).
--
-- Este script crea la tabla usuarios con la misma definición
-- que 04, de forma que ambos scripts son idempotentes.
-- Los 2 usuarios dev que inserta 04 NO crea — solo los crea aquí.
--
-- Password de ambos usuarios: dev123
-- (bcrypt $2b$, 10 rounds — solo para desarrollo local)
-- En producción la autenticación va por Keycloak (T-010).
-- ============================================================

-- ENUM compartido con 04 (idempotente)
DO $$ BEGIN
    CREATE TYPE rol_usuario AS ENUM ('admin', 'vendedor', 'operario', 'comprador');
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

-- Tabla de usuarios (misma definición que en 04-seed-arteo-data.sql)
CREATE TABLE IF NOT EXISTS usuarios (
    id_usuario    SERIAL       PRIMARY KEY,
    nombre        VARCHAR(100) NOT NULL,
    apellido      VARCHAR(100) NOT NULL,
    email         VARCHAR(200) NOT NULL UNIQUE,
    password_hash TEXT         NOT NULL,
    rol           rol_usuario  NOT NULL DEFAULT 'operario',
    activo        BOOLEAN      NOT NULL DEFAULT TRUE,
    created_at    TIMESTAMPTZ  NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_usuarios_email ON usuarios(email);
CREATE INDEX IF NOT EXISTS idx_usuarios_rol   ON usuarios(rol);

-- ── Usuarios dev ──────────────────────────────────────────────────────────
-- Hash bcrypt de "dev123" (10 rounds). Válido solo para desarrollo local.
INSERT INTO usuarios (nombre, apellido, email, password_hash, rol) VALUES
    ('Admin',      'Demo', 'admin@arteo.dev',
     '$2b$10$N9qo8uLOickgx2ZMRZoMyeIjZAgcfl7p92ldGxad68LJZdL17lHuu',
     'admin'),
    ('Bodeguero',  'Demo', 'bodeguero@arteo.dev',
     '$2b$10$N9qo8uLOickgx2ZMRZoMyeIjZAgcfl7p92ldGxad68LJZdL17lHuu',
     'operario')
ON CONFLICT (email) DO NOTHING;
