-- ============================================
-- SCHNITTWERK Database Schema
-- Migration: 00006_shop.sql
-- Description: Products, categories, inventory
-- ============================================

-- ============================================
-- PRODUCT_CATEGORIES TABLE
-- Groups products for navigation
-- ============================================
CREATE TABLE product_categories (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  salon_id UUID NOT NULL REFERENCES salons(id) ON DELETE CASCADE,

  -- Category Info
  name TEXT NOT NULL,
  slug TEXT NOT NULL,
  description TEXT,
  image_url TEXT,

  -- Parent category for hierarchy
  parent_id UUID REFERENCES product_categories(id) ON DELETE SET NULL,

  -- Display
  sort_order INTEGER DEFAULT 0,

  -- Status
  is_active BOOLEAN NOT NULL DEFAULT true,

  -- Timestamps
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),

  -- Constraints
  CONSTRAINT unique_product_category_slug_per_salon UNIQUE (salon_id, slug)
);

COMMENT ON TABLE product_categories IS 'Product categories for shop';
COMMENT ON COLUMN product_categories.parent_id IS 'Parent category for hierarchical structure';

-- Indexes
CREATE INDEX idx_product_categories_salon ON product_categories(salon_id);
CREATE INDEX idx_product_categories_parent ON product_categories(parent_id);

-- Apply updated_at trigger
CREATE TRIGGER update_product_categories_updated_at
  BEFORE UPDATE ON product_categories
  FOR EACH ROW
  EXECUTE FUNCTION update_updated_at_column();

-- ============================================
-- PRODUCTS TABLE
-- Products available for purchase
-- ============================================
CREATE TABLE products (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  salon_id UUID NOT NULL REFERENCES salons(id) ON DELETE CASCADE,
  category_id UUID REFERENCES product_categories(id) ON DELETE SET NULL,

  -- Product Info
  name TEXT NOT NULL,
  slug TEXT NOT NULL,
  description TEXT,
  short_description TEXT,
  brand TEXT,

  -- SKU for inventory management
  sku TEXT,

  -- Pricing (in CHF cents)
  price_cents INTEGER NOT NULL,
  compare_at_price_cents INTEGER,
  cost_price_cents INTEGER,

  -- Tax
  vat_rate DECIMAL(5,2) DEFAULT 8.1,

  -- Inventory
  track_inventory BOOLEAN DEFAULT true,
  stock_quantity INTEGER DEFAULT 0,
  low_stock_threshold INTEGER DEFAULT 5,
  allow_backorder BOOLEAN DEFAULT false,

  -- Shipping
  weight_grams INTEGER,
  requires_shipping BOOLEAN DEFAULT true,

  -- Display
  sort_order INTEGER DEFAULT 0,
  is_featured BOOLEAN DEFAULT false,

  -- Status
  is_active BOOLEAN NOT NULL DEFAULT true,
  is_published BOOLEAN NOT NULL DEFAULT true,

  -- Timestamps
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),

  -- Constraints
  CONSTRAINT unique_product_slug_per_salon UNIQUE (salon_id, slug),
  CONSTRAINT unique_product_sku_per_salon UNIQUE (salon_id, sku),
  CONSTRAINT positive_product_price CHECK (price_cents >= 0)
);

COMMENT ON TABLE products IS 'Products available in shop';
COMMENT ON COLUMN products.price_cents IS 'Price in CHF cents';
COMMENT ON COLUMN products.compare_at_price_cents IS 'Original price for sale items';
COMMENT ON COLUMN products.cost_price_cents IS 'Cost price for margin calculation';
COMMENT ON COLUMN products.low_stock_threshold IS 'Alert threshold for low stock';

-- Indexes
CREATE INDEX idx_products_salon ON products(salon_id);
CREATE INDEX idx_products_category ON products(category_id);
CREATE INDEX idx_products_sku ON products(salon_id, sku);
CREATE INDEX idx_products_active ON products(salon_id, is_active, is_published) WHERE is_active = true AND is_published = true;
CREATE INDEX idx_products_low_stock ON products(salon_id, stock_quantity)
  WHERE track_inventory = true AND stock_quantity <= low_stock_threshold;

-- Apply updated_at trigger
CREATE TRIGGER update_products_updated_at
  BEFORE UPDATE ON products
  FOR EACH ROW
  EXECUTE FUNCTION update_updated_at_column();

