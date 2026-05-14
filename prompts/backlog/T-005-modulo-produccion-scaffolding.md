# T-005 · Scaffolding del módulo producción dentro del monolito (NestJS)

**Ticket Jira:** https://tu-org.atlassian.net/browse/T-005
**Agente asignado:** A1 (Arquitecto NestJS)
**Supervisor humano:** S1 (con coordinación de S2 para invariantes de dominio)
**Sprint:** Semana 1 — Fundamentos
**Estimación:** 3 puntos
**Prioridad:** crítica
**Rama:** `feat/T-005-modulo-produccion-scaffolding`

---

## ⚠️ Nota sobre el cambio de naturaleza del ticket

> El backlog original (visible en `dashboard/erp_agentes_ia.html`) describía este ticket como **"Proyecto Spring Boot base con JPA, Flyway, actuator"** asignado al agente **A2**.
>
> Tras la decisión arquitectónica documentada en **ADR-010 (monolito modular)** y la **v2.0 del contrato de A2**, esa descripción quedó obsoleta:
>
> - No hay un servicio Spring Boot. El backend completo (incluido producción) vive en el **monolito NestJS** bajo responsabilidad de **A1**.
> - El agente A2 está en estado **EN ESPERA** hasta que se cumpla un criterio de extracción del módulo producción como microservicio (ver `docs/arquitectura-decision.md`).
>
> Este ticket se reinterpreta para **preparar el módulo producción dentro del monolito** con las cuatro garantías que después harán la extracción posible:
>
> 1. Bounded context claro (carpeta, módulo NestJS, public/internal separados).
> 2. Comunicación interna por `EventEmitter2` con **el mismo schema** que se usará luego en RabbitMQ.
> 3. Aislamiento de dependencias: ningún otro módulo accede a tablas o repositorios de producción directamente.
> 4. Espacios reservados (sin lógica todavía) para tarifas, recetas, OPs y motor de costos — los tickets T-026 a T-034 los rellenan.
>
> El dashboard se actualizará junto con el merge de este ticket. El supervisor S1 abre un PR aparte sobre `dashboard/erp_agentes_ia.html` con la nueva descripción y agente correcto.

---

## Contexto de negocio

El módulo de producción es **el más crítico del ERP**. Contiene el motor de costos que el cliente ya pidió validar contra ≥99% de los casos de su Excel histórico (fixture de 50+ casos). El motor en sí se construye en tickets posteriores (T-029, T-034), pero antes necesitamos un terreno donde ese motor pueda nacer con todas las garantías arquitectónicas correctas desde el día uno.

Si el scaffolding queda mal hecho — por ejemplo, si otros módulos empiezan a leer directamente tablas de producción, o si los eventos internos usan un formato distinto del que usaríamos en RabbitMQ — extraer este módulo como microservicio (cuando el negocio lo justifique) será mucho más costoso. Este ticket es un seguro contra esa deuda técnica.

Adicionalmente, este ticket cierra la transición de la decisión arquitectónica registrada en ADR-010 (de microservicios desde el día uno a monolito modular evolutivo). Hasta que exista, el repo tiene una incoherencia visible entre el contrato actual de A2 ("en espera") y el dashboard ("Spring Boot base"). Aterrizarlo aquí desactiva esa fricción para todos los siguientes tickets de producción.

---

## Alcance técnico

### Crear

Estructura dentro del monolito NestJS (`services/erp-api/`):

