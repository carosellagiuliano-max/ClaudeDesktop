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

-- ============================================
-- VIEW: Recent orders
-- ============================================

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

-- ============================================
-- VIEW: Monthly revenue
-- ============================================

-- ============================================
-- SCHNITTWERK Database Schema
-- Migration: 00009_loyalty.sql
-- Description: Loyalty program, points, tiers
-- ============================================

-- ============================================
-- LOYALTY_PROGRAMS TABLE
-- Salon loyalty program configuration
-- ============================================
CREATE TABLE loyalty_programs (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  salon_id UUID NOT NULL REFERENCES salons(id) ON DELETE CASCADE,

  -- Program Info
  name TEXT NOT NULL DEFAULT 'Treuepunkte',
  description TEXT,

  -- Points configuration
  points_per_chf INTEGER DEFAULT 1,
  points_value_cents INTEGER DEFAULT 1,

  -- Earning rules
  earn_on_services BOOLEAN DEFAULT true,
  earn_on_products BOOLEAN DEFAULT true,
  earn_on_vouchers BOOLEAN DEFAULT false,

  -- Redemption rules
  min_points_to_redeem INTEGER DEFAULT 100,
  max_discount_percent INTEGER DEFAULT 100,

  -- Birthday bonus
  birthday_bonus_points INTEGER DEFAULT 0,
  birthday_bonus_days_before INTEGER DEFAULT 7,

  -- Status
  is_active BOOLEAN NOT NULL DEFAULT true,

  -- Timestamps
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),

  -- Constraints
  CONSTRAINT unique_loyalty_program_per_salon UNIQUE (salon_id)
);

COMMENT ON TABLE loyalty_programs IS 'Salon loyalty program settings';
COMMENT ON COLUMN loyalty_programs.points_per_chf IS 'Points earned per CHF spent';
COMMENT ON COLUMN loyalty_programs.points_value_cents IS 'Value of 1 point in cents';
COMMENT ON COLUMN loyalty_programs.birthday_bonus_points IS 'Bonus points on birthday';

-- Indexes
CREATE INDEX idx_loyalty_programs_salon ON loyalty_programs(salon_id);

-- Apply updated_at trigger
CREATE TRIGGER update_loyalty_programs_updated_at
  BEFORE UPDATE ON loyalty_programs
  FOR EACH ROW
  EXECUTE FUNCTION update_updated_at_column();

-- ============================================
-- LOYALTY_TIERS TABLE
-- Loyalty tier definitions
-- ============================================
CREATE TABLE loyalty_tiers (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  program_id UUID NOT NULL REFERENCES loyalty_programs(id) ON DELETE CASCADE,

  -- Tier Info
  name TEXT NOT NULL,
  description TEXT,
  icon TEXT,
  color TEXT,

  -- Requirements
  min_points INTEGER NOT NULL DEFAULT 0,
  min_annual_spend_cents INTEGER DEFAULT 0,

  -- Benefits
  points_multiplier DECIMAL(3,2) DEFAULT 1.00,
  discount_percent INTEGER DEFAULT 0,
  free_service_after_visits INTEGER,
  priority_booking BOOLEAN DEFAULT false,

  -- Display
  sort_order INTEGER DEFAULT 0,

  -- Timestamps
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

COMMENT ON TABLE loyalty_tiers IS 'Loyalty tier levels with benefits';
COMMENT ON COLUMN loyalty_tiers.points_multiplier IS 'Multiplier for earned points (e.g., 1.5x)';
COMMENT ON COLUMN loyalty_tiers.free_service_after_visits IS 'Free service after N visits';

-- Indexes
CREATE INDEX idx_loyalty_tiers_program ON loyalty_tiers(program_id);

-- ============================================
-- CUSTOMER_LOYALTY TABLE
-- Customer loyalty balances
-- ============================================
CREATE TABLE customer_loyalty (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  customer_id UUID NOT NULL REFERENCES customers(id) ON DELETE CASCADE,
  program_id UUID NOT NULL REFERENCES loyalty_programs(id) ON DELETE CASCADE,

  -- Current balance
  points_balance INTEGER DEFAULT 0,
  lifetime_points INTEGER DEFAULT 0,

  -- Tier
  current_tier_id UUID REFERENCES loyalty_tiers(id),

  -- Annual tracking (for tier qualification)
  annual_spend_cents INTEGER DEFAULT 0,
  annual_visits INTEGER DEFAULT 0,
  annual_period_start DATE,

  -- Timestamps
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),

  -- Constraints
  CONSTRAINT unique_customer_loyalty UNIQUE (customer_id, program_id),
  CONSTRAINT non_negative_balance CHECK (points_balance >= 0)
);

