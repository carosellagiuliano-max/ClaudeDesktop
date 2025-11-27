-- ============================================
-- Contact Inquiries Table
-- ============================================

CREATE TYPE contact_inquiry_status AS ENUM ('new', 'in_progress', 'resolved', 'spam');

CREATE TABLE IF NOT EXISTS contact_inquiries (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  salon_id UUID NOT NULL REFERENCES salons(id) ON DELETE CASCADE,

  first_name TEXT NOT NULL,
  last_name TEXT NOT NULL,
  email TEXT NOT NULL,
  phone TEXT,
  reason TEXT NOT NULL,
  message TEXT NOT NULL,

  status contact_inquiry_status NOT NULL DEFAULT 'new',
  assigned_to UUID REFERENCES profiles(id),
  notes TEXT,

  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  resolved_at TIMESTAMPTZ
);

-- Index for fast lookup
CREATE INDEX idx_contact_inquiries_salon_status ON contact_inquiries(salon_id, status);
CREATE INDEX idx_contact_inquiries_created_at ON contact_inquiries(created_at DESC);

-- RLS
ALTER TABLE contact_inquiries ENABLE ROW LEVEL SECURITY;

-- Only admins and managers can view contact inquiries
CREATE POLICY "Staff can view contact inquiries" ON contact_inquiries
  FOR SELECT
  USING (
    EXISTS (
      SELECT 1 FROM user_roles
      WHERE user_roles.profile_id = auth.uid()
        AND user_roles.salon_id = contact_inquiries.salon_id
        AND user_roles.role_name IN ('admin', 'manager')
    )
  );

-- Only admins and managers can update
CREATE POLICY "Staff can update contact inquiries" ON contact_inquiries
  FOR UPDATE
  USING (
    EXISTS (
      SELECT 1 FROM user_roles
      WHERE user_roles.profile_id = auth.uid()
        AND user_roles.salon_id = contact_inquiries.salon_id
        AND user_roles.role_name IN ('admin', 'manager')
    )
  );

-- Service role can insert (from server actions)
CREATE POLICY "Service role can insert contact inquiries" ON contact_inquiries
  FOR INSERT
  WITH CHECK (true);

-- Trigger for updated_at
CREATE TRIGGER contact_inquiries_updated_at
  BEFORE UPDATE ON contact_inquiries
  FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
-- ============================================
-- SCHNITTWERK Database Schema
-- Migration: 00016_booking_enhancements.sql
-- Description: Add columns for booking flow and customer portal
-- ============================================

-- ============================================
-- ADD COLUMNS TO APPOINTMENTS
-- ============================================

-- Add booking number for customer reference
ALTER TABLE appointments
ADD COLUMN IF NOT EXISTS booking_number TEXT UNIQUE;

-- Add guest customer info (for non-registered bookings)
ALTER TABLE appointments
ADD COLUMN IF NOT EXISTS customer_name TEXT,
ADD COLUMN IF NOT EXISTS customer_email TEXT,
ADD COLUMN IF NOT EXISTS customer_phone TEXT;

-- Make customer_id nullable for guest bookings
ALTER TABLE appointments
ALTER COLUMN customer_id DROP NOT NULL;

-- Add notes column for customer messages
ALTER TABLE appointments
ADD COLUMN IF NOT EXISTS notes TEXT;

-- Add payment method
DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'payment_method') THEN
    CREATE TYPE payment_method AS ENUM ('cash', 'card', 'stripe_card', 'twint');
  END IF;
END$$;

ALTER TABLE appointments
ADD COLUMN IF NOT EXISTS payment_method TEXT DEFAULT 'cash';

COMMENT ON COLUMN appointments.booking_number IS 'Human-readable booking reference (e.g., SW-ABC123)';
COMMENT ON COLUMN appointments.customer_name IS 'Guest customer name (when not registered)';
COMMENT ON COLUMN appointments.customer_email IS 'Guest customer email (when not registered)';
COMMENT ON COLUMN appointments.customer_phone IS 'Guest customer phone (when not registered)';

-- Create index for booking number
CREATE INDEX IF NOT EXISTS idx_appointments_booking_number ON appointments(booking_number)
WHERE booking_number IS NOT NULL;

-- Create index for guest email lookup
CREATE INDEX IF NOT EXISTS idx_appointments_customer_email ON appointments(customer_email)
WHERE customer_email IS NOT NULL;

-- ============================================
-- RLS POLICIES FOR CUSTOMER ACCESS
-- ============================================

-- Drop existing policies if they exist (to avoid conflicts)
DROP POLICY IF EXISTS "Customers can view own appointments" ON appointments;
DROP POLICY IF EXISTS "Customers can cancel own appointments" ON appointments;
DROP POLICY IF EXISTS "Service role full access appointments" ON appointments;

-- Enable RLS on appointments if not already enabled
ALTER TABLE appointments ENABLE ROW LEVEL SECURITY;

-- Customers can view their own appointments (via customer_id or email)
CREATE POLICY "Customers can view own appointments"
ON appointments FOR SELECT
USING (
  auth.uid() IS NOT NULL AND (
    -- Via customer_id linkage
    customer_id IN (
      SELECT c.id FROM customers c
      JOIN profiles p ON c.profile_id = p.id
      WHERE p.id = auth.uid()
    )
    -- Or via direct email match (guest bookings)
    OR customer_email = (SELECT email FROM profiles WHERE id = auth.uid())
  )
);

-- Customers can update (cancel) their own appointments
CREATE POLICY "Customers can cancel own appointments"
ON appointments FOR UPDATE
USING (
  auth.uid() IS NOT NULL AND (
    customer_id IN (
      SELECT c.id FROM customers c
      JOIN profiles p ON c.profile_id = p.id
      WHERE p.id = auth.uid()
    )
    OR customer_email = (SELECT email FROM profiles WHERE id = auth.uid())
  )
);

-- Service role (server actions) has full access
CREATE POLICY "Service role full access appointments"
ON appointments FOR ALL
TO service_role
USING (true)
WITH CHECK (true);

-- Staff can view and manage salon appointments
CREATE POLICY "Staff can view salon appointments"
ON appointments FOR SELECT
USING (
  salon_id IN (
    SELECT ur.salon_id FROM user_roles ur
    WHERE ur.profile_id = auth.uid()
    AND ur.role_name IN ('admin', 'manager', 'mitarbeiter')
  )
);

CREATE POLICY "Staff can manage salon appointments"
ON appointments FOR ALL
USING (
  salon_id IN (
    SELECT ur.salon_id FROM user_roles ur
    WHERE ur.profile_id = auth.uid()
    AND ur.role_name IN ('admin', 'manager', 'mitarbeiter')
  )
);

-- ============================================
-- RLS POLICIES FOR APPOINTMENT_SERVICES
-- ============================================

DROP POLICY IF EXISTS "Customers can view appointment services" ON appointment_services;
DROP POLICY IF EXISTS "Service role full access appointment_services" ON appointment_services;

ALTER TABLE appointment_services ENABLE ROW LEVEL SECURITY;

-- Anyone can read appointment services for their appointments
CREATE POLICY "Customers can view appointment services"
ON appointment_services FOR SELECT
USING (
  appointment_id IN (
    SELECT id FROM appointments
    WHERE auth.uid() IS NOT NULL AND (
      customer_id IN (
        SELECT c.id FROM customers c
        JOIN profiles p ON c.profile_id = p.id
        WHERE p.id = auth.uid()
      )
      OR customer_email = (SELECT email FROM profiles WHERE id = auth.uid())
    )
  )
);

-- Service role has full access
CREATE POLICY "Service role full access appointment_services"
ON appointment_services FOR ALL
TO service_role
USING (true)
WITH CHECK (true);

-- Staff can view appointment services
CREATE POLICY "Staff can view appointment services"
ON appointment_services FOR SELECT
USING (
  appointment_id IN (
    SELECT id FROM appointments a
    WHERE a.salon_id IN (
      SELECT ur.salon_id FROM user_roles ur
      WHERE ur.profile_id = auth.uid()
      AND ur.role_name IN ('admin', 'manager', 'mitarbeiter')
    )
  )
);

-- Staff can manage appointment services
CREATE POLICY "Staff can manage appointment services"
ON appointment_services FOR ALL
USING (
  appointment_id IN (
    SELECT id FROM appointments a
    WHERE a.salon_id IN (
      SELECT ur.salon_id FROM user_roles ur
      WHERE ur.profile_id = auth.uid()
      AND ur.role_name IN ('admin', 'manager', 'mitarbeiter')
    )
  )
);
-- ============================================
-- SCHNITTWERK Database Schema
-- Migration: 00017_cron_jobs.sql
-- Description: Setup Cron Jobs for automated tasks
-- ============================================

-- Enable pg_cron extension (if not already enabled)
-- Note: This requires Supabase Pro plan or self-hosted
-- For Free tier, use Supabase Edge Function with external scheduler

-- ============================================
-- CLEANUP EXPIRED RESERVATIONS (every 5 minutes)
-- ============================================

-- Function to clean up expired reservations
CREATE OR REPLACE FUNCTION cleanup_expired_reservations()
RETURNS INTEGER
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  expired_count INTEGER;
BEGIN
  -- Update all expired reservations to cancelled
  UPDATE appointments
  SET
    status = 'cancelled',
    cancelled_at = NOW(),
    cancellation_reason = 'Reservierung abgelaufen (Timeout)'
  WHERE
    status = 'reserved'
    AND reservation_expires_at < NOW();

  -- Get count of updated rows
  GET DIAGNOSTICS expired_count = ROW_COUNT;

  -- Log if any were cleaned up
  IF expired_count > 0 THEN
    INSERT INTO audit_logs (action, entity_type, details)
    VALUES (
      'cleanup_expired_reservations',
      'appointment',
      jsonb_build_object(
        'count', expired_count,
        'timestamp', NOW()
      )
    );
  END IF;

  RETURN expired_count;
END;
$$;

-- ============================================
-- AUDIT_LOGS TABLE (if not exists)
-- ============================================