```
services/erp-api/src/modules/produccion/
├── produccion.module.ts                  ← módulo raíz del bounded context
├── README.md                              ← cómo se organiza el módulo
├── public/                                ← API pública que otros módulos pueden importar
│   ├── index.ts                           ← re-exports controlados
│   ├── produccion.facade.ts               ← fachada con métodos públicos (placeholder)
│   └── types.ts                           ← DTOs públicos del dominio
├── internal/                              ← código privado del módulo (no exportar)
│   ├── recetas/                           ← submódulo recetas (vacío con .gitkeep)
│   ├── variantes/                         ← submódulo variantes (vacío con .gitkeep)
│   ├── ordenes/                           ← submódulo OPs (vacío con .gitkeep)
│   ├── tarifas/                           ← submódulo tarifas (vacío con .gitkeep)
│   └── costos/                            ← submódulo motor de costos (vacío con .gitkeep)
├── events/
│   ├── index.ts                           ← exporta tipos de eventos
│   ├── produccion.events.ts               ← definición de eventos del dominio
│   └── produccion.events.spec.ts          ← test de schema (con zod) de eventos
└── __tests__/
    └── produccion.module.spec.ts          ← test de bootstrap del módulo
```

Y a nivel global del monolito:

```
services/erp-api/src/app.module.ts          ← agregar ProduccionModule
services/erp-api/src/modules/produccion/README.md
docs/architecture.md                         ← seccion "Módulos del monolito" actualizada
```

### Modificar

- `services/erp-api/src/app.module.ts`: registrar `ProduccionModule`.
- `docs/architecture.md`: marcar que el módulo producción existe con su bounded context y los submódulos pendientes.
- `dashboard/erp_agentes_ia.html`: actualizar T-005 (S1 lo hace en PR aparte si A1 no tiene permiso para tocar dashboard).

### No tocar

- **Otros módulos del monolito** (bodega, ventas, etc.). Si T-004 los creó como esqueleto, A1 no los modifica aquí.
- **`prisma/schema.prisma`**. Las tablas de producción (recetas, OPs, tarifas) se crean en tickets posteriores (T-026, T-027, T-028, T-030) cuando cada submódulo se implemente. Este ticket NO agrega modelos Prisma.
- **Migraciones**. No se crean migraciones en este ticket. Es deliberado: el scaffolding es 100% código TypeScript sin DDL.
- **Auth/RBAC**. Los guards globales se aplican en `main.ts` (T-004) y la matriz RBAC se configura en T-014. Este ticket no define permisos.
- **Frontends**. Cualquier UI de producción es de A4 (backoffice) y vive en otros tickets (T-031, T-032).

---

## Criterios de aceptación

### Estructura del módulo

- [ ] Existe `services/erp-api/src/modules/produccion/produccion.module.ts` con `@Module({ })` que registra los submódulos placeholder.
- [ ] El módulo se exporta y se importa una sola vez en `app.module.ts`.
- [ ] La estructura `public/` vs `internal/` está creada y documentada en el README del módulo.
- [ ] Cada submódulo (`recetas/`, `variantes/`, `ordenes/`, `tarifas/`, `costos/`) tiene un `.gitkeep` y un `README.md` que dice qué ticket lo poblará (T-026, T-027, T-028, T-030, T-029 respectivamente).
- [ ] El README del módulo describe el patrón "público vs interno" y prohíbe a otros módulos importar desde `internal/`.

### Encapsulamiento (bounded context)

- [ ] Existe `produccion.facade.ts` en `public/` con métodos placeholder (que lanzan `NotImplementedException`) para cada operación que otros módulos pueden invocar más adelante. Mínimo:
  - `obtenerCostoActualDeOP(opId: string): Promise<CostoBreakdown>` — placeholder.
  - `obtenerTarifaVigente(entidadTipo: string, entidadId: string, fecha: Date)` — placeholder.
- [ ] Existe `public/index.ts` que re-exporta **solo** la fachada y los tipos públicos. **Nada de `internal/`**.
- [ ] Existe un test (`produccion.module.spec.ts`) que verifica que `import { X } from '@/modules/produccion/internal/...'` falla con un linting rule explícito (ver siguiente criterio) o, si la rule no se puede aplicar todavía, deja documentado en el README qué patrones están prohibidos y por qué.

### Lint rule de encapsulamiento