COMMENT ON TABLE customer_loyalty IS 'Customer loyalty program membership';
COMMENT ON COLUMN customer_loyalty.points_balance IS 'Current redeemable points';
COMMENT ON COLUMN customer_loyalty.lifetime_points IS 'Total points earned all-time';

-- Indexes
CREATE INDEX idx_customer_loyalty_customer ON customer_loyalty(customer_id);
CREATE INDEX idx_customer_loyalty_program ON customer_loyalty(program_id);
CREATE INDEX idx_customer_loyalty_tier ON customer_loyalty(current_tier_id);

-- Apply updated_at trigger
CREATE TRIGGER update_customer_loyalty_updated_at
  BEFORE UPDATE ON customer_loyalty
  FOR EACH ROW
  EXECUTE FUNCTION update_updated_at_column();

-- ============================================
-- LOYALTY_TRANSACTIONS TABLE
-- Points transactions (earn/redeem)
-- ============================================
CREATE TABLE loyalty_transactions (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  customer_loyalty_id UUID NOT NULL REFERENCES customer_loyalty(id) ON DELETE CASCADE,

  -- Transaction type
  transaction_type TEXT NOT NULL,
  -- Types: 'earn_purchase', 'earn_bonus', 'earn_birthday', 'redeem', 'adjustment', 'expire'

  -- Points
  points INTEGER NOT NULL,
  balance_before INTEGER NOT NULL,
  balance_after INTEGER NOT NULL,

  -- Reference
  reference_type TEXT,
  reference_id UUID,
  -- e.g., reference_type: 'order', reference_id: orders.id

  -- Description
  description TEXT,

  -- Metadata
  metadata JSONB DEFAULT '{}',

  -- Who processed
  processed_by UUID REFERENCES profiles(id),

  -- Timestamps
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),

  -- Expiry (for earned points)
  expires_at TIMESTAMPTZ
);

COMMENT ON TABLE loyalty_transactions IS 'Points earn/redeem transactions';
COMMENT ON COLUMN loyalty_transactions.points IS 'Positive for earn, negative for redeem';

-- Indexes
CREATE INDEX idx_loyalty_trans_customer ON loyalty_transactions(customer_loyalty_id);
CREATE INDEX idx_loyalty_trans_type ON loyalty_transactions(transaction_type);
CREATE INDEX idx_loyalty_trans_reference ON loyalty_transactions(reference_type, reference_id);
CREATE INDEX idx_loyalty_trans_date ON loyalty_transactions(created_at);
CREATE INDEX idx_loyalty_trans_expiry ON loyalty_transactions(expires_at) WHERE expires_at IS NOT NULL;

-- ============================================
-- FUNCTION: Initialize customer loyalty
-- ============================================
CREATE OR REPLACE FUNCTION initialize_customer_loyalty(
  p_customer_id UUID,
  p_salon_id UUID
)
RETURNS UUID AS $$
DECLARE
  program_record RECORD;
  new_loyalty_id UUID;
  base_tier_id UUID;
BEGIN
  -- Get loyalty program
  SELECT * INTO program_record
  FROM loyalty_programs
  WHERE salon_id = p_salon_id AND is_active = true;

  IF NOT FOUND THEN
    RETURN NULL;
  END IF;

  -- Get base tier
  SELECT id INTO base_tier_id
  FROM loyalty_tiers
  WHERE program_id = program_record.id
  ORDER BY min_points ASC
  LIMIT 1;

  -- Create customer loyalty record
  INSERT INTO customer_loyalty (
    customer_id, program_id, current_tier_id,
    annual_period_start
  ) VALUES (
    p_customer_id, program_record.id, base_tier_id,
    DATE_TRUNC('year', NOW())
  )
  ON CONFLICT (customer_id, program_id) DO NOTHING
  RETURNING id INTO new_loyalty_id;

  RETURN new_loyalty_id;
END;
$$ LANGUAGE plpgsql;

-- ============================================
-- FUNCTION: Earn loyalty points
-- ============================================
CREATE OR REPLACE FUNCTION earn_loyalty_points(
  p_customer_id UUID,
  p_salon_id UUID,
  p_amount_cents INTEGER,
  p_reference_type TEXT DEFAULT NULL,
  p_reference_id UUID DEFAULT NULL,
  p_description TEXT DEFAULT NULL
)
RETURNS INTEGER AS $$
DECLARE
  loyalty_record RECORD;
  program_record RECORD;
  tier_record RECORD;
  points_to_earn INTEGER;
  multiplier DECIMAL(3,2);