CREATE TABLE IF NOT EXISTS audit_logs (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  action TEXT NOT NULL,
  entity_type TEXT,
  entity_id UUID,
  actor_id UUID REFERENCES profiles(id),
  actor_type TEXT DEFAULT 'system',
  details JSONB,
  ip_address INET,
  user_agent TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_audit_logs_action ON audit_logs(action);
CREATE INDEX IF NOT EXISTS idx_audit_logs_entity ON audit_logs(entity_type, entity_id);
CREATE INDEX IF NOT EXISTS idx_audit_logs_actor ON audit_logs(actor_id);
CREATE INDEX IF NOT EXISTS idx_audit_logs_created_at ON audit_logs(created_at);

COMMENT ON TABLE audit_logs IS 'Audit trail for critical actions';

-- ============================================
-- LEGAL DOCUMENT ACCEPTANCE (for booking/checkout)
-- ============================================

CREATE TABLE IF NOT EXISTS legal_document_acceptances (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  customer_id UUID REFERENCES customers(id),
  profile_id UUID REFERENCES profiles(id),
  legal_document_id UUID REFERENCES legal_documents(id),
  legal_document_type TEXT NOT NULL,
  legal_document_version INTEGER NOT NULL,
  accepted_at TIMESTAMPTZ DEFAULT NOW(),
  ip_address INET,
  user_agent TEXT,
  appointment_id UUID REFERENCES appointments(id),
  order_id UUID REFERENCES orders(id),
  CONSTRAINT legal_acceptance_customer_or_profile CHECK (
    customer_id IS NOT NULL OR profile_id IS NOT NULL
  )
);

CREATE INDEX IF NOT EXISTS idx_legal_acceptances_customer ON legal_document_acceptances(customer_id);
CREATE INDEX IF NOT EXISTS idx_legal_acceptances_profile ON legal_document_acceptances(profile_id);
CREATE INDEX IF NOT EXISTS idx_legal_acceptances_appointment ON legal_document_acceptances(appointment_id);

-- ============================================
-- NO-SHOW FEE TRACKING
-- ============================================

-- Add no-show fee column to appointments
ALTER TABLE appointments
ADD COLUMN IF NOT EXISTS no_show_fee_cents INTEGER DEFAULT 0,
ADD COLUMN IF NOT EXISTS no_show_fee_charged_at TIMESTAMPTZ,
ADD COLUMN IF NOT EXISTS no_show_fee_payment_id UUID;

COMMENT ON COLUMN appointments.no_show_fee_cents IS 'No-show fee amount charged to customer';
COMMENT ON COLUMN appointments.no_show_fee_charged_at IS 'When the no-show fee was charged';

-- ============================================
-- IDEMPOTENCY KEYS TABLE (for payment operations)
-- ============================================

CREATE TABLE IF NOT EXISTS idempotency_keys (
  key TEXT PRIMARY KEY,
  operation TEXT NOT NULL,
  entity_type TEXT NOT NULL,
  entity_id UUID,
  result JSONB,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  expires_at TIMESTAMPTZ DEFAULT NOW() + INTERVAL '24 hours'
);

CREATE INDEX IF NOT EXISTS idx_idempotency_keys_expires ON idempotency_keys(expires_at);

COMMENT ON TABLE idempotency_keys IS 'Ensures idempotent operations for payments and bookings';

-- Function to check/set idempotency
CREATE OR REPLACE FUNCTION check_idempotency(
  p_key TEXT,
  p_operation TEXT,
  p_entity_type TEXT
)
RETURNS JSONB
LANGUAGE plpgsql
AS $$
DECLARE
  existing_result JSONB;
BEGIN
  -- Check for existing key
  SELECT result INTO existing_result
  FROM idempotency_keys
  WHERE key = p_key AND expires_at > NOW();

  -- If found, return existing result
  IF existing_result IS NOT NULL THEN
    RETURN jsonb_build_object(
      'exists', true,
      'result', existing_result
    );
  END IF;

  -- Create new key entry (without result yet)
  INSERT INTO idempotency_keys (key, operation, entity_type)
  VALUES (p_key, p_operation, p_entity_type)
  ON CONFLICT (key) DO NOTHING;

  RETURN jsonb_build_object('exists', false);
END;
$$;

-- Function to set idempotency result
CREATE OR REPLACE FUNCTION set_idempotency_result(
  p_key TEXT,
  p_entity_id UUID,
  p_result JSONB
)
RETURNS VOID
LANGUAGE plpgsql
AS $$
BEGIN
  UPDATE idempotency_keys
  SET entity_id = p_entity_id, result = p_result
  WHERE key = p_key;
END;
$$;

-- Cleanup old idempotency keys (daily)
CREATE OR REPLACE FUNCTION cleanup_idempotency_keys()
RETURNS INTEGER
LANGUAGE plpgsql
AS $$
DECLARE
  deleted_count INTEGER;
BEGIN
  DELETE FROM idempotency_keys WHERE expires_at < NOW();
  GET DIAGNOSTICS deleted_count = ROW_COUNT;
  RETURN deleted_count;
END;
$$;

-- ============================================
-- RLS POLICIES
-- ============================================

ALTER TABLE audit_logs ENABLE ROW LEVEL SECURITY;
ALTER TABLE legal_document_acceptances ENABLE ROW LEVEL SECURITY;
ALTER TABLE idempotency_keys ENABLE ROW LEVEL SECURITY;

-- Audit logs: only service role
CREATE POLICY "Service role access audit_logs"
ON audit_logs FOR ALL TO service_role
USING (true) WITH CHECK (true);

-- Legal acceptances: users can see their own
CREATE POLICY "Users can view own legal acceptances"
ON legal_document_acceptances FOR SELECT
USING (profile_id = auth.uid());

CREATE POLICY "Service role access legal_acceptances"
ON legal_document_acceptances FOR ALL TO service_role
USING (true) WITH CHECK (true);

-- Idempotency keys: only service role
CREATE POLICY "Service role access idempotency_keys"
ON idempotency_keys FOR ALL TO service_role
USING (true) WITH CHECK (true);
-- ============================================
-- SCHNITTWERK Database Schema
-- Migration: 00018_payment_enhancements.sql
-- Description: Stripe webhook support, payment status
-- ============================================

-- ============================================
-- PAYMENT STATUS ENUM (if not exists)
-- ============================================
DO $$ BEGIN
  CREATE TYPE order_payment_status AS ENUM (
    'pending',
    'processing',
    'succeeded',
    'failed',
    'refunded',
    'partially_refunded'
  );
EXCEPTION
  WHEN duplicate_object THEN NULL;
END $$;

-- ============================================
-- ADD PAYMENT COLUMNS TO ORDERS
-- ============================================

-- Payment status tracking
ALTER TABLE orders ADD COLUMN IF NOT EXISTS payment_status order_payment_status DEFAULT 'pending';

-- Stripe integration fields
ALTER TABLE orders ADD COLUMN IF NOT EXISTS stripe_session_id TEXT;
ALTER TABLE orders ADD COLUMN IF NOT EXISTS stripe_payment_intent_id TEXT;
ALTER TABLE orders ADD COLUMN IF NOT EXISTS stripe_charge_id TEXT;

-- Payment timestamps
ALTER TABLE orders ADD COLUMN IF NOT EXISTS paid_at TIMESTAMPTZ;

-- Cancellation details
ALTER TABLE orders ADD COLUMN IF NOT EXISTS cancellation_reason TEXT;

-- Payment error tracking
ALTER TABLE orders ADD COLUMN IF NOT EXISTS payment_error TEXT;

-- Refund tracking
ALTER TABLE orders ADD COLUMN IF NOT EXISTS refunded_amount_cents INTEGER DEFAULT 0;
ALTER TABLE orders ADD COLUMN IF NOT EXISTS refunded_at TIMESTAMPTZ;

-- Dispute tracking
ALTER TABLE orders ADD COLUMN IF NOT EXISTS has_dispute BOOLEAN DEFAULT false;
ALTER TABLE orders ADD COLUMN IF NOT EXISTS dispute_reason TEXT;

-- Create indexes for new columns
CREATE INDEX IF NOT EXISTS idx_orders_stripe_session ON orders(stripe_session_id) WHERE stripe_session_id IS NOT NULL;
CREATE INDEX IF NOT EXISTS idx_orders_stripe_pi ON orders(stripe_payment_intent_id) WHERE stripe_payment_intent_id IS NOT NULL;
CREATE INDEX IF NOT EXISTS idx_orders_payment_status ON orders(salon_id, payment_status);

COMMENT ON COLUMN orders.payment_status IS 'Current payment status from Stripe';
COMMENT ON COLUMN orders.stripe_session_id IS 'Stripe Checkout Session ID';
COMMENT ON COLUMN orders.stripe_payment_intent_id IS 'Stripe PaymentIntent ID';
COMMENT ON COLUMN orders.stripe_charge_id IS 'Stripe Charge ID';

-- ============================================
-- ENHANCE VOUCHERS TABLE FOR ORDER LINKING
-- ============================================

-- Order reference for purchased vouchers
ALTER TABLE vouchers ADD COLUMN IF NOT EXISTS order_id UUID REFERENCES orders(id) ON DELETE SET NULL;
ALTER TABLE vouchers ADD COLUMN IF NOT EXISTS order_item_id UUID REFERENCES order_items(id) ON DELETE SET NULL;

-- Expiry (if not already present)
ALTER TABLE vouchers ADD COLUMN IF NOT EXISTS expires_at TIMESTAMPTZ;

-- Status for more control
ALTER TABLE vouchers ADD COLUMN IF NOT EXISTS status TEXT DEFAULT 'active';

-- Amount tracking (align naming with code)
ALTER TABLE vouchers ADD COLUMN IF NOT EXISTS amount_cents INTEGER;

-- Purchaser tracking
ALTER TABLE vouchers ADD COLUMN IF NOT EXISTS purchaser_customer_id UUID REFERENCES customers(id);

-- Update existing vouchers to have amount_cents
UPDATE vouchers SET amount_cents = initial_value_cents WHERE amount_cents IS NULL;

-- Add indexes
CREATE INDEX IF NOT EXISTS idx_vouchers_order ON vouchers(order_id) WHERE order_id IS NOT NULL;
CREATE INDEX IF NOT EXISTS idx_vouchers_status ON vouchers(salon_id, status);

COMMENT ON COLUMN vouchers.order_id IS 'Order that purchased this voucher';
COMMENT ON COLUMN vouchers.expires_at IS 'When voucher expires';
COMMENT ON COLUMN vouchers.status IS 'Voucher status: active, used, expired, cancelled';

-- ============================================
-- ADD VOUCHER TYPE TO ORDER ITEMS
-- ============================================
ALTER TABLE order_items ADD COLUMN IF NOT EXISTS voucher_type TEXT;
ALTER TABLE order_items ADD COLUMN IF NOT EXISTS recipient_email TEXT;
ALTER TABLE order_items ADD COLUMN IF NOT EXISTS recipient_name TEXT;
ALTER TABLE order_items ADD COLUMN IF NOT EXISTS personal_message TEXT;

COMMENT ON COLUMN order_items.voucher_type IS 'Type: value or service voucher';
COMMENT ON COLUMN order_items.recipient_email IS 'Voucher recipient email';
COMMENT ON COLUMN order_items.recipient_name IS 'Voucher recipient name';

-- ============================================
-- STRIPE WEBHOOKS LOG ENHANCEMENTS
-- ============================================

-- Add result tracking if not exists
ALTER TABLE stripe_webhooks_log ADD COLUMN IF NOT EXISTS processing_result TEXT;

-- ============================================
-- FUNCTION: Handle successful payment
-- Updates order status when payment succeeds
-- ============================================
CREATE OR REPLACE FUNCTION handle_payment_success(
  p_order_id UUID,
  p_stripe_session_id TEXT DEFAULT NULL,
  p_stripe_payment_intent_id TEXT DEFAULT NULL,
  p_stripe_charge_id TEXT DEFAULT NULL
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

  -- Already paid - idempotent
  IF order_record.payment_status = 'succeeded' THEN
    RETURN true;
  END IF;

  -- Update order
  UPDATE orders
  SET
    status = 'paid',
    payment_status = 'succeeded',
    stripe_session_id = COALESCE(p_stripe_session_id, stripe_session_id),
    stripe_payment_intent_id = COALESCE(p_stripe_payment_intent_id, stripe_payment_intent_id),
    stripe_charge_id = COALESCE(p_stripe_charge_id, stripe_charge_id),
    paid_at = NOW(),
    updated_at = NOW()
  WHERE id = p_order_id;

  -- Record status change
  INSERT INTO order_status_history (order_id, previous_status, new_status, notes)
  VALUES (p_order_id, order_record.status, 'paid', 'Payment succeeded via Stripe');

  RETURN true;
END;
$$ LANGUAGE plpgsql;

-- ============================================
-- FUNCTION: Generate voucher code
-- Generates unique voucher code
-- ============================================
CREATE OR REPLACE FUNCTION generate_voucher_code(p_salon_id UUID)
RETURNS TEXT AS $$
DECLARE
  chars TEXT := 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
  prefix TEXT := 'SW-';
  new_code TEXT;
  attempts INTEGER := 0;
BEGIN
  LOOP
    -- Generate code: SW-XXXX-XXXX-XXXX
    new_code := prefix;
    FOR i IN 1..3 LOOP
      FOR j IN 1..4 LOOP
        new_code := new_code || SUBSTRING(chars FROM (FLOOR(RANDOM() * LENGTH(chars)) + 1)::INT FOR 1);
      END LOOP;
      IF i < 3 THEN
        new_code := new_code || '-';
      END IF;
    END LOOP;

    -- Check uniqueness
    IF NOT EXISTS (SELECT 1 FROM vouchers WHERE salon_id = p_salon_id AND code = new_code) THEN
      RETURN new_code;
    END IF;

    attempts := attempts + 1;
    IF attempts > 100 THEN
      RAISE EXCEPTION 'Could not generate unique voucher code';
    END IF;
  END LOOP;
END;
$$ LANGUAGE plpgsql;

-- ============================================
-- FUNCTION: Create voucher from order
-- Creates voucher when order is paid
-- ============================================
CREATE OR REPLACE FUNCTION create_voucher_from_order(
  p_order_id UUID,
  p_order_item_id UUID,
  p_salon_id UUID,
  p_purchaser_customer_id UUID DEFAULT NULL,
  p_recipient_email TEXT DEFAULT NULL,
  p_recipient_name TEXT DEFAULT NULL,
  p_personal_message TEXT DEFAULT NULL,
  p_amount_cents INTEGER DEFAULT NULL,
  p_voucher_type TEXT DEFAULT 'value'
)
RETURNS UUID AS $$
DECLARE
  new_voucher_id UUID;
  new_code TEXT;
  expires_at_val TIMESTAMPTZ;
BEGIN
  -- Generate unique code
  new_code := generate_voucher_code(p_salon_id);

  -- Calculate expiry (1 year from now)
  expires_at_val := NOW() + INTERVAL '1 year';

  -- Create voucher
  INSERT INTO vouchers (
    salon_id,
    code,
    type,
    initial_value_cents,
    remaining_value_cents,
    amount_cents,
    order_id,
    order_item_id,
    purchaser_customer_id,
    purchased_by_customer_id,
    recipient_email,
    recipient_name,
    personal_message,
    status,
    valid_until,
    expires_at,
    is_active
  ) VALUES (
    p_salon_id,
    new_code,
    p_voucher_type,
    p_amount_cents,
    p_amount_cents,
    p_amount_cents,
    p_order_id,
    p_order_item_id,
    p_purchaser_customer_id,
    p_purchaser_customer_id,
    p_recipient_email,
    p_recipient_name,
    p_personal_message,
    'active',
    expires_at_val,
    expires_at_val,
    true
  )
  RETURNING id INTO new_voucher_id;

  -- Link back to order item
  UPDATE order_items
  SET voucher_id = new_voucher_id
  WHERE id = p_order_item_id;

  RETURN new_voucher_id;
END;
$$ LANGUAGE plpgsql;

-- ============================================
-- TRIGGER: Auto-update payment status
-- ============================================
CREATE OR REPLACE FUNCTION update_order_payment_status()
RETURNS TRIGGER AS $$
BEGIN
  -- Update payment_status based on status changes
  IF NEW.status = 'paid' AND OLD.status != 'paid' THEN
    NEW.payment_status := 'succeeded';
    NEW.paid_at := COALESCE(NEW.paid_at, NOW());
  ELSIF NEW.status = 'cancelled' AND NEW.payment_status IS DISTINCT FROM 'refunded' THEN
    NEW.payment_status := 'failed';
  ELSIF NEW.status = 'refunded' THEN
    NEW.payment_status := 'refunded';
    NEW.refunded_at := COALESCE(NEW.refunded_at, NOW());
  END IF;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trigger_update_order_payment_status ON orders;
CREATE TRIGGER trigger_update_order_payment_status
  BEFORE UPDATE ON orders
  FOR EACH ROW
  EXECUTE FUNCTION update_order_payment_status();
-- ============================================
-- SCHNITTWERK Database Schema
-- Migration: 00019_payment_events.sql
-- Description: Payment events tracking for webhooks
-- ============================================

-- ============================================
-- PAYMENT_EVENTS TABLE
-- Track all payment-related events (success, failure, refund, dispute)
-- ============================================
CREATE TABLE IF NOT EXISTS payment_events (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),

  -- Reference
  order_id UUID REFERENCES orders(id) ON DELETE CASCADE,
  payment_id UUID REFERENCES payments(id) ON DELETE CASCADE,

  -- Event info
  event_type TEXT NOT NULL,
  -- event_type values:
  -- 'payment_succeeded', 'payment_failed', 'payment_expired'
  -- 'refund', 'partial_refund'
  -- 'dispute_created', 'dispute_won', 'dispute_lost'
  -- 'chargeback'

  -- Amount involved (for refunds/disputes)
  amount_cents INTEGER,

  -- Stripe references
  stripe_event_id TEXT,
  stripe_payment_intent_id TEXT,
  stripe_charge_id TEXT,
  stripe_refund_id TEXT,
  stripe_dispute_id TEXT,

  -- Additional data
  metadata JSONB DEFAULT '{}',

  -- Timestamps
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

COMMENT ON TABLE payment_events IS 'Payment event log for tracking all payment-related activities';
COMMENT ON COLUMN payment_events.event_type IS 'Type of payment event';
COMMENT ON COLUMN payment_events.stripe_event_id IS 'Original Stripe webhook event ID';

-- Indexes
CREATE INDEX IF NOT EXISTS idx_payment_events_order ON payment_events(order_id);
CREATE INDEX IF NOT EXISTS idx_payment_events_payment ON payment_events(payment_id);
CREATE INDEX IF NOT EXISTS idx_payment_events_type ON payment_events(event_type);
CREATE INDEX IF NOT EXISTS idx_payment_events_stripe ON payment_events(stripe_event_id);
CREATE INDEX IF NOT EXISTS idx_payment_events_date ON payment_events(created_at);

-- RLS
ALTER TABLE payment_events ENABLE ROW LEVEL SECURITY;

-- Policy: Staff can view payment events for their salon
CREATE POLICY "Staff can view payment events"
  ON payment_events FOR SELECT
  USING (
    order_id IN (
      SELECT id FROM orders WHERE salon_id IN (
        SELECT salon_id FROM staff WHERE user_id = auth.uid()
      )
    )
    OR
    payment_id IN (
      SELECT id FROM payments WHERE salon_id IN (
        SELECT salon_id FROM staff WHERE user_id = auth.uid()
      )
    )
  );

-- Policy: System can insert payment events (service role)
CREATE POLICY "System can insert payment events"
  ON payment_events FOR INSERT
  WITH CHECK (true);
-- ============================================
-- STAFF BLOCKS TABLE
-- Time blocks where staff are unavailable
-- ============================================

CREATE TABLE IF NOT EXISTS staff_blocks (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  salon_id UUID NOT NULL REFERENCES salons(id) ON DELETE CASCADE,
  staff_id UUID NOT NULL REFERENCES staff(id) ON DELETE CASCADE,
  start_time TIMESTAMPTZ NOT NULL,
  end_time TIMESTAMPTZ NOT NULL,
  reason TEXT DEFAULT 'Blockiert',
  is_all_day BOOLEAN DEFAULT FALSE,
  is_recurring BOOLEAN DEFAULT FALSE,
  recurrence_pattern JSONB, -- For recurring blocks
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW(),
  CONSTRAINT valid_block_time CHECK (end_time > start_time)
);

-- Index for querying blocks by staff and time
CREATE INDEX IF NOT EXISTS idx_staff_blocks_staff_time
  ON staff_blocks(staff_id, start_time, end_time);

CREATE INDEX IF NOT EXISTS idx_staff_blocks_salon
  ON staff_blocks(salon_id);

-- ============================================
-- STAFF SKILLS TABLE
-- Track which services each staff member can perform
-- ============================================

CREATE TABLE IF NOT EXISTS staff_skills (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  staff_id UUID NOT NULL REFERENCES staff(id) ON DELETE CASCADE,
  service_id UUID NOT NULL REFERENCES services(id) ON DELETE CASCADE,
  proficiency_level TEXT DEFAULT 'standard' CHECK (proficiency_level IN ('beginner', 'standard', 'expert')),
  created_at TIMESTAMPTZ DEFAULT NOW(),
  UNIQUE(staff_id, service_id)
);

CREATE INDEX IF NOT EXISTS idx_staff_skills_staff ON staff_skills(staff_id);
CREATE INDEX IF NOT EXISTS idx_staff_skills_service ON staff_skills(service_id);

-- ============================================
-- STAFF WORKING HOURS TABLE
-- Regular weekly working hours for staff
-- ============================================

CREATE TABLE IF NOT EXISTS staff_working_hours (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  staff_id UUID NOT NULL REFERENCES staff(id) ON DELETE CASCADE,
  day_of_week INTEGER NOT NULL CHECK (day_of_week >= 0 AND day_of_week <= 6), -- 0=Sunday, 6=Saturday
  start_time TIME NOT NULL,
  end_time TIME NOT NULL,
  is_active BOOLEAN DEFAULT TRUE,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW(),
  UNIQUE(staff_id, day_of_week),
  CONSTRAINT valid_working_time CHECK (end_time > start_time)
);

CREATE INDEX IF NOT EXISTS idx_staff_working_hours_staff ON staff_working_hours(staff_id);

-- ============================================
-- STAFF ABSENCES TABLE
-- Planned absences (vacation, sick leave, etc.)
-- ============================================

CREATE TABLE IF NOT EXISTS staff_absences (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  salon_id UUID NOT NULL REFERENCES salons(id) ON DELETE CASCADE,
  staff_id UUID NOT NULL REFERENCES staff(id) ON DELETE CASCADE,
  start_date DATE NOT NULL,
  end_date DATE NOT NULL,
  absence_type TEXT NOT NULL DEFAULT 'vacation' CHECK (absence_type IN ('vacation', 'sick', 'personal', 'training', 'other')),
  status TEXT DEFAULT 'pending' CHECK (status IN ('pending', 'approved', 'rejected')),
  notes TEXT,
  approved_by UUID REFERENCES staff(id),
  approved_at TIMESTAMPTZ,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW(),
  CONSTRAINT valid_absence_dates CHECK (end_date >= start_date)
);

CREATE INDEX IF NOT EXISTS idx_staff_absences_staff ON staff_absences(staff_id);
CREATE INDEX IF NOT EXISTS idx_staff_absences_dates ON staff_absences(start_date, end_date);
CREATE INDEX IF NOT EXISTS idx_staff_absences_salon ON staff_absences(salon_id);

-- ============================================
-- ADD FIELDS TO STAFF TABLE
-- ============================================

-- Add additional fields to staff table if not exists
DO $$
BEGIN
  -- Employment type
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'staff' AND column_name = 'employment_type') THEN
    ALTER TABLE staff ADD COLUMN employment_type TEXT DEFAULT 'full_time' CHECK (employment_type IN ('full_time', 'part_time', 'contractor', 'apprentice'));
  END IF;

  -- Hire date
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'staff' AND column_name = 'hire_date') THEN
    ALTER TABLE staff ADD COLUMN hire_date DATE;
  END IF;

  -- Termination date
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'staff' AND column_name = 'termination_date') THEN
    ALTER TABLE staff ADD COLUMN termination_date DATE;
  END IF;

  -- Bio
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'staff' AND column_name = 'bio') THEN
    ALTER TABLE staff ADD COLUMN bio TEXT;
  END IF;

  -- Specializations
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'staff' AND column_name = 'specializations') THEN
    ALTER TABLE staff ADD COLUMN specializations TEXT[];
  END IF;
