# ADR-008: Validación contra Excel como guardrail de CI

- **Status:** accepted
- **Date:** 2026-04-17
- **Deciders:** TL, PO, S2, QA
- **Tags:** calidad, testing, dominio, ci-cd

---

## Contexto

El cliente opera hoy con un ecosistema de Excel donde viven las fórmulas críticas del negocio: cálculo de costos de producción, precios a clientes, proyecciones, consolidados mensuales. Lo que estos Excel producen es **la verdad operativa** — es lo que el cliente factura, lo que reporta a su contador, lo que discute con sus propios clientes.

Migrar estas fórmulas al nuevo ERP tiene un riesgo enorme: si el sistema calcula aunque sea **$10 distintos** para una O/P que históricamente costó $4.427.510, el cliente pierde confianza en todo el proyecto. Y una vez perdida, no se recupera.

El problema no es escribir código correcto la primera vez. El problema es **detectar regresiones** a lo largo de 6 meses de desarrollo, con varios agentes IA generando código, en un dominio donde los errores son sutiles (redondeo, orden de operaciones, precisión decimal, tarifas temporales) y las consecuencias son monetarias.

Necesitamos un mecanismo que:

1. Capture la verdad actual del cliente antes de que migremos.
2. Verifique continuamente que el nuevo sistema coincide con esa verdad.
3. Bloquee automáticamente cualquier cambio que rompa esa verdad.

---

## Decisión

Implementaremos un **guardrail de CI basado en un fixture de casos reales extraídos de los Excel del cliente**. El fixture se llama `tests/fixtures/excel-costos.json`, contiene mínimo 50 casos representativos, y es ejecutado automáticamente en cada PR que toca código de costos.

### Criterios de aprobación/rechazo

- **Tolerancia por caso:** diferencia de hasta $0.01 por cálculo individual.
- **Umbral global:** al menos 49 de los 50 casos deben coincidir dentro de la tolerancia.
- **Bloqueo automático:** si el umbral no se cumple, el PR **no puede mergearse**, no importa qué tan aprobado esté por los supervisores.
- **No hay override:** ni el Tech Lead puede saltarse este check sin un ADR nuevo que lo modifique.

### Estructura del fixture

```json
{
  "version": "1.0",
  "fuente": "costos_op.xlsx del cliente, snapshot 2026-04-10",
  "extractado_por": "A5",
  "validado_por": "PO",
  "aprobado_en_kickoff": "2026-04-15",
  "casos": [
    {
      "id": "caso-001",
      "descripcion": "OP típica de estante metálico, cliente regular",
      "inputs": {
        "orden_id": "OP-2025-0234",
        "producto": "Estante metálico industrial 2x1m",
        "cantidad": 50,
        "receta_version": 3,
        "fecha_cierre": "2025-09-15T14:30:00Z",
        "insumos_consumidos": [...],
        "tiempo_maquinas": [...],
        "tiempo_horas_hombre": [...]
      },
      "resultado_esperado": {
        "costo_insumos": 3120000.00,
        "costo_maquina": 890000.00,
        "costo_horas_hombre": 417500.00,
        "costo_total": 4427500.00
      },
      "tarifas_vigentes": {
        "maquina_sold_02": 780.00,
        "trabajador_soldador_senior": 220.00
      }
    },
    { ... 49 casos más ... }
  ]
}
```

### Test parametrizado

En `services/produccion/src/test/.../ExcelFixtureValidationTest.java`:

```java
@ParameterizedTest(name = "Caso {0}: {1}")
@MethodSource("cargarCasosExcel")
void calculoDebeCoincidirConExcel(String casoId, String descripcion,
                                    CasoExcel caso) {
    CostoBreakdown resultado = costoCalculator.calcular(caso.getInputs());

    assertEquals(caso.getResultadoEsperado().getCostoTotal(),
                  resultado.getCostoTotal(),
                  new `BigDecimal` (originalmente; hoy `Decimal.js` — ver ADR-010)("0.01"),
                  "Costo total difiere más de $0.01");
}

@Test
void alMenosCuarentaYNueveDeCincuentaCasosDebenCoincidir() {
    List<CasoExcel> casos = cargarFixture();
    int coincidencias = 0;

    for (CasoExcel caso : casos) {
        if (comparar(caso, tolerancia).esIgual()) coincidencias++;
    }

    assertThat(coincidencias)
        .as("Al menos 49/50 casos deben coincidir con Excel")
        .isGreaterThanOrEqualTo(49);
}
```

### Pipeline de CI

En `.github/workflows/produccion-ci.yml`:

```yaml
- name: Validar contra fixture Excel
  run: ./mvnw test -Dtest=ExcelFixtureValidationTest
  # Si este job falla, el PR no puede mergearse (branch protection)
```

### Modificación del fixture

El fixture **solo se modifica** bajo estas condiciones:

1. El cliente confirma formalmente un cambio en sus fórmulas.
2. PR que modifica el fixture incluye justificación y evidencia (Excel nuevo, memo del cliente).
3. Aprobación obligatoria de: PO + A5 + Tech Lead + supervisor técnico (S2 si aplica).
4. El PR al fixture es tratado como un cambio contractual — se notifica al cliente antes del merge.

---

## Alternativas consideradas

### A) Tests sintéticos escritos por el equipo

Tests unitarios típicos con casos inventados por el equipo.

**Pros:**
- Rápidos de escribir.
- Fácil cobertura de casos borde.

**Cons:**
- **No capturan la realidad del cliente.** El equipo no conoce todos los casos raros que la empresa vivió en 8 años.
- Si el equipo entiende mal una fórmula, escribe el test equivocado y no detecta el problema.
- No genera confianza para el cliente — son "tests nuestros", no "tests contra su verdad".
- **Descartada como única validación.** Se mantienen como complemento.