BEGIN
  -- Get or create customer loyalty
  SELECT cl.*, lp.points_per_chf
  INTO loyalty_record
  FROM customer_loyalty cl
  JOIN loyalty_programs lp ON cl.program_id = lp.id
  WHERE cl.customer_id = p_customer_id;

  IF NOT FOUND THEN
    PERFORM initialize_customer_loyalty(p_customer_id, p_salon_id);

    SELECT cl.*, lp.points_per_chf
    INTO loyalty_record
    FROM customer_loyalty cl
    JOIN loyalty_programs lp ON cl.program_id = lp.id
    WHERE cl.customer_id = p_customer_id;

    IF NOT FOUND THEN
      RETURN 0;
    END IF;
  END IF;

  -- Get tier multiplier
  IF loyalty_record.current_tier_id IS NOT NULL THEN
    SELECT points_multiplier INTO multiplier
    FROM loyalty_tiers
    WHERE id = loyalty_record.current_tier_id;
  END IF;
  multiplier := COALESCE(multiplier, 1.00);

  -- Calculate points
  points_to_earn := FLOOR((p_amount_cents / 100.0) * loyalty_record.points_per_chf * multiplier);

  IF points_to_earn <= 0 THEN
    RETURN 0;
  END IF;

  -- Record transaction
  INSERT INTO loyalty_transactions (
    customer_loyalty_id, transaction_type,
    points, balance_before, balance_after,
    reference_type, reference_id, description,
    expires_at
  ) VALUES (
    loyalty_record.id, 'earn_purchase',
    points_to_earn, loyalty_record.points_balance, loyalty_record.points_balance + points_to_earn,
    p_reference_type, p_reference_id, COALESCE(p_description, 'Points earned from purchase'),
    NOW() + INTERVAL '2 years'
  );

  -- Update balance
  UPDATE customer_loyalty
  SET
    points_balance = points_balance + points_to_earn,
    lifetime_points = lifetime_points + points_to_earn,
    annual_spend_cents = annual_spend_cents + p_amount_cents
  WHERE id = loyalty_record.id;

  -- Check for tier upgrade
  PERFORM check_tier_upgrade(loyalty_record.id);

  RETURN points_to_earn;
END;
$$ LANGUAGE plpgsql;

-- ============================================
-- FUNCTION: Redeem loyalty points
-- ============================================
CREATE OR REPLACE FUNCTION redeem_loyalty_points(
  p_customer_id UUID,
  p_points_to_redeem INTEGER,
  p_reference_type TEXT DEFAULT NULL,
  p_reference_id UUID DEFAULT NULL,
  p_description TEXT DEFAULT NULL
)
RETURNS INTEGER AS $$
DECLARE
  loyalty_record RECORD;
  program_record RECORD;
  discount_cents INTEGER;
BEGIN
  -- Get customer loyalty
  SELECT cl.*, lp.points_value_cents, lp.min_points_to_redeem
  INTO loyalty_record
  FROM customer_loyalty cl
  JOIN loyalty_programs lp ON cl.program_id = lp.id
  WHERE cl.customer_id = p_customer_id
  FOR UPDATE;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Customer not enrolled in loyalty program';
  END IF;

  -- Validate points
  IF p_points_to_redeem < loyalty_record.min_points_to_redeem THEN
    RAISE EXCEPTION 'Minimum redemption is % points', loyalty_record.min_points_to_redeem;
  END IF;

  IF p_points_to_redeem > loyalty_record.points_balance THEN
    RAISE EXCEPTION 'Insufficient points balance';
  END IF;

  -- Calculate discount value
  discount_cents := p_points_to_redeem * loyalty_record.points_value_cents;

  -- Record transaction
  INSERT INTO loyalty_transactions (
    customer_loyalty_id, transaction_type,
    points, balance_before, balance_after,
    reference_type, reference_id, description
  ) VALUES (
    loyalty_record.id, 'redeem',
    -p_points_to_redeem, loyalty_record.points_balance, loyalty_record.points_balance - p_points_to_redeem,
    p_reference_type, p_reference_id, COALESCE(p_description, 'Points redeemed')
  );

  -- Update balance
  UPDATE customer_loyalty
  SET points_balance = points_balance - p_points_to_redeem
  WHERE id = loyalty_record.id;

  RETURN discount_cents;
END;
$$ LANGUAGE plpgsql;

-- ============================================
-- FUNCTION: Check and apply tier upgrade
-- ============================================
CREATE OR REPLACE FUNCTION check_tier_upgrade(p_customer_loyalty_id UUID)
RETURNS BOOLEAN AS $$
DECLARE
  loyalty_record RECORD;
  new_tier RECORD;
  upgraded BOOLEAN := false;