END $$;

-- ============================================
-- RLS POLICIES FOR NEW TABLES
-- ============================================

ALTER TABLE staff_blocks ENABLE ROW LEVEL SECURITY;
ALTER TABLE staff_skills ENABLE ROW LEVEL SECURITY;
ALTER TABLE staff_working_hours ENABLE ROW LEVEL SECURITY;
ALTER TABLE staff_absences ENABLE ROW LEVEL SECURITY;

-- Staff blocks policies
CREATE POLICY "Staff can view their own blocks"
  ON staff_blocks FOR SELECT
  TO authenticated
  USING (
    staff_id IN (SELECT id FROM staff WHERE user_id = auth.uid())
    OR EXISTS (
      SELECT 1 FROM staff
      WHERE user_id = auth.uid()
      AND salon_id = staff_blocks.salon_id
      AND role IN ('admin', 'manager', 'hq')
    )
  );

CREATE POLICY "Managers can manage blocks"
  ON staff_blocks FOR ALL
  TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM staff
      WHERE user_id = auth.uid()
      AND salon_id = staff_blocks.salon_id
      AND role IN ('admin', 'manager', 'hq')
    )
  );

-- Staff skills policies
CREATE POLICY "Anyone can view staff skills"
  ON staff_skills FOR SELECT
  TO authenticated
  USING (true);

CREATE POLICY "Managers can manage skills"
  ON staff_skills FOR ALL
  TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM staff s1
      JOIN staff s2 ON s1.salon_id = s2.salon_id
      WHERE s1.user_id = auth.uid()
      AND s1.role IN ('admin', 'manager', 'hq')
      AND s2.id = staff_skills.staff_id
    )
  );

-- Working hours policies
CREATE POLICY "Anyone can view working hours"
  ON staff_working_hours FOR SELECT
  TO authenticated
  USING (true);

CREATE POLICY "Managers can manage working hours"
  ON staff_working_hours FOR ALL
  TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM staff s1
      JOIN staff s2 ON s1.salon_id = s2.salon_id
      WHERE s1.user_id = auth.uid()
      AND s1.role IN ('admin', 'manager', 'hq')
      AND s2.id = staff_working_hours.staff_id
    )
  );

-- Absences policies
CREATE POLICY "Staff can view their own absences"
  ON staff_absences FOR SELECT
  TO authenticated
  USING (
    staff_id IN (SELECT id FROM staff WHERE user_id = auth.uid())
    OR EXISTS (
      SELECT 1 FROM staff
      WHERE user_id = auth.uid()
      AND salon_id = staff_absences.salon_id
      AND role IN ('admin', 'manager', 'hq')
    )
  );

