-- ============================================================
-- ARTEO SCHEMA SEED — versión idempotente para ERP
-- Ejecutado automáticamente por docker-compose al crear la BD
-- Puede correrse múltiples veces sin errores
-- ============================================================

-- ============================================================
-- TALLER ARTEO - Script SQL Completo
-- Base de datos PostgreSQL v1.0
-- Incluye: Schema + Datos semilla de ambos Excel
-- ============================================================

-- ============================================================
-- 0. TIPOS ENUM
-- ============================================================

DO $$ BEGIN
  CREATE TYPE rol_usuario AS ENUM (
    'admin', 'vendedor', 'operario', 'comprador'
);
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

DO $$ BEGIN
  CREATE TYPE estado_pedido AS ENUM (
    'borrador', 'confirmado', 'en_produccion', 'listo', 'entregado', 'cancelado'
);
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

DO $$ BEGIN
  CREATE TYPE canal_venta AS ENUM (
    'instagram', 'whatsapp', 'presencial', 'mercadolibre', 'web'
);
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

DO $$ BEGIN
  CREATE TYPE estado_orden AS ENUM (
    'pendiente', 'en_proceso', 'finalizado'
);
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

DO $$ BEGIN
  CREATE TYPE estado_venta AS ENUM (
    'pendiente', 'parcial', 'pagado'
);
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

DO $$ BEGIN
  CREATE TYPE medio_pago AS ENUM (
    'efectivo', 'transferencia', 'mercadopago', 'debito', 'credito'
);
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

DO $$ BEGIN
  CREATE TYPE estado_producto AS ENUM (
    'activo', 'por_cortar', 'cortado', 'pendiente', 'no_cortado', 'sin_diseno'
);
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

-- ============================================================
-- 1. MÓDULO: USUARIOS Y ROLES
-- ============================================================

