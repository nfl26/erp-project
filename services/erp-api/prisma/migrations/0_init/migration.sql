Loaded Prisma config from prisma.config.ts.

-- CreateSchema
CREATE SCHEMA IF NOT EXISTS "public";

-- CreateSchema
CREATE SCHEMA IF NOT EXISTS "tenant_demo";

-- CreateEnum
CREATE TYPE "tenant_demo"."rol_usuario" AS ENUM ('admin', 'vendedor', 'operario', 'comprador');

-- CreateEnum
CREATE TYPE "tenant_demo"."estado_pedido" AS ENUM ('borrador', 'confirmado', 'en_produccion', 'listo', 'entregado', 'cancelado');

-- CreateEnum
CREATE TYPE "tenant_demo"."canal_venta" AS ENUM ('instagram', 'whatsapp', 'presencial', 'mercadolibre', 'web');

-- CreateEnum
CREATE TYPE "tenant_demo"."estado_orden" AS ENUM ('pendiente', 'en_proceso', 'finalizado');

-- CreateEnum
CREATE TYPE "tenant_demo"."estado_venta" AS ENUM ('pendiente', 'parcial', 'pagado');

-- CreateEnum
CREATE TYPE "tenant_demo"."medio_pago" AS ENUM ('efectivo', 'transferencia', 'mercadopago', 'debito', 'credito');

-- CreateEnum
CREATE TYPE "tenant_demo"."estado_producto" AS ENUM ('activo', 'por_cortar', 'cortado', 'pendiente', 'no_cortado', 'sin_diseno');

-- CreateTable
CREATE TABLE "tenants" (
    "id" UUID NOT NULL DEFAULT gen_random_uuid(),
    "slug" VARCHAR NOT NULL,
    "nombre" VARCHAR NOT NULL,
    "activo" BOOLEAN DEFAULT true,
    "config" JSONB,
    "created_at" TIMESTAMPTZ(6) DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMPTZ(6),

    CONSTRAINT "tenants_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "tenant_demo"."categorias" (
    "id_categoria" SERIAL NOT NULL,
    "nombre" VARCHAR(100) NOT NULL,
    "descripcion" TEXT,

    CONSTRAINT "categorias_pkey" PRIMARY KEY ("id_categoria")
);