CREATE POLICY "Staff can request absences"
  ON staff_absences FOR INSERT
  TO authenticated
  WITH CHECK (
    staff_id IN (SELECT id FROM staff WHERE user_id = auth.uid())
  );

CREATE POLICY "Managers can manage absences"
  ON staff_absences FOR ALL
  TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM staff
      WHERE user_id = auth.uid()
      AND salon_id = staff_absences.salon_id
      AND role IN ('admin', 'manager', 'hq')
    )
  );
-- ============================================
-- 00021: SMS Reminders & Notification Tracking
-- SCHNITTWERK Phase 8 - Notification System
-- ============================================

-- ============================================
-- 1. APPOINTMENT REMINDERS TABLE
-- Track which reminders have been sent
-- ============================================

CREATE TABLE IF NOT EXISTS appointment_reminders (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  appointment_id UUID NOT NULL REFERENCES appointments(id) ON DELETE CASCADE,
  reminder_type VARCHAR(10) NOT NULL CHECK (reminder_type IN ('24h', '1h', 'custom')),
  channel VARCHAR(10) NOT NULL DEFAULT 'sms' CHECK (channel IN ('sms', 'email', 'push')),
  message_id VARCHAR(100), -- External ID from Twilio/SendGrid
  status VARCHAR(20) DEFAULT 'sent' CHECK (status IN ('pending', 'sent', 'delivered', 'failed')),
  sent_at TIMESTAMPTZ DEFAULT NOW(),
  delivered_at TIMESTAMPTZ,
  error_message TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW(),

  -- Prevent duplicate reminders
  CONSTRAINT unique_appointment_reminder
    UNIQUE (appointment_id, reminder_type, channel)
);

-- Index for querying by appointment
CREATE INDEX IF NOT EXISTS idx_appointment_reminders_appointment
ON appointment_reminders(appointment_id);

-- Index for status tracking
CREATE INDEX IF NOT EXISTS idx_appointment_reminders_status
ON appointment_reminders(status) WHERE status != 'delivered';

-- ============================================
-- 2. NOTIFICATION LOGS TABLE
-- Central log for all notifications
-- ============================================

CREATE TABLE IF NOT EXISTS notification_logs (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  salon_id UUID REFERENCES salons(id),
  customer_id UUID REFERENCES customers(id),

  -- Notification details
  channel VARCHAR(10) NOT NULL CHECK (channel IN ('sms', 'email', 'push')),
  event_type VARCHAR(50) NOT NULL,
  recipient VARCHAR(255) NOT NULL, -- Phone or email (masked)

  -- External tracking
  external_id VARCHAR(100), -- Twilio MessageSid, etc.

  -- Status tracking
  status VARCHAR(20) DEFAULT 'sent' CHECK (status IN ('pending', 'sent', 'delivered', 'failed', 'undelivered')),

  -- Content (for debugging/audit)
  template_id VARCHAR(50),
  content_preview VARCHAR(160), -- First 160 chars

  -- Error tracking
  error_code VARCHAR(20),
  error_message TEXT,

  -- Timestamps
  sent_at TIMESTAMPTZ DEFAULT NOW(),
  delivered_at TIMESTAMPTZ,
  created_at TIMESTAMPTZ DEFAULT NOW(),

  -- Costs (for SMS billing tracking)
  segments INTEGER DEFAULT 1,
  cost_cents INTEGER -- Cost in cents
);

-- Indexes for common queries
CREATE INDEX IF NOT EXISTS idx_notification_logs_customer
ON notification_logs(customer_id);

CREATE INDEX IF NOT EXISTS idx_notification_logs_salon
ON notification_logs(salon_id);

CREATE INDEX IF NOT EXISTS idx_notification_logs_event
ON notification_logs(event_type);

CREATE INDEX IF NOT EXISTS idx_notification_logs_sent_at
ON notification_logs(sent_at DESC);

-- ============================================
-- 3. NOTIFICATION PREFERENCES TABLE
-- Customer preferences for notifications
-- ============================================

CREATE TABLE IF NOT EXISTS notification_preferences (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  customer_id UUID NOT NULL REFERENCES customers(id) ON DELETE CASCADE,

  -- Channel preferences
  sms_enabled BOOLEAN DEFAULT true,
  email_enabled BOOLEAN DEFAULT true,
  push_enabled BOOLEAN DEFAULT false,

  -- Reminder preferences
  reminder_24h BOOLEAN DEFAULT true,
  reminder_1h BOOLEAN DEFAULT true,

  -- Marketing preferences
  marketing_emails BOOLEAN DEFAULT false,
  marketing_sms BOOLEAN DEFAULT false,

  -- Timestamps
  updated_at TIMESTAMPTZ DEFAULT NOW(),
  created_at TIMESTAMPTZ DEFAULT NOW(),

  CONSTRAINT unique_customer_preferences
    UNIQUE (customer_id)
);

-- ============================================
-- 4. SMS TEMPLATES TABLE
-- Customizable SMS templates per salon
-- ============================================

CREATE TABLE IF NOT EXISTS sms_templates (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  salon_id UUID REFERENCES salons(id),

  -- Template identification
  event_type VARCHAR(50) NOT NULL,
  name VARCHAR(100) NOT NULL,

  -- Template content
  template TEXT NOT NULL,

  -- Settings
  enabled BOOLEAN DEFAULT true,

  -- Timestamps
  updated_at TIMESTAMPTZ DEFAULT NOW(),
  created_at TIMESTAMPTZ DEFAULT NOW(),

  -- Either global (salon_id NULL) or per-salon
  CONSTRAINT unique_salon_template
    UNIQUE (salon_id, event_type)
);

-- Insert default templates
INSERT INTO sms_templates (salon_id, event_type, name, template) VALUES
(NULL, 'appointment_confirmed', 'Terminbestätigung',
  'Hallo {{customerName}}, Ihr Termin bei SCHNITTWERK wurde bestätigt: {{date}} um {{time}} Uhr ({{serviceName}} mit {{staffName}}). Wir freuen uns auf Sie!'),
(NULL, 'appointment_reminder_24h', 'Terminerinnerung (24h)',
  'Hallo {{customerName}}, zur Erinnerung: Morgen um {{time}} Uhr haben Sie einen Termin bei SCHNITTWERK ({{serviceName}}). Bis morgen!'),
(NULL, 'appointment_reminder_1h', 'Terminerinnerung (1h)',
  'Hallo {{customerName}}, in einer Stunde beginnt Ihr Termin bei SCHNITTWERK ({{serviceName}} mit {{staffName}}). Wir erwarten Sie!'),
(NULL, 'appointment_cancelled', 'Termin abgesagt',
  'Hallo {{customerName}}, Ihr Termin am {{date}} um {{time}} bei SCHNITTWERK wurde storniert. Bei Fragen kontaktieren Sie uns gerne.'),
(NULL, 'appointment_no_show', 'Verpasster Termin',
  'Hallo {{customerName}}, leider haben Sie Ihren Termin am {{date}} verpasst. Bitte kontaktieren Sie uns für einen neuen Termin.'),
(NULL, 'appointment_rescheduled', 'Termin verschoben',
  'Hallo {{customerName}}, Ihr Termin wurde verschoben auf: {{date}} um {{time}} Uhr ({{serviceName}}). Bis dann!'),
(NULL, 'order_confirmed', 'Bestellung bestätigt',
  'Hallo {{customerName}}, Ihre Bestellung #{{orderNumber}} über CHF {{totalAmount}} wurde bestätigt. Vielen Dank!'),
(NULL, 'loyalty_tier_upgrade', 'Loyalty-Stufe Upgrade',
  'Herzlichen Glückwunsch {{customerName}}! Sie sind jetzt {{newTier}}-Mitglied bei SCHNITTWERK und erhalten {{discount}} Rabatt!'),
(NULL, 'waitlist_available', 'Warteliste: Platz frei',
  'Gute Nachricht {{customerName}}! Am {{date}} um {{time}} ist ein Termin für {{serviceName}} frei geworden. Jetzt buchen: {{bookingLink}}')
ON CONFLICT DO NOTHING;

-- ============================================
-- 5. RLS POLICIES
-- ============================================

-- Enable RLS
ALTER TABLE appointment_reminders ENABLE ROW LEVEL SECURITY;
ALTER TABLE notification_logs ENABLE ROW LEVEL SECURITY;
ALTER TABLE notification_preferences ENABLE ROW LEVEL SECURITY;
ALTER TABLE sms_templates ENABLE ROW LEVEL SECURITY;

-- Appointment Reminders: Admin can view all for their salon
CREATE POLICY "Admin can view appointment reminders"
ON appointment_reminders FOR SELECT
TO authenticated
USING (
  EXISTS (
    SELECT 1 FROM appointments a
    JOIN staff s ON s.id = a.staff_id
    WHERE a.id = appointment_reminders.appointment_id
    AND s.salon_id IN (
      SELECT salon_id FROM staff WHERE user_id = auth.uid()
    )
  )
);

-- Notification Logs: Admin can view for their salon
CREATE POLICY "Admin can view notification logs"
ON notification_logs FOR SELECT
TO authenticated
USING (
  salon_id IN (
    SELECT salon_id FROM staff WHERE user_id = auth.uid()
  )
);

-- Notification Preferences: Customers can manage their own
CREATE POLICY "Customers can manage own preferences"
ON notification_preferences FOR ALL
TO authenticated
USING (
  customer_id IN (
    SELECT id FROM customers WHERE user_id = auth.uid()
  )
);

-- SMS Templates: Admin can manage salon templates
CREATE POLICY "Admin can manage SMS templates"
ON sms_templates FOR ALL
TO authenticated
USING (
  salon_id IS NULL OR
  salon_id IN (
    SELECT salon_id FROM staff
    WHERE user_id = auth.uid()
    AND role IN ('admin', 'manager')
  )
);

-- ============================================
-- 6. TRIGGER FOR PREFERENCE UPDATES
-- ============================================

CREATE OR REPLACE FUNCTION update_notification_preferences_timestamp()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER notification_preferences_updated
BEFORE UPDATE ON notification_preferences
FOR EACH ROW
EXECUTE FUNCTION update_notification_preferences_timestamp();

-- ============================================
-- 7. ANALYTICS VIEW
-- ============================================

CREATE OR REPLACE VIEW notification_analytics AS
SELECT
  salon_id,
  channel,
  event_type,
  DATE(sent_at) as date,
  COUNT(*) as total_sent,
  COUNT(*) FILTER (WHERE status = 'delivered') as delivered,
  COUNT(*) FILTER (WHERE status = 'failed') as failed,
  AVG(segments) as avg_segments,
  SUM(cost_cents) as total_cost_cents
FROM notification_logs
GROUP BY salon_id, channel, event_type, DATE(sent_at);

COMMENT ON TABLE appointment_reminders IS 'Tracks sent appointment reminders to prevent duplicates';
COMMENT ON TABLE notification_logs IS 'Central log for all notification activity';
COMMENT ON TABLE notification_preferences IS 'Customer notification channel preferences';
COMMENT ON TABLE sms_templates IS 'Customizable SMS templates per event type';
-- ============================================
-- 00022: Waitlist Feature
-- SCHNITTWERK Phase 8 - Waitlist for Booked Slots
-- ============================================

-- ============================================
-- 1. WAITLIST TABLE
-- Track customers waiting for slots
-- ============================================

CREATE TABLE IF NOT EXISTS waitlist (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  salon_id UUID NOT NULL REFERENCES salons(id) ON DELETE CASCADE,
  customer_id UUID NOT NULL REFERENCES customers(id) ON DELETE CASCADE,

  -- Service preferences
  service_id UUID NOT NULL REFERENCES services(id),
  staff_id UUID REFERENCES staff(id), -- NULL = any staff

  -- Requested time
  requested_date DATE NOT NULL,
  requested_time_start TIME, -- NULL = any time that day
  requested_time_end TIME,
  flexible_time BOOLEAN DEFAULT false,

  -- Status tracking
  status VARCHAR(20) DEFAULT 'waiting' CHECK (status IN (
    'waiting',    -- Actively waiting
    'notified',   -- Slot became available, customer notified
    'booked',     -- Customer booked the available slot
    'expired',    -- Notification expired without booking
    'cancelled'   -- Customer cancelled from waitlist
  )),

  -- Notification tracking
  notified_at TIMESTAMPTZ,
  notification_expires_at TIMESTAMPTZ,
  notification_channel VARCHAR(10), -- 'sms', 'email', 'push'

  -- Booking reference (if booked)
  appointment_id UUID REFERENCES appointments(id),

  -- Position (for fair ordering)
  position INTEGER,

  -- Timestamps
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW(),

  -- Prevent duplicate entries
  CONSTRAINT unique_waitlist_entry
    UNIQUE (salon_id, customer_id, service_id, requested_date)
);