BEGIN
  -- Get current loyalty status
  SELECT * INTO loyalty_record
  FROM customer_loyalty
  WHERE id = p_customer_loyalty_id;

  -- Find appropriate tier
  SELECT * INTO new_tier
  FROM loyalty_tiers
  WHERE program_id = loyalty_record.program_id
    AND min_points <= loyalty_record.lifetime_points
    AND (min_annual_spend_cents IS NULL OR min_annual_spend_cents <= loyalty_record.annual_spend_cents)
  ORDER BY min_points DESC
  LIMIT 1;

  -- Update if different
  IF new_tier.id IS DISTINCT FROM loyalty_record.current_tier_id THEN
    UPDATE customer_loyalty
    SET current_tier_id = new_tier.id
    WHERE id = p_customer_loyalty_id;
    upgraded := true;
  END IF;

  RETURN upgraded;
END;
$$ LANGUAGE plpgsql;

-- ============================================
-- FUNCTION: Award birthday bonus
-- ============================================
CREATE OR REPLACE FUNCTION award_birthday_bonus(p_customer_id UUID)
RETURNS INTEGER AS $$
DECLARE
  loyalty_record RECORD;
  program_record RECORD;
  customer_record RECORD;
  bonus_points INTEGER;
BEGIN
  -- Get customer birthday
  SELECT * INTO customer_record FROM customers WHERE id = p_customer_id;
  IF NOT FOUND OR customer_record.birthday IS NULL THEN
    RETURN 0;
  END IF;

  -- Get loyalty and program
  SELECT cl.*, lp.birthday_bonus_points
  INTO loyalty_record
  FROM customer_loyalty cl
  JOIN loyalty_programs lp ON cl.program_id = lp.id
  WHERE cl.customer_id = p_customer_id;

  IF NOT FOUND OR loyalty_record.birthday_bonus_points <= 0 THEN
    RETURN 0;
  END IF;

  bonus_points := loyalty_record.birthday_bonus_points;

  -- Check if already awarded this year
  IF EXISTS (
    SELECT 1 FROM loyalty_transactions
    WHERE customer_loyalty_id = loyalty_record.id
      AND transaction_type = 'earn_birthday'
      AND DATE_PART('year', created_at) = DATE_PART('year', NOW())
  ) THEN
    RETURN 0;
  END IF;

  -- Award bonus
  INSERT INTO loyalty_transactions (
    customer_loyalty_id, transaction_type,
    points, balance_before, balance_after,
    description, expires_at
  ) VALUES (
    loyalty_record.id, 'earn_birthday',
    bonus_points, loyalty_record.points_balance, loyalty_record.points_balance + bonus_points,
    'Geburtstagsbonus', NOW() + INTERVAL '1 year'
  );

  UPDATE customer_loyalty
  SET
    points_balance = points_balance + bonus_points,
    lifetime_points = lifetime_points + bonus_points
  WHERE id = loyalty_record.id;

  RETURN bonus_points;
END;
$$ LANGUAGE plpgsql;

-- ============================================
-- VIEW: Customer loyalty summary
-- ============================================

-- ============================================
-- VIEW: Recent loyalty transactions
-- ============================================

-- ============================================
-- SCHNITTWERK Database Schema
-- Migration: 00010_notifications.sql
-- Description: Notifications, email templates, notification preferences
-- ============================================

-- ============================================
-- NOTIFICATION_TEMPLATES TABLE
-- Email/SMS templates per salon
-- ============================================
CREATE TABLE notification_templates (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  salon_id UUID NOT NULL REFERENCES salons(id) ON DELETE CASCADE,

  -- Template Info
  name TEXT NOT NULL,
  code TEXT NOT NULL,
  -- Codes: appointment_confirmation, appointment_reminder, appointment_cancelled,
  --        order_confirmation, order_shipped, voucher_received, birthday_greeting,
  --        welcome, password_reset

  -- Channel
  channel notification_channel NOT NULL DEFAULT 'email',

  -- Email template
  subject TEXT,
  body_html TEXT,
  body_text TEXT,

  -- SMS template (shorter)
  sms_body TEXT,

  -- Variables available in template
  -- Stored as reference, e.g., ["customer_name", "appointment_date", "salon_name"]
  available_variables JSONB DEFAULT '[]',

  -- Status
  is_active BOOLEAN NOT NULL DEFAULT true,

  -- Timestamps
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),

  -- Constraints
  CONSTRAINT unique_template_code_per_salon_channel UNIQUE (salon_id, code, channel)
);

COMMENT ON TABLE notification_templates IS 'Customizable notification templates';
COMMENT ON COLUMN notification_templates.code IS 'Template identifier';
COMMENT ON COLUMN notification_templates.available_variables IS 'Variables that can be used in template';

-- Indexes
CREATE INDEX idx_notification_templates_salon ON notification_templates(salon_id);
CREATE INDEX idx_notification_templates_code ON notification_templates(salon_id, code);

