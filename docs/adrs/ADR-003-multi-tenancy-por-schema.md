# ADR-003: Multi-tenancy por schema en PostgreSQL

- **Status:** accepted
- **Date:** 2026-04-15
- **Deciders:** TL, S1, DO
- **Tags:** datos, arquitectura, escalabilidad, multi-tenancy

---

## Contexto

El cliente declaró explícitamente en el kickoff la intención de **escalar el ERP a múltiples rubros** después del MVP. Esto no es una expansión del mismo negocio — cada rubro es una operación distinta, posiblemente con catálogos de insumos diferentes, tarifas diferentes, incluso recetas con dominios distintos.

Hay tres arquetipos comunes para resolver esto:

1. **Multi-tenancy por fila:** todas las empresas comparten las mismas tablas, filtradas por columna `tenant_id`.
2. **Multi-tenancy por schema:** cada empresa tiene su propio schema en la misma base de datos.
3. **Multi-tenancy por base de datos:** cada empresa tiene su propia instancia de PostgreSQL.

La decisión afecta desde el día uno cómo se escriben las migraciones, cómo se conectan los servicios a la BD, cómo se maneja el backup, cómo se factura el hosting, y cómo se aíslan los datos entre clientes.

Tiene que decidirse **antes** del MVP porque cambiar después requiere migrar datos reales del cliente.

---

## Decisión

Implementaremos multi-tenancy **por schema dentro de la misma base de datos PostgreSQL**. Cada tenant (empresa/rubro) tendrá su propio schema con las mismas tablas.

### Arquitectura

```
PostgreSQL instance
├── schema: public              ← metadatos compartidos (lista de tenants, usuarios globales)
├── schema: tenant_acme         ← datos de ACME SA
│   ├── insumos
│   ├── movimientos_bodega
│   ├── ordenes_produccion
│   └── ... (todas las tablas)
├── schema: tenant_beta         ← datos de Beta Industrial
│   ├── insumos
│   ├── movimientos_bodega
│   └── ...
└── schema: tenant_erp         ← para demos y testing
```

### Resolución de tenant

El tenant se resuelve en **este orden**:

1. **Por subdominio:** `acme.erp.empresa.com` → tenant `acme`.
2. **Por header HTTP:** `X-Tenant-Id: acme` (para llamadas internas entre servicios).
3. **Por claim del JWT:** el usuario autenticado tiene un claim `tenant_id` en el token de Keycloak.

El API Gateway resuelve el tenant en el paso 1 y lo inyecta como header para los servicios downstream.

### Implementación en los servicios

Cada servicio tiene un **middleware/interceptor** que:

1. Lee el tenant del request.
2. Valida que el usuario autenticado tiene acceso a ese tenant.
3. Establece `SET search_path TO tenant_<id>` al obtener una conexión de la pool.
4. Todas las queries subsiguientes usan el schema del tenant automáticamente.

En NestJS con Prisma:

```typescript
@Injectable()
export class TenantAwarePrismaService {
  async getClient(tenantId: string): Promise<PrismaClient> {
    const client = this.pool.acquire(tenantId);
    await client.$executeRawUnsafe(`SET search_path TO tenant_${tenantId}`);
    return client;
  }
}
```

En Spring Boot con Hibernate:

```java
@Component
public class TenantConnectionProvider implements MultiTenantConnectionProvider {
    @Override
    public Connection getConnection(String tenantId) throws SQLException {
        Connection conn = dataSource.getConnection();
        conn.createStatement()
            .execute("SET search_path TO tenant_" + tenantId);
        return conn;
    }
}
```

### Migraciones

Cada migración se aplica **a todos los schemas de tenants existentes**. Herramienta:

- Script Python/bash que lista los tenants activos y corre `prisma migrate deploy` o `flyway migrate` con el schema apropiado en cada uno.
- Ejecutado en CI al mergeado a `main`, antes del deploy de servicios.

```bash
# scripts/migrate-all-tenants.sh
for tenant in $(psql -At -c "SELECT tenant_id FROM public.tenants WHERE active = true"); do
  echo "Migrando schema tenant_$tenant..."
  SCHEMA=tenant_$tenant npx prisma migrate deploy
done
```

---

## Alternativas consideradas

### A) Multi-tenancy por fila (columna `tenant_id`)

Una sola copia de cada tabla, filtrada por columna.

**Pros:**
- Implementación más simple (una sola migración aplica a todos).
- Consultas cross-tenant triviales (para admin global).
- Menos overhead de infraestructura.

**Cons:**
- **Aislamiento débil.** Un bug en un WHERE puede leak datos entre tenants. Problema crítico para un ERP con datos sensibles.
- Índices compartidos degradan rendimiento cuando un tenant grande satura.
- Backups/restores granulares por tenant son complejos.
- Incumple requisitos de cumplimiento/privacidad que algunos rubros exigen.
- El cliente específicamente pidió que los datos de un rubro no se mezclen con otro.
- **Descartada.**

### B) Multi-tenancy por base de datos

Una instancia de PostgreSQL por tenant.

**Pros:**
- Máximo aislamiento.
- Backups/restores independientes triviales.
- Un tenant grande no afecta performance de otros.
- Cumplimiento total con cualquier exigencia de aislamiento.

**Cons:**
- **Costo de infraestructura mucho más alto.** Una RDS por tenant = N veces el costo.
- Operacionalmente complejo: N conexiones, N backups, N monitoreos.
- Migraciones son N veces más lentas y más propensas a error.
- Injustificable para un MVP con 1-5 tenants previstos.
- Migrar de este modelo a schema es fácil; migrar al revés es difícil.
- **Se mantiene como opción futura** si algún tenant grande lo requiere.

