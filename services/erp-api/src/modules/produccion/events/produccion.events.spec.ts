import {
  EnvelopeSchema,
  OpCreadaSchema,
  OpCerradaSchema,
  TarifaCambiadaSchema,
} from './produccion.events';

const BASE_ENVELOPE = {
  eventId:    '550e8400-e29b-41d4-a716-446655440000',
  occurredAt: '2026-04-22T14:30:12.453Z',
  producedBy: 'monolith@2026.04.22-a1b2c3d',
  tenantId:   'tenant_erp',
};

describe('EnvelopeSchema', () => {
  it('acepta envelope válido con todos los campos opcionales', () => {
    const valid = {
      ...BASE_ENVELOPE,
      eventType:     'produccion.op.creada.v1',
      correlationId: 'req-abc123',
      causationId:   'cmd-xyz789',
    };
    expect(() => EnvelopeSchema.parse(valid)).not.toThrow();
  });

  it('acepta envelope válido sin campos opcionales', () => {
    const valid = { ...BASE_ENVELOPE, eventType: 'produccion.op.creada.v1' };
    expect(() => EnvelopeSchema.parse(valid)).not.toThrow();
  });

  it('rechaza eventId que no es UUID', () => {
    const invalid = { ...BASE_ENVELOPE, eventId: 'not-a-uuid', eventType: 'test' };
    expect(() => EnvelopeSchema.parse(invalid)).toThrow();
  });

  it('rechaza occurredAt con formato de fecha inválido', () => {
    const invalid = { ...BASE_ENVELOPE, eventType: 'test', occurredAt: '22-04-2026' };
    expect(() => EnvelopeSchema.parse(invalid)).toThrow();
  });

  it('rechaza envelope sin campos obligatorios', () => {
    expect(() => EnvelopeSchema.parse({})).toThrow();
    expect(() => EnvelopeSchema.parse({ eventId: '550e8400-e29b-41d4-a716-446655440000' })).toThrow();
  });
});

// ─── OpCreadaSchema ────────────────────────────────────────────────────────

const VALID_OP_CREADA_PAYLOAD = {
  opId:         '3f2504e0-4f89-11d3-9a0c-0305e82c3301',
  ordenVentaId: 'b1c2d3e4-f5a6-4789-9abc-def012345678',
  productoId:   'c2d3e4f5-a6b7-4890-9bcd-ef0123456789',
  cantidad:     10,
  creadaPor:    'a1b2c3d4-e5f6-7890-abcd-ef0123456789',
};

const VALID_OP_CREADA_ENVELOPE = {
  ...BASE_ENVELOPE,
  eventType: 'produccion.op.creada.v1',
};

describe('OpCreadaSchema', () => {
  it('acepta evento válido', () => {
    const valid = { envelope: VALID_OP_CREADA_ENVELOPE, payload: VALID_OP_CREADA_PAYLOAD };
    expect(OpCreadaSchema.parse(valid)).toEqual(valid);
  });

  it('acepta ordenVentaId null (O/P creada sin O/V previa)', () => {
    const valid = {
      envelope: VALID_OP_CREADA_ENVELOPE,
      payload: { ...VALID_OP_CREADA_PAYLOAD, ordenVentaId: null },
    };
    expect(() => OpCreadaSchema.parse(valid)).not.toThrow();
  });

  it('rechaza cuando ordenVentaId tiene formato inválido (no UUID ni null)', () => {
    const invalid = {
      envelope: VALID_OP_CREADA_ENVELOPE,
      payload: { ...VALID_OP_CREADA_PAYLOAD, ordenVentaId: 'not-a-uuid' },
    };
    expect(() => OpCreadaSchema.parse(invalid)).toThrow();
  });

  it('rechaza cantidad cero', () => {
    const invalid = {
      envelope: VALID_OP_CREADA_ENVELOPE,
      payload: { ...VALID_OP_CREADA_PAYLOAD, cantidad: 0 },
    };
    expect(() => OpCreadaSchema.parse(invalid)).toThrow();
  });

  it('rechaza cantidad negativa', () => {
    const invalid = {
      envelope: VALID_OP_CREADA_ENVELOPE,
      payload: { ...VALID_OP_CREADA_PAYLOAD, cantidad: -5 },
    };
    expect(() => OpCreadaSchema.parse(invalid)).toThrow();
  });

  it('rechaza envelope con eventType incorrecto', () => {
    const invalid = {
      envelope: { ...BASE_ENVELOPE, eventType: 'produccion.op.cerrada.v1' },
      payload: VALID_OP_CREADA_PAYLOAD,
    };
    expect(() => OpCreadaSchema.parse(invalid)).toThrow();
  });

  it('rechaza payload vacío', () => {
    expect(() => OpCreadaSchema.parse({ envelope: VALID_OP_CREADA_ENVELOPE, payload: {} })).toThrow();
  });
});

// ─── OpCerradaSchema ───────────────────────────────────────────────────────

const VALID_OP_CERRADA_PAYLOAD = {
  ordenId:       'b1c2d3e4-f5a6-4789-9abc-def012345678',
  codigo:        'OP-2026-0481',
  productoId:    'c2d3e4f5-a6b7-4890-9bcd-ef0123456789',
  varianteId:    'd3e4f5a6-b7c8-4901-9cde-f01234567890',
  recetaVersion: 1,
  cantidad:      50,
  breakdown: {
    costoInsumos:     '3120000.00',
    costoMaquina:     '890000.00',
    costoHorasHombre: '417500.00',
    costoTotal:       '4427500.00',
  },
  fechaCierre: '2026-04-22T16:45:00Z',
  cerradaPor:  'a1b2c3d4-e5f6-7890-abcd-ef0123456789',
};