-- Apply updated_at trigger
CREATE TRIGGER update_notification_templates_updated_at
  BEFORE UPDATE ON notification_templates
  FOR EACH ROW
  EXECUTE FUNCTION update_updated_at_column();

-- ============================================
-- NOTIFICATION_PREFERENCES TABLE
-- Customer notification preferences
-- ============================================
CREATE TABLE notification_preferences (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  profile_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,

  -- Preferences per category
  appointment_reminders BOOLEAN DEFAULT true,
  appointment_reminders_channel notification_channel DEFAULT 'email',

  marketing_emails BOOLEAN DEFAULT false,
  marketing_sms BOOLEAN DEFAULT false,

  order_updates BOOLEAN DEFAULT true,
  order_updates_channel notification_channel DEFAULT 'email',

  loyalty_updates BOOLEAN DEFAULT true,

  -- Reminder timing
  reminder_hours_before INTEGER DEFAULT 24,

  -- Timestamps
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),

  -- Constraints
  CONSTRAINT unique_notification_prefs_per_profile UNIQUE (profile_id)
);

COMMENT ON TABLE notification_preferences IS 'User notification preferences';
COMMENT ON COLUMN notification_preferences.reminder_hours_before IS 'Hours before appointment to send reminder';

-- Indexes
CREATE INDEX idx_notification_prefs_profile ON notification_preferences(profile_id);

-- Apply updated_at trigger
CREATE TRIGGER update_notification_prefs_updated_at
  BEFORE UPDATE ON notification_preferences
  FOR EACH ROW
  EXECUTE FUNCTION update_updated_at_column();

-- ============================================
-- NOTIFICATIONS TABLE
-- Sent/queued notifications
-- ============================================
CREATE TABLE notifications (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  salon_id UUID NOT NULL REFERENCES salons(id) ON DELETE CASCADE,
  profile_id UUID REFERENCES profiles(id) ON DELETE SET NULL,

  -- Template used
  template_id UUID REFERENCES notification_templates(id),
  template_code TEXT,

  -- Channel and recipient
  channel notification_channel NOT NULL,
  recipient_email TEXT,
  recipient_phone TEXT,

  -- Content (rendered)
  subject TEXT,
  body_html TEXT,
  body_text TEXT,

  -- Reference to related entity
  reference_type TEXT,
  reference_id UUID,

  -- Status
  status TEXT NOT NULL DEFAULT 'pending',
  -- Status: pending, sending, sent, failed, bounced

  -- Scheduling
  scheduled_for TIMESTAMPTZ,
  sent_at TIMESTAMPTZ,

  -- Error tracking
  error_message TEXT,
  retry_count INTEGER DEFAULT 0,
  max_retries INTEGER DEFAULT 3,

  -- External IDs
  external_id TEXT,

  -- Timestamps
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

COMMENT ON TABLE notifications IS 'Notification log and queue';
COMMENT ON COLUMN notifications.status IS 'Delivery status: pending, sending, sent, failed, bounced';
COMMENT ON COLUMN notifications.external_id IS 'ID from email/SMS provider';

-- Indexes
CREATE INDEX idx_notifications_salon ON notifications(salon_id);
CREATE INDEX idx_notifications_profile ON notifications(profile_id);
CREATE INDEX idx_notifications_status ON notifications(status) WHERE status IN ('pending', 'sending');
CREATE INDEX idx_notifications_scheduled ON notifications(scheduled_for) WHERE status = 'pending';
CREATE INDEX idx_notifications_reference ON notifications(reference_type, reference_id);

-- ============================================
-- SCHEDULED_REMINDERS TABLE
-- Track scheduled appointment reminders
-- ============================================
CREATE TABLE scheduled_reminders (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  appointment_id UUID NOT NULL REFERENCES appointments(id) ON DELETE CASCADE,

  -- Reminder details
  reminder_type TEXT NOT NULL DEFAULT 'appointment_reminder',
  scheduled_for TIMESTAMPTZ NOT NULL,

  -- Status
  status TEXT NOT NULL DEFAULT 'scheduled',
  -- Status: scheduled, sent, cancelled, skipped

  -- Result
  notification_id UUID REFERENCES notifications(id),
  processed_at TIMESTAMPTZ,

  -- Timestamps
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),

  -- Constraints
  CONSTRAINT unique_reminder_per_appointment_type UNIQUE (appointment_id, reminder_type)
);

COMMENT ON TABLE scheduled_reminders IS 'Scheduled appointment reminders';

-- Indexes
CREATE INDEX idx_scheduled_reminders_appointment ON scheduled_reminders(appointment_id);
CREATE INDEX idx_scheduled_reminders_scheduled ON scheduled_reminders(scheduled_for)
  WHERE status = 'scheduled';