- [ ] Se agrega regla de ESLint que prohíbe imports desde `**/internal/**` fuera del propio módulo (`no-restricted-imports` o `boundaries/element-types`).
- [ ] Hay un test que intenta importar desde `internal/` desde otro módulo (ej: bodega) y verifica que ESLint lo reporta como error.
- [ ] La regla está documentada en `services/erp-api/.eslintrc.js` con un comentario que apunta a este ticket.

### Eventos del dominio (con schema)

- [ ] Existe `events/produccion.events.ts` con la definición de los **3 eventos clave del dominio**, aún sin emisores (los tickets posteriores los emiten):
  - `produccion.op.creada.v1`
  - `produccion.op.cerrada.v1`
  - `produccion.tarifa.cambiada.v1`
- [ ] Cada evento usa el formato estándar de envelope+payload definido en `docs/events.md`:
  ```typescript
  {
    envelope: {
      eventId: string;     // uuid
      eventName: string;   // p.ej. "produccion.op.cerrada.v1"
      eventVersion: 1;
      tenantId: string;
      occurredAt: string;  // ISO 8601
      producedBy: 'monolith' | 'erp-produccion';  // hoy es monolith
    },
    payload: { /* específico por evento */ }
  }
  ```
- [ ] Cada payload está validado con un schema **zod** que se usa tanto en el publisher (cuando exista) como en el consumer.
- [ ] El test `produccion.events.spec.ts` verifica que un payload válido pasa el schema y que payloads malformados (campos faltantes, tipos incorrectos) son rechazados.
- [ ] Comentario explícito al inicio del archivo: "estos eventos se emiten internamente con EventEmitter2 hoy y se publicarán en RabbitMQ cuando el módulo se extraiga; el schema es idéntico, solo cambia el transporte". Referencia a `docs/events.md` y `docs/roadmap-microservicios.md`.

### Tests

- [ ] El test `produccion.module.spec.ts` arranca el módulo en un contexto NestJS de testing (`Test.createTestingModule`) y verifica que:
  - El módulo se carga sin errores.
  - `ProduccionFacade` está disponible para inyección.
  - Los métodos placeholder lanzan `NotImplementedException` (no `Error` genérico).
- [ ] El test de eventos cubre los 3 schemas zod (casos válidos e inválidos).
- [ ] La cobertura del módulo en este punto es **100%** (porque solo hay esqueleto). Esto sirve como baseline.

### Documentación

- [ ] `services/erp-api/src/modules/produccion/README.md` incluye:
  - Propósito del módulo y bounded context.
  - Diagrama de carpetas (`public/` vs `internal/`).
  - Tabla de submódulos con el ticket que los implementa.
  - Tabla de eventos emitidos (con link a `docs/events.md`).
  - Tabla de eventos consumidos (vacía por ahora, se rellenará).
  - Regla de oro: "ningún otro módulo importa de `internal/`. Si necesitas algo de producción, hay tres opciones: agregarlo a la fachada pública, suscribirte a un evento, o pedir al supervisor S1 que coordine con S2".
- [ ] `docs/architecture.md` actualizado con la sección "Módulos del monolito" listando los 5 módulos del MVP (auth, bodega, ventas, producción, notificaciones) y su estado actual.

### Verificación del bounded context

- [ ] Existe un test en `services/erp-api/test/architecture.spec.ts` que recorre el código fuente y verifica que **ningún archivo fuera de `modules/produccion/`** importa nada que no venga de `modules/produccion/public/`. Si encuentra una violación, falla con mensaje claro indicando el archivo infractor.

---

## Invariantes que el agente DEBE respetar