-- CreateTable
CREATE TABLE "tenant_demo"."compradores" (
    "id_comprador" SERIAL NOT NULL,
    "nombre" VARCHAR(100) NOT NULL,
    "apellido" VARCHAR(100),
    "email" VARCHAR(200),
    "telefono" VARCHAR(30),
    "instagram" VARCHAR(100),
    "direccion" TEXT,
    "created_at" TIMESTAMPTZ(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "compradores_pkey" PRIMARY KEY ("id_comprador")
);

-- CreateTable
CREATE TABLE "tenant_demo"."proveedores" (
    "id_proveedor" SERIAL NOT NULL,
    "nombre" VARCHAR(200) NOT NULL,
    "contacto" VARCHAR(200),
    "telefono" VARCHAR(30),
    "email" VARCHAR(200),
    "direccion" TEXT,
    "url_catalogo" TEXT,
    "activo" BOOLEAN NOT NULL DEFAULT true,

    CONSTRAINT "proveedores_pkey" PRIMARY KEY ("id_proveedor")
);

-- CreateTable
CREATE TABLE "tenant_demo"."usuarios" (
    "id_usuario" SERIAL NOT NULL,
    "nombre" VARCHAR(100) NOT NULL,
    "apellido" VARCHAR(100) NOT NULL,
    "email" VARCHAR(200) NOT NULL,
    "password_hash" TEXT NOT NULL,
    "rol" "tenant_demo"."rol_usuario" NOT NULL DEFAULT 'operario',
    "activo" BOOLEAN NOT NULL DEFAULT true,
    "created_at" TIMESTAMPTZ(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "usuarios_pkey" PRIMARY KEY ("id_usuario")
);

-- CreateTable
CREATE TABLE "tenant_demo"."vendedores" (
    "id_vendedor" SERIAL NOT NULL,
    "id_usuario" INTEGER NOT NULL,
    "comision_pct" DECIMAL(5,2) NOT NULL DEFAULT 0.00,
    "zona" VARCHAR(100),

    CONSTRAINT "vendedores_pkey" PRIMARY KEY ("id_vendedor")
);

-- CreateTable
CREATE TABLE "tenant_demo"."mano_de_obra" (
    "id_operario" SERIAL NOT NULL,
    "id_usuario" INTEGER NOT NULL,
    "especialidad" VARCHAR(100) NOT NULL,
    "valor_hora" DECIMAL(10,2) NOT NULL DEFAULT 0.00,
    "activo" BOOLEAN NOT NULL DEFAULT true,

    CONSTRAINT "mano_de_obra_pkey" PRIMARY KEY ("id_operario")
);

-- CreateTable
CREATE TABLE "tenant_demo"."materiales" (
    "id_material" SERIAL NOT NULL,
    "cod_interno" VARCHAR(20),
    "tipo" VARCHAR(100) NOT NULL,
    "marca" VARCHAR(100),
    "descripcion" VARCHAR(200),
    "grosor_mm" DECIMAL(5,2),
    "valor_plancha" DECIMAL(10,2) NOT NULL DEFAULT 0.00,
    "ancho_cm" DECIMAL(10,2),
    "alto_cm" DECIMAL(10,2),
    "cm2_por_plancha" DECIMAL(12,2),
    "tipo_medida" VARCHAR(20),
    "proveedor" VARCHAR(200),
    "codigo_proveedor" VARCHAR(100),
    "url_referencia" TEXT,
    "activo" BOOLEAN NOT NULL DEFAULT true,

    CONSTRAINT "materiales_pkey" PRIMARY KEY ("id_material")
);

-- CreateTable
CREATE TABLE "tenant_demo"."compras" (
    "id_compra" SERIAL NOT NULL,
    "id_proveedor" INTEGER NOT NULL,
    "id_usuario" INTEGER NOT NULL,
    "fecha_compra" DATE NOT NULL,
    "total" DECIMAL(12,2),
    "factura_nro" VARCHAR(100),
    "observaciones" TEXT,
    "created_at" TIMESTAMPTZ(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "compras_pkey" PRIMARY KEY ("id_compra")
);

-- CreateTable
CREATE TABLE "tenant_demo"."detalle_compra" (
    "id_detalle_compra" SERIAL NOT NULL,
    "id_compra" INTEGER NOT NULL,
    "id_material" INTEGER NOT NULL,
    "cantidad" DECIMAL(10,2) NOT NULL,
    "unidad" VARCHAR(50) NOT NULL DEFAULT 'plancha',
    "precio_unitario" DECIMAL(10,2) NOT NULL,
    "subtotal" DECIMAL(10,2),

    CONSTRAINT "detalle_compra_pkey" PRIMARY KEY ("id_detalle_compra")
);

-- CreateTable
CREATE TABLE "tenant_demo"."productos" (
    "id_producto" SERIAL NOT NULL,
    "id_categoria" INTEGER,
    "codigo" VARCHAR(50),
    "nombre" VARCHAR(200) NOT NULL,
    "descripcion" TEXT,
    "estado" "tenant_demo"."estado_producto" NOT NULL DEFAULT 'activo',
    "activo" BOOLEAN NOT NULL DEFAULT true,

    CONSTRAINT "productos_pkey" PRIMARY KEY ("id_producto")
);

-- CreateTable
CREATE TABLE "tenant_demo"."niveles_precio_corte" (
    "id_nivel" SERIAL NOT NULL,
    "nivel" INTEGER NOT NULL,
    "precio_por_minuto" DECIMAL(10,2) NOT NULL,
    "descripcion" VARCHAR(200),

    CONSTRAINT "niveles_precio_corte_pkey" PRIMARY KEY ("id_nivel")
);

-- CreateTable
CREATE TABLE "tenant_demo"."recetas" (
    "id_receta" SERIAL NOT NULL,
    "id_producto" INTEGER NOT NULL,
    "id_material" INTEGER NOT NULL,
    "parte" VARCHAR(100),
    "tamano_ancho_mm" DECIMAL(8,2),
    "tamano_alto_mm" DECIMAL(8,2),
    "tiempo_seg" DECIMAL(12,6),
    "requiere_sublimacion" BOOLEAN NOT NULL DEFAULT false,
    "costo_sublimacion_unidad" DECIMAL(10,2),
    "requiere_barniz" BOOLEAN NOT NULL DEFAULT false,
    "requiere_corcho" BOOLEAN NOT NULL DEFAULT false,
    "costo_material_calculado" DECIMAL(10,2),
    "costo_tiempo_base" DECIMAL(10,2),
    "costo_embalaje" DECIMAL(10,2) DEFAULT 0,
    "valor_neto" DECIMAL(10,2),
    "version" INTEGER NOT NULL DEFAULT 1,
    "activa" BOOLEAN NOT NULL DEFAULT true,
    "notas" TEXT,

    CONSTRAINT "recetas_pkey" PRIMARY KEY ("id_receta")
);

-- CreateTable
CREATE TABLE "tenant_demo"."parametros_corte" (
    "id_parametro" SERIAL NOT NULL,
    "id_receta" INTEGER NOT NULL,
    "tecnica" VARCHAR(50),
    "velocidad" DECIMAL(8,2),
    "potencia_pct" DECIMAL(5,2),
    "interlineado" DECIMAL(5,2),
    "pasadas" INTEGER DEFAULT 1,
    "tiempo_por_lote_seg" DECIMAL(12,6),
    "notas" TEXT,

    CONSTRAINT "parametros_corte_pkey" PRIMARY KEY ("id_parametro")
);

-- CreateTable
CREATE TABLE "tenant_demo"."grabados" (
    "id_grabado" SERIAL NOT NULL,
    "id_producto" INTEGER,
    "nombre_diseno" VARCHAR(200),
    "ancho_mm" DECIMAL(8,2),
    "alto_mm" DECIMAL(8,2),
    "tecnica" VARCHAR(50),
    "velocidad" DECIMAL(8,2),
    "potencia_pct" DECIMAL(5,2),
    "interlineado" DECIMAL(5,2),
    "minutos" DECIMAL(10,6),
    "vel_marcado" DECIMAL(8,2),
    "pot_marcado" DECIMAL(5,2),

    CONSTRAINT "grabados_pkey" PRIMARY KEY ("id_grabado")
);

-- CreateTable
CREATE TABLE "tenant_demo"."precios_venta" (
    "id_precio" SERIAL NOT NULL,
    "id_producto" INTEGER NOT NULL,
    "cantidad_desde" INTEGER NOT NULL DEFAULT 1,
    "precio_unitario" DECIMAL(10,2) NOT NULL,
    "precio_con_argolla" DECIMAL(10,2),
    "observacion" VARCHAR(200),

    CONSTRAINT "precios_venta_pkey" PRIMARY KEY ("id_precio")
);

-- CreateTable
CREATE TABLE "tenant_demo"."pedidos" (
    "id_pedido" SERIAL NOT NULL,
    "id_comprador" INTEGER NOT NULL,
    "id_vendedor" INTEGER,
    "fecha_pedido" TIMESTAMPTZ(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "fecha_entrega_prometida" DATE,
    "estado" "tenant_demo"."estado_pedido" NOT NULL DEFAULT 'borrador',
    "canal_venta" "tenant_demo"."canal_venta",
    "observaciones" TEXT,
    "created_at" TIMESTAMPTZ(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "pedidos_pkey" PRIMARY KEY ("id_pedido")
);

-- CreateTable
CREATE TABLE "tenant_demo"."detalle_pedido" (
    "id_detalle" SERIAL NOT NULL,
    "id_pedido" INTEGER NOT NULL,
    "id_producto" INTEGER NOT NULL,
    "id_receta" INTEGER,
    "cantidad" INTEGER NOT NULL DEFAULT 1,
    "precio_unitario_acordado" DECIMAL(10,2) NOT NULL,
    "personalizacion" TEXT,
    "subtotal" DECIMAL(10,2),

    CONSTRAINT "detalle_pedido_pkey" PRIMARY KEY ("id_detalle")
);

-- CreateTable
CREATE TABLE "tenant_demo"."ordenes_produccion" (
    "id_orden" SERIAL NOT NULL,
    "id_pedido" INTEGER NOT NULL,
    "id_receta" INTEGER NOT NULL,
    "id_nivel" INTEGER NOT NULL,
    "id_operario" INTEGER,
    "cantidad_a_producir" INTEGER NOT NULL DEFAULT 1,
    "fecha_inicio" TIMESTAMPTZ(6),
    "fecha_fin" TIMESTAMPTZ(6),
    "estado" "tenant_demo"."estado_orden" NOT NULL DEFAULT 'pendiente',
    "costo_material_total" DECIMAL(10,2),
    "costo_corte_total" DECIMAL(10,2),
    "costo_sublimacion_total" DECIMAL(10,2),
    "costo_mano_obra_total" DECIMAL(10,2),
    "costo_total" DECIMAL(10,2),

    CONSTRAINT "ordenes_produccion_pkey" PRIMARY KEY ("id_orden")
);

-- CreateTable
CREATE TABLE "tenant_demo"."ventas" (
    "id_venta" SERIAL NOT NULL,
    "id_pedido" INTEGER NOT NULL,
    "id_vendedor" INTEGER,
    "fecha_venta" TIMESTAMPTZ(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "total_bruto" DECIMAL(12,2) NOT NULL,
    "descuento" DECIMAL(10,2) NOT NULL DEFAULT 0.00,
    "total_final" DECIMAL(12,2),
    "estado" "tenant_demo"."estado_venta" NOT NULL DEFAULT 'pendiente',

    CONSTRAINT "ventas_pkey" PRIMARY KEY ("id_venta")
);

-- CreateTable
CREATE TABLE "tenant_demo"."pagos" (
    "id_pago" SERIAL NOT NULL,
    "id_venta" INTEGER NOT NULL,
    "fecha_pago" TIMESTAMPTZ(6) NOT NULL,
    "monto" DECIMAL(12,2) NOT NULL,
    "medio_pago" "tenant_demo"."medio_pago" NOT NULL,
    "referencia" VARCHAR(200),
    "observacion" VARCHAR(300),

    CONSTRAINT "pagos_pkey" PRIMARY KEY ("id_pago")
);

-- CreateIndex
CREATE UNIQUE INDEX "tenants_slug_key" ON "tenants"("slug");

-- CreateIndex
CREATE UNIQUE INDEX "usuarios_email_key" ON "tenant_demo"."usuarios"("email");

-- CreateIndex
CREATE UNIQUE INDEX "productos_codigo_key" ON "tenant_demo"."productos"("codigo");

-- CreateIndex
CREATE UNIQUE INDEX "niveles_precio_corte_nivel_key" ON "tenant_demo"."niveles_precio_corte"("nivel");

-- AddForeignKey
ALTER TABLE "tenant_demo"."vendedores" ADD CONSTRAINT "vendedores_id_usuario_fkey" FOREIGN KEY ("id_usuario") REFERENCES "tenant_demo"."usuarios"("id_usuario") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "tenant_demo"."mano_de_obra" ADD CONSTRAINT "mano_de_obra_id_usuario_fkey" FOREIGN KEY ("id_usuario") REFERENCES "tenant_demo"."usuarios"("id_usuario") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "tenant_demo"."compras" ADD CONSTRAINT "compras_id_proveedor_fkey" FOREIGN KEY ("id_proveedor") REFERENCES "tenant_demo"."proveedores"("id_proveedor") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "tenant_demo"."compras" ADD CONSTRAINT "compras_id_usuario_fkey" FOREIGN KEY ("id_usuario") REFERENCES "tenant_demo"."usuarios"("id_usuario") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "tenant_demo"."detalle_compra" ADD CONSTRAINT "detalle_compra_id_compra_fkey" FOREIGN KEY ("id_compra") REFERENCES "tenant_demo"."compras"("id_compra") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "tenant_demo"."detalle_compra" ADD CONSTRAINT "detalle_compra_id_material_fkey" FOREIGN KEY ("id_material") REFERENCES "tenant_demo"."materiales"("id_material") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "tenant_demo"."productos" ADD CONSTRAINT "productos_id_categoria_fkey" FOREIGN KEY ("id_categoria") REFERENCES "tenant_demo"."categorias"("id_categoria") ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "tenant_demo"."recetas" ADD CONSTRAINT "recetas_id_producto_fkey" FOREIGN KEY ("id_producto") REFERENCES "tenant_demo"."productos"("id_producto") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "tenant_demo"."recetas" ADD CONSTRAINT "recetas_id_material_fkey" FOREIGN KEY ("id_material") REFERENCES "tenant_demo"."materiales"("id_material") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "tenant_demo"."parametros_corte" ADD CONSTRAINT "parametros_corte_id_receta_fkey" FOREIGN KEY ("id_receta") REFERENCES "tenant_demo"."recetas"("id_receta") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "tenant_demo"."grabados" ADD CONSTRAINT "grabados_id_producto_fkey" FOREIGN KEY ("id_producto") REFERENCES "tenant_demo"."productos"("id_producto") ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "tenant_demo"."precios_venta" ADD CONSTRAINT "precios_venta_id_producto_fkey" FOREIGN KEY ("id_producto") REFERENCES "tenant_demo"."productos"("id_producto") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "tenant_demo"."pedidos" ADD CONSTRAINT "pedidos_id_comprador_fkey" FOREIGN KEY ("id_comprador") REFERENCES "tenant_demo"."compradores"("id_comprador") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "tenant_demo"."pedidos" ADD CONSTRAINT "pedidos_id_vendedor_fkey" FOREIGN KEY ("id_vendedor") REFERENCES "tenant_demo"."vendedores"("id_vendedor") ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "tenant_demo"."detalle_pedido" ADD CONSTRAINT "detalle_pedido_id_pedido_fkey" FOREIGN KEY ("id_pedido") REFERENCES "tenant_demo"."pedidos"("id_pedido") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "tenant_demo"."detalle_pedido" ADD CONSTRAINT "detalle_pedido_id_producto_fkey" FOREIGN KEY ("id_producto") REFERENCES "tenant_demo"."productos"("id_producto") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "tenant_demo"."detalle_pedido" ADD CONSTRAINT "detalle_pedido_id_receta_fkey" FOREIGN KEY ("id_receta") REFERENCES "tenant_demo"."recetas"("id_receta") ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "tenant_demo"."ordenes_produccion" ADD CONSTRAINT "ordenes_produccion_id_pedido_fkey" FOREIGN KEY ("id_pedido") REFERENCES "tenant_demo"."pedidos"("id_pedido") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "tenant_demo"."ordenes_produccion" ADD CONSTRAINT "ordenes_produccion_id_receta_fkey" FOREIGN KEY ("id_receta") REFERENCES "tenant_demo"."recetas"("id_receta") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "tenant_demo"."ordenes_produccion" ADD CONSTRAINT "ordenes_produccion_id_nivel_fkey" FOREIGN KEY ("id_nivel") REFERENCES "tenant_demo"."niveles_precio_corte"("id_nivel") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "tenant_demo"."ordenes_produccion" ADD CONSTRAINT "ordenes_produccion_id_operario_fkey" FOREIGN KEY ("id_operario") REFERENCES "tenant_demo"."mano_de_obra"("id_operario") ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "tenant_demo"."ventas" ADD CONSTRAINT "ventas_id_pedido_fkey" FOREIGN KEY ("id_pedido") REFERENCES "tenant_demo"."pedidos"("id_pedido") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "tenant_demo"."ventas" ADD CONSTRAINT "ventas_id_vendedor_fkey" FOREIGN KEY ("id_vendedor") REFERENCES "tenant_demo"."vendedores"("id_vendedor") ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "tenant_demo"."pagos" ADD CONSTRAINT "pagos_id_venta_fkey" FOREIGN KEY ("id_venta") REFERENCES "tenant_demo"."ventas"("id_venta") ON DELETE RESTRICT ON UPDATE CASCADE;