-- ============================================
-- FUNCTION: Create notification from template
-- ============================================
CREATE OR REPLACE FUNCTION create_notification_from_template(
  p_salon_id UUID,
  p_profile_id UUID,
  p_template_code TEXT,
  p_channel notification_channel,
  p_variables JSONB DEFAULT '{}',
  p_scheduled_for TIMESTAMPTZ DEFAULT NULL,
  p_reference_type TEXT DEFAULT NULL,
  p_reference_id UUID DEFAULT NULL
)
RETURNS UUID AS $$
DECLARE
  template_record RECORD;
  profile_record RECORD;
  new_notification_id UUID;
  rendered_subject TEXT;
  rendered_body_html TEXT;
  rendered_body_text TEXT;
  recipient_email TEXT;
  recipient_phone TEXT;
  var_key TEXT;
  var_value TEXT;
BEGIN
  -- Get template
  SELECT * INTO template_record
  FROM notification_templates
  WHERE salon_id = p_salon_id
    AND code = p_template_code
    AND channel = p_channel
    AND is_active = true;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Template not found: %', p_template_code;
  END IF;

  -- Get profile for recipient info
  SELECT * INTO profile_record FROM profiles WHERE id = p_profile_id;

  recipient_email := profile_record.email;
  recipient_phone := profile_record.phone;

  -- Render template (simple variable replacement)
  rendered_subject := template_record.subject;
  rendered_body_html := template_record.body_html;
  rendered_body_text := COALESCE(template_record.body_text, template_record.sms_body);

  FOR var_key, var_value IN SELECT * FROM jsonb_each_text(p_variables)
  LOOP
    rendered_subject := REPLACE(rendered_subject, '{{' || var_key || '}}', var_value);
    rendered_body_html := REPLACE(rendered_body_html, '{{' || var_key || '}}', var_value);
    rendered_body_text := REPLACE(rendered_body_text, '{{' || var_key || '}}', var_value);
  END LOOP;

  -- Create notification
  INSERT INTO notifications (
    salon_id, profile_id, template_id, template_code,
    channel, recipient_email, recipient_phone,
    subject, body_html, body_text,
    reference_type, reference_id,
    scheduled_for, status
  ) VALUES (
    p_salon_id, p_profile_id, template_record.id, p_template_code,
    p_channel, recipient_email, recipient_phone,
    rendered_subject, rendered_body_html, rendered_body_text,
    p_reference_type, p_reference_id,
    p_scheduled_for, CASE WHEN p_scheduled_for IS NULL THEN 'pending' ELSE 'scheduled' END
  )
  RETURNING id INTO new_notification_id;

  RETURN new_notification_id;
END;
$$ LANGUAGE plpgsql;

-- ============================================
-- FUNCTION: Schedule appointment reminder
-- ============================================
CREATE OR REPLACE FUNCTION schedule_appointment_reminder(
  p_appointment_id UUID
)
RETURNS UUID AS $$
DECLARE
  appt_record RECORD;
  customer_record RECORD;
  prefs_record RECORD;
  reminder_time TIMESTAMPTZ;
  new_reminder_id UUID;
BEGIN
  -- Get appointment
  SELECT * INTO appt_record
  FROM appointments
  WHERE id = p_appointment_id;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Appointment not found';
  END IF;

  -- Get customer
  SELECT c.*, p.id AS profile_id INTO customer_record
  FROM customers c
  JOIN profiles p ON c.profile_id = p.id
  WHERE c.id = appt_record.customer_id;

  -- Get notification preferences
  SELECT * INTO prefs_record
  FROM notification_preferences
  WHERE profile_id = customer_record.profile_id;

  -- Default to 24 hours if no preference
  IF NOT FOUND OR NOT prefs_record.appointment_reminders THEN
    RETURN NULL;
  END IF;

  -- Calculate reminder time
  reminder_time := appt_record.start_time - (COALESCE(prefs_record.reminder_hours_before, 24) || ' hours')::INTERVAL;

  -- Don't schedule if already passed
  IF reminder_time <= NOW() THEN
    RETURN NULL;
  END IF;

  -- Create scheduled reminder
  INSERT INTO scheduled_reminders (
    appointment_id, reminder_type, scheduled_for
  ) VALUES (
    p_appointment_id, 'appointment_reminder', reminder_time
  )
  ON CONFLICT (appointment_id, reminder_type) DO UPDATE
  SET scheduled_for = reminder_time, status = 'scheduled'
  RETURNING id INTO new_reminder_id;

  RETURN new_reminder_id;
END;
$$ LANGUAGE plpgsql;

-- ============================================
-- FUNCTION: Process scheduled reminders
-- (Called by cron job)
-- ============================================
CREATE OR REPLACE FUNCTION process_scheduled_reminders()
RETURNS INTEGER AS $$
DECLARE
  reminder RECORD;
  processed_count INTEGER := 0;
  notification_id UUID;
  appt RECORD;
  customer RECORD;
  variables JSONB;