-- Indexes for efficient queries
CREATE INDEX IF NOT EXISTS idx_waitlist_salon_date
ON waitlist(salon_id, requested_date);

CREATE INDEX IF NOT EXISTS idx_waitlist_customer
ON waitlist(customer_id);

CREATE INDEX IF NOT EXISTS idx_waitlist_status
ON waitlist(status) WHERE status IN ('waiting', 'notified');

CREATE INDEX IF NOT EXISTS idx_waitlist_service_date
ON waitlist(service_id, requested_date, status);

-- ============================================
-- 2. TRIGGER: Auto-update position
-- ============================================

CREATE OR REPLACE FUNCTION set_waitlist_position()
RETURNS TRIGGER AS $$
BEGIN
  IF NEW.position IS NULL THEN
    SELECT COALESCE(MAX(position), 0) + 1 INTO NEW.position
    FROM waitlist
    WHERE salon_id = NEW.salon_id
      AND service_id = NEW.service_id
      AND requested_date = NEW.requested_date
      AND status = 'waiting';
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER waitlist_set_position
BEFORE INSERT ON waitlist
FOR EACH ROW
EXECUTE FUNCTION set_waitlist_position();

-- ============================================
-- 3. TRIGGER: Update timestamp
-- ============================================

CREATE TRIGGER waitlist_updated_at
BEFORE UPDATE ON waitlist
FOR EACH ROW
EXECUTE FUNCTION update_updated_at_column();

-- ============================================
-- 4. FUNCTION: Join waitlist
-- ============================================

CREATE OR REPLACE FUNCTION join_waitlist(
  p_salon_id UUID,
  p_customer_id UUID,
  p_service_id UUID,
  p_staff_id UUID DEFAULT NULL,
  p_requested_date DATE DEFAULT NULL,
  p_requested_time_start TIME DEFAULT NULL,
  p_requested_time_end TIME DEFAULT NULL,
  p_flexible_time BOOLEAN DEFAULT false
)
RETURNS UUID AS $$
DECLARE
  v_waitlist_id UUID;
  v_existing_count INTEGER;
BEGIN
  -- Check if already on waitlist for this date/service
  SELECT COUNT(*) INTO v_existing_count
  FROM waitlist
  WHERE salon_id = p_salon_id
    AND customer_id = p_customer_id
    AND service_id = p_service_id
    AND requested_date = COALESCE(p_requested_date, CURRENT_DATE)
    AND status IN ('waiting', 'notified');

  IF v_existing_count > 0 THEN
    RAISE EXCEPTION 'Already on waitlist for this service and date';
  END IF;

  -- Check max waitlist entries per customer per salon (prevent abuse)
  SELECT COUNT(*) INTO v_existing_count
  FROM waitlist
  WHERE salon_id = p_salon_id
    AND customer_id = p_customer_id
    AND status = 'waiting';

  IF v_existing_count >= 5 THEN
    RAISE EXCEPTION 'Maximum waitlist entries reached (5)';
  END IF;

  -- Add to waitlist
  INSERT INTO waitlist (
    salon_id, customer_id, service_id, staff_id,
    requested_date, requested_time_start, requested_time_end,
    flexible_time
  ) VALUES (
    p_salon_id, p_customer_id, p_service_id, p_staff_id,
    COALESCE(p_requested_date, CURRENT_DATE),
    p_requested_time_start, p_requested_time_end,
    p_flexible_time
  )
  RETURNING id INTO v_waitlist_id;

  RETURN v_waitlist_id;
END;
$$ LANGUAGE plpgsql;

-- ============================================
-- 5. FUNCTION: Notify waitlist when slot opens
-- ============================================

CREATE OR REPLACE FUNCTION notify_waitlist_for_slot(
  p_salon_id UUID,
  p_service_id UUID,
  p_date DATE,
  p_time TIME,
  p_staff_id UUID DEFAULT NULL
)
RETURNS TABLE (
  waitlist_id UUID,
  customer_id UUID,
  customer_phone TEXT,
  customer_email TEXT
) AS $$
BEGIN
  -- Find matching waitlist entries
  RETURN QUERY
  UPDATE waitlist w
  SET
    status = 'notified',
    notified_at = NOW(),
    notification_expires_at = NOW() + INTERVAL '30 minutes'
  FROM customers c
  WHERE w.customer_id = c.id
    AND w.salon_id = p_salon_id
    AND w.service_id = p_service_id
    AND w.requested_date = p_date
    AND w.status = 'waiting'
    AND (w.staff_id IS NULL OR w.staff_id = p_staff_id)
    AND (
      w.flexible_time = true
      OR w.requested_time_start IS NULL
      OR (p_time >= w.requested_time_start AND p_time <= COALESCE(w.requested_time_end, '23:59:59'::TIME))
    )
  RETURNING
    w.id,
    w.customer_id,
    c.phone,
    c.email;
END;
$$ LANGUAGE plpgsql;

-- ============================================
-- 6. FUNCTION: Complete waitlist booking
-- ============================================

CREATE OR REPLACE FUNCTION complete_waitlist_booking(
  p_waitlist_id UUID,
  p_appointment_id UUID
)
RETURNS BOOLEAN AS $$
BEGIN
  UPDATE waitlist
  SET
    status = 'booked',
    appointment_id = p_appointment_id,
    updated_at = NOW()
  WHERE id = p_waitlist_id
    AND status = 'notified';

  RETURN FOUND;
END;
$$ LANGUAGE plpgsql;

-- ============================================
-- 7. FUNCTION: Expire old notifications
-- Run via cron every 5 minutes
-- ============================================

CREATE OR REPLACE FUNCTION expire_waitlist_notifications()
RETURNS INTEGER AS $$
DECLARE
  v_expired_count INTEGER;
BEGIN
  WITH expired AS (
    UPDATE waitlist
    SET status = 'expired'
    WHERE status = 'notified'
      AND notification_expires_at < NOW()
    RETURNING id
  )
  SELECT COUNT(*) INTO v_expired_count FROM expired;

  RETURN v_expired_count;
END;
$$ LANGUAGE plpgsql;

-- ============================================
-- 8. VIEW: Active waitlist with details
-- ============================================

CREATE OR REPLACE VIEW v_active_waitlist AS
SELECT
  w.*,
  c.first_name || ' ' || c.last_name AS customer_name,
  c.phone AS customer_phone,
  c.email AS customer_email,
  s.name AS service_name,
  s.duration_minutes,
  COALESCE(st.first_name || ' ' || st.last_name, 'Beliebig') AS staff_name
FROM waitlist w
JOIN customers c ON w.customer_id = c.id
JOIN services s ON w.service_id = s.id
LEFT JOIN staff st ON w.staff_id = st.id
WHERE w.status IN ('waiting', 'notified');

COMMENT ON VIEW v_active_waitlist IS 'Active waitlist entries with customer/service details';

-- ============================================
-- 9. VIEW: Waitlist statistics
-- ============================================

CREATE OR REPLACE VIEW v_waitlist_stats AS
SELECT
  salon_id,
  requested_date,
  COUNT(*) FILTER (WHERE status = 'waiting') AS waiting_count,
  COUNT(*) FILTER (WHERE status = 'notified') AS notified_count,
  COUNT(*) FILTER (WHERE status = 'booked') AS booked_count,
  COUNT(*) FILTER (WHERE status = 'expired') AS expired_count,
  ROUND(
    COUNT(*) FILTER (WHERE status = 'booked')::NUMERIC /
    NULLIF(COUNT(*) FILTER (WHERE status IN ('booked', 'expired')), 0) * 100,
    1
  ) AS conversion_rate
FROM waitlist
GROUP BY salon_id, requested_date;

COMMENT ON VIEW v_waitlist_stats IS 'Waitlist statistics per salon and date';

-- ============================================
-- 10. RLS POLICIES
-- ============================================

ALTER TABLE waitlist ENABLE ROW LEVEL SECURITY;

-- Customers can view their own waitlist entries
CREATE POLICY "Customers can view own waitlist"
ON waitlist FOR SELECT
TO authenticated
USING (
  customer_id IN (
    SELECT id FROM customers WHERE user_id = auth.uid()
  )
);

-- Customers can join/leave waitlist
CREATE POLICY "Customers can manage own waitlist"
ON waitlist FOR ALL
TO authenticated
USING (
  customer_id IN (
    SELECT id FROM customers WHERE user_id = auth.uid()
  )
);

-- Staff can view waitlist for their salon
CREATE POLICY "Staff can view salon waitlist"
ON waitlist FOR SELECT
TO authenticated
USING (
  salon_id IN (
    SELECT salon_id FROM staff WHERE user_id = auth.uid()
  )
);

-- Staff can update waitlist status
CREATE POLICY "Staff can update salon waitlist"
ON waitlist FOR UPDATE
TO authenticated
USING (
  salon_id IN (
    SELECT salon_id FROM staff
    WHERE user_id = auth.uid()
    AND role IN ('admin', 'manager', 'mitarbeiter')
  )
);

-- ============================================
-- 11. COMMENTS
-- ============================================

COMMENT ON TABLE waitlist IS 'Customer waitlist for fully booked time slots';
COMMENT ON COLUMN waitlist.flexible_time IS 'Customer accepts any available time on the requested date';
COMMENT ON COLUMN waitlist.notification_expires_at IS 'Time limit for customer to book after notification';
COMMENT ON FUNCTION join_waitlist IS 'Add customer to waitlist with validation';
COMMENT ON FUNCTION notify_waitlist_for_slot IS 'Notify waiting customers when a slot becomes available';
-- ============================================
-- 00023: Marketing Automation & Customer Feedback
-- SCHNITTWERK Phase 8 - Marketing & Feedback Systems
-- ============================================

-- ============================================
-- 1. MARKETING LOGS TABLE
-- Track sent marketing campaigns
-- ============================================