### B) Validación manual al final de cada sprint

El PO revisa manualmente una muestra de cálculos al final del sprint y reporta diferencias.

**Pros:**
- Involucra al cliente en la validación.
- No requiere automatización.

**Cons:**
- Lento para detectar regresiones.
- Un bug introducido en sprint 2 puede pasar hasta sprint 5 sin detectar.
- Depende de la disponibilidad del PO.
- No escala si hay múltiples módulos con cálculos.
- **Descartada como único mecanismo.** Se mantiene como validación adicional en demos.

### C) Comparación paralela en producción (shadow mode)

El nuevo ERP corre en paralelo al Excel durante meses, comparando resultados.

**Pros:**
- Validación con tráfico real.
- Máxima cobertura.

**Cons:**
- Solo detecta problemas después de go-live.
- Requiere doble carga de trabajo en el cliente.
- No previene regresiones durante desarrollo.
- Útil para post-launch pero no para desarrollo.
- **Se adopta complementariamente** después del go-live, no durante.

### D) Fixture de casos reales + test parametrizado bloqueante **(elegida)**

Extraer 50+ casos reales del Excel, convertirlos a JSON fixture, ejecutarlos en cada PR.

**Pros:**
- Detecta regresiones en minutos, no en semanas.
- Captura la verdad real del cliente.
- Genera confianza contractual: "el sistema produce los mismos resultados que sus Excel en estos 50 casos".
- Automatizado, no depende de disponibilidad humana.
- Escalable a otros dominios (no solo costos; también precios, proyecciones).
- Versionado en Git, auditable.

**Cons:**
- Requiere trabajo inicial del agente A5 para extraer los casos.
- El fixture puede quedar desactualizado si el cliente cambia fórmulas (mitigado con el proceso de modificación descrito).
- Sólo valida los 50 casos extraídos, no casos que no están en el fixture.

---

## Consecuencias

### Positivas

- **Confianza contractual con el cliente.** El cliente puede ver el fixture, validar los casos, y saber que el sistema los respeta.
- **Regresiones imposibles de ignorar.** Un commit que rompe el cálculo **no puede mergearse**. No hay debate, no hay "lo arreglamos después".
- **Onboarding de nuevos agentes/supervisores más fácil.** El fixture es la especificación ejecutable del dominio.
- **Herramienta de pruebas contra bugs históricos.** Si el cliente reporta "este cálculo está mal", añadir el caso al fixture asegura que no se repita.
- **Base para otros guardrails.** Este patrón se replicará para precios (ventas) y proyecciones (analytics) más adelante.

### Negativas aceptadas

- **Inversión inicial significativa** del agente A5 en extraer y formalizar los 50 casos (ticket T-030 en sprint 2).
- **Ralentización marginal del CI** (~30 segundos extra por cada corrida).
- **Rigidez ante cambios legítimos** del cliente en sus fórmulas. Mitigación: proceso formal de modificación.
- **Dependencia crítica de la calidad del fixture.** Un fixture con errores pasa errores al sistema. Mitigación: validación del fixture por el PO + cliente antes del kickoff formal.

---

## Reglas derivadas que los agentes deben respetar

**⚠️ Críticas — hay tests que las verifican:**

1. **A6 (QA) mantiene el test parametrizado.** Si el test está roto o deshabilitado, el CI global falla.
2. **A5 extrae y mantiene el fixture.** Cualquier modificación del fixture requiere PR con aprobación del PO.
3. **A2 implementa el cálculo para pasar el fixture.** Si no pasa, es problema del código, no del fixture.
4. **Nadie deshabilita este test.** Ni con `@Disabled`, ni con `@Ignore`, ni comentando. El CI tiene un guard adicional que detecta si el test fue modificado para saltarse casos.
5. **Tolerancia de $0.01 es el techo.** No se aumenta sin ADR. Si se necesita tolerancia mayor para algún caso específico, se analiza por qué (posible bug de redondeo) antes de ajustar.
6. **El umbral de 49/50 es el piso.** No se baja sin ADR. Si un caso no se puede resolver, se documenta como issue conocida, pero no se baja el umbral.

---

## Extensión a otros dominios

Este patrón se replicará en:

- **Ventas** (sprint 3): fixture de precios calculados para clientes con condiciones comerciales mixtas.
- **Analytics** (post-MVP): fixture de consolidados mensuales históricos que deben coincidir con los reportes históricos del cliente.
- **Nóminas** (módulo 2): fixture de cálculo de horas-hombre pagadas al personal.

Cada extensión requerirá un ADR específico o un sub-documento de este.

---

## Referencias

- Libro _Working Effectively with Legacy Code_ (Michael Feathers) — patrón de "characterization tests" que inspira este enfoque.
- [ADR-005](ADR-005-stock-calculado-desde-movimientos.md) — depende de este ADR para que el cálculo histórico sea reproducible.
- [ADR-007](ADR-007-tarifas-temporales.md) — depende de este ADR para que las tarifas vigentes sean las correctas al momento del cierre.
- [Contrato A6](../../agents/A6-qa.md) — responsable de mantener el test parametrizado.
- [Contrato A5](../../agents/A5-etl.md) — responsable de extraer y mantener el fixture.
- Tickets T-030 (extracción de fixture) y T-031 (implementación del test).

---

**Revisitar esta decisión si:**

- El fixture crece a un tamaño donde ejecutarlo ralentiza el CI más de 2 minutos.
- El cliente cambia su modelo de negocio de forma que los 50 casos dejan de ser representativos.
- Se detecta una clase de bug que el fixture no captura (expandir, no reemplazar el enfoque).