BEGIN
  FOR reminder IN
    SELECT sr.*, a.salon_id, a.start_time, a.customer_id, a.staff_id
    FROM scheduled_reminders sr
    JOIN appointments a ON sr.appointment_id = a.id
    WHERE sr.status = 'scheduled'
      AND sr.scheduled_for <= NOW()
      AND a.status = 'confirmed'
    FOR UPDATE OF sr SKIP LOCKED
  LOOP
    -- Get customer
    SELECT c.*, p.email, p.phone
    INTO customer
    FROM customers c
    JOIN profiles p ON c.profile_id = p.id
    WHERE c.id = reminder.customer_id;

    -- Build variables
    variables := jsonb_build_object(
      'customer_name', customer.first_name,
      'appointment_date', TO_CHAR(reminder.start_time AT TIME ZONE 'Europe/Zurich', 'DD.MM.YYYY'),
      'appointment_time', TO_CHAR(reminder.start_time AT TIME ZONE 'Europe/Zurich', 'HH24:MI')
    );

    -- Create notification
    notification_id := create_notification_from_template(
      reminder.salon_id,
      customer.profile_id,
      'appointment_reminder',
      'email',
      variables,
      NULL,
      'appointment',
      reminder.appointment_id
    );

    -- Update reminder
    UPDATE scheduled_reminders
    SET status = 'sent', notification_id = notification_id, processed_at = NOW()
    WHERE id = reminder.id;

    processed_count := processed_count + 1;
  END LOOP;

  RETURN processed_count;
END;
$$ LANGUAGE plpgsql;

-- ============================================
-- FUNCTION: Cancel scheduled reminders for appointment
-- ============================================
CREATE OR REPLACE FUNCTION cancel_appointment_reminders(p_appointment_id UUID)
RETURNS INTEGER AS $$
DECLARE
  updated_count INTEGER;
BEGIN
  UPDATE scheduled_reminders
  SET status = 'cancelled'
  WHERE appointment_id = p_appointment_id
    AND status = 'scheduled';

  GET DIAGNOSTICS updated_count = ROW_COUNT;
  RETURN updated_count;
END;
$$ LANGUAGE plpgsql;

-- ============================================
-- VIEW: Pending notifications
-- ============================================

-- ============================================
-- VIEW: Notification statistics
-- ============================================

-- ============================================
-- SCHNITTWERK Database Schema
-- Migration: 00011_consent.sql
-- Description: GDPR/DSG compliance, consent tracking
-- ============================================

-- ============================================
-- CONSENT_RECORDS TABLE
-- Track user consent for data processing
-- ============================================
CREATE TABLE consent_records (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  profile_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
  salon_id UUID REFERENCES salons(id) ON DELETE CASCADE,

  -- Consent category
  category consent_category NOT NULL,

  -- Consent status
  consented BOOLEAN NOT NULL,

  -- Version of terms consented to
  terms_version TEXT,

  -- How consent was given
  consent_method TEXT DEFAULT 'web_form',
  -- Methods: web_form, checkbox, verbal, written, api

  -- IP address for audit trail
  ip_address INET,
  user_agent TEXT,

  -- Timestamps
  consented_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  expires_at TIMESTAMPTZ,
  revoked_at TIMESTAMPTZ
);

COMMENT ON TABLE consent_records IS 'GDPR/DSG consent records';
COMMENT ON COLUMN consent_records.category IS 'What the consent is for';
COMMENT ON COLUMN consent_records.terms_version IS 'Version of privacy policy/terms';
COMMENT ON COLUMN consent_records.consent_method IS 'How consent was obtained';

-- Indexes
CREATE INDEX idx_consent_records_profile ON consent_records(profile_id);
CREATE INDEX idx_consent_records_salon ON consent_records(salon_id);
CREATE INDEX idx_consent_records_category ON consent_records(profile_id, category);
CREATE INDEX idx_consent_records_active ON consent_records(profile_id, category)
  WHERE consented = true AND revoked_at IS NULL;