-- ============================================
-- PRODUCT_IMAGES TABLE
-- Multiple images per product
-- ============================================
CREATE TABLE product_images (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  product_id UUID NOT NULL REFERENCES products(id) ON DELETE CASCADE,

  -- Image Info
  url TEXT NOT NULL,
  alt_text TEXT,

  -- Display
  is_primary BOOLEAN DEFAULT false,
  sort_order INTEGER DEFAULT 0,

  -- Timestamps
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

COMMENT ON TABLE product_images IS 'Product images gallery';
COMMENT ON COLUMN product_images.is_primary IS 'Primary image shown in listings';

-- Indexes
CREATE INDEX idx_product_images_product ON product_images(product_id);

-- ============================================
-- PRODUCT_VARIANTS TABLE
-- Product variants (size, color, etc.)
-- ============================================
CREATE TABLE product_variants (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  product_id UUID NOT NULL REFERENCES products(id) ON DELETE CASCADE,

  -- Variant Info
  name TEXT NOT NULL,
  sku TEXT,

  -- Pricing overrides
  price_cents INTEGER,
  compare_at_price_cents INTEGER,

  -- Inventory overrides
  stock_quantity INTEGER DEFAULT 0,

  -- Attributes (JSON for flexibility)
  -- Format: { "size": "500ml", "scent": "Lavender" }
  attributes JSONB DEFAULT '{}',

  -- Display
  sort_order INTEGER DEFAULT 0,

  -- Status
  is_active BOOLEAN NOT NULL DEFAULT true,

  -- Timestamps
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

COMMENT ON TABLE product_variants IS 'Product variants (different sizes, etc.)';
COMMENT ON COLUMN product_variants.attributes IS 'Variant attributes as JSON';

-- Indexes
CREATE INDEX idx_product_variants_product ON product_variants(product_id);
CREATE INDEX idx_product_variants_sku ON product_variants(sku);

-- Apply updated_at trigger
CREATE TRIGGER update_product_variants_updated_at
  BEFORE UPDATE ON product_variants
  FOR EACH ROW
  EXECUTE FUNCTION update_updated_at_column();

-- ============================================
-- STOCK_MOVEMENTS TABLE
-- Track inventory changes
-- ============================================
CREATE TABLE stock_movements (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  salon_id UUID NOT NULL REFERENCES salons(id) ON DELETE CASCADE,
  product_id UUID NOT NULL REFERENCES products(id) ON DELETE CASCADE,
  variant_id UUID REFERENCES product_variants(id) ON DELETE CASCADE,

  -- Movement Info
  movement_type stock_movement_type NOT NULL,
  quantity INTEGER NOT NULL,
  previous_quantity INTEGER NOT NULL,
  new_quantity INTEGER NOT NULL,

  -- Reference (order_id, adjustment_id, etc.)
  reference_type TEXT,
  reference_id UUID,

  -- Notes
  notes TEXT,

  -- Who made the change
  created_by UUID REFERENCES profiles(id),

  -- Timestamps
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

COMMENT ON TABLE stock_movements IS 'Inventory movement audit trail';
COMMENT ON COLUMN stock_movements.reference_type IS 'Type of reference (order, adjustment, etc.)';
COMMENT ON COLUMN stock_movements.reference_id IS 'ID of related record';

-- Indexes
CREATE INDEX idx_stock_movements_salon ON stock_movements(salon_id);
CREATE INDEX idx_stock_movements_product ON stock_movements(product_id);
CREATE INDEX idx_stock_movements_date ON stock_movements(created_at);
CREATE INDEX idx_stock_movements_reference ON stock_movements(reference_type, reference_id);

-- ============================================
-- VOUCHERS TABLE
-- Gift vouchers / gift cards
-- ============================================
CREATE TABLE vouchers (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  salon_id UUID NOT NULL REFERENCES salons(id) ON DELETE CASCADE,

  -- Voucher Info
  code TEXT NOT NULL,
  type TEXT NOT NULL DEFAULT 'gift_card',

  -- Value
  initial_value_cents INTEGER NOT NULL,
  remaining_value_cents INTEGER NOT NULL,

  -- Validity
  valid_from TIMESTAMPTZ DEFAULT NOW(),
  valid_until TIMESTAMPTZ,
  is_single_use BOOLEAN DEFAULT false,

  -- Purchase info
  purchased_by_customer_id UUID REFERENCES customers(id),
  recipient_email TEXT,
  recipient_name TEXT,
  personal_message TEXT,

  -- Status
  is_active BOOLEAN NOT NULL DEFAULT true,
  redeemed_at TIMESTAMPTZ,
  redeemed_by_customer_id UUID REFERENCES customers(id),

  -- Timestamps
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),

  -- Constraints
  CONSTRAINT unique_voucher_code_per_salon UNIQUE (salon_id, code),
  CONSTRAINT positive_voucher_value CHECK (initial_value_cents > 0),
  CONSTRAINT valid_remaining_value CHECK (remaining_value_cents >= 0)
);

COMMENT ON TABLE vouchers IS 'Gift vouchers and gift cards';
COMMENT ON COLUMN vouchers.code IS 'Unique redemption code';
COMMENT ON COLUMN vouchers.remaining_value_cents IS 'Remaining balance';

-- Indexes
CREATE INDEX idx_vouchers_salon ON vouchers(salon_id);
CREATE INDEX idx_vouchers_code ON vouchers(salon_id, code);
CREATE INDEX idx_vouchers_active ON vouchers(salon_id, is_active) WHERE is_active = true;

-- Apply updated_at trigger
CREATE TRIGGER update_vouchers_updated_at
  BEFORE UPDATE ON vouchers
  FOR EACH ROW
  EXECUTE FUNCTION update_updated_at_column();

-- ============================================
-- VIEW: Published products with category
-- ============================================
CREATE VIEW v_published_products AS
SELECT
  p.*,
  pc.name AS category_name,
  pc.slug AS category_slug,
  (p.price_cents::DECIMAL / 100) AS price_chf,
  CASE
    WHEN p.compare_at_price_cents IS NOT NULL
    THEN (p.compare_at_price_cents::DECIMAL / 100)
    ELSE NULL
  END AS compare_at_price_chf,
  (
    SELECT pi.url
    FROM product_images pi
    WHERE pi.product_id = p.id AND pi.is_primary = true
    LIMIT 1
  ) AS primary_image_url,
  CASE
    WHEN p.track_inventory AND p.stock_quantity <= 0 AND NOT p.allow_backorder
    THEN false
    ELSE true
  END AS is_in_stock
FROM products p
LEFT JOIN product_categories pc ON p.category_id = pc.id
WHERE p.is_active = true AND p.is_published = true;

COMMENT ON VIEW v_published_products IS 'Products visible in shop';

-- ============================================
-- VIEW: Low stock products
-- ============================================
CREATE VIEW v_low_stock_products AS
SELECT
  p.*,
  (p.price_cents::DECIMAL / 100) AS price_chf
FROM products p
WHERE p.is_active = true
  AND p.track_inventory = true
  AND p.stock_quantity <= p.low_stock_threshold;

COMMENT ON VIEW v_low_stock_products IS 'Products below stock threshold';

-- ============================================
-- FUNCTION: Adjust stock
-- ============================================
CREATE OR REPLACE FUNCTION adjust_stock(
  p_product_id UUID,
  p_quantity_change INTEGER,
  p_movement_type stock_movement_type,
  p_reference_type TEXT DEFAULT NULL,
  p_reference_id UUID DEFAULT NULL,
  p_notes TEXT DEFAULT NULL,
  p_created_by UUID DEFAULT NULL,
  p_variant_id UUID DEFAULT NULL
)
RETURNS INTEGER AS $$
DECLARE
  product_record RECORD;
  variant_record RECORD;
  previous_qty INTEGER;
  new_qty INTEGER;
  salon_id_val UUID;
BEGIN
  IF p_variant_id IS NOT NULL THEN
    -- Adjust variant stock
    SELECT * INTO variant_record
    FROM product_variants
    WHERE id = p_variant_id
    FOR UPDATE;

    IF NOT FOUND THEN
      RAISE EXCEPTION 'Product variant not found';
    END IF;

    previous_qty := COALESCE(variant_record.stock_quantity, 0);
    new_qty := previous_qty + p_quantity_change;

    UPDATE product_variants
    SET stock_quantity = new_qty
    WHERE id = p_variant_id;

    -- Get salon_id from parent product
    SELECT salon_id INTO salon_id_val FROM products WHERE id = variant_record.product_id;
  ELSE
    -- Adjust product stock
    SELECT * INTO product_record
    FROM products
    WHERE id = p_product_id
    FOR UPDATE;

    IF NOT FOUND THEN
      RAISE EXCEPTION 'Product not found';
    END IF;

    previous_qty := COALESCE(product_record.stock_quantity, 0);
    new_qty := previous_qty + p_quantity_change;

    UPDATE products
    SET stock_quantity = new_qty
    WHERE id = p_product_id;

    salon_id_val := product_record.salon_id;
  END IF;

  -- Record movement
  INSERT INTO stock_movements (
    salon_id, product_id, variant_id,
    movement_type, quantity, previous_quantity, new_quantity,
    reference_type, reference_id, notes, created_by
  ) VALUES (
    salon_id_val, p_product_id, p_variant_id,
    p_movement_type, p_quantity_change, previous_qty, new_qty,
    p_reference_type, p_reference_id, p_notes, p_created_by
  );

  RETURN new_qty;
END;
$$ LANGUAGE plpgsql;

-- ============================================
-- FUNCTION: Validate voucher
-- ============================================
CREATE OR REPLACE FUNCTION validate_voucher(
  p_salon_id UUID,
  p_code TEXT
)
RETURNS TABLE (
  voucher_id UUID,
  remaining_value_cents INTEGER,
  is_valid BOOLEAN,
  invalid_reason TEXT
) AS $$
DECLARE
  voucher_record RECORD;
BEGIN
  SELECT * INTO voucher_record
  FROM vouchers
  WHERE salon_id = p_salon_id AND code = UPPER(TRIM(p_code));

  IF NOT FOUND THEN
    voucher_id := NULL;
    remaining_value_cents := 0;
    is_valid := false;
    invalid_reason := 'Voucher not found';
    RETURN NEXT;
    RETURN;
  END IF;

  voucher_id := voucher_record.id;
  remaining_value_cents := voucher_record.remaining_value_cents;

  -- Check if active
  IF NOT voucher_record.is_active THEN
    is_valid := false;
    invalid_reason := 'Voucher is not active';
    RETURN NEXT;
    RETURN;
  END IF;

  -- Check validity period
  IF voucher_record.valid_from IS NOT NULL AND NOW() < voucher_record.valid_from THEN
    is_valid := false;
    invalid_reason := 'Voucher is not yet valid';
    RETURN NEXT;
    RETURN;
  END IF;

  IF voucher_record.valid_until IS NOT NULL AND NOW() > voucher_record.valid_until THEN
    is_valid := false;
    invalid_reason := 'Voucher has expired';
    RETURN NEXT;
    RETURN;
  END IF;

  -- Check remaining value
  IF voucher_record.remaining_value_cents <= 0 THEN
    is_valid := false;
    invalid_reason := 'Voucher has no remaining balance';
    RETURN NEXT;
    RETURN;
  END IF;

  -- Check if already redeemed (for single-use)
  IF voucher_record.is_single_use AND voucher_record.redeemed_at IS NOT NULL THEN
    is_valid := false;
    invalid_reason := 'Voucher has already been used';
    RETURN NEXT;
    RETURN;
  END IF;

  -- Voucher is valid
  is_valid := true;
  invalid_reason := NULL;
  RETURN NEXT;
END;
$$ LANGUAGE plpgsql STABLE;

-- ============================================
-- FUNCTION: Redeem voucher
-- ============================================
CREATE OR REPLACE FUNCTION redeem_voucher(
  p_voucher_id UUID,
  p_amount_cents INTEGER,
  p_customer_id UUID DEFAULT NULL
)
RETURNS INTEGER AS $$
DECLARE
  voucher_record RECORD;
  new_remaining INTEGER;
BEGIN
  -- Lock voucher for update
  SELECT * INTO voucher_record
  FROM vouchers
  WHERE id = p_voucher_id
  FOR UPDATE;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Voucher not found';
  END IF;

  -- Check sufficient balance
  IF p_amount_cents > voucher_record.remaining_value_cents THEN
    RAISE EXCEPTION 'Insufficient voucher balance';
  END IF;

  -- Calculate new remaining value
  new_remaining := voucher_record.remaining_value_cents - p_amount_cents;

  -- Update voucher
  UPDATE vouchers
  SET
    remaining_value_cents = new_remaining,
    redeemed_at = CASE WHEN new_remaining = 0 OR is_single_use THEN NOW() ELSE redeemed_at END,
    redeemed_by_customer_id = COALESCE(redeemed_by_customer_id, p_customer_id)
  WHERE id = p_voucher_id;

  RETURN new_remaining;
END;
$$ LANGUAGE plpgsql;
-- ============================================
-- SCHNITTWERK Database Schema
-- Migration: 00007_orders.sql
-- Description: Orders, order items, shipping
-- ============================================

-- ============================================
-- ORDERS TABLE
-- Customer orders (shop purchases, vouchers, etc.)
-- ============================================
CREATE TABLE orders (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  salon_id UUID NOT NULL REFERENCES salons(id) ON DELETE CASCADE,
  customer_id UUID REFERENCES customers(id) ON DELETE SET NULL,

  -- Order number (human-readable)
  order_number TEXT NOT NULL,

  -- Status
  status order_status NOT NULL DEFAULT 'pending',

  -- Pricing (in CHF cents)
  subtotal_cents INTEGER NOT NULL DEFAULT 0,
  discount_cents INTEGER DEFAULT 0,
  shipping_cents INTEGER DEFAULT 0,
  tax_cents INTEGER DEFAULT 0,
  total_cents INTEGER NOT NULL DEFAULT 0,

  -- Tax breakdown
  tax_rate DECIMAL(5,2),

  -- Voucher applied
  voucher_id UUID REFERENCES vouchers(id),
  voucher_discount_cents INTEGER DEFAULT 0,

  -- Shipping info
  shipping_method shipping_method_type,
  shipping_address JSONB,
  -- Format: { "name": "...", "street": "...", "zip": "...", "city": "...", "country": "..." }

  -- Pickup info (if pickup)
  pickup_date DATE,
  pickup_time TIME,

  -- Tracking
  tracking_number TEXT,
  shipped_at TIMESTAMPTZ,
  delivered_at TIMESTAMPTZ,

  -- Customer info snapshot
  customer_email TEXT NOT NULL,
  customer_name TEXT,
  customer_phone TEXT,

  -- Notes
  customer_notes TEXT,
  internal_notes TEXT,

  -- Source tracking
  source TEXT DEFAULT 'online',

  -- Timestamps
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  completed_at TIMESTAMPTZ,
  cancelled_at TIMESTAMPTZ,

  -- Constraints
  CONSTRAINT unique_order_number_per_salon UNIQUE (salon_id, order_number)
);

COMMENT ON TABLE orders IS 'Customer shop orders';
COMMENT ON COLUMN orders.order_number IS 'Human-readable order number (e.g., SW-2024-00001)';
COMMENT ON COLUMN orders.shipping_address IS 'Shipping address as JSON';
COMMENT ON COLUMN orders.source IS 'Where order was placed (online, in_person, phone)';

-- Indexes
CREATE INDEX idx_orders_salon ON orders(salon_id);
CREATE INDEX idx_orders_customer ON orders(customer_id);
CREATE INDEX idx_orders_status ON orders(salon_id, status);
CREATE INDEX idx_orders_number ON orders(salon_id, order_number);
CREATE INDEX idx_orders_date ON orders(salon_id, created_at);

-- Apply updated_at trigger
CREATE TRIGGER update_orders_updated_at
  BEFORE UPDATE ON orders
  FOR EACH ROW
  EXECUTE FUNCTION update_updated_at_column();

-- ============================================
-- ORDER_ITEMS TABLE
-- Individual items within an order
-- ============================================
CREATE TABLE order_items (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  order_id UUID NOT NULL REFERENCES orders(id) ON DELETE CASCADE,

  -- Item type (product, voucher, service)
  item_type TEXT NOT NULL DEFAULT 'product',

  -- Product reference
  product_id UUID REFERENCES products(id) ON DELETE SET NULL,
  variant_id UUID REFERENCES product_variants(id) ON DELETE SET NULL,

  -- Item details (snapshot at order time)
  item_name TEXT NOT NULL,
  item_sku TEXT,
  item_description TEXT,

  -- Quantity and pricing
  quantity INTEGER NOT NULL DEFAULT 1,
  unit_price_cents INTEGER NOT NULL,
  discount_cents INTEGER DEFAULT 0,
  total_cents INTEGER NOT NULL,

  -- Tax
  tax_rate DECIMAL(5,2),
  tax_cents INTEGER DEFAULT 0,

  -- Voucher specific (if item_type = 'voucher')
  voucher_id UUID REFERENCES vouchers(id),
  voucher_recipient_email TEXT,
  voucher_recipient_name TEXT,
  voucher_message TEXT,

  -- Timestamps
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),

  -- Constraints
  CONSTRAINT positive_quantity CHECK (quantity > 0),
  CONSTRAINT positive_unit_price CHECK (unit_price_cents >= 0)
);

COMMENT ON TABLE order_items IS 'Individual items in an order';
COMMENT ON COLUMN order_items.item_type IS 'Type: product, voucher, service';
COMMENT ON COLUMN order_items.item_name IS 'Snapshot of item name at order time';

-- Indexes
CREATE INDEX idx_order_items_order ON order_items(order_id);
CREATE INDEX idx_order_items_product ON order_items(product_id);

-- ============================================
-- ORDER_STATUS_HISTORY TABLE
-- Track status changes
-- ============================================
CREATE TABLE order_status_history (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  order_id UUID NOT NULL REFERENCES orders(id) ON DELETE CASCADE,

  -- Status change
  previous_status order_status,
  new_status order_status NOT NULL,

  -- Who made the change
  changed_by UUID REFERENCES profiles(id),

  -- Notes
  notes TEXT,

  -- Timestamps
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

COMMENT ON TABLE order_status_history IS 'Order status change audit trail';

-- Indexes
CREATE INDEX idx_order_history_order ON order_status_history(order_id);

-- ============================================
-- FUNCTION: Generate order number
-- ============================================
CREATE OR REPLACE FUNCTION generate_order_number(p_salon_id UUID)
RETURNS TEXT AS $$
DECLARE
  year_part TEXT;
  sequence_num INTEGER;
  new_order_number TEXT;
  prefix TEXT;
BEGIN
  year_part := TO_CHAR(NOW(), 'YYYY');

  -- Get salon prefix (first 2 chars of slug or 'SW')
  SELECT UPPER(LEFT(slug, 2)) INTO prefix
  FROM salons WHERE id = p_salon_id;
  prefix := COALESCE(prefix, 'SW');

  -- Get next sequence number for this salon/year
  SELECT COALESCE(MAX(
    CAST(SPLIT_PART(order_number, '-', 3) AS INTEGER)
  ), 0) + 1 INTO sequence_num
  FROM orders
  WHERE salon_id = p_salon_id
    AND order_number LIKE prefix || '-' || year_part || '-%';

  -- Format: SW-2024-00001
  new_order_number := prefix || '-' || year_part || '-' || LPAD(sequence_num::TEXT, 5, '0');

  RETURN new_order_number;
END;
$$ LANGUAGE plpgsql;

-- ============================================
-- FUNCTION: Create order
-- ============================================
CREATE OR REPLACE FUNCTION create_order(
  p_salon_id UUID,
  p_customer_id UUID,
  p_customer_email TEXT,
  p_customer_name TEXT DEFAULT NULL,
  p_customer_phone TEXT DEFAULT NULL,
  p_shipping_method shipping_method_type DEFAULT NULL,
  p_shipping_address JSONB DEFAULT NULL,
  p_customer_notes TEXT DEFAULT NULL
)
RETURNS UUID AS $$
DECLARE
  new_order_id UUID;
  new_order_number TEXT;
BEGIN
  -- Generate order number
  new_order_number := generate_order_number(p_salon_id);

  -- Create order
  INSERT INTO orders (
    salon_id, customer_id, order_number,
    customer_email, customer_name, customer_phone,
    shipping_method, shipping_address, customer_notes
  ) VALUES (
    p_salon_id, p_customer_id, new_order_number,
    p_customer_email, p_customer_name, p_customer_phone,
    p_shipping_method, p_shipping_address, p_customer_notes
  )
  RETURNING id INTO new_order_id;

  -- Record initial status
  INSERT INTO order_status_history (order_id, new_status, notes)
  VALUES (new_order_id, 'pending', 'Order created');

  RETURN new_order_id;
END;
$$ LANGUAGE plpgsql;

-- ============================================
-- FUNCTION: Add item to order
-- ============================================
CREATE OR REPLACE FUNCTION add_order_item(
  p_order_id UUID,
  p_product_id UUID,
  p_quantity INTEGER,
  p_variant_id UUID DEFAULT NULL
)
RETURNS UUID AS $$
DECLARE
  new_item_id UUID;
  product_record RECORD;
  variant_record RECORD;
  item_price INTEGER;
  item_name TEXT;
  item_sku TEXT;
  tax_rate_val DECIMAL(5,2);
  tax_amount INTEGER;
  item_total INTEGER;
BEGIN
  -- Get product
  SELECT * INTO product_record
  FROM products
  WHERE id = p_product_id;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Product not found';
  END IF;

  -- Get variant if specified
  IF p_variant_id IS NOT NULL THEN
    SELECT * INTO variant_record
    FROM product_variants
    WHERE id = p_variant_id;

    IF FOUND THEN
      item_price := COALESCE(variant_record.price_cents, product_record.price_cents);
      item_sku := COALESCE(variant_record.sku, product_record.sku);
      item_name := product_record.name || ' - ' || variant_record.name;
    ELSE
      item_price := product_record.price_cents;
      item_sku := product_record.sku;
      item_name := product_record.name;
    END IF;
  ELSE
    item_price := product_record.price_cents;
    item_sku := product_record.sku;
    item_name := product_record.name;
  END IF;

  -- Calculate tax
  tax_rate_val := COALESCE(product_record.vat_rate, 8.1);
  item_total := item_price * p_quantity;
  tax_amount := ROUND(item_total * (tax_rate_val / (100 + tax_rate_val)));

  -- Insert item
  INSERT INTO order_items (
    order_id, item_type, product_id, variant_id,
    item_name, item_sku, quantity,
    unit_price_cents, total_cents,
    tax_rate, tax_cents
  ) VALUES (
    p_order_id, 'product', p_product_id, p_variant_id,
    item_name, item_sku, p_quantity,
    item_price, item_total,
    tax_rate_val, tax_amount
  )
  RETURNING id INTO new_item_id;

  -- Update order totals
  PERFORM recalculate_order_totals(p_order_id);

  RETURN new_item_id;
END;
$$ LANGUAGE plpgsql;

-- ============================================
-- FUNCTION: Add voucher to order
-- ============================================
CREATE OR REPLACE FUNCTION add_voucher_to_order(
  p_order_id UUID,
  p_value_cents INTEGER,
  p_recipient_email TEXT,
  p_recipient_name TEXT DEFAULT NULL,
  p_personal_message TEXT DEFAULT NULL
)
RETURNS UUID AS $$
DECLARE
  new_item_id UUID;
  item_total INTEGER;
BEGIN
  item_total := p_value_cents;

  -- Insert voucher item (no tax on vouchers typically)
  INSERT INTO order_items (
    order_id, item_type, item_name, quantity,
    unit_price_cents, total_cents,
    voucher_recipient_email, voucher_recipient_name, voucher_message
  ) VALUES (
    p_order_id, 'voucher', 'Geschenkgutschein ' || (p_value_cents / 100) || ' CHF', 1,
    p_value_cents, item_total,
    p_recipient_email, p_recipient_name, p_personal_message
  )
  RETURNING id INTO new_item_id;

  -- Update order totals
  PERFORM recalculate_order_totals(p_order_id);

  RETURN new_item_id;
END;
$$ LANGUAGE plpgsql;

-- ============================================
-- FUNCTION: Recalculate order totals
-- ============================================
CREATE OR REPLACE FUNCTION recalculate_order_totals(p_order_id UUID)
RETURNS VOID AS $$
DECLARE
  order_record RECORD;
  totals RECORD;
BEGIN
  -- Get order
  SELECT * INTO order_record FROM orders WHERE id = p_order_id;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'Order not found';
  END IF;

  -- Calculate totals from items
  SELECT
    COALESCE(SUM(total_cents), 0) AS subtotal,
    COALESCE(SUM(discount_cents), 0) AS discount,
    COALESCE(SUM(tax_cents), 0) AS tax
  INTO totals
  FROM order_items
  WHERE order_id = p_order_id;

  -- Update order
  UPDATE orders
  SET
    subtotal_cents = totals.subtotal,
    discount_cents = order_record.discount_cents + totals.discount,
    tax_cents = totals.tax,
    total_cents = totals.subtotal - order_record.discount_cents - totals.discount
                  - COALESCE(order_record.voucher_discount_cents, 0)
                  + COALESCE(order_record.shipping_cents, 0)
  WHERE id = p_order_id;
END;
$$ LANGUAGE plpgsql;

-- ============================================
-- FUNCTION: Apply voucher to order
-- ============================================
CREATE OR REPLACE FUNCTION apply_voucher_to_order(
  p_order_id UUID,
  p_voucher_code TEXT
)
RETURNS INTEGER AS $$
DECLARE
  order_record RECORD;
  voucher_result RECORD;
  discount_amount INTEGER;
BEGIN
  -- Get order
  SELECT * INTO order_record FROM orders WHERE id = p_order_id FOR UPDATE;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'Order not found';
  END IF;

  IF order_record.status != 'pending' THEN
    RAISE EXCEPTION 'Cannot apply voucher to non-pending order';
  END IF;

  -- Validate voucher
  SELECT * INTO voucher_result
  FROM validate_voucher(order_record.salon_id, p_voucher_code);

  IF NOT voucher_result.is_valid THEN
    RAISE EXCEPTION 'Invalid voucher: %', voucher_result.invalid_reason;
  END IF;

  -- Calculate discount (max of voucher value or order total)
  discount_amount := LEAST(
    voucher_result.remaining_value_cents,
    order_record.total_cents + COALESCE(order_record.voucher_discount_cents, 0)
  );

  -- Update order
  UPDATE orders
  SET
    voucher_id = voucher_result.voucher_id,
    voucher_discount_cents = discount_amount,
    total_cents = total_cents - discount_amount + COALESCE(voucher_discount_cents, 0)
  WHERE id = p_order_id;

  RETURN discount_amount;
END;
$$ LANGUAGE plpgsql;

-- ============================================
-- FUNCTION: Update order status
-- ============================================
CREATE OR REPLACE FUNCTION update_order_status(
  p_order_id UUID,
  p_new_status order_status,
  p_changed_by UUID DEFAULT NULL,
  p_notes TEXT DEFAULT NULL
)
RETURNS BOOLEAN AS $$
DECLARE
  order_record RECORD;
BEGIN
  -- Get and lock order
  SELECT * INTO order_record
  FROM orders
  WHERE id = p_order_id
  FOR UPDATE;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Order not found';
  END IF;

  -- Record history
  INSERT INTO order_status_history (order_id, previous_status, new_status, changed_by, notes)
  VALUES (p_order_id, order_record.status, p_new_status, p_changed_by, p_notes);

  -- Update order
  UPDATE orders
  SET
    status = p_new_status,
    completed_at = CASE WHEN p_new_status = 'completed' THEN NOW() ELSE completed_at END,
    cancelled_at = CASE WHEN p_new_status = 'cancelled' THEN NOW() ELSE cancelled_at END,
    shipped_at = CASE WHEN p_new_status = 'shipped' THEN NOW() ELSE shipped_at END
  WHERE id = p_order_id;

  RETURN true;
END;
$$ LANGUAGE plpgsql;

-- ============================================
-- VIEW: Orders with customer info
-- ============================================
CREATE VIEW v_orders_with_details AS
SELECT
  o.*,
  c.first_name || ' ' || c.last_name AS customer_full_name,
  (o.subtotal_cents::DECIMAL / 100) AS subtotal_chf,
  (o.total_cents::DECIMAL / 100) AS total_chf,
  (o.shipping_cents::DECIMAL / 100) AS shipping_chf,
  (
    SELECT COUNT(*) FROM order_items oi WHERE oi.order_id = o.id
  ) AS item_count
FROM orders o
LEFT JOIN customers c ON o.customer_id = c.id;

COMMENT ON VIEW v_orders_with_details IS 'Orders with computed fields';

-- ============================================
-- VIEW: Recent orders
-- ============================================
CREATE VIEW v_recent_orders AS
SELECT *
FROM v_orders_with_details
WHERE created_at >= NOW() - INTERVAL '30 days'
ORDER BY created_at DESC;

COMMENT ON VIEW v_recent_orders IS 'Orders from last 30 days';
-- ============================================
-- SCHNITTWERK Database Schema
-- Migration: 00008_payments.sql
-- Description: Payments, refunds, Stripe integration
-- ============================================

-- ============================================
-- PAYMENTS TABLE
-- All payment transactions
-- ============================================
CREATE TABLE payments (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  salon_id UUID NOT NULL REFERENCES salons(id) ON DELETE CASCADE,

  -- Reference to what was paid for
  reference_type TEXT NOT NULL,
  reference_id UUID NOT NULL,
  -- reference_type: 'order', 'appointment', 'deposit'
  -- reference_id: orders.id, appointments.id, etc.

  -- Payment details
  amount_cents INTEGER NOT NULL,
  currency TEXT NOT NULL DEFAULT 'CHF',

  -- Payment method
  payment_method payment_method NOT NULL,

  -- Status
  status payment_status NOT NULL DEFAULT 'pending',

  -- Stripe integration
  stripe_payment_intent_id TEXT,
  stripe_charge_id TEXT,
  stripe_customer_id TEXT,

  -- Payment method details (card info snapshot)
  payment_method_details JSONB,
  -- Format: { "type": "card", "brand": "visa", "last4": "4242", "exp_month": 12, "exp_year": 2025 }

  -- Error tracking
  error_code TEXT,
  error_message TEXT,

  -- Metadata
  metadata JSONB DEFAULT '{}',

  -- Timestamps
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  succeeded_at TIMESTAMPTZ,
  failed_at TIMESTAMPTZ,

  -- Constraints
  CONSTRAINT positive_payment_amount CHECK (amount_cents > 0)
);

COMMENT ON TABLE payments IS 'Payment transactions';
COMMENT ON COLUMN payments.reference_type IS 'Type of entity being paid for';
COMMENT ON COLUMN payments.reference_id IS 'ID of the entity being paid for';
COMMENT ON COLUMN payments.stripe_payment_intent_id IS 'Stripe PaymentIntent ID';
COMMENT ON COLUMN payments.payment_method_details IS 'Payment method details snapshot';

-- Indexes
CREATE INDEX idx_payments_salon ON payments(salon_id);
CREATE INDEX idx_payments_reference ON payments(reference_type, reference_id);
CREATE INDEX idx_payments_status ON payments(salon_id, status);
CREATE INDEX idx_payments_stripe_pi ON payments(stripe_payment_intent_id);
CREATE INDEX idx_payments_date ON payments(salon_id, created_at);

-- Apply updated_at trigger
CREATE TRIGGER update_payments_updated_at
  BEFORE UPDATE ON payments
  FOR EACH ROW
  EXECUTE FUNCTION update_updated_at_column();

-- ============================================
-- REFUNDS TABLE
-- Track refunds for payments
-- ============================================
CREATE TABLE refunds (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  payment_id UUID NOT NULL REFERENCES payments(id) ON DELETE CASCADE,
  salon_id UUID NOT NULL REFERENCES salons(id) ON DELETE CASCADE,

  -- Refund amount
  amount_cents INTEGER NOT NULL,

  -- Status
  status payment_status NOT NULL DEFAULT 'pending',

  -- Reason
  reason TEXT,

  -- Stripe integration
  stripe_refund_id TEXT,

  -- Who initiated
  initiated_by UUID REFERENCES profiles(id),

  -- Timestamps
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  succeeded_at TIMESTAMPTZ,
  failed_at TIMESTAMPTZ,

  -- Constraints
  CONSTRAINT positive_refund_amount CHECK (amount_cents > 0)
);

COMMENT ON TABLE refunds IS 'Payment refund records';

-- Indexes
CREATE INDEX idx_refunds_payment ON refunds(payment_id);
CREATE INDEX idx_refunds_salon ON refunds(salon_id);
CREATE INDEX idx_refunds_stripe ON refunds(stripe_refund_id);

-- ============================================
-- STRIPE_WEBHOOKS_LOG TABLE
-- Log all Stripe webhook events
-- ============================================
CREATE TABLE stripe_webhooks_log (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),

  -- Event info
  stripe_event_id TEXT NOT NULL UNIQUE,
  event_type TEXT NOT NULL,

  -- Processing
  processed BOOLEAN DEFAULT false,
  processed_at TIMESTAMPTZ,
  error TEXT,

  -- Raw payload
  payload JSONB NOT NULL,

  -- Timestamps
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

COMMENT ON TABLE stripe_webhooks_log IS 'Stripe webhook event log';
COMMENT ON COLUMN stripe_webhooks_log.stripe_event_id IS 'Stripe event ID for idempotency';

-- Indexes
CREATE INDEX idx_stripe_webhooks_event_id ON stripe_webhooks_log(stripe_event_id);
CREATE INDEX idx_stripe_webhooks_type ON stripe_webhooks_log(event_type);
CREATE INDEX idx_stripe_webhooks_processed ON stripe_webhooks_log(processed) WHERE processed = false;

-- ============================================
-- DAILY_SALES TABLE
-- Aggregated daily sales for reporting
-- ============================================
CREATE TABLE daily_sales (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  salon_id UUID NOT NULL REFERENCES salons(id) ON DELETE CASCADE,

  -- Date
  date DATE NOT NULL,

  -- Totals
  total_revenue_cents INTEGER DEFAULT 0,
  total_orders INTEGER DEFAULT 0,
  total_appointments INTEGER DEFAULT 0,

  -- Breakdown by payment method
  cash_cents INTEGER DEFAULT 0,
  card_cents INTEGER DEFAULT 0,
  twint_cents INTEGER DEFAULT 0,
  voucher_cents INTEGER DEFAULT 0,

  -- Refunds
  refunds_cents INTEGER DEFAULT 0,
  refunds_count INTEGER DEFAULT 0,

  -- Net
  net_revenue_cents INTEGER DEFAULT 0,

  -- Tax collected
  tax_collected_cents INTEGER DEFAULT 0,

  -- Timestamps
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),

  -- Constraints
  CONSTRAINT unique_daily_sales_per_salon UNIQUE (salon_id, date)
);

COMMENT ON TABLE daily_sales IS 'Aggregated daily sales for reporting';

-- Indexes
CREATE INDEX idx_daily_sales_salon ON daily_sales(salon_id);
CREATE INDEX idx_daily_sales_date ON daily_sales(salon_id, date);

-- Apply updated_at trigger
CREATE TRIGGER update_daily_sales_updated_at
  BEFORE UPDATE ON daily_sales
  FOR EACH ROW
  EXECUTE FUNCTION update_updated_at_column();

-- ============================================
-- FUNCTION: Record payment
-- ============================================
CREATE OR REPLACE FUNCTION record_payment(
  p_salon_id UUID,
  p_reference_type TEXT,
  p_reference_id UUID,
  p_amount_cents INTEGER,
  p_payment_method payment_method,
  p_stripe_payment_intent_id TEXT DEFAULT NULL,
  p_metadata JSONB DEFAULT '{}'
)
RETURNS UUID AS $$
DECLARE
  new_payment_id UUID;
BEGIN
  INSERT INTO payments (
    salon_id, reference_type, reference_id,
    amount_cents, payment_method, stripe_payment_intent_id, metadata
  ) VALUES (
    p_salon_id, p_reference_type, p_reference_id,
    p_amount_cents, p_payment_method, p_stripe_payment_intent_id, p_metadata
  )
  RETURNING id INTO new_payment_id;

  RETURN new_payment_id;
END;
$$ LANGUAGE plpgsql;

-- ============================================
-- FUNCTION: Confirm payment success
-- ============================================
CREATE OR REPLACE FUNCTION confirm_payment_success(
  p_payment_id UUID,
  p_stripe_charge_id TEXT DEFAULT NULL,
  p_payment_method_details JSONB DEFAULT NULL
)
RETURNS BOOLEAN AS $$
DECLARE
  payment_record RECORD;
BEGIN
  -- Get and lock payment
  SELECT * INTO payment_record
  FROM payments
  WHERE id = p_payment_id
  FOR UPDATE;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Payment not found';
  END IF;

  IF payment_record.status = 'succeeded' THEN
    -- Already succeeded, idempotent return
    RETURN true;
  END IF;

  -- Update payment
  UPDATE payments
  SET
    status = 'succeeded',
    stripe_charge_id = COALESCE(p_stripe_charge_id, stripe_charge_id),
    payment_method_details = COALESCE(p_payment_method_details, payment_method_details),
    succeeded_at = NOW()
  WHERE id = p_payment_id;

  -- Update related entity based on reference_type
  IF payment_record.reference_type = 'order' THEN
    PERFORM update_order_status(payment_record.reference_id, 'paid', NULL, 'Payment confirmed');
  ELSIF payment_record.reference_type = 'appointment' THEN
    PERFORM confirm_appointment(payment_record.reference_id, NULL);
  END IF;

  -- Update daily sales
  PERFORM update_daily_sales(payment_record.salon_id, CURRENT_DATE);

  RETURN true;
END;
$$ LANGUAGE plpgsql;

-- ============================================
-- FUNCTION: Record payment failure
-- ============================================
CREATE OR REPLACE FUNCTION record_payment_failure(
  p_payment_id UUID,
  p_error_code TEXT DEFAULT NULL,
  p_error_message TEXT DEFAULT NULL
)
RETURNS BOOLEAN AS $$
BEGIN
  UPDATE payments
  SET
    status = 'failed',
    error_code = p_error_code,
    error_message = p_error_message,
    failed_at = NOW()
  WHERE id = p_payment_id;

  RETURN true;
END;
$$ LANGUAGE plpgsql;

-- ============================================
-- FUNCTION: Process refund
-- ============================================
CREATE OR REPLACE FUNCTION process_refund(
  p_payment_id UUID,
  p_amount_cents INTEGER,
  p_reason TEXT DEFAULT NULL,
  p_initiated_by UUID DEFAULT NULL,
  p_stripe_refund_id TEXT DEFAULT NULL
)
RETURNS UUID AS $$
DECLARE
  payment_record RECORD;
  new_refund_id UUID;
  total_refunded INTEGER;
BEGIN
  -- Get payment
  SELECT * INTO payment_record
  FROM payments
  WHERE id = p_payment_id;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Payment not found';
  END IF;

  IF payment_record.status != 'succeeded' THEN
    RAISE EXCEPTION 'Can only refund successful payments';
  END IF;

  -- Check total refunds don't exceed payment
  SELECT COALESCE(SUM(amount_cents), 0) INTO total_refunded
  FROM refunds
  WHERE payment_id = p_payment_id AND status = 'succeeded';

  IF total_refunded + p_amount_cents > payment_record.amount_cents THEN
    RAISE EXCEPTION 'Refund amount exceeds remaining payment value';
  END IF;

  -- Create refund record
  INSERT INTO refunds (
    payment_id, salon_id, amount_cents, reason, initiated_by, stripe_refund_id
  ) VALUES (
    p_payment_id, payment_record.salon_id, p_amount_cents, p_reason, p_initiated_by, p_stripe_refund_id
  )
  RETURNING id INTO new_refund_id;

  RETURN new_refund_id;
END;
$$ LANGUAGE plpgsql;

-- ============================================
-- FUNCTION: Confirm refund success
-- ============================================
CREATE OR REPLACE FUNCTION confirm_refund_success(p_refund_id UUID)
RETURNS BOOLEAN AS $$
DECLARE
  refund_record RECORD;
  payment_record RECORD;
  total_refunded INTEGER;
BEGIN
  -- Get refund
  SELECT * INTO refund_record FROM refunds WHERE id = p_refund_id;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'Refund not found';
  END IF;

  -- Update refund status
  UPDATE refunds
  SET status = 'succeeded', succeeded_at = NOW()
  WHERE id = p_refund_id;

  -- Check if fully refunded
  SELECT * INTO payment_record FROM payments WHERE id = refund_record.payment_id;

  SELECT COALESCE(SUM(amount_cents), 0) INTO total_refunded
  FROM refunds
  WHERE payment_id = refund_record.payment_id AND status = 'succeeded';

  IF total_refunded >= payment_record.amount_cents THEN
    UPDATE payments SET status = 'refunded' WHERE id = refund_record.payment_id;
  ELSIF total_refunded > 0 THEN
    UPDATE payments SET status = 'partially_refunded' WHERE id = refund_record.payment_id;
  END IF;

  -- Update daily sales
  PERFORM update_daily_sales(refund_record.salon_id, CURRENT_DATE);

  RETURN true;
END;
$$ LANGUAGE plpgsql;

-- ============================================
-- FUNCTION: Update daily sales aggregation
-- ============================================
CREATE OR REPLACE FUNCTION update_daily_sales(p_salon_id UUID, p_date DATE)
RETURNS VOID AS $$
DECLARE
  revenue_data RECORD;
  refund_data RECORD;
BEGIN
  -- Calculate revenue from payments
  SELECT
    COALESCE(SUM(amount_cents), 0) AS total,
    COALESCE(SUM(CASE WHEN payment_method = 'cash' THEN amount_cents ELSE 0 END), 0) AS cash,
    COALESCE(SUM(CASE WHEN payment_method IN ('stripe_card', 'terminal') THEN amount_cents ELSE 0 END), 0) AS card,
    COALESCE(SUM(CASE WHEN payment_method = 'stripe_twint' THEN amount_cents ELSE 0 END), 0) AS twint,
    COALESCE(SUM(CASE WHEN payment_method = 'voucher' THEN amount_cents ELSE 0 END), 0) AS voucher,
    COUNT(*) AS payment_count
  INTO revenue_data
  FROM payments
  WHERE salon_id = p_salon_id
    AND DATE(succeeded_at AT TIME ZONE 'Europe/Zurich') = p_date
    AND status = 'succeeded';

  -- Calculate refunds
  SELECT
    COALESCE(SUM(amount_cents), 0) AS total,
    COUNT(*) AS refund_count
  INTO refund_data
  FROM refunds
  WHERE salon_id = p_salon_id
    AND DATE(succeeded_at AT TIME ZONE 'Europe/Zurich') = p_date
    AND status = 'succeeded';

  -- Upsert daily sales
  INSERT INTO daily_sales (
    salon_id, date,
    total_revenue_cents, cash_cents, card_cents, twint_cents, voucher_cents,
    refunds_cents, refunds_count, net_revenue_cents
  ) VALUES (
    p_salon_id, p_date,
    revenue_data.total, revenue_data.cash, revenue_data.card, revenue_data.twint, revenue_data.voucher,
    refund_data.total, refund_data.refund_count,
    revenue_data.total - refund_data.total
  )
  ON CONFLICT (salon_id, date) DO UPDATE SET
    total_revenue_cents = EXCLUDED.total_revenue_cents,
    cash_cents = EXCLUDED.cash_cents,
    card_cents = EXCLUDED.card_cents,
    twint_cents = EXCLUDED.twint_cents,
    voucher_cents = EXCLUDED.voucher_cents,
    refunds_cents = EXCLUDED.refunds_cents,
    refunds_count = EXCLUDED.refunds_count,
    net_revenue_cents = EXCLUDED.net_revenue_cents,
    updated_at = NOW();
END;
$$ LANGUAGE plpgsql;

-- ============================================
-- VIEW: Payment summary
-- ============================================
CREATE VIEW v_payment_summary AS
SELECT
  p.*,
  (p.amount_cents::DECIMAL / 100) AS amount_chf,
  o.order_number,
  c.first_name || ' ' || c.last_name AS customer_name
FROM payments p
LEFT JOIN orders o ON p.reference_type = 'order' AND p.reference_id = o.id
LEFT JOIN customers c ON o.customer_id = c.id;

COMMENT ON VIEW v_payment_summary IS 'Payments with related order info';

-- ============================================
-- VIEW: Monthly revenue
-- ============================================
CREATE VIEW v_monthly_revenue AS
SELECT
  salon_id,
  DATE_TRUNC('month', date) AS month,
  SUM(total_revenue_cents) AS total_revenue_cents,
  SUM(net_revenue_cents) AS net_revenue_cents,
  SUM(refunds_cents) AS total_refunds_cents,
  SUM(total_orders) AS total_orders,
  SUM(total_appointments) AS total_appointments,
  (SUM(total_revenue_cents)::DECIMAL / 100) AS total_revenue_chf,
  (SUM(net_revenue_cents)::DECIMAL / 100) AS net_revenue_chf
FROM daily_sales
GROUP BY salon_id, DATE_TRUNC('month', date);

COMMENT ON VIEW v_monthly_revenue IS 'Monthly aggregated revenue';