CREATE TABLE IF NOT EXISTS marketing_logs (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  salon_id UUID NOT NULL REFERENCES salons(id) ON DELETE CASCADE,
  customer_id UUID NOT NULL REFERENCES customers(id) ON DELETE CASCADE,

  -- Campaign details
  campaign_type VARCHAR(30) NOT NULL CHECK (campaign_type IN (
    'birthday', 'reengagement', 'welcome', 'post_visit', 'newsletter', 'custom'
  )),
  campaign_name VARCHAR(100),

  -- Channel
  channel VARCHAR(10) NOT NULL DEFAULT 'email' CHECK (channel IN ('email', 'sms', 'push')),

  -- Reference (e.g., appointment_id for post_visit)
  reference_type VARCHAR(30),
  reference_id UUID,

  -- Tracking
  sent_at TIMESTAMPTZ DEFAULT NOW(),
  opened BOOLEAN DEFAULT false,
  opened_at TIMESTAMPTZ,
  clicked BOOLEAN DEFAULT false,
  clicked_at TIMESTAMPTZ,
  converted BOOLEAN DEFAULT false,
  converted_at TIMESTAMPTZ,

  -- Metadata
  subject TEXT,
  template_id VARCHAR(50),
  metadata JSONB DEFAULT '{}',

  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Indexes
CREATE INDEX IF NOT EXISTS idx_marketing_logs_salon
ON marketing_logs(salon_id);

CREATE INDEX IF NOT EXISTS idx_marketing_logs_customer
ON marketing_logs(customer_id);

CREATE INDEX IF NOT EXISTS idx_marketing_logs_type
ON marketing_logs(campaign_type);

CREATE INDEX IF NOT EXISTS idx_marketing_logs_sent_at
ON marketing_logs(sent_at DESC);

CREATE INDEX IF NOT EXISTS idx_marketing_logs_reference
ON marketing_logs(reference_type, reference_id);

-- ============================================
-- 2. MARKETING CAMPAIGNS TABLE
-- Campaign configuration
-- ============================================

CREATE TABLE IF NOT EXISTS marketing_campaigns (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  salon_id UUID REFERENCES salons(id) ON DELETE CASCADE,

  -- Campaign info
  type VARCHAR(30) NOT NULL,
  name VARCHAR(100) NOT NULL,
  description TEXT,

  -- Content
  subject TEXT NOT NULL,
  email_content TEXT,
  sms_content VARCHAR(320),

  -- Trigger configuration
  trigger_type VARCHAR(30) DEFAULT 'automatic' CHECK (trigger_type IN (
    'automatic', 'manual', 'scheduled'
  )),
  trigger_days INTEGER DEFAULT 0, -- Days before (-) or after (+) event

  -- Incentive
  discount_percent INTEGER CHECK (discount_percent >= 0 AND discount_percent <= 100),
  voucher_value_cents INTEGER,
  voucher_code VARCHAR(50),

  -- Targeting
  target_segment VARCHAR(30) DEFAULT 'all' CHECK (target_segment IN (
    'all', 'new', 'inactive', 'vip', 'birthday'
  )),

  -- Status
  is_active BOOLEAN DEFAULT true,

  -- Stats (cached)
  total_sent INTEGER DEFAULT 0,
  total_opened INTEGER DEFAULT 0,
  total_clicked INTEGER DEFAULT 0,
  total_converted INTEGER DEFAULT 0,

  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Index
CREATE INDEX IF NOT EXISTS idx_marketing_campaigns_salon
ON marketing_campaigns(salon_id);

CREATE INDEX IF NOT EXISTS idx_marketing_campaigns_type
ON marketing_campaigns(type);

-- Trigger for updated_at
CREATE TRIGGER marketing_campaigns_updated_at
BEFORE UPDATE ON marketing_campaigns
FOR EACH ROW
EXECUTE FUNCTION update_updated_at_column();

-- ============================================
-- 3. CUSTOMER FEEDBACK TABLE
-- Store customer reviews and ratings
-- ============================================

CREATE TABLE IF NOT EXISTS customer_feedback (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  salon_id UUID NOT NULL REFERENCES salons(id) ON DELETE CASCADE,
  customer_id UUID NOT NULL REFERENCES customers(id) ON DELETE CASCADE,

  -- Reference
  appointment_id UUID REFERENCES appointments(id) ON DELETE SET NULL,
  staff_id UUID REFERENCES staff(id) ON DELETE SET NULL,
  service_id UUID REFERENCES services(id) ON DELETE SET NULL,

  -- Rating (1-5 stars)
  rating INTEGER NOT NULL CHECK (rating >= 1 AND rating <= 5),

  -- Optional comment
  comment TEXT,

  -- Categories
  service_quality INTEGER CHECK (service_quality >= 1 AND service_quality <= 5),
  cleanliness INTEGER CHECK (cleanliness >= 1 AND cleanliness <= 5),
  wait_time INTEGER CHECK (wait_time >= 1 AND wait_time <= 5),
  value_for_money INTEGER CHECK (value_for_money >= 1 AND value_for_money <= 5),

  -- Response
  response TEXT,
  responded_at TIMESTAMPTZ,
  responded_by UUID REFERENCES profiles(id),

  -- Status
  status VARCHAR(20) DEFAULT 'pending' CHECK (status IN (
    'pending', 'approved', 'hidden', 'flagged'
  )),

  -- Google Review tracking
  google_review_prompted BOOLEAN DEFAULT false,
  google_review_clicked BOOLEAN DEFAULT false,

  -- Timestamps
  submitted_at TIMESTAMPTZ DEFAULT NOW(),
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Indexes
CREATE INDEX IF NOT EXISTS idx_customer_feedback_salon
ON customer_feedback(salon_id);

CREATE INDEX IF NOT EXISTS idx_customer_feedback_customer
ON customer_feedback(customer_id);

CREATE INDEX IF NOT EXISTS idx_customer_feedback_appointment
ON customer_feedback(appointment_id);

CREATE INDEX IF NOT EXISTS idx_customer_feedback_staff
ON customer_feedback(staff_id);

CREATE INDEX IF NOT EXISTS idx_customer_feedback_rating
ON customer_feedback(rating);

CREATE INDEX IF NOT EXISTS idx_customer_feedback_status
ON customer_feedback(status);

CREATE INDEX IF NOT EXISTS idx_customer_feedback_submitted
ON customer_feedback(submitted_at DESC);

-- ============================================
-- 4. FEEDBACK REQUESTS TABLE
-- Track feedback request sending
-- ============================================

CREATE TABLE IF NOT EXISTS feedback_requests (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  salon_id UUID NOT NULL REFERENCES salons(id) ON DELETE CASCADE,
  appointment_id UUID NOT NULL REFERENCES appointments(id) ON DELETE CASCADE,
  customer_id UUID NOT NULL REFERENCES customers(id) ON DELETE CASCADE,

  -- Request details
  channel VARCHAR(10) NOT NULL DEFAULT 'email' CHECK (channel IN ('email', 'sms')),
  sent_at TIMESTAMPTZ DEFAULT NOW(),

  -- Status
  opened BOOLEAN DEFAULT false,
  opened_at TIMESTAMPTZ,
  completed BOOLEAN DEFAULT false,
  completed_at TIMESTAMPTZ,

  -- Token for secure feedback submission
  token VARCHAR(64) UNIQUE NOT NULL,
  expires_at TIMESTAMPTZ NOT NULL,

  created_at TIMESTAMPTZ DEFAULT NOW(),

  -- Prevent duplicate requests per appointment
  CONSTRAINT unique_feedback_request_per_appointment
    UNIQUE (appointment_id)
);

-- Indexes
CREATE INDEX IF NOT EXISTS idx_feedback_requests_salon
ON feedback_requests(salon_id);

CREATE INDEX IF NOT EXISTS idx_feedback_requests_customer
ON feedback_requests(customer_id);

CREATE INDEX IF NOT EXISTS idx_feedback_requests_token
ON feedback_requests(token);

-- ============================================
-- 5. VIEWS FOR ANALYTICS
-- ============================================

-- Marketing campaign performance
CREATE OR REPLACE VIEW v_marketing_performance AS
SELECT
  ml.salon_id,
  ml.campaign_type,
  DATE(ml.sent_at) as date,
  COUNT(*) as total_sent,
  COUNT(*) FILTER (WHERE ml.opened) as total_opened,
  COUNT(*) FILTER (WHERE ml.clicked) as total_clicked,
  COUNT(*) FILTER (WHERE ml.converted) as total_converted,
  ROUND(COUNT(*) FILTER (WHERE ml.opened)::NUMERIC / NULLIF(COUNT(*), 0) * 100, 1) as open_rate,
  ROUND(COUNT(*) FILTER (WHERE ml.clicked)::NUMERIC / NULLIF(COUNT(*), 0) * 100, 1) as click_rate,
  ROUND(COUNT(*) FILTER (WHERE ml.converted)::NUMERIC / NULLIF(COUNT(*), 0) * 100, 1) as conversion_rate
FROM marketing_logs ml
GROUP BY ml.salon_id, ml.campaign_type, DATE(ml.sent_at);

COMMENT ON VIEW v_marketing_performance IS 'Marketing campaign performance metrics';

-- Feedback summary
CREATE OR REPLACE VIEW v_feedback_summary AS
SELECT
  cf.salon_id,
  cf.staff_id,
  st.first_name || ' ' || st.last_name as staff_name,
  COUNT(*) as total_reviews,
  ROUND(AVG(cf.rating), 2) as average_rating,
  COUNT(*) FILTER (WHERE cf.rating = 5) as five_star,
  COUNT(*) FILTER (WHERE cf.rating = 4) as four_star,
  COUNT(*) FILTER (WHERE cf.rating = 3) as three_star,
  COUNT(*) FILTER (WHERE cf.rating = 2) as two_star,
  COUNT(*) FILTER (WHERE cf.rating = 1) as one_star,
  ROUND(AVG(cf.service_quality), 2) as avg_service_quality,
  ROUND(AVG(cf.cleanliness), 2) as avg_cleanliness,
  ROUND(AVG(cf.value_for_money), 2) as avg_value_for_money
FROM customer_feedback cf
LEFT JOIN staff st ON cf.staff_id = st.id
WHERE cf.status = 'approved'
GROUP BY cf.salon_id, cf.staff_id, st.first_name, st.last_name;

COMMENT ON VIEW v_feedback_summary IS 'Customer feedback summary by salon and staff';

-- Recent feedback
CREATE OR REPLACE VIEW v_recent_feedback AS
SELECT
  cf.*,
  c.first_name || ' ' || c.last_name as customer_name,
  s.name as service_name,
  st.first_name || ' ' || st.last_name as staff_name
FROM customer_feedback cf
JOIN customers c ON cf.customer_id = c.id
LEFT JOIN services s ON cf.service_id = s.id
LEFT JOIN staff st ON cf.staff_id = st.id
WHERE cf.submitted_at >= NOW() - INTERVAL '30 days'
ORDER BY cf.submitted_at DESC;

COMMENT ON VIEW v_recent_feedback IS 'Recent customer feedback with details';

-- ============================================
-- 6. FUNCTIONS
-- ============================================

-- Generate secure feedback token
CREATE OR REPLACE FUNCTION generate_feedback_token()
RETURNS VARCHAR(64) AS $$
BEGIN
  RETURN encode(gen_random_bytes(32), 'hex');
END;
$$ LANGUAGE plpgsql;

-- Create feedback request for appointment
CREATE OR REPLACE FUNCTION create_feedback_request(
  p_appointment_id UUID,
  p_channel VARCHAR DEFAULT 'email'
)
RETURNS UUID AS $$
DECLARE
  v_salon_id UUID;
  v_customer_id UUID;
  v_request_id UUID;
BEGIN
  -- Get appointment details
  SELECT salon_id, customer_id INTO v_salon_id, v_customer_id
  FROM appointments
  WHERE id = p_appointment_id;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Appointment not found';
  END IF;

  -- Create request
  INSERT INTO feedback_requests (
    salon_id, appointment_id, customer_id, channel,
    token, expires_at
  ) VALUES (
    v_salon_id, p_appointment_id, v_customer_id, p_channel,
    generate_feedback_token(),
    NOW() + INTERVAL '7 days'
  )
  ON CONFLICT (appointment_id) DO NOTHING
  RETURNING id INTO v_request_id;

  RETURN v_request_id;
END;
$$ LANGUAGE plpgsql;

-- Submit feedback by token
CREATE OR REPLACE FUNCTION submit_feedback_by_token(
  p_token VARCHAR,
  p_rating INTEGER,
  p_comment TEXT DEFAULT NULL,
  p_service_quality INTEGER DEFAULT NULL,
  p_cleanliness INTEGER DEFAULT NULL,
  p_wait_time INTEGER DEFAULT NULL,
  p_value_for_money INTEGER DEFAULT NULL
)
RETURNS UUID AS $$
DECLARE
  v_request feedback_requests%ROWTYPE;
  v_appointment appointments%ROWTYPE;
  v_feedback_id UUID;
BEGIN
  -- Get and validate request
  SELECT * INTO v_request
  FROM feedback_requests
  WHERE token = p_token
    AND expires_at > NOW()
    AND NOT completed
  FOR UPDATE;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Invalid or expired feedback token';
  END IF;

  -- Get appointment details
  SELECT * INTO v_appointment
  FROM appointments
  WHERE id = v_request.appointment_id;

  -- Create feedback
  INSERT INTO customer_feedback (
    salon_id, customer_id, appointment_id, staff_id, service_id,
    rating, comment, service_quality, cleanliness, wait_time, value_for_money
  ) VALUES (
    v_request.salon_id, v_request.customer_id, v_request.appointment_id,
    v_appointment.staff_id, v_appointment.service_id,
    p_rating, p_comment, p_service_quality, p_cleanliness, p_wait_time, p_value_for_money
  )
  RETURNING id INTO v_feedback_id;

  -- Mark request as completed
  UPDATE feedback_requests
  SET completed = true, completed_at = NOW()
  WHERE id = v_request.id;

  RETURN v_feedback_id;
END;
$$ LANGUAGE plpgsql;

-- ============================================
-- 7. RLS POLICIES
-- ============================================

ALTER TABLE marketing_logs ENABLE ROW LEVEL SECURITY;
ALTER TABLE marketing_campaigns ENABLE ROW LEVEL SECURITY;
ALTER TABLE customer_feedback ENABLE ROW LEVEL SECURITY;
ALTER TABLE feedback_requests ENABLE ROW LEVEL SECURITY;

-- Marketing Logs: Staff can view their salon's logs
CREATE POLICY "Staff can view salon marketing logs"
ON marketing_logs FOR SELECT
TO authenticated
USING (
  salon_id IN (
    SELECT salon_id FROM staff WHERE user_id = auth.uid()
  )
);

-- Marketing Campaigns: Staff can manage their salon's campaigns
CREATE POLICY "Staff can manage salon campaigns"
ON marketing_campaigns FOR ALL
TO authenticated
USING (
  salon_id IS NULL OR
  salon_id IN (
    SELECT salon_id FROM staff
    WHERE user_id = auth.uid()
    AND role IN ('admin', 'manager')
  )
);

-- Customer Feedback: Customers can view/submit their own
CREATE POLICY "Customers can manage own feedback"
ON customer_feedback FOR ALL
TO authenticated
USING (
  customer_id IN (
    SELECT id FROM customers WHERE user_id = auth.uid()
  )
);

-- Customer Feedback: Staff can view salon feedback
CREATE POLICY "Staff can view salon feedback"
ON customer_feedback FOR SELECT
TO authenticated
USING (
  salon_id IN (
    SELECT salon_id FROM staff WHERE user_id = auth.uid()
  )
);

-- Staff can respond to feedback
CREATE POLICY "Staff can respond to feedback"
ON customer_feedback FOR UPDATE
TO authenticated
USING (
  salon_id IN (
    SELECT salon_id FROM staff
    WHERE user_id = auth.uid()
    AND role IN ('admin', 'manager')
  )
);

-- Feedback Requests: Service role only (system creates these)
CREATE POLICY "Service role can manage feedback requests"
ON feedback_requests FOR ALL
TO service_role
USING (true);

-- Allow token-based feedback submission (anonymous)
CREATE POLICY "Public can view feedback request by token"
ON feedback_requests FOR SELECT
TO anon
USING (token IS NOT NULL AND expires_at > NOW());

-- ============================================
-- 8. INSERT DEFAULT CAMPAIGNS
-- ============================================

INSERT INTO marketing_campaigns (salon_id, type, name, subject, email_content, trigger_type, trigger_days, discount_percent)
VALUES
  (NULL, 'birthday', 'Geburtstagsgruss', 'Alles Gute zum Geburtstag von SCHNITTWERK!',
   'Liebe/r {{firstName}}, wir wünschen Ihnen alles Gute zum Geburtstag!', 'automatic', 0, 10),
  (NULL, 'reengagement', 'Wir vermissen Sie', 'Wir vermissen Sie bei SCHNITTWERK!',
   'Liebe/r {{firstName}}, es ist schon eine Weile her seit Ihrem letzten Besuch.', 'automatic', 60, 5),
  (NULL, 'welcome', 'Willkommen', 'Willkommen bei SCHNITTWERK!',
   'Liebe/r {{firstName}}, herzlich willkommen bei SCHNITTWERK!', 'automatic', 1, NULL),
  (NULL, 'post_visit', 'Feedback-Anfrage', 'Wie war Ihr Besuch bei SCHNITTWERK?',
   'Liebe/r {{firstName}}, wir hoffen, Sie waren zufrieden mit unserem Service.', 'automatic', 1, NULL)
ON CONFLICT DO NOTHING;

-- ============================================
-- 9. COMMENTS
-- ============================================

COMMENT ON TABLE marketing_logs IS 'Log of all sent marketing communications';
COMMENT ON TABLE marketing_campaigns IS 'Marketing campaign configurations';
COMMENT ON TABLE customer_feedback IS 'Customer reviews and ratings';
COMMENT ON TABLE feedback_requests IS 'Pending feedback requests with secure tokens';
COMMENT ON FUNCTION create_feedback_request IS 'Create a feedback request for a completed appointment';
COMMENT ON FUNCTION submit_feedback_by_token IS 'Submit feedback using a secure token';
-- ============================================
-- 00024: Web Push Subscriptions
-- SCHNITTWERK Phase 8 - Push Notifications
-- ============================================

-- ============================================
-- 1. PUSH SUBSCRIPTIONS TABLE
-- Store web push subscriptions per customer
-- ============================================

CREATE TABLE IF NOT EXISTS push_subscriptions (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  customer_id UUID NOT NULL REFERENCES customers(id) ON DELETE CASCADE,

  -- Push subscription data
  endpoint TEXT NOT NULL,
  p256dh_key TEXT NOT NULL,
  auth_key TEXT NOT NULL,

  -- Device info
  user_agent TEXT,
  device_type VARCHAR(20), -- 'mobile', 'desktop', 'tablet'

  -- Tracking
  last_used_at TIMESTAMPTZ,
  last_error TEXT,
  error_count INTEGER DEFAULT 0,

  -- Timestamps
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW(),

  -- Prevent duplicate subscriptions per customer+endpoint
  CONSTRAINT unique_customer_endpoint
    UNIQUE (customer_id, endpoint)
);

-- Indexes
CREATE INDEX IF NOT EXISTS idx_push_subscriptions_customer
ON push_subscriptions(customer_id);

CREATE INDEX IF NOT EXISTS idx_push_subscriptions_endpoint
ON push_subscriptions(endpoint);

-- Updated_at trigger
CREATE TRIGGER push_subscriptions_updated_at
BEFORE UPDATE ON push_subscriptions
FOR EACH ROW
EXECUTE FUNCTION update_updated_at_column();

-- ============================================
-- 2. PUSH NOTIFICATION LOGS
-- Track sent push notifications
-- ============================================

CREATE TABLE IF NOT EXISTS push_notification_logs (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  salon_id UUID REFERENCES salons(id),
  customer_id UUID REFERENCES customers(id),
  subscription_id UUID REFERENCES push_subscriptions(id) ON DELETE SET NULL,

  -- Notification details
  event_type VARCHAR(50) NOT NULL,
  title TEXT NOT NULL,
  body TEXT,

  -- Status
  status VARCHAR(20) DEFAULT 'sent' CHECK (status IN ('sent', 'delivered', 'clicked', 'failed')),
  error_message TEXT,

  -- Reference
  reference_type VARCHAR(30),
  reference_id UUID,

  -- Timestamps
  sent_at TIMESTAMPTZ DEFAULT NOW(),
  delivered_at TIMESTAMPTZ,
  clicked_at TIMESTAMPTZ,

  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Indexes
CREATE INDEX IF NOT EXISTS idx_push_logs_customer
ON push_notification_logs(customer_id);

CREATE INDEX IF NOT EXISTS idx_push_logs_salon
ON push_notification_logs(salon_id);

CREATE INDEX IF NOT EXISTS idx_push_logs_event
ON push_notification_logs(event_type);

CREATE INDEX IF NOT EXISTS idx_push_logs_sent_at
ON push_notification_logs(sent_at DESC);

-- ============================================
-- 3. RLS POLICIES
-- ============================================

ALTER TABLE push_subscriptions ENABLE ROW LEVEL SECURITY;
ALTER TABLE push_notification_logs ENABLE ROW LEVEL SECURITY;

-- Customers can manage their own subscriptions
CREATE POLICY "Customers can manage own push subscriptions"
ON push_subscriptions FOR ALL
TO authenticated
USING (
  customer_id IN (
    SELECT id FROM customers WHERE user_id = auth.uid()
  )
);

-- Staff can view push logs for their salon
CREATE POLICY "Staff can view salon push logs"
ON push_notification_logs FOR SELECT
TO authenticated
USING (
  salon_id IN (
    SELECT salon_id FROM staff WHERE user_id = auth.uid()
  )
);

-- ============================================
-- 4. VIEW: Push notification analytics
-- ============================================

CREATE OR REPLACE VIEW v_push_analytics AS
SELECT
  pnl.salon_id,
  pnl.event_type,
  DATE(pnl.sent_at) as date,
  COUNT(*) as total_sent,
  COUNT(*) FILTER (WHERE pnl.status = 'delivered') as delivered,
  COUNT(*) FILTER (WHERE pnl.status = 'clicked') as clicked,
  COUNT(*) FILTER (WHERE pnl.status = 'failed') as failed,
  ROUND(
    COUNT(*) FILTER (WHERE pnl.status = 'clicked')::NUMERIC /
    NULLIF(COUNT(*) FILTER (WHERE pnl.status IN ('delivered', 'clicked')), 0) * 100,
    1
  ) as click_rate
FROM push_notification_logs pnl
GROUP BY pnl.salon_id, pnl.event_type, DATE(pnl.sent_at);

COMMENT ON VIEW v_push_analytics IS 'Push notification performance analytics';

-- ============================================
-- 5. FUNCTION: Clean up old/invalid subscriptions
-- ============================================

CREATE OR REPLACE FUNCTION cleanup_invalid_push_subscriptions()
RETURNS INTEGER AS $$
DECLARE
  v_deleted_count INTEGER;
BEGIN
  -- Delete subscriptions with too many errors or unused for 90+ days
  WITH deleted AS (
    DELETE FROM push_subscriptions
    WHERE error_count >= 5
       OR (last_used_at IS NOT NULL AND last_used_at < NOW() - INTERVAL '90 days')
       OR (last_used_at IS NULL AND created_at < NOW() - INTERVAL '90 days')
    RETURNING id
  )
  SELECT COUNT(*) INTO v_deleted_count FROM deleted;

  RETURN v_deleted_count;
END;
$$ LANGUAGE plpgsql;

COMMENT ON FUNCTION cleanup_invalid_push_subscriptions IS 'Remove stale or invalid push subscriptions';

-- ============================================
-- 6. COMMENTS
-- ============================================

COMMENT ON TABLE push_subscriptions IS 'Web Push API subscription storage per customer device';
COMMENT ON TABLE push_notification_logs IS 'Log of sent push notifications';
COMMENT ON COLUMN push_subscriptions.endpoint IS 'Push service endpoint URL';
COMMENT ON COLUMN push_subscriptions.p256dh_key IS 'Public key for encryption';
COMMENT ON COLUMN push_subscriptions.auth_key IS 'Authentication secret';
-- ============================================
-- 00025: Appointment Deposits / Anzahlungen
-- SCHNITTWERK Phase 8 - Deposit System
-- ============================================

-- ============================================
-- 1. SERVICE DEPOSIT CONFIGURATION
-- Add deposit settings to services
-- ============================================

ALTER TABLE services
ADD COLUMN IF NOT EXISTS deposit_required BOOLEAN DEFAULT false,
ADD COLUMN IF NOT EXISTS deposit_type VARCHAR(20) DEFAULT 'percentage' CHECK (deposit_type IN ('fixed', 'percentage')),
ADD COLUMN IF NOT EXISTS deposit_amount INTEGER DEFAULT 0, -- CHF cents for fixed, percentage for percentage type
ADD COLUMN IF NOT EXISTS deposit_refundable_until INTEGER DEFAULT 24; -- Hours before appointment

COMMENT ON COLUMN services.deposit_required IS 'Whether a deposit is required for booking this service';
COMMENT ON COLUMN services.deposit_type IS 'fixed = CHF amount, percentage = % of service price';
COMMENT ON COLUMN services.deposit_amount IS 'Amount in cents (fixed) or percentage (0-100)';
COMMENT ON COLUMN services.deposit_refundable_until IS 'Hours before appointment when deposit becomes non-refundable';

-- ============================================
-- 2. APPOINTMENT DEPOSITS TABLE
-- Track deposits for appointments
-- ============================================

CREATE TABLE IF NOT EXISTS appointment_deposits (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  appointment_id UUID NOT NULL REFERENCES appointments(id) ON DELETE CASCADE,
  salon_id UUID NOT NULL REFERENCES salons(id),
  customer_id UUID NOT NULL REFERENCES customers(id),

  -- Deposit details
  amount_cents INTEGER NOT NULL,
  currency VARCHAR(3) DEFAULT 'CHF',

  -- Payment
  stripe_payment_intent_id VARCHAR(100),
  stripe_charge_id VARCHAR(100),

  -- Status
  status VARCHAR(20) DEFAULT 'pending' CHECK (status IN (
    'pending',       -- Awaiting payment
    'paid',          -- Deposit received
    'applied',       -- Applied to final payment
    'refunded',      -- Refunded to customer
    'forfeited',     -- No-show or late cancellation
    'cancelled'      -- Cancelled before payment
  )),

  -- Refund tracking
  refund_amount_cents INTEGER,
  refund_reason TEXT,
  refunded_at TIMESTAMPTZ,
  refunded_by UUID REFERENCES profiles(id),

  -- Timestamps
  paid_at TIMESTAMPTZ,
  applied_at TIMESTAMPTZ,
  forfeited_at TIMESTAMPTZ,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW(),

  -- One deposit per appointment
  CONSTRAINT unique_appointment_deposit
    UNIQUE (appointment_id)
);

-- Indexes
CREATE INDEX IF NOT EXISTS idx_appointment_deposits_appointment
ON appointment_deposits(appointment_id);

CREATE INDEX IF NOT EXISTS idx_appointment_deposits_salon
ON appointment_deposits(salon_id);

CREATE INDEX IF NOT EXISTS idx_appointment_deposits_customer
ON appointment_deposits(customer_id);

CREATE INDEX IF NOT EXISTS idx_appointment_deposits_status
ON appointment_deposits(status);

CREATE INDEX IF NOT EXISTS idx_appointment_deposits_stripe
ON appointment_deposits(stripe_payment_intent_id);

-- Updated_at trigger
CREATE TRIGGER appointment_deposits_updated_at
BEFORE UPDATE ON appointment_deposits
FOR EACH ROW
EXECUTE FUNCTION update_updated_at_column();

-- ============================================
-- 3. DEPOSIT POLICIES TABLE
-- Salon-wide deposit policies
-- ============================================

CREATE TABLE IF NOT EXISTS deposit_policies (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  salon_id UUID NOT NULL REFERENCES salons(id) ON DELETE CASCADE,

  -- Policy configuration
  name VARCHAR(100) NOT NULL,
  description TEXT,

  -- Default settings
  default_type VARCHAR(20) DEFAULT 'percentage' CHECK (default_type IN ('fixed', 'percentage')),
  default_amount INTEGER DEFAULT 20, -- 20% or 20 CHF
  min_service_price_cents INTEGER DEFAULT 5000, -- Only require for services > CHF 50

  -- Refund policy
  full_refund_hours INTEGER DEFAULT 48, -- Full refund if cancelled 48h+ before
  partial_refund_hours INTEGER DEFAULT 24, -- Partial refund if cancelled 24-48h before
  partial_refund_percent INTEGER DEFAULT 50, -- 50% refund for partial

  -- No-show policy
  no_show_forfeit BOOLEAN DEFAULT true, -- Forfeit deposit on no-show

  -- Status
  is_active BOOLEAN DEFAULT true,

  -- Timestamps
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW(),

  -- One active policy per salon
  CONSTRAINT unique_active_policy_per_salon
    UNIQUE (salon_id) WHERE is_active = true
);

COMMENT ON TABLE deposit_policies IS 'Salon-wide deposit and refund policies';

-- ============================================
-- 4. FUNCTIONS
-- ============================================

-- Calculate deposit amount for a service
CREATE OR REPLACE FUNCTION calculate_deposit_amount(
  p_service_id UUID,
  p_service_price_cents INTEGER DEFAULT NULL
)
RETURNS INTEGER AS $$
DECLARE
  v_service services%ROWTYPE;
  v_deposit_amount INTEGER;
BEGIN
  SELECT * INTO v_service FROM services WHERE id = p_service_id;

  IF NOT FOUND OR NOT v_service.deposit_required THEN
    RETURN 0;
  END IF;

  IF v_service.deposit_type = 'fixed' THEN
    v_deposit_amount := v_service.deposit_amount;
  ELSE
    -- Percentage
    v_deposit_amount := FLOOR(
      COALESCE(p_service_price_cents, v_service.price_cents) *
      v_service.deposit_amount / 100.0
    );
  END IF;

  RETURN v_deposit_amount;
END;
$$ LANGUAGE plpgsql;

-- Check if deposit is refundable
CREATE OR REPLACE FUNCTION is_deposit_refundable(
  p_appointment_id UUID
)
RETURNS TABLE (
  refundable BOOLEAN,
  refund_percent INTEGER,
  reason TEXT
) AS $$
DECLARE
  v_appointment appointments%ROWTYPE;
  v_service services%ROWTYPE;
  v_hours_until NUMERIC;
BEGIN
  SELECT * INTO v_appointment FROM appointments WHERE id = p_appointment_id;
  IF NOT FOUND THEN
    RETURN QUERY SELECT false, 0, 'Appointment not found'::TEXT;
    RETURN;
  END IF;

  SELECT * INTO v_service FROM services WHERE id = v_appointment.service_id;

  -- Calculate hours until appointment
  v_hours_until := EXTRACT(EPOCH FROM (v_appointment.starts_at - NOW())) / 3600;

  IF v_hours_until >= v_service.deposit_refundable_until THEN
    RETURN QUERY SELECT true, 100, 'Full refund eligible'::TEXT;
  ELSIF v_hours_until >= (v_service.deposit_refundable_until / 2) THEN
    RETURN QUERY SELECT true, 50, 'Partial refund eligible (50%)'::TEXT;
  ELSE
    RETURN QUERY SELECT false, 0, 'Cancellation deadline passed'::TEXT;
  END IF;
END;
$$ LANGUAGE plpgsql;

-- Create deposit for appointment
CREATE OR REPLACE FUNCTION create_appointment_deposit(
  p_appointment_id UUID,
  p_stripe_payment_intent_id VARCHAR DEFAULT NULL
)
RETURNS UUID AS $$
DECLARE
  v_appointment appointments%ROWTYPE;
  v_service services%ROWTYPE;
  v_deposit_amount INTEGER;
  v_deposit_id UUID;
BEGIN
  SELECT * INTO v_appointment FROM appointments WHERE id = p_appointment_id;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'Appointment not found';
  END IF;

  SELECT * INTO v_service FROM services WHERE id = v_appointment.service_id;
  IF NOT v_service.deposit_required THEN
    RETURN NULL;
  END IF;

  v_deposit_amount := calculate_deposit_amount(v_service.id, v_service.price_cents);

  INSERT INTO appointment_deposits (
    appointment_id, salon_id, customer_id,
    amount_cents, stripe_payment_intent_id, status
  ) VALUES (
    p_appointment_id, v_appointment.salon_id, v_appointment.customer_id,
    v_deposit_amount, p_stripe_payment_intent_id,
    CASE WHEN p_stripe_payment_intent_id IS NOT NULL THEN 'pending' ELSE 'pending' END
  )
  ON CONFLICT (appointment_id) DO UPDATE SET
    stripe_payment_intent_id = EXCLUDED.stripe_payment_intent_id,
    updated_at = NOW()
  RETURNING id INTO v_deposit_id;

  RETURN v_deposit_id;
END;
$$ LANGUAGE plpgsql;

-- Mark deposit as paid
CREATE OR REPLACE FUNCTION mark_deposit_paid(
  p_deposit_id UUID,
  p_stripe_charge_id VARCHAR DEFAULT NULL
)
RETURNS BOOLEAN AS $$
BEGIN
  UPDATE appointment_deposits
  SET
    status = 'paid',
    stripe_charge_id = COALESCE(p_stripe_charge_id, stripe_charge_id),
    paid_at = NOW()
  WHERE id = p_deposit_id
    AND status = 'pending';

  RETURN FOUND;
END;
$$ LANGUAGE plpgsql;

-- Process deposit refund
CREATE OR REPLACE FUNCTION process_deposit_refund(
  p_appointment_id UUID,
  p_reason TEXT DEFAULT 'Customer cancellation'
)
RETURNS TABLE (
  success BOOLEAN,
  refund_amount INTEGER,
  message TEXT
) AS $$
DECLARE
  v_deposit appointment_deposits%ROWTYPE;
  v_refund_info RECORD;
BEGIN
  SELECT * INTO v_deposit
  FROM appointment_deposits
  WHERE appointment_id = p_appointment_id
    AND status = 'paid'
  FOR UPDATE;

  IF NOT FOUND THEN
    RETURN QUERY SELECT false, 0, 'No paid deposit found'::TEXT;
    RETURN;
  END IF;

  -- Check refundability
  SELECT * INTO v_refund_info FROM is_deposit_refundable(p_appointment_id);

  IF NOT v_refund_info.refundable THEN
    -- Forfeit the deposit
    UPDATE appointment_deposits
    SET status = 'forfeited', forfeited_at = NOW()
    WHERE id = v_deposit.id;

    RETURN QUERY SELECT false, 0, v_refund_info.reason;
    RETURN;
  END IF;

  -- Calculate refund amount
  DECLARE
    v_refund_amount INTEGER;
  BEGIN
    v_refund_amount := FLOOR(v_deposit.amount_cents * v_refund_info.refund_percent / 100.0);

    UPDATE appointment_deposits
    SET
      status = 'refunded',
      refund_amount_cents = v_refund_amount,
      refund_reason = p_reason,
      refunded_at = NOW()
    WHERE id = v_deposit.id;

    RETURN QUERY SELECT true, v_refund_amount, v_refund_info.reason;
  END;
END;
$$ LANGUAGE plpgsql;

-- Apply deposit to final payment
CREATE OR REPLACE FUNCTION apply_deposit_to_payment(
  p_appointment_id UUID,
  p_order_id UUID DEFAULT NULL
)
RETURNS INTEGER AS $$
DECLARE
  v_deposit appointment_deposits%ROWTYPE;
BEGIN
  UPDATE appointment_deposits
  SET status = 'applied', applied_at = NOW()
  WHERE appointment_id = p_appointment_id
    AND status = 'paid'
  RETURNING * INTO v_deposit;

  IF FOUND THEN
    RETURN v_deposit.amount_cents;
  END IF;

  RETURN 0;
END;
$$ LANGUAGE plpgsql;

-- ============================================
-- 5. VIEWS
-- ============================================

-- Pending deposits view
CREATE OR REPLACE VIEW v_pending_deposits AS
SELECT
  ad.*,
  a.starts_at as appointment_starts_at,
  a.status as appointment_status,
  c.first_name || ' ' || c.last_name as customer_name,
  c.email as customer_email,
  c.phone as customer_phone,
  s.name as service_name,
  EXTRACT(EPOCH FROM (a.starts_at - NOW())) / 3600 as hours_until_appointment
FROM appointment_deposits ad
JOIN appointments a ON ad.appointment_id = a.id
JOIN customers c ON ad.customer_id = c.id
JOIN services s ON a.service_id = s.id
WHERE ad.status IN ('pending', 'paid');

COMMENT ON VIEW v_pending_deposits IS 'Active deposits with appointment details';

-- Deposit statistics view
CREATE OR REPLACE VIEW v_deposit_stats AS
SELECT
  ad.salon_id,
  DATE(ad.created_at) as date,
  COUNT(*) as total_deposits,
  COUNT(*) FILTER (WHERE ad.status = 'paid') as paid,
  COUNT(*) FILTER (WHERE ad.status = 'applied') as applied,
  COUNT(*) FILTER (WHERE ad.status = 'refunded') as refunded,
  COUNT(*) FILTER (WHERE ad.status = 'forfeited') as forfeited,
  SUM(ad.amount_cents) FILTER (WHERE ad.status IN ('paid', 'applied', 'forfeited')) as total_collected_cents,
  SUM(ad.refund_amount_cents) FILTER (WHERE ad.status = 'refunded') as total_refunded_cents
FROM appointment_deposits ad
GROUP BY ad.salon_id, DATE(ad.created_at);

COMMENT ON VIEW v_deposit_stats IS 'Deposit statistics by salon and date';

-- ============================================
-- 6. RLS POLICIES
-- ============================================

ALTER TABLE appointment_deposits ENABLE ROW LEVEL SECURITY;
ALTER TABLE deposit_policies ENABLE ROW LEVEL SECURITY;

-- Customers can view their own deposits
CREATE POLICY "Customers can view own deposits"
ON appointment_deposits FOR SELECT
TO authenticated
USING (
  customer_id IN (
    SELECT id FROM customers WHERE user_id = auth.uid()
  )
);

-- Staff can view salon deposits
CREATE POLICY "Staff can view salon deposits"
ON appointment_deposits FOR SELECT
TO authenticated
USING (
  salon_id IN (
    SELECT salon_id FROM staff WHERE user_id = auth.uid()
  )
);

-- Staff can manage deposits
CREATE POLICY "Staff can manage salon deposits"
ON appointment_deposits FOR ALL
TO authenticated
USING (
  salon_id IN (
    SELECT salon_id FROM staff
    WHERE user_id = auth.uid()
    AND role IN ('admin', 'manager')
  )
);

-- Deposit policies: Admin only
CREATE POLICY "Admin can manage deposit policies"
ON deposit_policies FOR ALL
TO authenticated
USING (
  salon_id IN (
    SELECT salon_id FROM staff
    WHERE user_id = auth.uid()
    AND role = 'admin'
  )
);

-- ============================================
-- 7. COMMENTS
-- ============================================

COMMENT ON TABLE appointment_deposits IS 'Deposit payments for appointment bookings';
COMMENT ON FUNCTION calculate_deposit_amount IS 'Calculate required deposit for a service';
COMMENT ON FUNCTION is_deposit_refundable IS 'Check if a deposit can be refunded based on timing';
COMMENT ON FUNCTION process_deposit_refund IS 'Process a deposit refund with policy checks';