-- ============================================
-- DATA_EXPORT_REQUESTS TABLE
-- Track GDPR data export requests
-- ============================================
CREATE TABLE data_export_requests (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  profile_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,

  -- Request status
  status TEXT NOT NULL DEFAULT 'pending',
  -- Status: pending, processing, completed, failed, expired

  -- Request details
  request_type TEXT NOT NULL DEFAULT 'export',
  -- Types: export, delete

  -- Processing
  started_at TIMESTAMPTZ,
  completed_at TIMESTAMPTZ,

  -- Result
  export_file_url TEXT,
  export_expires_at TIMESTAMPTZ,

  -- Error
  error_message TEXT,

  -- Request metadata
  ip_address INET,
  user_agent TEXT,

  -- Timestamps
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

COMMENT ON TABLE data_export_requests IS 'GDPR data export/deletion requests';
COMMENT ON COLUMN data_export_requests.status IS 'Request processing status';

-- Indexes
CREATE INDEX idx_data_export_requests_profile ON data_export_requests(profile_id);
CREATE INDEX idx_data_export_requests_status ON data_export_requests(status)
  WHERE status IN ('pending', 'processing');

-- ============================================
-- DATA_RETENTION_POLICIES TABLE
-- Configure data retention per salon
-- ============================================
CREATE TABLE data_retention_policies (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  salon_id UUID NOT NULL REFERENCES salons(id) ON DELETE CASCADE,

  -- Data type
  data_type TEXT NOT NULL,
  -- Types: appointments, orders, customers_inactive, audit_logs, notifications

  -- Retention period in days
  retention_days INTEGER NOT NULL,

  -- What to do after retention period
  action TEXT NOT NULL DEFAULT 'anonymize',
  -- Actions: delete, anonymize, archive

  -- Status
  is_active BOOLEAN NOT NULL DEFAULT true,

  -- Timestamps
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),

  -- Constraints
  CONSTRAINT unique_retention_policy UNIQUE (salon_id, data_type),
  CONSTRAINT positive_retention CHECK (retention_days > 0)
);

COMMENT ON TABLE data_retention_policies IS 'Data retention configuration';
COMMENT ON COLUMN data_retention_policies.action IS 'What to do with expired data';

-- Indexes
CREATE INDEX idx_data_retention_salon ON data_retention_policies(salon_id);

-- Apply updated_at trigger
CREATE TRIGGER update_data_retention_updated_at
  BEFORE UPDATE ON data_retention_policies
  FOR EACH ROW
  EXECUTE FUNCTION update_updated_at_column();

-- ============================================
-- FUNCTION: Check if consent is given
-- ============================================
CREATE OR REPLACE FUNCTION has_consent(
  p_profile_id UUID,
  p_category consent_category,
  p_salon_id UUID DEFAULT NULL
)
RETURNS BOOLEAN AS $$
  SELECT EXISTS (
    SELECT 1 FROM consent_records
    WHERE profile_id = p_profile_id
      AND category = p_category
      AND consented = true
      AND revoked_at IS NULL
      AND (expires_at IS NULL OR expires_at > NOW())
      AND (p_salon_id IS NULL OR salon_id = p_salon_id OR salon_id IS NULL)
    ORDER BY consented_at DESC
    LIMIT 1
  );
$$ LANGUAGE sql STABLE;

-- ============================================
-- FUNCTION: Record consent
-- ============================================
CREATE OR REPLACE FUNCTION record_consent(
  p_profile_id UUID,
  p_category consent_category,
  p_consented BOOLEAN,
  p_salon_id UUID DEFAULT NULL,
  p_terms_version TEXT DEFAULT NULL,
  p_consent_method TEXT DEFAULT 'web_form',
  p_ip_address INET DEFAULT NULL,
  p_user_agent TEXT DEFAULT NULL
)
RETURNS UUID AS $$
DECLARE
  new_consent_id UUID;
BEGIN
  -- Revoke previous consent for this category
  UPDATE consent_records
  SET revoked_at = NOW()
  WHERE profile_id = p_profile_id
    AND category = p_category
    AND (p_salon_id IS NULL OR salon_id = p_salon_id)
    AND revoked_at IS NULL;

  -- Record new consent
  INSERT INTO consent_records (
    profile_id, salon_id, category, consented,
    terms_version, consent_method, ip_address, user_agent
  ) VALUES (
    p_profile_id, p_salon_id, p_category, p_consented,
    p_terms_version, p_consent_method, p_ip_address, p_user_agent
  )
  RETURNING id INTO new_consent_id;

  RETURN new_consent_id;
END;
$$ LANGUAGE plpgsql;

-- ============================================
-- FUNCTION: Revoke consent
-- ============================================
CREATE OR REPLACE FUNCTION revoke_consent(
  p_profile_id UUID,
  p_category consent_category,
  p_salon_id UUID DEFAULT NULL
)
RETURNS BOOLEAN AS $$
DECLARE
  updated_count INTEGER;
BEGIN
  UPDATE consent_records
  SET revoked_at = NOW()
  WHERE profile_id = p_profile_id
    AND category = p_category
    AND (p_salon_id IS NULL OR salon_id = p_salon_id)
    AND revoked_at IS NULL;

  GET DIAGNOSTICS updated_count = ROW_COUNT;
  RETURN updated_count > 0;