### C) Multi-tenancy por schema **(elegida)**

Un schema por tenant en la misma BD.

**Pros:**
- **Aislamiento fuerte** (SQL garantiza que `SET search_path` solo ve ese schema).
- Migraciones simples (repetir por tenant).
- Backups granulares con `pg_dump --schema=tenant_xxx`.
- Performance aislada por schema (índices separados).
- Costo de infraestructura moderado (una RDS, varios schemas).
- Evolución futura hacia opción B es factible.
- Compatible con extensiones de PostgreSQL (Row-Level Security adicional si se requiere).

**Cons:**
- Migraciones deben ejecutarse N veces.
- Cross-tenant queries (admin global) requieren lógica especial.
- Número de schemas crece con tenants (PostgreSQL maneja bien hasta varios miles).

---

## Consecuencias

### Positivas

- **Aislamiento fuerte por diseño.** Un bug en la lógica de aplicación no puede leakear datos entre tenants — el schema activo define el universo visible.
- **Onboarding de un nuevo tenant es trivial:** crear schema + correr migraciones + registrar en `public.tenants`.
- **Costo moderado:** una sola RDS sirve para todos los tenants del MVP y los siguientes años.
- **Cumple la expectativa del cliente** de que un rubro no ve datos de otro.
- **Compatible con el dashboard visual** (`dashboard/erp_agentes_ia.html`) que ya muestra multi-tenancy como feature planeada.

### Negativas aceptadas

- **Migraciones más lentas** con el crecimiento de tenants. Mitigación: paralelización del script de migración.
- **Lógica de resolución de tenant** en cada servicio. Mitigación: encapsulado en middleware/interceptor reutilizable.
- **Queries cross-tenant** (para reportes globales al operador del ERP, no al cliente final) requieren cuidado. Mitigación: endpoints admin específicos, separados de los endpoints regulares.
- **Performance de la pool de conexiones:** `SET search_path` tiene un costo por query. Mitigación: pool de conexiones con `search_path` predefinido por tenant.

---

## Reglas derivadas que los agentes deben respetar

**⚠️ Críticas — hay tests que las verifican:**

1. **NUNCA generar queries sin resolución de tenant.** Toda query debe ejecutarse con el `search_path` correcto.
2. **NUNCA hardcodear nombres de schema** (`tenant_acme.insumos`). Usar siempre el nombre de tabla sin prefijo y confiar en el `search_path`.
3. **NUNCA escribir queries cross-schema** fuera de endpoints admin explícitamente autorizados.
4. **Las migraciones son agnósticas del tenant:** el script de aplicación se encarga de replicarlas.
5. **Test de aislamiento obligatorio** por servicio: un test que verifica que usuario del tenant A no puede leer datos del tenant B, incluso con malicia.
6. **Metadatos globales van en schema `public`:** lista de tenants, usuarios globales (si los hay), configuración general.
7. **IDs son UUIDs**, no secuenciales. Un `SERIAL` en tenant A y otro en tenant B tendrían los mismos valores, generando ambigüedad en logs globales.

---

## Aspectos operativos

### Crear un nuevo tenant

```bash
# scripts/tenant-create.sh acme "ACME Industrial SA"
TENANT_ID=$1
TENANT_NAME=$2

psql <<EOF
  CREATE SCHEMA tenant_${TENANT_ID};
  INSERT INTO public.tenants (id, nombre, active, created_at)
  VALUES ('${TENANT_ID}', '${TENANT_NAME}', true, now());
EOF

SCHEMA=tenant_${TENANT_ID} npx prisma migrate deploy
SCHEMA=tenant_${TENANT_ID} ./mvnw -pl services/produccion flyway:migrate
```

### Backup por tenant

```bash
pg_dump -n tenant_acme --data-only erp_db > backup-acme-$(date +%F).sql
```

### Restaurar un tenant

```bash
# En caso de restaurar un tenant específico sin afectar a otros
psql erp_db -c "TRUNCATE SCHEMA tenant_acme CASCADE;"
psql erp_db < backup-acme-2026-04-20.sql
```

### Desactivar un tenant

```sql
UPDATE public.tenants SET active = false WHERE id = 'acme';
-- El schema se mantiene, pero las migraciones y conexiones lo omiten.
```

---

## Referencias

- PostgreSQL schemas: https://www.postgresql.org/docs/15/ddl-schemas.html
- Patrón [Multi-Tenant Data Architecture](https://learn.microsoft.com/en-us/azure/architecture/guide/multitenant/considerations/data-partitioning) (MSDN).
- [ADR-001](ADR-001-microservicios-por-dominio.md) — los microservicios son compatibles con multi-tenancy por schema.
- [ADR-005](ADR-005-stock-calculado-desde-movimientos.md) — el stock se calcula por schema; cada tenant tiene su propia bodega.
- [Stack tecnológico](../stack.md) — PostgreSQL como base de datos principal.
- [Contrato A7](../../agents/A7-devops.md) — responsable de scripts de tenant y backups.

---

**Revisitar esta decisión si:**

- Algún tenant crece al punto de saturar la BD compartida.
- Aparece un requisito regulatorio de aislamiento físico (ej: datos de un país no pueden coexistir en la misma instancia con datos de otro).
- El número de tenants supera varios miles y la gestión de schemas se vuelve onerosa.