1. **Encapsulamiento por carpeta `internal/`**: nada en otros módulos importa desde `internal/`. Esta es la garantía estructural que hace posible una extracción futura barata.
2. **Schema de eventos idéntico al de RabbitMQ futuro**: el formato envelope+payload, los nombres con `.v1`, y los campos del envelope son los que `docs/events.md` define. Si A1 propone un formato distinto, debe parar y coordinar con TL antes.
3. **No hay lógica de negocio en este ticket**. Si el agente empieza a implementar el cálculo de costos, validación de recetas o tarifas, se salió del scope. El scaffolding precede a la lógica.
4. **No se crean modelos Prisma en este ticket**. Los modelos de producción nacen junto con cada submódulo (T-026 a T-030), no aquí.
5. **NotImplementedException, no `throw new Error()`**: NestJS provee `NotImplementedException` para placeholders. Es un 501 limpio si alguien llega a invocar la fachada por error.

---

## Casos de prueba obligatorios

### Caso 1 — El módulo arranca sin errores

```typescript
// services/erp-api/src/modules/produccion/__tests__/produccion.module.spec.ts
const moduleRef = await Test.createTestingModule({
  imports: [ProduccionModule],
}).compile();

const facade = moduleRef.get(ProduccionFacade);
expect(facade).toBeDefined();
```

### Caso 2 — Los métodos placeholder responden con NotImplementedException

```typescript
const facade = moduleRef.get(ProduccionFacade);
await expect(facade.obtenerCostoActualDeOP('op-123'))
  .rejects.toThrow(NotImplementedException);
```

### Caso 3 — Schema de evento rechaza payload inválido

```typescript
const invalidPayload = {
  envelope: { eventId: 'not-a-uuid' /* faltan campos */ },
  payload: {},
};

expect(() => OpCerradaSchema.parse(invalidPayload)).toThrow();
```

### Caso 4 — Schema acepta payload válido

```typescript
const validPayload = {
  envelope: {
    eventId: uuid(),
    eventName: 'produccion.op.cerrada.v1',
    eventVersion: 1,
    tenantId: 'tenant_erp',
    occurredAt: new Date().toISOString(),
    producedBy: 'monolith',
  },
  payload: { opId: 'op-1', cerradaPor: 'user-1', costoTotal: '1250.00' },
};

expect(OpCerradaSchema.parse(validPayload)).toEqual(validPayload);
```

### Caso 5 — Lint rule bloquea import inválido

```bash
# Crear archivo de prueba que viole la regla (en otro módulo)
cat > services/erp-api/src/modules/bodega/test-violation.ts <<'EOF'
import { CostoCalculator } from '../produccion/internal/costos/costo.calculator';
EOF

cd services/erp-api && npm run lint -- src/modules/bodega/test-violation.ts
# Esperado: ERROR — "no-restricted-imports: '../produccion/internal/...' is forbidden"

# Limpiar
rm services/erp-api/src/modules/bodega/test-violation.ts
```

### Caso 6 — Test de arquitectura detecta violaciones reales

```bash
# Crear violación deliberada
echo "import x from '@/modules/produccion/internal/recetas';" >> \
  services/erp-api/src/modules/bodega/bodega.module.ts

npm run test -- architecture.spec.ts
# Esperado: FAIL — "bodega/bodega.module.ts imports from produccion/internal which is forbidden"

# Limpiar
git checkout services/erp-api/src/modules/bodega/bodega.module.ts
```

### Caso 7 — Producción consume Prisma como cualquier otro módulo

```typescript
// Verificar que ProduccionModule puede inyectar PrismaService (creado en T-004)
const moduleRef = await Test.createTestingModule({
  imports: [PrismaModule, ProduccionModule],
}).compile();

const facade = moduleRef.get(ProduccionFacade);
expect(facade).toBeDefined();
// Sin errores de DI.
```

---

## Lo que NO se debe hacer en esta tarea

