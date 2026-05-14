-- Rename schema preserving all data (T-FIX-001)
-- MANUAL EDIT: executed directly in psql, then marked applied with prisma migrate resolve.
-- Rollback: ALTER SCHEMA tenant_erp RENAME TO tenant_demo;
ALTER SCHEMA tenant_demo RENAME TO tenant_erp;
