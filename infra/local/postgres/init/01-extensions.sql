-- ============================================================
-- 01-extensions.sql — Extensiones de PostgreSQL
-- Se instalan en el schema public (nivel de base de datos).
-- Ejecutado antes de crear tenants y sembrar datos.
-- ============================================================

-- UUID v4 nativo — todos los IDs del ERP son UUID, no SERIAL
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- Búsqueda de texto con trigrams — para búsquedas "contiene" en insumos y productos
CREATE EXTENSION IF NOT EXISTS "pg_trgm";

-- Índices GIN sobre columnas JSONB — para variantes dinámicas de producto (ADR-004)
CREATE EXTENSION IF NOT EXISTS "btree_gin";