const VALID_OP_CERRADA_ENVELOPE = {
  ...BASE_ENVELOPE,
  eventType: 'produccion.op.cerrada.v1',
};

describe('OpCerradaSchema', () => {
  it('acepta evento válido', () => {
    const valid = { envelope: VALID_OP_CERRADA_ENVELOPE, payload: VALID_OP_CERRADA_PAYLOAD };
    expect(() => OpCerradaSchema.parse(valid)).not.toThrow();
  });

  it('acepta evento con detalleInsumos opcional', () => {
    const valid = {
      envelope: VALID_OP_CERRADA_ENVELOPE,
      payload: {
        ...VALID_OP_CERRADA_PAYLOAD,
        breakdown: {
          ...VALID_OP_CERRADA_PAYLOAD.breakdown,
          detalleInsumos: [
            {
              insumoId:       '3f2504e0-4f89-11d3-9a0c-0305e82c3301',
              cantidad:       '120.0000',
              precioUnitario: '8500.0000',
              subtotal:       '1020000.00',
            },
          ],
        },
      },
    };
    expect(() => OpCerradaSchema.parse(valid)).not.toThrow();
  });

  it('rechaza breakdown sin costoTotal', () => {
    const { costoTotal: _removed, ...breakdownSinTotal } = VALID_OP_CERRADA_PAYLOAD.breakdown;
    const invalid = {
      envelope: VALID_OP_CERRADA_ENVELOPE,
      payload: { ...VALID_OP_CERRADA_PAYLOAD, breakdown: breakdownSinTotal },
    };
    expect(() => OpCerradaSchema.parse(invalid)).toThrow();
  });

  it('rechaza recetaVersion menor a 1', () => {
    const invalid = {
      envelope: VALID_OP_CERRADA_ENVELOPE,
      payload: { ...VALID_OP_CERRADA_PAYLOAD, recetaVersion: 0 },
    };
    expect(() => OpCerradaSchema.parse(invalid)).toThrow();
  });

  it('rechaza payload vacío', () => {
    expect(() =>
      OpCerradaSchema.parse({ envelope: VALID_OP_CERRADA_ENVELOPE, payload: {} }),
    ).toThrow();
  });
});

// ─── TarifaCambiadaSchema ──────────────────────────────────────────────────

const VALID_TARIFA_PAYLOAD = {
  tarifaAnteriorId: 'a1b2c3d4-e5f6-7890-abcd-ef0123456789',
  tarifaNuevaId:    'b2c3d4e5-f6a7-8901-bcde-f01234567890',
  entidadTipo:      'MAQUINA' as const,
  entidadId:        'maquina-cortadora-1',
  valorAnterior:    '150.0000',
  valorNuevo:       '175.0000',
  validFrom:        '2026-05-01T00:00:00Z',
  motivo:           'Actualización semestral de tarifas',
  cambiadaPor:      'a1b2c3d4-e5f6-7890-abcd-ef0123456789',
};

const VALID_TARIFA_ENVELOPE = {
  ...BASE_ENVELOPE,
  eventType: 'produccion.tarifa.cambiada.v1',
};

describe('TarifaCambiadaSchema', () => {
  it('acepta evento válido con tarifa anterior', () => {
    const valid = { envelope: VALID_TARIFA_ENVELOPE, payload: VALID_TARIFA_PAYLOAD };
    expect(() => TarifaCambiadaSchema.parse(valid)).not.toThrow();
  });

  it('acepta tarifaAnteriorId null (primera tarifa del sistema)', () => {
    const valid = {
      envelope: VALID_TARIFA_ENVELOPE,
      payload: { ...VALID_TARIFA_PAYLOAD, tarifaAnteriorId: null },
    };
    expect(() => TarifaCambiadaSchema.parse(valid)).not.toThrow();
  });

  it('acepta valorAnterior null', () => {
    const valid = {
      envelope: VALID_TARIFA_ENVELOPE,
      payload: { ...VALID_TARIFA_PAYLOAD, valorAnterior: null },
    };
    expect(() => TarifaCambiadaSchema.parse(valid)).not.toThrow();
  });

  it('rechaza entidadTipo con valor no permitido', () => {
    const invalid = {
      envelope: VALID_TARIFA_ENVELOPE,
      payload: { ...VALID_TARIFA_PAYLOAD, entidadTipo: 'HERRAMIENTA' },
    };
    expect(() => TarifaCambiadaSchema.parse(invalid)).toThrow();
  });

  it('rechaza motivo vacío', () => {
    const invalid = {
      envelope: VALID_TARIFA_ENVELOPE,
      payload: { ...VALID_TARIFA_PAYLOAD, motivo: '' },
    };
    expect(() => TarifaCambiadaSchema.parse(invalid)).toThrow();
  });

  it('rechaza payload vacío', () => {
    expect(() =>
      TarifaCambiadaSchema.parse({ envelope: VALID_TARIFA_ENVELOPE, payload: {} }),
    ).toThrow();
  });
});
