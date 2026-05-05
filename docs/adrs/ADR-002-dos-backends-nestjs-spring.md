# ADR-002: Dos backends: NestJS + Spring Boot
> 🚫 **Supersedado por [ADR-010](ADR-010-monolito-modular.md)** (Abril 2026).
>
> Esta decisión de tener dos backends (NestJS + Spring Boot) fue revertida. Hoy todo el backend es un monolito NestJS único. El módulo de producción usa `Decimal.js` para los cálculos monetarios críticos en lugar de `BigDecimal` de Java. Se mantendrá la opción de usar Python (no Java) si el módulo de producción se extrae como microservicio en el futuro.


- **Status:** accepted
- **Date:** 2026-04-15
- **Deciders:** TL, S1, S2
- **Tags:** stack, backend, arquitectura

---

## Contexto

La decisión natural para un equipo pequeño es usar un solo stack de backend en todo el proyecto. Reduce la curva de aprendizaje, simplifica la infraestructura y permite que cualquier persona del equipo trabaje en cualquier servicio.

Sin embargo, los dominios de este ERP tienen características técnicas muy distintas:

- **Bodega, ventas, auth, notificaciones** son dominios con muchos endpoints CRUD, validaciones, flujos de eventos y comunicación entre servicios. Son "transaccionalmente simples" pero numerosos.

- **Producción** es el corazón del negocio: cálculo monetario con BigDecimal preciso, reglas de dominio densas (recetas con variantes, cálculo de costos con vigencia temporal, órdenes con fases paralelas), transacciones complejas que mezclan múltiples agregados. Un error aquí tiene impacto económico directo.

El cliente tiene ingenieros actualmente en Java (por Oracle ERP) y quiere poder contratar perfiles de su ecosistema regional donde Java es abundante. Al mismo tiempo, el equipo humano del proyecto tiene experiencia mixta y los perfiles de Node.js son más fáciles de encontrar para la capa de portal.

Hay que decidir si aceptar dos stacks es mejor que forzar uno solo.

---

## Decisión

El backend del ERP usa **dos frameworks** según el dominio:

- **NestJS (Node.js 20 LTS)** para servicios con lógica CRUD + eventos: `core`, `bodega`, `ventas`, `notificaciones`.
- **Spring Boot 3 (Java 21 LTS)** exclusivamente para el servicio `produccion` donde vive el motor de costos y la lógica monetaria crítica.

Los servicios se comunican entre sí por HTTP (REST) y por eventos (RabbitMQ). Nunca comparten base de datos ni código.

---

## Alternativas consideradas

### A) Todo NestJS

Un solo stack, equipo más flexible, menor complejidad operativa.

**Pros:**
- Curva de aprendizaje única.
- Docker images, CI/CD y observabilidad más simples.
- Un solo gestor de dependencias (npm).
- Mezclar servicios más fácil si hace falta refactoring.

**Cons:**
- TypeScript y JavaScript tienen limitaciones conocidas con aritmética decimal. `Decimal.js` o librerías equivalentes funcionan pero son verbosas y proclives a errores silenciosos.
- JPA + Testcontainers para tests de integración monetaria es superior a cualquier equivalente en Node.js.
- El cliente no puede absorber el código de producción a futuro con sus ingenieros Java actuales.
- Contratar perfiles senior Node.js para dominio monetario es más difícil que contratar seniors Java con experiencia ERP.

### B) Todo Spring Boot

Un solo stack Java, alineado con Oracle ERP existente del cliente.

**Pros:**
- Cliente puede absorber todo el código a futuro.
- Ecosistema Java maduro para ERPs.
- Precisión monetaria de primera clase con BigDecimal.

**Cons:**
- Spring Boot es significativamente más lento para escribir CRUD simple que NestJS.
- El portal público en Next.js se alinea mejor con backends Node.js por tipos compartidos y DX del equipo frontend.
- La mayoría de los agentes IA (Copilot, Claude Code) han sido más probados en TypeScript para backend moderno.
- Velocidad del MVP se vería afectada. Un módulo CRUD en NestJS con Prisma toma la mitad de tiempo que el equivalente en Spring Boot.

### C) Dos backends, uno por dominio **(elegida)**

NestJS para dominios ágiles, Spring Boot para producción.

**Pros:**
- Cada herramienta aplicada a su punto fuerte.
- El dominio monetario más crítico usa el stack más confiable para cálculos.
- El resto del sistema avanza rápido con NestJS.
- Alineado con la división en microservicios (ADR-001) — cada servicio puede elegir su stack.
- Cliente puede eventualmente absorber producción, la parte más crítica, con sus ingenieros Java.

**Cons:**
- Dos curvas de aprendizaje para el equipo humano.
- Dos pipelines de CI (Node.js y Maven).
- Dos conjuntos de imágenes Docker base.
- Supervisores humanos deben entender ambos mundos.

---

## Consecuencias

### Positivas

- El motor de costos (`CostoCalculator`) se implementa con BigDecimal nativo, Testcontainers para validación contra Excel, y el ecosistema de testing Java maduro.
- La velocidad de desarrollo en bodega, ventas y auth no se sacrifica por los requisitos de producción.
- Dos agentes IA especializados (A1 NestJS, A2 Spring Boot) en lugar de un agente generalista — cada uno con mejor contexto y menor tasa de alucinación.
- Posibilidad futura de que el cliente migre los módulos Oracle ERP existentes al stack Spring Boot sin cambio de lenguaje.

### Negativas aceptadas

- **DevOps más complejo.** Dos Dockerfiles base, dos tipos de pipeline CI/CD. Mitigación: A7 (agente DevOps) encapsula la complejidad en Helm charts templatizados.
- **Dos supervisores humanos especializados** (S1 para backend NestJS, S2 para Spring Boot). Sin rotación cruzada a ciegas.
- **Dos pools de dependencias que actualizar.** Mitigación: Dependabot configurado para ambos.
- **Contratos entre servicios más importantes que nunca.** Mitigación: OpenAPI + Pact tests obligatorios.

---

## Reglas derivadas que los agentes deben respetar

1. **A1 (NestJS) nunca toca código Java.** Si una tarea requiere cambios en `services/produccion/`, el supervisor reasigna al A2.
2. **A2 (Spring Boot) nunca toca código TypeScript.** Simétrico.
3. **La comunicación entre servicios es siempre HTTP o evento.** Nunca llamadas directas a BD de otro servicio, nunca librerías compartidas de lógica de negocio.
4. **Los contratos entre servicios viven en `docs/api/`** como OpenAPI versionado. Cualquier cambio en el contrato es un PR revisado por ambos supervisores (S1 y S2).
5. **Los eventos entre servicios viven en `docs/events.md`** con esquemas JSON versionados (`v1`, `v2`).

---

## Criterios para revisitar esta decisión

- **Si el cliente cambia de estrategia** y quiere consolidar en un solo stack: re-evaluar. Probablemente migrando lo no-monetario a Spring Boot, no al revés.
- **Si el equipo no logra hacer productivos a ambos stacks** después del sprint 2: consolidar temporalmente hasta tener más personas.
- **Si aparece una tecnología nueva** que cubra bien ambos dominios (improbable a corto plazo).

---

## Referencias

- [ADR-001](ADR-001-microservicios-por-dominio.md) — base arquitectónica de microservicios que habilita esta decisión.
- [Stack tecnológico](../stack.md) — detalles técnicos de cada stack.
- [Contrato A1](../../agents/A1-nestjs.md) — agente NestJS.
- `agents/A2-springboot.md` — agente Spring Boot (pendiente).
- `docs/api/` — contratos OpenAPI entre servicios.