- **No implementar el motor de costos**, ni siquiera una versión simplificada. Es T-029, validado contra el Excel del cliente en T-034.
- **No crear modelos Prisma** de `Tarifa`, `Receta`, `OrdenProduccion`, `Variante`, ni ningún otro. Los crean los tickets de cada submódulo.
- **No migrar Spring Boot**: no hay Spring Boot que migrar. Si encuentras código Java/Maven referenciado en cualquier parte del repo, eso es un artefacto del ADR-001 original (microservicios). Repórtalo al TL pero no lo borres en este ticket.
- **No agregar dependencias nuevas** salvo `zod` (que ya viene de T-004) y eventualmente `eslint-plugin-boundaries` si la rule de no-restricted-imports nativa no alcanza. Cualquier otra librería requiere ADR.
- **No tocar otros módulos** salvo `app.module.ts` para registrar `ProduccionModule`.
- **No emitir eventos reales todavía**. La emisión empieza cuando exista lógica de dominio (T-026+).
- **No definir endpoints HTTP**. La fachada es una clase TypeScript, no un controller. Los endpoints nacen con cada submódulo.

---

## Contratos y referencias

- **Contrato del agente:** [`agents/A1-nestjs.md`](../../agents/A1-nestjs.md) (sección "Dominio propio" incluye `modules/produccion/`)
- **Contrato A2 (estado actual):** [`agents/A2-springboot.md`](../../agents/A2-springboot.md) (en espera, ver v2.0)
- **ADRs relevantes:**
  - [ADR-001 Microservicios por dominio](../../docs/adrs/ADR-001-microservicios-por-dominio.md) (supersedido por ADR-010, leer para entender historial)
  - [ADR-010 Monolito modular](../../docs/adrs/ADR-010-monolito-modular.md) (decisión vigente)
  - [ADR-007 Tarifas temporales](../../docs/adrs/ADR-007-tarifas-temporales.md) (invariante futura del módulo)
- **Events catalog:** [`docs/events.md`](../../docs/events.md) (formato envelope+payload)
- **Roadmap microservicios:** [`docs/roadmap-microservicios.md`](../../docs/roadmap-microservicios.md) (qué cambia al extraer)
- **Arquitectura general:** [`docs/architecture.md`](../../docs/architecture.md)
- **Glosario:** [`docs/glossary.md`](../../docs/glossary.md) (O/P, tarifa, h/h, costo total)

---

## Entregables

- [ ] Estructura de carpetas del módulo `produccion/` creada según el alcance técnico.
- [ ] `produccion.module.ts` y `produccion.facade.ts` implementados con placeholders.
- [ ] `events/produccion.events.ts` con los 3 eventos y schemas zod.
- [ ] Tests unitarios: `produccion.module.spec.ts` y `produccion.events.spec.ts`.
- [ ] Test de arquitectura en `services/erp-api/test/architecture.spec.ts`.
- [ ] ESLint rule de no-restricted-imports configurada.
- [ ] `services/erp-api/src/modules/produccion/README.md` completo.
- [ ] `docs/architecture.md` actualizado con la tabla de módulos.
- [ ] `app.module.ts` modificado para registrar `ProduccionModule`.
- [ ] Commit: `feat(produccion): scaffolding del módulo dentro del monolito [A1]`
- [ ] PR con labels: `agent:A1`, `supervisor:S1`, `sprint:semana-1`, `priority:critical`, `type:feature`

### Side-quest del supervisor S1 (PR separado)

- [ ] Actualizar `dashboard/erp_agentes_ia.html` para que T-005 muestre:
  - Agente: A1 (no A2)
  - Título: "Scaffolding del módulo producción dentro del monolito"
  - Tag: `produccion`, `scaffolding`, `nestjs`
- [ ] Este PR es trivial y lo abre S1 directamente (no es trabajo de A1, porque `dashboard/` está fuera del dominio A1).

---

## Cómo invocar al agente en Claude Code

```bash
cd erp-project
git checkout -b feat/T-005-modulo-produccion-scaffolding
claude
```

Prompt:

```
Ejecuta T-005 (scaffolding del módulo producción dentro del monolito).

Actúas como agente A1. Lee en orden:
1. @CLAUDE.md
2. @agents/A1-nestjs.md (sección "Dominio propio" incluye produccion/)
3. @prompts/backlog/T-005-modulo-produccion-scaffolding.md (este ticket)
4. @docs/adrs/ADR-010-monolito-modular.md (decisión arquitectónica vigente)
5. @docs/adrs/ADR-001-microservicios-por-dominio.md (contexto histórico)
6. @docs/events.md (formato envelope+payload de eventos)
7. @docs/roadmap-microservicios.md (qué cambia al extraer)
8. @agents/A2-springboot.md (estado "en espera" — para entender por qué A1 toma esto)

⚠️ Importante:
- NO implementes lógica de negocio (motor de costos, validación de recetas, etc.).
  Es solo scaffolding. Si dudas si algo es scaffolding o lógica, pregunta.
- NO crees modelos Prisma. Cero migraciones en este ticket.
- NO toques otros módulos salvo agregar la línea de import en app.module.ts.
- El bounded context se garantiza con ESLint rule + carpeta internal/ + test de arquitectura.

Antes de empezar, confirma:
1. ¿T-004 está completado? (necesitas PrismaModule, app.module.ts, y la configuración ESLint base)
2. ¿Hay alguna preferencia entre eslint-plugin-boundaries y no-restricted-imports nativo? (yo recomiendo lo nativo si alcanza)
```

---

## Validación post-ejecución (lo llena S1)

```bash
cd services/erp-api

# 1. Pre-check automático
./scripts/pre-pr-check.sh

# 2. Estructura del módulo
tree src/modules/produccion
# Verificar que existen: public/, internal/, events/, __tests__/

# 3. Compilación
npm run build
# Sin errores

# 4. Lint (incluida la nueva rule)
npm run lint
# Sin errores

# 5. Tests
npm test -- produccion
# Todos verdes

# 6. Test de arquitectura
npm test -- architecture
# Verde

# 7. Smoke test: intentar import desde otro módulo
cat > /tmp/smoke-violation.ts <<'EOF'
import { CostoCalculator } from 'src/modules/produccion/internal/costos/costo.calculator';
EOF
# La rule de ESLint debe reportar el error

# 8. Arrancar el servicio
npm run start:dev
# Verificar que ProduccionModule aparece en los logs de NestJS al cargar
```

- **Fecha de ejecución:** _pendiente_
- **Iteraciones necesarias:** _pendiente_
- **Cobertura del módulo:** _pendiente (objetivo 100% por ser scaffolding)_
- **ESLint rule probada con violación deliberada:** _pendiente_
- **Test de arquitectura pasa:** _pendiente_
- **Resultado:** _pendiente_
- **Notas para futuros tickets de producción (T-026+):** _pendiente_

---

## Notas para los supervisores S1 y S2

**Antes de aprobar el merge:**

- **S1** revisa la implementación técnica (estructura, fachada, eventos, lint rule).
- **S2** revisa que el contrato del bounded context refleje correctamente el dominio de producción del cliente (nombres de eventos, separación de submódulos). S2 no toca código pero su firma es necesaria porque las decisiones de aquí afectan al motor de costos que viene en T-029.

**Si surgen dudas durante el ticket:**

- Pregunta de eventos / dominio → S2 + PO.
- Pregunta de patrón NestJS → S1.
- Pregunta de ESLint/lint rule → DO (DevOps tiene experiencia con tooling).

**Prerrequisitos confirmados:**

- T-001 (bootstrap del repo) ✅
- T-002 (docker-compose local con PostgreSQL) ✅
- T-003 (pipelines CI/CD) ✅
- T-004 (NestJS base + Prisma init) ✅

---

**Creado:** 2026-04-28 por TL + S1 + S2 (revisión conjunta por el cambio de naturaleza del ticket)
**Plantilla base:** `prompts/templates/ticket-template.md` v1.0
**Supersede:** descripción anterior del dashboard ("Proyecto Spring Boot base")