CREATE TABLE IF NOT EXISTS usuarios (
    id_usuario      SERIAL          PRIMARY KEY,
    nombre          VARCHAR(100)    NOT NULL,
    apellido        VARCHAR(100)    NOT NULL,
    email           VARCHAR(200)    NOT NULL UNIQUE,
    password_hash   TEXT            NOT NULL,
    rol             rol_usuario     NOT NULL DEFAULT 'operario',
    activo          BOOLEAN         NOT NULL DEFAULT TRUE,
    created_at      TIMESTAMPTZ     NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_usuarios_email ON usuarios(email);
CREATE INDEX IF NOT EXISTS idx_usuarios_rol   ON usuarios(rol);

CREATE TABLE IF NOT EXISTS vendedores (
    id_vendedor     SERIAL          PRIMARY KEY,
    id_usuario      INTEGER         NOT NULL REFERENCES usuarios(id_usuario) ON DELETE RESTRICT,
    comision_pct    DECIMAL(5,2)    NOT NULL DEFAULT 0.00,
    zona            VARCHAR(100)
);

CREATE TABLE IF NOT EXISTS mano_de_obra (
    id_operario     SERIAL          PRIMARY KEY,
    id_usuario      INTEGER         NOT NULL REFERENCES usuarios(id_usuario) ON DELETE RESTRICT,
    especialidad    VARCHAR(100)    NOT NULL,
    valor_hora      DECIMAL(10,2)   NOT NULL DEFAULT 0.00,
    activo          BOOLEAN         NOT NULL DEFAULT TRUE
);

-- ============================================================
-- 2. MÓDULO: CATÁLOGO DE PRODUCTOS
-- ============================================================

CREATE TABLE IF NOT EXISTS categorias (
    id_categoria    SERIAL          PRIMARY KEY,
    nombre          VARCHAR(100)    NOT NULL,
    descripcion     TEXT
);

CREATE TABLE IF NOT EXISTS materiales (
    id_material         SERIAL          PRIMARY KEY,
    cod_interno         VARCHAR(20),
    tipo                VARCHAR(100)    NOT NULL,
    marca               VARCHAR(100),
    descripcion         VARCHAR(200),
    grosor_mm           DECIMAL(5,2),
    valor_plancha       DECIMAL(10,2)   NOT NULL DEFAULT 0.00,
    ancho_cm            DECIMAL(10,2),
    alto_cm             DECIMAL(10,2),
    cm2_por_plancha     DECIMAL(12,2),
    tipo_medida         VARCHAR(20),
    proveedor           VARCHAR(200),
    codigo_proveedor    VARCHAR(100),
    url_referencia      TEXT,
    activo              BOOLEAN         NOT NULL DEFAULT TRUE
);

CREATE INDEX IF NOT EXISTS idx_materiales_tipo ON materiales(tipo);

CREATE TABLE IF NOT EXISTS niveles_precio_corte (
    id_nivel            SERIAL          PRIMARY KEY,
    nivel               INTEGER         NOT NULL UNIQUE,
    precio_por_minuto   DECIMAL(10,2)   NOT NULL,
    descripcion         VARCHAR(200)
);

CREATE TABLE IF NOT EXISTS productos (
    id_producto         SERIAL              PRIMARY KEY,
    id_categoria        INTEGER             REFERENCES categorias(id_categoria),
    codigo              VARCHAR(50)         UNIQUE,
    nombre              VARCHAR(200)        NOT NULL,
    descripcion         TEXT,
    estado              estado_producto     NOT NULL DEFAULT 'activo',
    activo              BOOLEAN             NOT NULL DEFAULT TRUE
);

CREATE INDEX IF NOT EXISTS idx_productos_codigo     ON productos(codigo);
CREATE INDEX IF NOT EXISTS idx_productos_categoria  ON productos(id_categoria);

CREATE TABLE IF NOT EXISTS recetas (
    id_receta                   SERIAL          PRIMARY KEY,
    id_producto                 INTEGER         NOT NULL REFERENCES productos(id_producto),
    id_material                 INTEGER         NOT NULL REFERENCES materiales(id_material),
    parte                       VARCHAR(100),
    tamano_ancho_mm             DECIMAL(8,2),
    tamano_alto_mm              DECIMAL(8,2),
    tiempo_seg                  DECIMAL(12,6),
    requiere_sublimacion        BOOLEAN         NOT NULL DEFAULT FALSE,
    costo_sublimacion_unidad    DECIMAL(10,2),
    requiere_barniz             BOOLEAN         NOT NULL DEFAULT FALSE,
    requiere_corcho             BOOLEAN         NOT NULL DEFAULT FALSE,
    costo_material_calculado    DECIMAL(10,2),
    costo_tiempo_base           DECIMAL(10,2),
    costo_embalaje              DECIMAL(10,2)   DEFAULT 0,
    valor_neto                  DECIMAL(10,2),
    version                     INTEGER         NOT NULL DEFAULT 1,
    activa                      BOOLEAN         NOT NULL DEFAULT TRUE,
    notas                       TEXT
);

CREATE INDEX IF NOT EXISTS idx_recetas_producto ON recetas(id_producto);

CREATE TABLE IF NOT EXISTS parametros_corte (
    id_parametro        SERIAL          PRIMARY KEY,
    id_receta           INTEGER         NOT NULL REFERENCES recetas(id_receta),
    tecnica             VARCHAR(50),
    velocidad           DECIMAL(8,2),
    potencia_pct        DECIMAL(5,2),
    interlineado        DECIMAL(5,2),
    pasadas             INTEGER         DEFAULT 1,
    tiempo_por_lote_seg DECIMAL(12,6),
    notas               TEXT
);

CREATE TABLE IF NOT EXISTS grabados (
    id_grabado      SERIAL          PRIMARY KEY,
    id_producto     INTEGER         REFERENCES productos(id_producto),
    nombre_diseno   VARCHAR(200),
    ancho_mm        DECIMAL(8,2),
    alto_mm         DECIMAL(8,2),
    tecnica         VARCHAR(50),
    velocidad       DECIMAL(8,2),
    potencia_pct    DECIMAL(5,2),
    interlineado    DECIMAL(5,2),
    minutos         DECIMAL(10,6),
    vel_marcado     DECIMAL(8,2),
    pot_marcado     DECIMAL(5,2)
);

CREATE TABLE IF NOT EXISTS precios_venta (
    id_precio           SERIAL          PRIMARY KEY,
    id_producto         INTEGER         NOT NULL REFERENCES productos(id_producto),
    cantidad_desde      INTEGER         NOT NULL DEFAULT 1,
    precio_unitario     DECIMAL(10,2)   NOT NULL,
    precio_con_argolla  DECIMAL(10,2),
    observacion         VARCHAR(200)
);

-- ============================================================
-- 3. MÓDULO: COMPRADORES Y PEDIDOS
-- ============================================================

CREATE TABLE IF NOT EXISTS compradores (
    id_comprador    SERIAL          PRIMARY KEY,
    nombre          VARCHAR(100)    NOT NULL,
    apellido        VARCHAR(100),
    email           VARCHAR(200),
    telefono        VARCHAR(30),
    instagram       VARCHAR(100),
    direccion       TEXT,
    created_at      TIMESTAMPTZ     NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS pedidos (
    id_pedido                   SERIAL          PRIMARY KEY,
    id_comprador                INTEGER         NOT NULL REFERENCES compradores(id_comprador),
    id_vendedor                 INTEGER         REFERENCES vendedores(id_vendedor),
    fecha_pedido                TIMESTAMPTZ     NOT NULL DEFAULT NOW(),
    fecha_entrega_prometida     DATE,
    estado                      estado_pedido   NOT NULL DEFAULT 'borrador',
    canal_venta                 canal_venta,
    observaciones               TEXT,
    created_at                  TIMESTAMPTZ     NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_pedidos_comprador ON pedidos(id_comprador);
CREATE INDEX IF NOT EXISTS idx_pedidos_estado    ON pedidos(estado);

CREATE TABLE IF NOT EXISTS detalle_pedido (
    id_detalle                  SERIAL          PRIMARY KEY,
    id_pedido                   INTEGER         NOT NULL REFERENCES pedidos(id_pedido),
    id_producto                 INTEGER         NOT NULL REFERENCES productos(id_producto),
    id_receta                   INTEGER         REFERENCES recetas(id_receta),
    cantidad                    INTEGER         NOT NULL DEFAULT 1,
    precio_unitario_acordado    DECIMAL(10,2)   NOT NULL,
    personalizacion             TEXT,
    subtotal                    DECIMAL(10,2)   GENERATED ALWAYS AS (cantidad * precio_unitario_acordado) STORED
);

-- ============================================================
-- 4. MÓDULO: PRODUCCIÓN
-- ============================================================

CREATE TABLE IF NOT EXISTS ordenes_produccion (
    id_orden                SERIAL          PRIMARY KEY,
    id_pedido               INTEGER         NOT NULL REFERENCES pedidos(id_pedido),
    id_receta               INTEGER         NOT NULL REFERENCES recetas(id_receta),
    id_nivel                INTEGER         NOT NULL REFERENCES niveles_precio_corte(id_nivel),
    id_operario             INTEGER         REFERENCES mano_de_obra(id_operario),
    cantidad_a_producir     INTEGER         NOT NULL DEFAULT 1,
    fecha_inicio            TIMESTAMPTZ,
    fecha_fin               TIMESTAMPTZ,
    estado                  estado_orden    NOT NULL DEFAULT 'pendiente',
    costo_material_total    DECIMAL(10,2),
    costo_corte_total       DECIMAL(10,2),
    costo_sublimacion_total DECIMAL(10,2),
    costo_mano_obra_total   DECIMAL(10,2),
    costo_total             DECIMAL(10,2)
);

-- ============================================================
-- 5. MÓDULO: COMPRAS DE INSUMOS
-- ============================================================

CREATE TABLE IF NOT EXISTS proveedores (
    id_proveedor    SERIAL          PRIMARY KEY,
    nombre          VARCHAR(200)    NOT NULL,
    contacto        VARCHAR(200),
    telefono        VARCHAR(30),
    email           VARCHAR(200),
    direccion       TEXT,
    url_catalogo    TEXT,
    activo          BOOLEAN         NOT NULL DEFAULT TRUE
);

CREATE TABLE IF NOT EXISTS compras (
    id_compra       SERIAL          PRIMARY KEY,
    id_proveedor    INTEGER         NOT NULL REFERENCES proveedores(id_proveedor),
    id_usuario      INTEGER         NOT NULL REFERENCES usuarios(id_usuario),
    fecha_compra    DATE            NOT NULL,
    total           DECIMAL(12,2),
    factura_nro     VARCHAR(100),
    observaciones   TEXT,
    created_at      TIMESTAMPTZ     NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS detalle_compra (
    id_detalle_compra   SERIAL          PRIMARY KEY,
    id_compra           INTEGER         NOT NULL REFERENCES compras(id_compra),
    id_material         INTEGER         NOT NULL REFERENCES materiales(id_material),
    cantidad            DECIMAL(10,2)   NOT NULL,
    unidad              VARCHAR(50)     NOT NULL DEFAULT 'plancha',
    precio_unitario     DECIMAL(10,2)   NOT NULL,
    subtotal            DECIMAL(10,2)   GENERATED ALWAYS AS (cantidad * precio_unitario) STORED
);

-- ============================================================
-- 6. MÓDULO: VENTAS Y PAGOS
-- ============================================================

CREATE TABLE IF NOT EXISTS ventas (
    id_venta        SERIAL          PRIMARY KEY,
    id_pedido       INTEGER         NOT NULL REFERENCES pedidos(id_pedido),
    id_vendedor     INTEGER         REFERENCES vendedores(id_vendedor),
    fecha_venta     TIMESTAMPTZ     NOT NULL DEFAULT NOW(),
    total_bruto     DECIMAL(12,2)   NOT NULL,
    descuento       DECIMAL(10,2)   NOT NULL DEFAULT 0.00,
    total_final     DECIMAL(12,2)   GENERATED ALWAYS AS (total_bruto - descuento) STORED,
    estado          estado_venta    NOT NULL DEFAULT 'pendiente'
);

CREATE TABLE IF NOT EXISTS pagos (
    id_pago         SERIAL          PRIMARY KEY,
    id_venta        INTEGER         NOT NULL REFERENCES ventas(id_venta),
    fecha_pago      TIMESTAMPTZ     NOT NULL,
    monto           DECIMAL(12,2)   NOT NULL,
    medio_pago      medio_pago      NOT NULL,
    referencia      VARCHAR(200),
    observacion     VARCHAR(300)
);

-- ============================================================
-- ============================================================
-- DATOS SEMILLA
-- ============================================================
-- ============================================================

-- ============================================================
-- CATEGORÍAS (de PRODUCTOS sheet + TABLA GENERAL)
-- ============================================================

INSERT INTO categorias (nombre, descripcion) VALUES
    ('Geometricos',     'Figuras y animales en corte geometrico laser'),
    ('Cajas',           'Cajas y contenedores cortados a laser'),
    ('Posavasos',       'Posavasos de madera y acrilico'),
    ('Organizadores',   'Organizadores de escritorio y hogar'),
    ('Marcos',          'Marcos de fotos y cuadros decorativos'),
    ('Llaveros',        'Llaveros de madera y acrilico'),
    ('Papeleria',       'Marca paginas, memorice y papeleria'),
    ('Hogar',           'Articulos decorativos para el hogar'),
    ('Repisa',          'Repisas de acrilico para pared'),
    ('Navidad',         'Articulos navidenos y estacionales'),
    ('Aros',            'Bases de aro sublimadas y perforadas'),
    ('Carteles',        'Carteles y senaletica en madera y acrilico'),
    ('Medallero',       'Medalleros para premios y condecoraciones'),
    ('Accesorios',      'Argollas, bisagras y accesorios varios');

-- ============================================================
-- MATERIALES (de MATERIA PRIMA sheet + referencias en TABLA GENERAL)
-- ============================================================

INSERT INTO materiales (
    cod_interno, tipo, marca, descripcion, grosor_mm,
    valor_plancha, ancho_cm, alto_cm, cm2_por_plancha, tipo_medida,
    proveedor, codigo_proveedor, url_referencia
) VALUES
    ('MAT-001', 'MDF',      'Durolac', 'Durolac blanco IMPERIAL',       3.0,  10300, 244, 152, 37088, 'CMS',  NULL, NULL, NULL),
    ('MAT-002', 'MDF',      'Durolac', 'Durolac blanco SODIMAC',         2.8,  8490,  244, 152, 37088, 'CMS',  NULL, NULL, NULL),
    ('MAT-003', 'MDF',      'Durolac', 'Durolac blanco POROSO',          3.0,  11050, 244, 152, 37088, 'CMS',  NULL, NULL, NULL),
    ('MAT-004', 'MDF',      'Durolac', 'Durolac negro',                  3.0,  10990, 244, 152, 37088, 'CMS',  NULL, NULL, NULL),
    ('MAT-005', 'Acrilico', NULL,      'Acrilico transparente 2 MM',     2.0,  4500,  40,  60,  2400,  'CMS',  NULL, NULL, NULL),
    ('MAT-006', 'Acrilico', NULL,      'Acrilico transparente 3 MM',     3.0,  7500,  40,  60,  2400,  'CMS',  NULL, NULL, NULL),
    ('MAT-007', 'Acrilico', NULL,      'Acrilico transparente 4 MM',     4.0,  11500, 40,  60,  2400,  'CMS',  NULL, NULL, NULL),
    ('MAT-008', 'MDF',      'Arauco',  'MDF 5.5 MM',                     5.5,  13590, 244, 152, 37088, 'CMS',  'Imperial / Arauco', '83632', NULL),
    ('MAT-009', 'MDF',      NULL,      'MDF Desnudo 3MM',                3.0,  7980,  244, 152, 37088, 'CMS',  NULL, NULL, NULL),
    ('MAT-010', 'Textil',   NULL,      'Alfombra boucle',                NULL, 5800,  400, 100, 40000, 'CMS',  NULL, NULL, 'https://www.multipisos.cl/producto/alfombras-boucle-muro-a-muro-380-gramos-por-m%c2%b2-valor-al-detalle-5-800-m%c2%b2-iva-incluido-al-por-mayor-rollo/'),
    ('MAT-011', 'Corcho',   'Artel',   'Corcho artel 2 MM',              2.0,  NULL,  30,  20,  600,   'CMS',  NULL, NULL, NULL),
    ('MAT-012', 'Embalaje', NULL,      'Carton corrugado',               NULL, 2490,  77,  110, 8470,  'CMS',  NULL, NULL, NULL),
    ('MAT-013', 'Embalaje', NULL,      'Carton negro 1 MM',              1.0,  2290,  55,  77,  NULL,  'CMS',  'Libreria Nacional', NULL, NULL),
    ('MAT-014', 'Insumo',   NULL,      'Cinta doble contacto',           NULL, 5290,  2.54, 139, NULL, 'CMS',  NULL, NULL, NULL),
    ('MAT-015', 'Insumo',   NULL,      'Lamina imantada 4mm',            4.0,  4700,  100, 60,  6000,  'CMS',  NULL, NULL, NULL),
    ('MAT-016', 'Acrilico', NULL,      'Acrilico marmolado 3MM',         3.0,  29500, 105, 65,  6825,  'CMS',  NULL, NULL, NULL),
    ('MAT-017', 'Acrilico', NULL,      'Acrilico transparente 5MM plancha', 5.0, 7500, 60, 40,  2400,  'CMS',  NULL, NULL, NULL),
    ('MAT-018', 'Acrilico', NULL,      'Acrilico blanco 3MM',            3.0,  7500,  60,  40,  2400,  'CMS',  NULL, NULL, NULL),
    ('MAT-019', 'Textil',   NULL,      'Toalla blanca',                  NULL, 5600,  140, 150, 21000, 'CMS',  NULL, NULL, NULL),
    ('MAT-020', 'MDF',      'Arauco',  'MDF 5.5 MM Hidro',               5.5,  16596, 244, 212, 51728, 'CMS',  'Imperial / Arauco', '83632', NULL),
    ('MAT-021', 'Acrilico', NULL,      'Acrilico transparente 5MM grande', 5.0, 90000, 244, 125, 30500, 'MM',  NULL, NULL, NULL),
    ('MAT-022', 'MDF',      NULL,      'MDF 2 caras brillo',             NULL, 4800,  40,  60,  2400,  'CMS',  NULL, NULL, NULL),
    ('MAT-023', 'Acrilico', NULL,      'Acrilico espejado 3MM',          3.0,  9990,  60,  40,  2400,  'CMS',  NULL, NULL, NULL),
    ('MAT-024', 'MDF',      NULL,      'MDF alto brillo 1 cara 3MM',     3.0,  11300, 120, 60,  7200,  'CMS',  NULL, NULL, NULL),
    ('MAT-025', 'MDF',      NULL,      'MDF alto brillo 2 caras 3MM',    3.0,  14300, 120, 60,  NULL,  'CMS',  NULL, NULL, NULL),
    ('MAT-026', 'Insumo',   NULL,      'Argolla para llavero 3 cms',     NULL, 3500,  NULL, NULL, NULL, 'UNIT', NULL, NULL, NULL),
    ('MAT-027', 'MDF',      'Durolac', 'MDF DUROLAC alto brillo unicapa 3MM', 3.0, 3800, 60, 40, 2400, 'CMS', NULL, NULL, NULL);

-- ============================================================
-- NIVELES DE PRECIO DE CORTE (de CALCULO DE TIEMPO sheet)
-- ============================================================

INSERT INTO niveles_precio_corte (nivel, precio_por_minuto, descripcion) VALUES
    (1, 300.00, 'Produccion masiva / economico'),
    (2, 350.00, 'Produccion estandar (recomendado)'),
    (3, 400.00, 'Trabajos urgentes / premium'),
    (4, 450.00, 'Pedidos express'),
    (5, 500.00, 'Maxima prioridad');

-- ============================================================
-- PRODUCTOS (de TABLA GENERAL + PRODUCTOS sheet)
-- Solo se insertan los registros con codigo y nombre definidos
-- ============================================================

INSERT INTO productos (codigo, id_categoria, nombre, estado, activo) VALUES
    -- Marcos
    ('COT001',      (SELECT id_categoria FROM categorias WHERE nombre='Marcos'),        'Marco de fotos 240x330 MDF',                       'activo',       TRUE),
    -- Medalleros
    ('DEP001A',     (SELECT id_categoria FROM categorias WHERE nombre='Medallero'),     'Medallero 5mm MDF',                                'activo',       TRUE),
    ('DEP001B',     (SELECT id_categoria FROM categorias WHERE nombre='Medallero'),     'Medallero 3mm Durolac blanco',                     'activo',       TRUE),
    -- Geometricos
    ('GEO001',      (SELECT id_categoria FROM categorias WHERE nombre='Geometricos'),   'Leon 55X37 geometrico',                            'activo',       TRUE),
    ('GEO002',      (SELECT id_categoria FROM categorias WHERE nombre='Geometricos'),   'Delfin 34x30 geometrico',                          'cortado',      TRUE),
    ('GEO003',      (SELECT id_categoria FROM categorias WHERE nombre='Geometricos'),   'Gato vertical 55X35 geometrico',                   'activo',       TRUE),
    ('GEO005',      (SELECT id_categoria FROM categorias WHERE nombre='Geometricos'),   'Gato caminando 35X30 geometrico',                  'activo',       TRUE),
    ('GEO005-B',    (SELECT id_categoria FROM categorias WHERE nombre='Geometricos'),   'Gato caminando 48X40 geometrico',                  'no_cortado',   TRUE),
    ('GEO006',      (SELECT id_categoria FROM categorias WHERE nombre='Geometricos'),   'Toro cabeza 55X40 geometrico',                     'activo',       TRUE),
    ('GEO010',      (SELECT id_categoria FROM categorias WHERE nombre='Geometricos'),   'Perro pug con lentes',                             'activo',       TRUE),
    ('GEO012',      (SELECT id_categoria FROM categorias WHERE nombre='Geometricos'),   'Leon a pedido de 40x40 geometrico',                'por_cortar',   TRUE),
    ('GEO0012',     (SELECT id_categoria FROM categorias WHERE nombre='Geometricos'),   'Orquidea 600x300',                                 'activo',       TRUE),
    -- Cotizaciones especiales
    ('COT002-A',    (SELECT id_categoria FROM categorias WHERE nombre='Hogar'),         'Mapamundi 440x330',                                'activo',       TRUE),
    ('COT002-B',    (SELECT id_categoria FROM categorias WHERE nombre='Hogar'),         'Mapamundi 350x400',                                'activo',       TRUE),
    -- Cajas
    ('PROD01',      (SELECT id_categoria FROM categorias WHERE nombre='Cajas'),         'Esfera grabado corte circular colgante',            'cortado',      TRUE),
    ('PROD013',     (SELECT id_categoria FROM categorias WHERE nombre='Cajas'),         'CASAX1 Caja 66x66 esquinas flexibles',              'cortado',      TRUE),
    ('PROD014',     (SELECT id_categoria FROM categorias WHERE nombre='Cajas'),         'CAJAX2 Caja 17x17x8 puerta deslizante',             'cortado',      TRUE),
    ('PROD015',     (SELECT id_categoria FROM categorias WHERE nombre='Cajas'),         'CAJAX3 Caja gatitos en tapa 20x16x5',              'cortado',      TRUE),
    ('PROD016',     (SELECT id_categoria FROM categorias WHERE nombre='Cajas'),         'CAJAX5 Caja corazon 120x120x50 curvas flexibles',  'cortado',      TRUE),
    ('PROD02',      (SELECT id_categoria FROM categorias WHERE nombre='Cajas'),         'Caja cuadrada 20x20x10 tapa bisagra',              'cortado',      TRUE),
    ('PROD022',     (SELECT id_categoria FROM categorias WHERE nombre='Cajas'),         'CAJAX13 Corazon 15cm diametro 2,5 alto bicapa',    'activo',       TRUE),
    ('PROD023',     (SELECT id_categoria FROM categorias WHERE nombre='Cajas'),         'CAJAX14 Corazon 17x15 diametro 6 alto troquel',    'activo',       TRUE),
    ('PROD024',     (SELECT id_categoria FROM categorias WHERE nombre='Cajas'),         'CAJAX15 Bandeja 25x25x9 bordes calados',           'cortado',      TRUE),
    ('PROD026',     (SELECT id_categoria FROM categorias WHERE nombre='Cajas'),         'CAJAX17 Caja 20x20 con diseno',                    'sin_diseno',   TRUE),
    ('PROD03',      (SELECT id_categoria FROM categorias WHERE nombre='Cajas'),         'Caja rectangular 20x18x9 tapa plana',              'cortado',      TRUE),
    ('PROD04',      (SELECT id_categoria FROM categorias WHERE nombre='Cajas'),         'Esfera Anne',                                      'cortado',      TRUE),
    ('PROD05',      (SELECT id_categoria FROM categorias WHERE nombre='Cajas'),         'Esfera 2',                                         'cortado',      TRUE),
    ('PROD06',      (SELECT id_categoria FROM categorias WHERE nombre='Cajas'),         'Rocky - esfera',                                   'cortado',      TRUE),
    ('PROD07',      (SELECT id_categoria FROM categorias WHERE nombre='Cajas'),         'Valki - esfera',                                   'cortado',      TRUE),
    ('PROD08',      (SELECT id_categoria FROM categorias WHERE nombre='Cajas'),         'Tercila grabado',                                  'cortado',      TRUE),
    ('PROD11',      (SELECT id_categoria FROM categorias WHERE nombre='Navidad'),       'Caja pino de navidad 440x370',                     'cortado',      TRUE),
    ('PROD12',      (SELECT id_categoria FROM categorias WHERE nombre='Navidad'),       'Caja estrella navidad 25cm diametro 7cm alto',     'cortado',      TRUE),
    -- Posavasos
    ('C28-010001',  (SELECT id_categoria FROM categorias WHERE nombre='Posavasos'),     'Posavasos madera 3mm 100x100',                     'cortado',      TRUE),
    ('C28-010002',  (SELECT id_categoria FROM categorias WHERE nombre='Posavasos'),     'Posavasos madera 3mm 95x95',                       'cortado',      TRUE),
    ('C28-010003',  (SELECT id_categoria FROM categorias WHERE nombre='Posavasos'),     'Posavasos base+bordes Durolac negro',               'cortado',      TRUE),
    ('C28-010004',  (SELECT id_categoria FROM categorias WHERE nombre='Posavasos'),     'Posavasos 0001 x5 corte Durolac negro 500x95',     'cortado',      TRUE),
    -- Llaveros
    ('C28-016001',  (SELECT id_categoria FROM categorias WHERE nombre='Llaveros'),      'Circulos acrilico llavero 3mm 50x50',              'por_cortar',   TRUE),
    ('C28-016002',  (SELECT id_categoria FROM categorias WHERE nombre='Llaveros'),      'Circulos acrilico llavero 4mm 50x50',              'activo',       TRUE),
    ('C28-016003',  (SELECT id_categoria FROM categorias WHERE nombre='Llaveros'),      'Llavero acrilico 3mm 50x50',                       'cortado',      TRUE),
    -- Rascador
    ('C28-011001',  (SELECT id_categoria FROM categorias WHERE nombre='Accesorios'),    'Rascador de muro multicapa',                       'cortado',      TRUE),
    -- Organizadores
    ('ORG001',      (SELECT id_categoria FROM categorias WHERE nombre='Organizadores'), 'Organizador 5.5mm tipo libreria 1000x730',         'activo',       TRUE),
    ('ORG002',      (SELECT id_categoria FROM categorias WHERE nombre='Organizadores'), 'Organizador gatito 5.5mm 600x500',                 'activo',       TRUE),
    -- Aros sublimados
    ('POS-ARO-001', (SELECT id_categoria FROM categorias WHERE nombre='Aros'),          'Aros sublimados y perforados 9cms MDF corcho base','activo',       TRUE),
    -- Repisa
    ('REP-001',     (SELECT id_categoria FROM categorias WHERE nombre='Repisa'),        'Repisa acrilico 52 cms',                           'activo',       TRUE),
    ('REP-002',     (SELECT id_categoria FROM categorias WHERE nombre='Repisa'),        'Repisa acrilico 34 cms',                           'activo',       TRUE),
    -- Papeleria
    ('C28-000001',  (SELECT id_categoria FROM categorias WHERE nombre='Papeleria'),     'Circulos acrilico llavero (catalogo)',              'activo',       TRUE),
    ('C28-000002',  (SELECT id_categoria FROM categorias WHERE nombre='Papeleria'),     'Rectangulo marca paginas acrilico 2mm',            'activo',       TRUE),
    -- Carteles
    ('CART-M-001',  (SELECT id_categoria FROM categorias WHERE nombre='Carteles'),      'Cartel M madera 180x130',                          'activo',       TRUE),
    ('CART-A-001',  (SELECT id_categoria FROM categorias WHERE nombre='Carteles'),      'Cartel M acrilico 3MM 180x130',                    'activo',       TRUE),
    ('CART-A-002',  (SELECT id_categoria FROM categorias WHERE nombre='Carteles'),      'Cartel acrilico 2MM 180x130',                      'activo',       TRUE),
    ('CART-A-003',  (SELECT id_categoria FROM categorias WHERE nombre='Carteles'),      'Cartel M doble sublimado 180x130',                 'activo',       TRUE);

-- ============================================================
-- RECETAS (datos de TABLA GENERAL - productos con medidas y costos)
-- ============================================================

INSERT INTO recetas (
    id_producto, id_material, parte,
    tamano_ancho_mm, tamano_alto_mm, tiempo_seg,
    costo_material_calculado, costo_tiempo_base, costo_embalaje, valor_neto,
    notas
) VALUES
    -- COT001 - Marco fotos
    ((SELECT id_producto FROM productos WHERE codigo='COT001'),
     (SELECT id_material FROM materiales WHERE cod_interno='MAT-001'),
     NULL, 240, 330, 1.3888888888888889E-3*86400, 219.95, 900, 0, 1119.95, 'Durolac blanco IMPERIAL 3MM'),
    -- DEP001A - Medallero 5mm
    ((SELECT id_producto FROM productos WHERE codigo='DEP001A'),
     (SELECT id_material FROM materiales WHERE cod_interno='MAT-008'),
     NULL, 280, 170, 2.7777777777777779E-3*86400, 174.42, 1400, 0, 1574.42, 'MDF 5.5 MM - Aerosol chino x2 - 12 hh'),
    -- DEP001B - Medallero 3mm
    ((SELECT id_producto FROM productos WHERE codigo='DEP001B'),
     (SELECT id_material FROM materiales WHERE cod_interno='MAT-001'),
     NULL, 80, 70, 6.9444444444444447E-4*86400, 15.55, 350, 0, 365.55, 'Durolac blanco IMPERIAL 3MM'),
    -- GEO001 - Leon 55x37
    ((SELECT id_producto FROM productos WHERE codigo='GEO001'),
     (SELECT id_material FROM materiales WHERE cod_interno='MAT-001'),
     NULL, 550, 300, 1.1215277777777777E-2*86400, 458.23, 4845, 0, 5303.23, NULL),
    -- GEO002 - Delfin
    ((SELECT id_producto FROM productos WHERE codigo='GEO002'),
     (SELECT id_material FROM materiales WHERE cod_interno='MAT-001'),
     NULL, 340, 300, 3.9583333333333337E-3*86400, 283.27, 1995, 0, 2278.27, 'Estado: CORTADO'),
    -- GEO003 - Gato vertical 55x35
    ((SELECT id_producto FROM productos WHERE codigo='GEO003'),
     (SELECT id_material FROM materiales WHERE cod_interno='MAT-001'),
     NULL, 350, 550, 6.145833333333333E-3*86400, 534.61, 3097.5, 0, 3632.11, NULL),
    -- GEO005 - Gato caminando 35x30
    ((SELECT id_producto FROM productos WHERE codigo='GEO005'),
     (SELECT id_material FROM materiales WHERE cod_interno='MAT-001'),
     NULL, 350, 300, 8.3333333333333332E-3*86400, 291.60, 6000, 0, 6291.60, NULL),
    -- GEO006 - Toro
    ((SELECT id_producto FROM productos WHERE codigo='GEO006'),
     (SELECT id_material FROM materiales WHERE cod_interno='MAT-001'),
     NULL, 550, 400, 8.2407407407407412E-3*86400, 610.98, 4153.33, 0, 4764.31, NULL),
    -- GEO0012 - Orquidea
    ((SELECT id_producto FROM productos WHERE codigo='GEO0012'),
     (SELECT id_material FROM materiales WHERE cod_interno='MAT-001'),
     NULL, 600, 300, 2.0833333333333332E-2*86400, 499.89, 15000, 0, 15499.89, NULL),
    -- GEO012 - Leon 40x40
    ((SELECT id_producto FROM productos WHERE codigo='GEO012'),
     (SELECT id_material FROM materiales WHERE cod_interno='MAT-001'),
     NULL, 400, 400, 1.1319444444444444E-2*86400, 444.35, 5705, 0, 6149.35, 'Estado: POR CORTAR'),
    -- COT002-A Mapamundi 440x330
    ((SELECT id_producto FROM productos WHERE codigo='COT002-A'),
     (SELECT id_material FROM materiales WHERE cod_interno='MAT-001'),
     NULL, 440, 330, 3.8194444444444443E-3*86400, 403.25, 1650, 0, 2053.25, NULL),
    -- COT002-B Mapamundi 350x400
    ((SELECT id_producto FROM productos WHERE codigo='COT002-B'),
     (SELECT id_material FROM materiales WHERE cod_interno='MAT-001'),
     NULL, 350, 400, 2.4305555555555556E-3*86400, 388.81, 1225, 0, 1613.81, NULL),
    -- ORG001 - Organizador libreria
    ((SELECT id_producto FROM productos WHERE codigo='ORG001'),
     (SELECT id_material FROM materiales WHERE cod_interno='MAT-008'),
     NULL, 1000, 730, 1.3171296296296294E-2*86400, 2674.91, 6638.33, 0, 9313.24, 'MDF 5.5 MM'),
    -- ORG002 - Organizador gatito
    ((SELECT id_producto FROM productos WHERE codigo='ORG002'),
     (SELECT id_material FROM materiales WHERE cod_interno='MAT-008'),
     NULL, 600, 500, 7.0023148148148154E-3*86400, 1099.28, 3529.17, 0, 4628.44, 'MDF 5.5 MM'),
    -- PROD01 - Esfera colgante
    ((SELECT id_producto FROM productos WHERE codigo='PROD01'),
     (SELECT id_material FROM materiales WHERE cod_interno='MAT-001'),
     NULL, 90, 100, 1.261574074074074E-3*86400, 25.00, 545, 0, 569.99, 'Durolac blanco - Estado: CORTADO'),
    -- PROD013 - CASAX1
    ((SELECT id_producto FROM productos WHERE codigo='PROD013'),
     (SELECT id_material FROM materiales WHERE cod_interno='MAT-001'),
     NULL, 234, 115, 3.6921296296296298E-3*86400, 74.73, 1860.83, 0, 1935.57, 'Estado: CORTADO'),
    -- PROD014 - CAJAX2
    ((SELECT id_producto FROM productos WHERE codigo='PROD014'),
     (SELECT id_material FROM materiales WHERE cod_interno='MAT-001'),
     NULL, 540, 283, 4.2129629629629626E-3*86400, 424.41, 1820, 0, 2244.41, 'Estado: CORTADO'),
    -- PROD015 - CAJAX3
    ((SELECT id_producto FROM productos WHERE codigo='PROD015'),
     (SELECT id_material FROM materiales WHERE cod_interno='MAT-001'),
     NULL, 380, 390, 7.3611111111111108E-3*86400, 411.58, 3710, 0, 4121.58, 'Estado: CORTADO'),
    -- PROD016 - CAJAX5
    ((SELECT id_producto FROM productos WHERE codigo='PROD016'),
     (SELECT id_material FROM materiales WHERE cod_interno='MAT-001'),
     NULL, 370, 240, 7.4421296296296293E-3*86400, 246.61, 3750.83, 0, 3997.45, 'Estado: CORTADO - Confirmar tamano'),
    -- PROD02 - Caja cuadrada
    ((SELECT id_producto FROM productos WHERE codigo='PROD02'),
     (SELECT id_material FROM materiales WHERE cod_interno='MAT-004'),
     NULL, 520, 390, 5.6018518518518518E-3*86400, 563.21, 2420, 0, 2983.21, 'Durolac Cafe - Estado: CORTADO'),
    -- PROD023 - CAJAX14
    ((SELECT id_producto FROM productos WHERE codigo='PROD023'),
     (SELECT id_material FROM materiales WHERE cod_interno='MAT-001'),
     NULL, 480, 260, 1.4340277777777776E-2*86400, 346.59, 6195, 0, 6541.59, NULL),
    -- PROD024 - CAJAX15
    ((SELECT id_producto FROM productos WHERE codigo='PROD024'),
     (SELECT id_material FROM materiales WHERE cod_interno='MAT-001'),
     NULL, 512, 360, 5.1736111111111115E-3*86400, 511.89, 2235, 0, 2746.89, 'Estado: CORTADO'),
    -- PROD026 - CAJAX17
    ((SELECT id_producto FROM productos WHERE codigo='PROD026'),
     (SELECT id_material FROM materiales WHERE cod_interno='MAT-001'),
     NULL, 630, 330, 3.5763888888888894E-3*86400, 577.38, 1545, 0, 2122.38, 'Estado: CORTADA PERO SIN DISENO'),
    -- PROD03 - Caja rectangular
    ((SELECT id_producto FROM productos WHERE codigo='PROD03'),
     (SELECT id_material FROM materiales WHERE cod_interno='MAT-001'),
     NULL, 390, 380, 3.3449074074074071E-3*86400, 411.58, 1685.83, 0, 2097.41, 'Durolac blanco - Estado: CORTADO'),
    -- PROD11 - Caja pino navidad
    ((SELECT id_producto FROM productos WHERE codigo='PROD11'),
     (SELECT id_material FROM materiales WHERE cod_interno='MAT-001'),
     NULL, 440, 370, 6.1342592592592594E-3*86400, 452.12, 3091.67, 0, 3543.79, 'Estado: CORTADO'),
    -- PROD12 - Caja estrella navidad
    ((SELECT id_producto FROM productos WHERE codigo='PROD12'),
     (SELECT id_material FROM materiales WHERE cod_interno='MAT-001'),
     NULL, 550, 330, 4.7685185185185183E-3*86400, 504.06, 2060, 0, 2564.06, 'Estado: CORTADO'),
    -- Posavasos
    -- C28-010001 parte 1
    ((SELECT id_producto FROM productos WHERE codigo='C28-010001'),
     (SELECT id_material FROM materiales WHERE cod_interno='MAT-001'),
     'C28-010001#1', 100, 100, 1.6203703703703703E-3*86400, 27.77, 816.67, 0, 844.44, 'Durolac blanco IMPERIAL 3MM'),
    -- C28-010002
    ((SELECT id_producto FROM productos WHERE codigo='C28-010002'),
     (SELECT id_material FROM materiales WHERE cod_interno='MAT-001'),
     NULL, 95, 95, 3.7037037037037034E-3*86400, 33.07, 1866.67, 0, 1899.74, 'Durolac blanco IMPERIAL 3MM'),
    -- C28-010003 base
    ((SELECT id_producto FROM productos WHERE codigo='C28-010003'),
     (SELECT id_material FROM materiales WHERE cod_interno='MAT-004'),
     'C28-010001#1', 100, 100, 2.3148148148148146E-4*86400, 27.77, 116.67, 0, 144.44, 'Durolac negro 3MM - base'),
    -- C28-010004
    ((SELECT id_producto FROM productos WHERE codigo='C28-010004'),
     (SELECT id_material FROM materiales WHERE cod_interno='MAT-004'),
     'C28-010004#1', 500, 95, 6.5509259259259262E-3*86400, 174.05, 3773.33, 0, 3947.39, 'Durolac negro 3MM'),
    -- Llaveros
    ((SELECT id_producto FROM productos WHERE codigo='C28-016001'),
     (SELECT id_material FROM materiales WHERE cod_interno='MAT-006'),
     NULL, 50, 50, 1.7361111111111112E-4*86400, 78.13, 75, 0, 153.13, 'Acrilico transparente 3MM - Estado: POR CORTAR'),
    ((SELECT id_producto FROM productos WHERE codigo='C28-016002'),
     (SELECT id_material FROM materiales WHERE cod_interno='MAT-007'),
     NULL, 50, 50, 1.7361111111111112E-4*86400, 119.79, 125, 0, 244.79, 'Acrilico transparente 4MM'),
    ((SELECT id_producto FROM productos WHERE codigo='C28-016003'),
     (SELECT id_material FROM materiales WHERE cod_interno='MAT-006'),
     'C28-016001', 50, 50, 2.0833333333333335E-4*86400, 78.13, 90, 0, 168.13, 'Acrilico transparente 3MM'),
    -- C28-011001 Rascador parte 1
    ((SELECT id_producto FROM productos WHERE codigo='C28-011001'),
     (SELECT id_material FROM materiales WHERE cod_interno='MAT-001'),
     'C28-011001#1', 580, 250, 1.2731481481481483E-3*86400, 402.69, 550, 0, 952.69, 'Durolac blanco IMPERIAL 3MM'),
    -- Aros sublimados (datos del primer Excel)
    ((SELECT id_producto FROM productos WHERE codigo='POS-ARO-001'),
     (SELECT id_material FROM materiales WHERE cod_interno='MAT-027'),
     NULL, 260, 125, NULL, 339.81, 3558.33, 0, 3898.14, '27 unidades por plancha - sublimado $100 por par'),
    -- Repisas acrilico
    ((SELECT id_producto FROM productos WHERE codigo='REP-001'),
     (SELECT id_material FROM materiales WHERE cod_interno='MAT-017'),
     'Respaldo', 510, 105, 2.4305555555555556E-3*86400, 1673.44, 1050, 0, 2723.44, 'Acrilico transparente 5MM'),
    ((SELECT id_producto FROM productos WHERE codigo='REP-002'),
     (SELECT id_material FROM materiales WHERE cod_interno='MAT-017'),
     'Respaldo', 340, 70, 1.736111111111111E-3*86400, 743.75, 750, 0, 1493.75, 'Acrilico transparente 5MM'),
    -- Carteles
    ((SELECT id_producto FROM productos WHERE codigo='CART-M-001'),
     (SELECT id_material FROM materiales WHERE cod_interno='MAT-001'),
     NULL, 180, 130, 4.3981481481481481E-4*86400, 64.99, 190, 0, 254.99, 'MDF 3MM madera'),
    ((SELECT id_producto FROM productos WHERE codigo='CART-A-001'),
     (SELECT id_material FROM materiales WHERE cod_interno='MAT-006'),
     NULL, 180, 130, 9.2592592592592596E-4*86400, 731.25, 400, 0, 1131.25, 'Acrilico transparente 3MM'),
    ((SELECT id_producto FROM productos WHERE codigo='CART-A-002'),
     (SELECT id_material FROM materiales WHERE cod_interno='MAT-005'),
     NULL, 180, 130, 9.2592592592592596E-4*86400, 438.75, 400, 0, 838.75, 'Acrilico 2MM'),
    ((SELECT id_producto FROM productos WHERE codigo='CART-A-003'),
     (SELECT id_material FROM materiales WHERE cod_interno='MAT-001'),
     NULL, 180, 130, 6.9444444444444447E-4*86400, 468, 300, 0, 768, 'MDF doble sublimado');

-- ============================================================
-- PARAMETROS DE CORTE (de Calculos de tiempo sheet + TABLA GENERAL)
-- ============================================================

INSERT INTO parametros_corte (id_receta, tecnica, velocidad, potencia_pct, pasadas, tiempo_por_lote_seg, notas)
SELECT r.id_receta, 'Corte', 15, 40, 1,
       3.6921296296296298E-3 * 86400,
       'CASAX1 - Estado: CORTADO'
FROM recetas r
JOIN productos p ON r.id_producto = p.id_producto
WHERE p.codigo = 'PROD013';

INSERT INTO parametros_corte (id_receta, tecnica, velocidad, potencia_pct, pasadas, tiempo_por_lote_seg, notas)
SELECT r.id_receta, 'Corte', 18, 45, 1,
       4.7685185185185183E-3 * 86400,
       'PROD12 Caja estrella navidad'
FROM recetas r
JOIN productos p ON r.id_producto = p.id_producto
WHERE p.codigo = 'PROD12';

INSERT INTO parametros_corte (id_receta, tecnica, velocidad, potencia_pct, pasadas, tiempo_por_lote_seg, notas)
SELECT r.id_receta, 'Corte', 15, 40, 2,
       7.060185185185185E-3 * 86400,
       'Aros sublimados - 2 pasadas incluidas en tiempo'
FROM recetas r
JOIN productos p ON r.id_producto = p.id_producto
WHERE p.codigo = 'POS-ARO-001';

INSERT INTO parametros_corte (id_receta, tecnica, velocidad, potencia_pct, pasadas, tiempo_por_lote_seg, notas)
SELECT r.id_receta, 'Corte', 13, 45, 1,
       0.54236111111111118 * 3600,
       'Gato vertical 45 cms - parametros medidos'
FROM recetas r
JOIN productos p ON r.id_producto = p.id_producto
WHERE p.codigo = 'GEO003';

-- ============================================================
-- GRABADOS (de GRABADOS sheet)
-- ============================================================

INSERT INTO grabados (nombre_diseno, ancho_mm, alto_mm, tecnica, velocidad, potencia_pct, interlineado, minutos, vel_marcado, pot_marcado) VALUES
    ('Escudo Capitan America',  53, 52, 'GRABADO', 300, 25, 2, 7.9861111111111105E-4 * 1440, NULL,  NULL),
    ('Escudo Capitan America v2',53, 52, 'GRABADO', 300, 25, 2, 9.0277777777777784E-4 * 1440, 100, 13),
    ('Logo Avenger',            48, 55, 'GRABADO', 300, 25, 2, 8.9120370370370362E-4 * 1440, 100, 13),
    ('Punio Hulk',              75, 70, 'GRABADO', 300, 25, 2, 1.5162037037037036E-3 * 1440, 100, 13),
    ('Mazo Thor',               60, 70, 'GRABADO', 300, 25, 2, 8.564814814814815E-4  * 1440, NULL,  NULL),
    ('HP Slitherin',            NULL, NULL, 'GRABADO', 300, 25, 2, 1.1574074074074073E-3 * 1440, NULL, NULL);

-- ============================================================
-- PRECIOS DE VENTA (de TABLA GENERAL + primer Excel)
-- ============================================================

-- Aros sublimados (datos primer Excel)
INSERT INTO precios_venta (id_producto, cantidad_desde, precio_unitario, precio_con_argolla, observacion)
SELECT id_producto, 1, 900, 1200, 'Precio unitario - con argolla $1200'
FROM productos WHERE codigo = 'POS-ARO-001';

INSERT INTO precios_venta (id_producto, cantidad_desde, precio_unitario, observacion)
SELECT id_producto, 10, 500, 'Precio x10 pares'
FROM productos WHERE codigo = 'POS-ARO-001';

INSERT INTO precios_venta (id_producto, cantidad_desde, precio_unitario, observacion)
SELECT id_producto, 50, 480, 'Precio x50 pares'
FROM productos WHERE codigo = 'POS-ARO-001';

-- Llavero acrilico 3mm
INSERT INTO precios_venta (id_producto, cantidad_desde, precio_unitario, observacion)
SELECT id_producto, 1, 231.25, 'Precio unitario incluye argolla'
FROM productos WHERE codigo = 'C28-016001';

-- ============================================================
-- ACTIVOS - Maquina laser
-- ============================================================
-- Nota: el valor de la maquina laser segun hoja ACTIVOS es $3.123.076
-- Modelo: 60x40 80w

-- Se registra como comentario de referencia en la BD:
COMMENT ON TABLE niveles_precio_corte IS
    'Maquina laser: 60x40 80w. Valor activo segun libro: $3.123.076 CLP';

-- ============================================================
-- VISTAS UTILES
-- ============================================================

-- Vista: costo completo por producto con nivel 2 (estandar)
CREATE OR REPLACE VIEW v_costos_productos AS
SELECT
    p.codigo,
    p.nombre,
    c.nombre                        AS categoria,
    r.tamano_ancho_mm               AS ancho_mm,
    r.tamano_alto_mm                AS alto_mm,
    m.descripcion                   AS material,
    m.grosor_mm,
    r.costo_material_calculado      AS costo_material,
    ROUND((r.tiempo_seg / 60.0) * n.precio_por_minuto, 2) AS costo_corte_nvl2,
    r.costo_embalaje,
    ROUND(r.costo_material_calculado +
          (r.tiempo_seg / 60.0) * n.precio_por_minuto +
          COALESCE(r.costo_embalaje, 0), 2)               AS costo_total_nvl2,
    r.notas,
    p.estado
FROM productos p
JOIN recetas r       ON r.id_producto = p.id_producto AND r.activa = TRUE
JOIN materiales m    ON m.id_material  = r.id_material
JOIN categorias c    ON c.id_categoria = p.id_categoria
CROSS JOIN niveles_precio_corte n
WHERE n.nivel = 2
ORDER BY c.nombre, p.codigo;

-- Vista: inventario de materiales
CREATE OR REPLACE VIEW v_materiales_activos AS
SELECT
    cod_interno,
    descripcion,
    grosor_mm,
    valor_plancha,
    ancho_cm || ' x ' || alto_cm  AS medida_plancha,
    cm2_por_plancha,
    ROUND(valor_plancha / NULLIF(cm2_por_plancha, 0), 4) AS precio_cm2
FROM materiales
WHERE activo = TRUE
ORDER BY tipo, grosor_mm;

-- ============================================================
-- FIN DEL SCRIPT
-- ============================================================

-- ============================================================
-- FIN DEL SEED ARTEO
-- Tablas creadas: usuarios, vendedores, mano_de_obra,
--   categorias, materiales, productos, recetas,
--   parametros_corte, grabados, precios_venta,
--   compradores, pedidos, detalle_pedido,
--   ordenes_produccion, proveedores, compras,
--   detalle_compra, ventas, pagos
-- Vistas: v_costos_productos, v_materiales_activos
-- ============================================================
