END;
$$ LANGUAGE plpgsql;

-- ============================================
-- FUNCTION: Create data export request
-- ============================================
CREATE OR REPLACE FUNCTION create_data_export_request(
  p_profile_id UUID,
  p_request_type TEXT DEFAULT 'export',
  p_ip_address INET DEFAULT NULL,
  p_user_agent TEXT DEFAULT NULL
)
RETURNS UUID AS $$
DECLARE
  new_request_id UUID;
  existing_request RECORD;
BEGIN
  -- Check for existing pending request
  SELECT * INTO existing_request
  FROM data_export_requests
  WHERE profile_id = p_profile_id
    AND status IN ('pending', 'processing')
    AND created_at > NOW() - INTERVAL '24 hours';

  IF FOUND THEN
    RAISE EXCEPTION 'A request is already pending';
  END IF;

  -- Create new request
  INSERT INTO data_export_requests (
    profile_id, request_type, ip_address, user_agent
  ) VALUES (
    p_profile_id, p_request_type, p_ip_address, p_user_agent
  )
  RETURNING id INTO new_request_id;

  RETURN new_request_id;
END;
$$ LANGUAGE plpgsql;

-- ============================================
-- FUNCTION: Export user data (GDPR)
-- ============================================
CREATE OR REPLACE FUNCTION export_user_data(p_profile_id UUID)
RETURNS JSONB AS $$
DECLARE
  result JSONB;
  profile_data JSONB;
  customer_data JSONB;
  appointments_data JSONB;
  orders_data JSONB;
  consent_data JSONB;
BEGIN
  -- Profile
  SELECT jsonb_build_object(
    'id', id,
    'email', email,
    'first_name', first_name,
    'last_name', last_name,
    'phone', phone,
    'created_at', created_at
  ) INTO profile_data
  FROM profiles WHERE id = p_profile_id;

  -- Customer records
  SELECT COALESCE(jsonb_agg(jsonb_build_object(
    'salon_id', c.salon_id,
    'first_name', c.first_name,
    'last_name', c.last_name,
    'birthday', c.birthday,
    'created_at', c.created_at
  )), '[]'::jsonb) INTO customer_data
  FROM customers c WHERE c.profile_id = p_profile_id;

  -- Appointments
  SELECT COALESCE(jsonb_agg(jsonb_build_object(
    'id', a.id,
    'start_time', a.start_time,
    'status', a.status,
    'total_cents', a.total_cents,
    'created_at', a.created_at
  )), '[]'::jsonb) INTO appointments_data
  FROM appointments a
  JOIN customers c ON a.customer_id = c.id
  WHERE c.profile_id = p_profile_id;

  -- Orders
  SELECT COALESCE(jsonb_agg(jsonb_build_object(
    'id', o.id,
    'order_number', o.order_number,
    'total_cents', o.total_cents,
    'status', o.status,
    'created_at', o.created_at
  )), '[]'::jsonb) INTO orders_data
  FROM orders o
  JOIN customers c ON o.customer_id = c.id
  WHERE c.profile_id = p_profile_id;

  -- Consent records
  SELECT COALESCE(jsonb_agg(jsonb_build_object(
    'category', category,
    'consented', consented,
    'consented_at', consented_at,
    'revoked_at', revoked_at
  )), '[]'::jsonb) INTO consent_data
  FROM consent_records WHERE profile_id = p_profile_id;

  -- Build result
  result := jsonb_build_object(
    'exported_at', NOW(),
    'profile', profile_data,
    'customers', customer_data,
    'appointments', appointments_data,
    'orders', orders_data,
    'consents', consent_data
  );

  RETURN result;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ============================================
-- FUNCTION: Anonymize customer data
-- ============================================
CREATE OR REPLACE FUNCTION anonymize_customer(p_customer_id UUID)
RETURNS BOOLEAN AS $$
DECLARE
  customer_record RECORD;
BEGIN
  -- Get customer
  SELECT * INTO customer_record FROM customers WHERE id = p_customer_id;
  IF NOT FOUND THEN
    RETURN false;
  END IF;

  -- Anonymize customer
  UPDATE customers
  SET
    first_name = 'Anonymisiert',
    last_name = 'Kunde',
    birthday = NULL,
    notes = NULL,
    hair_notes = NULL,
    is_active = false,
    updated_at = NOW()
  WHERE id = p_customer_id;

  -- Don't delete appointments/orders - keep for business records
  -- but anonymize customer notes
  UPDATE appointments
  SET customer_notes = NULL, internal_notes = NULL
  WHERE customer_id = p_customer_id;

  RETURN true;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ============================================
-- FUNCTION: Apply data retention policies
-- (Called by cron job)
-- ============================================
CREATE OR REPLACE FUNCTION apply_data_retention()
RETURNS TABLE (
  salon_id UUID,
  data_type TEXT,
  records_affected INTEGER
) AS $$
DECLARE
  policy RECORD;
  affected INTEGER;
BEGIN
  FOR policy IN
    SELECT * FROM data_retention_policies WHERE is_active = true
  LOOP
    affected := 0;

    CASE policy.data_type
      WHEN 'customers_inactive' THEN
        -- Anonymize inactive customers
        IF policy.action = 'anonymize' THEN
          WITH updated AS (
            UPDATE customers
            SET
              first_name = 'Anonymisiert',
              last_name = 'Kunde',
              birthday = NULL,
              notes = NULL,
              hair_notes = NULL
            WHERE salon_id = policy.salon_id
              AND is_active = false
              AND last_visit_at < NOW() - (policy.retention_days || ' days')::INTERVAL
              AND first_name != 'Anonymisiert'
            RETURNING id
          )
          SELECT COUNT(*) INTO affected FROM updated;
        END IF;

      WHEN 'notifications' THEN
        -- Delete old notifications
        IF policy.action = 'delete' THEN
          WITH deleted_rows AS (
            DELETE FROM notifications
            WHERE salon_id = policy.salon_id
              AND created_at < NOW() - (policy.retention_days || ' days')::INTERVAL
            RETURNING id
          )
          SELECT COUNT(*) INTO affected FROM deleted_rows;
        END IF;

      ELSE
        -- Other data types - implement as needed
        affected := 0;
    END CASE;

    IF affected > 0 THEN
      salon_id := policy.salon_id;
      data_type := policy.data_type;
      records_affected := affected;
      RETURN NEXT;
    END IF;
  END LOOP;
END;
$$ LANGUAGE plpgsql;

-- ============================================
-- VIEW: Current consents per user
-- ============================================

-- ============================================
-- Default retention policies (insert for each salon)
-- ============================================
-- These will be created per-salon when salon is created
-- ============================================
-- SCHNITTWERK Database Schema
-- Migration: 00012_system.sql
-- Description: Audit logs, settings, system tables
-- ============================================

-- ============================================
-- AUDIT_LOGS TABLE
-- Comprehensive audit trail
-- ============================================
CREATE TABLE audit_logs (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  salon_id UUID REFERENCES salons(id) ON DELETE SET NULL,

  -- Who performed the action
  actor_id UUID REFERENCES profiles(id) ON DELETE SET NULL,
  actor_email TEXT,
  actor_role role_name,

  -- What was done
  action audit_action_type NOT NULL,

  -- Target entity
  entity_type TEXT NOT NULL,
  entity_id UUID,

  -- Details
  old_values JSONB,
  new_values JSONB,
  metadata JSONB DEFAULT '{}',

  -- Context
  ip_address INET,
  user_agent TEXT,
  session_id TEXT,

  -- Timestamps
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

COMMENT ON TABLE audit_logs IS 'System-wide audit trail';
COMMENT ON COLUMN audit_logs.old_values IS 'Previous state before change';
COMMENT ON COLUMN audit_logs.new_values IS 'New state after change';
COMMENT ON COLUMN audit_logs.metadata IS 'Additional context data';

-- Indexes
CREATE INDEX idx_audit_logs_salon ON audit_logs(salon_id);
CREATE INDEX idx_audit_logs_actor ON audit_logs(actor_id);
CREATE INDEX idx_audit_logs_action ON audit_logs(action);
CREATE INDEX idx_audit_logs_entity ON audit_logs(entity_type, entity_id);
CREATE INDEX idx_audit_logs_date ON audit_logs(created_at);
CREATE INDEX idx_audit_logs_salon_date ON audit_logs(salon_id, created_at DESC);

-- ============================================
-- SETTINGS TABLE
-- Global application settings
-- ============================================
CREATE TABLE settings (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  salon_id UUID REFERENCES salons(id) ON DELETE CASCADE,

  -- Setting identification
  key TEXT NOT NULL,
  category TEXT NOT NULL DEFAULT 'general',

  -- Value
  value JSONB NOT NULL,
  value_type TEXT DEFAULT 'string',
  -- Types: string, number, boolean, json

  -- Description
  description TEXT,

  -- Access control
  is_public BOOLEAN DEFAULT false,
  is_editable BOOLEAN DEFAULT true,

  -- Timestamps
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),

  -- Constraints
  CONSTRAINT unique_setting_key UNIQUE (salon_id, key)
);

COMMENT ON TABLE settings IS 'Application settings';
COMMENT ON COLUMN settings.key IS 'Setting identifier';
COMMENT ON COLUMN settings.is_public IS 'Whether visible without auth';

-- Indexes
CREATE INDEX idx_settings_salon ON settings(salon_id);
CREATE INDEX idx_settings_key ON settings(key);
CREATE INDEX idx_settings_category ON settings(category);

-- Apply updated_at trigger
CREATE TRIGGER update_settings_updated_at
  BEFORE UPDATE ON settings
  FOR EACH ROW
  EXECUTE FUNCTION update_updated_at_column();

-- ============================================
-- FEATURE_FLAGS TABLE
-- Feature toggles per salon
-- ============================================
CREATE TABLE feature_flags (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  salon_id UUID REFERENCES salons(id) ON DELETE CASCADE,

  -- Flag identification
  flag_key TEXT NOT NULL,

  -- Status
  is_enabled BOOLEAN NOT NULL DEFAULT false,

  -- Rollout configuration
  rollout_percentage INTEGER DEFAULT 100 CHECK (rollout_percentage BETWEEN 0 AND 100),

  -- User targeting
  enabled_for_users UUID[] DEFAULT '{}',
  disabled_for_users UUID[] DEFAULT '{}',

  -- Metadata
  description TEXT,

  -- Timestamps
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),

  -- Constraints
  CONSTRAINT unique_feature_flag UNIQUE (salon_id, flag_key)
);

COMMENT ON TABLE feature_flags IS 'Feature flag configuration';
COMMENT ON COLUMN feature_flags.rollout_percentage IS 'Percentage of users who see feature';

-- Indexes
CREATE INDEX idx_feature_flags_salon ON feature_flags(salon_id);
CREATE INDEX idx_feature_flags_key ON feature_flags(flag_key);

-- Apply updated_at trigger
CREATE TRIGGER update_feature_flags_updated_at
  BEFORE UPDATE ON feature_flags
  FOR EACH ROW
  EXECUTE FUNCTION update_updated_at_column();

-- ============================================
-- OPENING_HOURS TABLE
-- Salon operating hours
-- ============================================
CREATE TABLE opening_hours (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  salon_id UUID NOT NULL REFERENCES salons(id) ON DELETE CASCADE,

  -- Day (0 = Monday, 6 = Sunday)
  day_of_week INTEGER NOT NULL CHECK (day_of_week BETWEEN 0 AND 6),

  -- Times
  open_time TIME NOT NULL,
  close_time TIME NOT NULL,

  -- Whether open on this day
  is_open BOOLEAN NOT NULL DEFAULT true,

  -- Timestamps
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),

  -- Constraints
  CONSTRAINT unique_opening_hours UNIQUE (salon_id, day_of_week),
  CONSTRAINT valid_hours CHECK (close_time > open_time)
);

COMMENT ON TABLE opening_hours IS 'Regular salon opening hours';

-- Indexes
CREATE INDEX idx_opening_hours_salon ON opening_hours(salon_id);

-- Apply updated_at trigger
CREATE TRIGGER update_opening_hours_updated_at
  BEFORE UPDATE ON opening_hours
  FOR EACH ROW
  EXECUTE FUNCTION update_updated_at_column();

-- ============================================
-- SPECIAL_HOURS TABLE
-- Exceptions to regular hours (holidays, special days)
-- ============================================
CREATE TABLE special_hours (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  salon_id UUID NOT NULL REFERENCES salons(id) ON DELETE CASCADE,

  -- Date
  date DATE NOT NULL,

  -- Override hours (NULL means closed)
  open_time TIME,
  close_time TIME,

  -- Whether open
  is_open BOOLEAN NOT NULL DEFAULT false,

  -- Reason
  reason TEXT,

  -- Timestamps
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),

  -- Constraints
  CONSTRAINT unique_special_hours UNIQUE (salon_id, date)
);

COMMENT ON TABLE special_hours IS 'Special hours exceptions';

-- Indexes
CREATE INDEX idx_special_hours_salon ON special_hours(salon_id);
CREATE INDEX idx_special_hours_date ON special_hours(salon_id, date);

-- ============================================
-- INTEGRATIONS TABLE
-- External service integrations
-- ============================================
CREATE TABLE integrations (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  salon_id UUID NOT NULL REFERENCES salons(id) ON DELETE CASCADE,

  -- Integration type
  integration_type TEXT NOT NULL,
  -- Types: google_calendar, google_reviews, instagram, facebook

  -- Status
  is_enabled BOOLEAN NOT NULL DEFAULT false,

  -- Credentials (encrypted in practice)
  credentials JSONB DEFAULT '{}',

  -- Configuration
  config JSONB DEFAULT '{}',

  -- Sync status
  last_sync_at TIMESTAMPTZ,
  last_sync_status TEXT,
  last_sync_error TEXT,

  -- Timestamps
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),

  -- Constraints
  CONSTRAINT unique_integration UNIQUE (salon_id, integration_type)
);

COMMENT ON TABLE integrations IS 'External service integrations';
COMMENT ON COLUMN integrations.credentials IS 'API keys/tokens (should be encrypted)';

-- Indexes
CREATE INDEX idx_integrations_salon ON integrations(salon_id);
CREATE INDEX idx_integrations_type ON integrations(integration_type);

-- Apply updated_at trigger
CREATE TRIGGER update_integrations_updated_at
  BEFORE UPDATE ON integrations
  FOR EACH ROW
  EXECUTE FUNCTION update_updated_at_column();

-- ============================================
-- CRON_JOBS TABLE
-- Track scheduled job executions
-- ============================================
CREATE TABLE cron_jobs (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),

  -- Job identification
  job_name TEXT NOT NULL,
  job_type TEXT NOT NULL,
  -- Types: cleanup_reservations, send_reminders, sync_calendar, aggregate_sales

  -- Schedule (cron expression)
  schedule TEXT NOT NULL,

  -- Status
  is_enabled BOOLEAN NOT NULL DEFAULT true,

  -- Last execution
  last_run_at TIMESTAMPTZ,
  last_run_status TEXT,
  last_run_duration_ms INTEGER,
  last_run_error TEXT,

  -- Next scheduled run
  next_run_at TIMESTAMPTZ,

  -- Timestamps
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),

  -- Constraints
  CONSTRAINT unique_cron_job UNIQUE (job_name)
);

COMMENT ON TABLE cron_jobs IS 'Scheduled job configuration and status';

-- Indexes
CREATE INDEX idx_cron_jobs_next_run ON cron_jobs(next_run_at) WHERE is_enabled = true;

-- Apply updated_at trigger
CREATE TRIGGER update_cron_jobs_updated_at
  BEFORE UPDATE ON cron_jobs
  FOR EACH ROW
  EXECUTE FUNCTION update_updated_at_column();

-- ============================================
-- FUNCTION: Log audit event
-- ============================================
CREATE OR REPLACE FUNCTION log_audit(
  p_salon_id UUID,
  p_actor_id UUID,
  p_action audit_action_type,
  p_entity_type TEXT,
  p_entity_id UUID,
  p_old_values JSONB DEFAULT NULL,
  p_new_values JSONB DEFAULT NULL,
  p_metadata JSONB DEFAULT '{}',
  p_ip_address INET DEFAULT NULL,
  p_user_agent TEXT DEFAULT NULL
)
RETURNS UUID AS $$
DECLARE
  new_log_id UUID;
  actor_email TEXT;
  actor_role role_name;
BEGIN
  -- Get actor info
  IF p_actor_id IS NOT NULL THEN
    SELECT email INTO actor_email FROM profiles WHERE id = p_actor_id;
    SELECT role_name INTO actor_role
    FROM user_roles
    WHERE profile_id = p_actor_id
      AND (salon_id = p_salon_id OR salon_id IS NULL)
    LIMIT 1;
  END IF;

  -- Insert log
  INSERT INTO audit_logs (
    salon_id, actor_id, actor_email, actor_role,
    action, entity_type, entity_id,
    old_values, new_values, metadata,
    ip_address, user_agent
  ) VALUES (
    p_salon_id, p_actor_id, actor_email, actor_role,
    p_action, p_entity_type, p_entity_id,
    p_old_values, p_new_values, p_metadata,
    p_ip_address, p_user_agent
  )
  RETURNING id INTO new_log_id;

  RETURN new_log_id;
END;
$$ LANGUAGE plpgsql;

-- ============================================
-- FUNCTION: Get setting value
-- ============================================
CREATE OR REPLACE FUNCTION get_setting(
  p_key TEXT,
  p_salon_id UUID DEFAULT NULL
)
RETURNS JSONB AS $$
  SELECT value
  FROM settings
  WHERE key = p_key
    AND (salon_id = p_salon_id OR (p_salon_id IS NULL AND salon_id IS NULL))
  LIMIT 1;
$$ LANGUAGE sql STABLE;

-- ============================================
-- FUNCTION: Set setting value
-- ============================================
CREATE OR REPLACE FUNCTION set_setting(
  p_key TEXT,
  p_value JSONB,
  p_salon_id UUID DEFAULT NULL,
  p_category TEXT DEFAULT 'general',
  p_description TEXT DEFAULT NULL
)
RETURNS VOID AS $$
BEGIN
  INSERT INTO settings (salon_id, key, value, category, description)
  VALUES (p_salon_id, p_key, p_value, p_category, p_description)
  ON CONFLICT (salon_id, key) DO UPDATE
  SET value = EXCLUDED.value, updated_at = NOW();
END;
$$ LANGUAGE plpgsql;

-- ============================================
-- FUNCTION: Check feature flag
-- ============================================
CREATE OR REPLACE FUNCTION is_feature_enabled(
  p_flag_key TEXT,
  p_salon_id UUID DEFAULT NULL,
  p_user_id UUID DEFAULT NULL
)
RETURNS BOOLEAN AS $$
DECLARE
  flag_record RECORD;
BEGIN
  SELECT * INTO flag_record
  FROM feature_flags
  WHERE flag_key = p_flag_key
    AND (salon_id = p_salon_id OR salon_id IS NULL);

  IF NOT FOUND THEN
    RETURN false;
  END IF;

  IF NOT flag_record.is_enabled THEN
    RETURN false;
  END IF;

  -- Check user-specific overrides
  IF p_user_id IS NOT NULL THEN
    IF p_user_id = ANY(flag_record.disabled_for_users) THEN
      RETURN false;
    END IF;
    IF p_user_id = ANY(flag_record.enabled_for_users) THEN
      RETURN true;
    END IF;
  END IF;

  -- Check rollout percentage
  IF flag_record.rollout_percentage < 100 THEN
    -- Simple hash-based rollout
    RETURN (ABS(HASHTEXT(COALESCE(p_user_id::TEXT, p_salon_id::TEXT, ''))) % 100) < flag_record.rollout_percentage;
  END IF;

  RETURN true;
END;
$$ LANGUAGE plpgsql STABLE;

-- ============================================
-- FUNCTION: Get salon opening hours for date
-- ============================================
CREATE OR REPLACE FUNCTION get_salon_hours_for_date(
  p_salon_id UUID,
  p_date DATE
)
RETURNS TABLE (
  is_open BOOLEAN,
  open_time TIME,
  close_time TIME,
  is_special BOOLEAN,
  reason TEXT
) AS $$
DECLARE
  special RECORD;
  regular RECORD;
  day_num INTEGER;
BEGIN
  -- Check special hours first
  SELECT * INTO special
  FROM special_hours
  WHERE salon_id = p_salon_id AND date = p_date;

  IF FOUND THEN
    is_open := special.is_open;
    open_time := special.open_time;
    close_time := special.close_time;
    is_special := true;
    reason := special.reason;
    RETURN NEXT;
    RETURN;
  END IF;

  -- Get regular hours
  day_num := EXTRACT(DOW FROM p_date)::INTEGER;
  -- Convert from Sunday=0 to Monday=0
  day_num := CASE WHEN day_num = 0 THEN 6 ELSE day_num - 1 END;

  SELECT * INTO regular
  FROM opening_hours
  WHERE salon_id = p_salon_id AND day_of_week = day_num;

  IF FOUND THEN
    is_open := regular.is_open;
    open_time := regular.open_time;
    close_time := regular.close_time;
    is_special := false;
    reason := NULL;
    RETURN NEXT;
    RETURN;
  END IF;

  -- No hours defined - default closed
  is_open := false;
  open_time := NULL;
  close_time := NULL;
  is_special := false;
  reason := NULL;
  RETURN NEXT;
END;
$$ LANGUAGE plpgsql STABLE;

-- ============================================
-- VIEW: Recent audit logs
-- ============================================

-- ============================================
-- Insert default cron jobs
-- ============================================
INSERT INTO cron_jobs (job_name, job_type, schedule) VALUES
  ('cleanup_expired_reservations', 'cleanup_reservations', '*/5 * * * *'),
  ('send_appointment_reminders', 'send_reminders', '0 * * * *'),
  ('aggregate_daily_sales', 'aggregate_sales', '0 1 * * *'),
  ('apply_data_retention', 'data_retention', '0 3 * * 0')
ON CONFLICT (job_name) DO NOTHING;
-- ============================================
-- SCHNITTWERK Database Schema
-- Migration: 00013_indexes.sql
-- Description: Additional performance indexes
-- ============================================

-- Note: Most indexes are created inline with their tables.
-- This file adds additional composite and specialized indexes
-- for common query patterns.

-- ============================================
-- APPOINTMENTS - Common Query Patterns
-- ============================================

-- Staff calendar view: appointments for a staff member in a date range
CREATE INDEX IF NOT EXISTS idx_appointments_staff_calendar
ON appointments (staff_id, start_time, status)
WHERE status NOT IN ('cancelled');

-- Customer history: all appointments for a customer
CREATE INDEX IF NOT EXISTS idx_appointments_customer_history
ON appointments (customer_id, start_time DESC);

-- Dashboard stats: completed appointments this month
CREATE INDEX IF NOT EXISTS idx_appointments_completed_month
ON appointments (salon_id, completed_at)
WHERE status = 'completed';

-- Upcoming reminders: confirmed appointments needing reminders
CREATE INDEX IF NOT EXISTS idx_appointments_for_reminders
ON appointments (start_time)
WHERE status = 'confirmed';

-- ============================================
-- ORDERS - Common Query Patterns
-- ============================================

-- Customer order history
CREATE INDEX IF NOT EXISTS idx_orders_customer_history
ON orders (customer_id, created_at DESC);

-- Unfulfilled orders (pending, paid)
CREATE INDEX IF NOT EXISTS idx_orders_unfulfilled
ON orders (salon_id, created_at)
WHERE status IN ('pending', 'paid');

-- Pickup orders
CREATE INDEX IF NOT EXISTS idx_orders_pickup
ON orders (salon_id, pickup_date)
WHERE shipping_method = 'pickup' AND status NOT IN ('cancelled', 'completed');

-- ============================================
-- PRODUCTS - Common Query Patterns
-- ============================================

-- Product search by name (simple btree index instead of trigram)
CREATE INDEX IF NOT EXISTS idx_products_name_search
ON products (name);

-- Featured products
CREATE INDEX IF NOT EXISTS idx_products_featured
ON products (salon_id, sort_order)
WHERE is_featured = true AND is_active = true AND is_published = true;

-- Category listing
CREATE INDEX IF NOT EXISTS idx_products_category_list
ON products (category_id, sort_order)
WHERE is_active = true AND is_published = true;

-- ============================================
-- CUSTOMERS - Common Query Patterns
-- ============================================

-- Customer search by name
CREATE INDEX IF NOT EXISTS idx_customers_name_search
ON customers (salon_id, last_name text_pattern_ops, first_name text_pattern_ops);

-- Birthday this month (for birthday greetings)
CREATE INDEX IF NOT EXISTS idx_customers_birthday_month
ON customers (salon_id, EXTRACT(MONTH FROM birthday), EXTRACT(DAY FROM birthday))
WHERE birthday IS NOT NULL AND is_active = true;

-- Inactive customers (no visit in X days)
CREATE INDEX IF NOT EXISTS idx_customers_inactive
ON customers (salon_id, last_visit_at)
WHERE is_active = true;

-- ============================================
-- STAFF - Common Query Patterns
-- ============================================

-- Bookable staff with services
CREATE INDEX IF NOT EXISTS idx_staff_bookable_active
ON staff (salon_id, sort_order)
WHERE is_active = true AND is_bookable = true;

-- ============================================
-- SERVICES - Common Query Patterns
-- ============================================

-- Services by category for booking
CREATE INDEX IF NOT EXISTS idx_services_booking
ON services (salon_id, category_id, sort_order)
WHERE is_active = true AND is_bookable_online = true;

-- Service duration lookup
CREATE INDEX IF NOT EXISTS idx_services_duration
ON services (id, duration_minutes, buffer_before_minutes, buffer_after_minutes)
WHERE is_active = true;

-- ============================================
-- PAYMENTS - Common Query Patterns
-- ============================================

-- Daily revenue aggregation
CREATE INDEX IF NOT EXISTS idx_payments_daily_revenue
ON payments (salon_id, DATE(succeeded_at), payment_method)
WHERE status = 'succeeded';

-- Stripe reconciliation
CREATE INDEX IF NOT EXISTS idx_payments_stripe_reconcile
ON payments (stripe_payment_intent_id)
WHERE stripe_payment_intent_id IS NOT NULL;

-- ============================================
-- VOUCHERS - Common Query Patterns
-- ============================================

-- Valid vouchers lookup
CREATE INDEX IF NOT EXISTS idx_vouchers_valid
ON vouchers (salon_id, UPPER(code))
WHERE is_active = true;

-- Expiring vouchers
CREATE INDEX IF NOT EXISTS idx_vouchers_expiring
ON vouchers (salon_id, valid_until)
WHERE is_active = true AND valid_until IS NOT NULL;

-- ============================================
-- LOYALTY - Common Query Patterns
-- ============================================

-- Top loyalty customers
CREATE INDEX IF NOT EXISTS idx_customer_loyalty_top
ON customer_loyalty (program_id, lifetime_points DESC);

-- Points expiring soon
CREATE INDEX IF NOT EXISTS idx_loyalty_trans_expiring
ON loyalty_transactions (expires_at)
WHERE expires_at IS NOT NULL AND expires_at > NOW();

-- ============================================
-- NOTIFICATIONS - Common Query Patterns
-- ============================================

-- Notification queue processing
CREATE INDEX IF NOT EXISTS idx_notifications_queue
ON notifications (scheduled_for NULLS FIRST, created_at)
WHERE status = 'pending';

-- Failed notifications for retry
CREATE INDEX IF NOT EXISTS idx_notifications_failed_retry
ON notifications (created_at)
WHERE status = 'failed' AND retry_count < max_retries;

-- ============================================
-- AUDIT LOGS - Common Query Patterns
-- ============================================

-- Customer data access audit
CREATE INDEX IF NOT EXISTS idx_audit_customer_access
ON audit_logs (entity_id, created_at DESC)
WHERE entity_type = 'customer' AND action IN ('customer_view', 'customer_export');

-- Settings changes
CREATE INDEX IF NOT EXISTS idx_audit_settings
ON audit_logs (salon_id, created_at DESC)
WHERE action = 'settings_changed';

-- ============================================
-- FULL TEXT SEARCH INDEXES
-- ============================================

-- Product full text search
-- CREATE INDEX IF NOT EXISTS idx_products_fts
-- ON products USING gin (
--   to_tsvector('german', COALESCE(name, '') || ' ' || COALESCE(description, '') || ' ' || COALESCE(brand, ''))
-- );

-- Customer full text search
-- CREATE INDEX IF NOT EXISTS idx_customers_fts
-- ON customers USING gin (
--   to_tsvector('german', COALESCE(first_name, '') || ' ' || COALESCE(last_name, '') || ' ' || COALESCE(notes, ''))
-- );

-- ============================================
-- PARTIAL INDEXES FOR PERFORMANCE
-- ============================================

-- Only index active records in frequently queried tables
CREATE INDEX IF NOT EXISTS idx_services_active_only
ON services (salon_id, name)
WHERE is_active = true;

CREATE INDEX IF NOT EXISTS idx_products_active_only
ON products (salon_id, name)
WHERE is_active = true;

CREATE INDEX IF NOT EXISTS idx_customers_active_only
ON customers (salon_id, first_name, last_name)
WHERE is_active = true;

-- ============================================
-- BRIN INDEXES FOR TIME-SERIES DATA
-- (Efficient for append-only tables)
-- ============================================

-- Audit logs are append-only, BRIN is efficient
CREATE INDEX IF NOT EXISTS idx_audit_logs_brin
ON audit_logs USING brin (created_at);

-- Stock movements are append-only
CREATE INDEX IF NOT EXISTS idx_stock_movements_brin
ON stock_movements USING brin (created_at);

-- Loyalty transactions are append-only
CREATE INDEX IF NOT EXISTS idx_loyalty_trans_brin
ON loyalty_transactions USING brin (created_at);

-- ============================================
-- STATISTICS TARGETS
-- Increase statistics for frequently used columns
-- ============================================

ALTER TABLE appointments ALTER COLUMN status SET STATISTICS 500;
ALTER TABLE appointments ALTER COLUMN start_time SET STATISTICS 500;
ALTER TABLE orders ALTER COLUMN status SET STATISTICS 500;
ALTER TABLE products ALTER COLUMN is_active SET STATISTICS 500;
ALTER TABLE customers ALTER COLUMN is_active SET STATISTICS 500;

-- ============================================
-- ANALYZE COMMAND
-- Run after data load to update statistics
-- ============================================
-- ANALYZE appointments;
-- ANALYZE orders;
-- ANALYZE products;
-- ANALYZE customers;
-- ANALYZE payments;
-- ============================================
-- SCHNITTWERK Database Schema
-- Migration: 00014_rls_policies.sql
-- Description: Row Level Security (RLS) policies
-- ============================================

-- ============================================
-- ENABLE RLS ON ALL TABLES
-- ============================================

ALTER TABLE salons ENABLE ROW LEVEL SECURITY;
ALTER TABLE profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE roles ENABLE ROW LEVEL SECURITY;
ALTER TABLE user_roles ENABLE ROW LEVEL SECURITY;
ALTER TABLE customers ENABLE ROW LEVEL SECURITY;
ALTER TABLE staff ENABLE ROW LEVEL SECURITY;
ALTER TABLE staff_schedule_overrides ENABLE ROW LEVEL SECURITY;
ALTER TABLE service_categories ENABLE ROW LEVEL SECURITY;
ALTER TABLE services ENABLE ROW LEVEL SECURITY;
ALTER TABLE service_length_variants ENABLE ROW LEVEL SECURITY;
ALTER TABLE staff_service_skills ENABLE ROW LEVEL SECURITY;
ALTER TABLE addon_services ENABLE ROW LEVEL SECURITY;
ALTER TABLE service_addon_compatibility ENABLE ROW LEVEL SECURITY;
ALTER TABLE appointments ENABLE ROW LEVEL SECURITY;
ALTER TABLE appointment_services ENABLE ROW LEVEL SECURITY;
ALTER TABLE appointment_addons ENABLE ROW LEVEL SECURITY;
ALTER TABLE waitlist ENABLE ROW LEVEL SECURITY;
ALTER TABLE blocked_times ENABLE ROW LEVEL SECURITY;
ALTER TABLE product_categories ENABLE ROW LEVEL SECURITY;
ALTER TABLE products ENABLE ROW LEVEL SECURITY;
ALTER TABLE product_images ENABLE ROW LEVEL SECURITY;
ALTER TABLE product_variants ENABLE ROW LEVEL SECURITY;
ALTER TABLE stock_movements ENABLE ROW LEVEL SECURITY;
ALTER TABLE vouchers ENABLE ROW LEVEL SECURITY;
ALTER TABLE orders ENABLE ROW LEVEL SECURITY;
ALTER TABLE order_items ENABLE ROW LEVEL SECURITY;
ALTER TABLE order_status_history ENABLE ROW LEVEL SECURITY;
ALTER TABLE payments ENABLE ROW LEVEL SECURITY;
ALTER TABLE refunds ENABLE ROW LEVEL SECURITY;
ALTER TABLE stripe_webhooks_log ENABLE ROW LEVEL SECURITY;
ALTER TABLE daily_sales ENABLE ROW LEVEL SECURITY;
ALTER TABLE loyalty_programs ENABLE ROW LEVEL SECURITY;
ALTER TABLE loyalty_tiers ENABLE ROW LEVEL SECURITY;
ALTER TABLE customer_loyalty ENABLE ROW LEVEL SECURITY;
ALTER TABLE loyalty_transactions ENABLE ROW LEVEL SECURITY;
ALTER TABLE notification_templates ENABLE ROW LEVEL SECURITY;
ALTER TABLE notification_preferences ENABLE ROW LEVEL SECURITY;
ALTER TABLE notifications ENABLE ROW LEVEL SECURITY;
ALTER TABLE scheduled_reminders ENABLE ROW LEVEL SECURITY;
ALTER TABLE consent_records ENABLE ROW LEVEL SECURITY;
ALTER TABLE data_export_requests ENABLE ROW LEVEL SECURITY;
ALTER TABLE data_retention_policies ENABLE ROW LEVEL SECURITY;
ALTER TABLE audit_logs ENABLE ROW LEVEL SECURITY;
ALTER TABLE settings ENABLE ROW LEVEL SECURITY;
ALTER TABLE feature_flags ENABLE ROW LEVEL SECURITY;
ALTER TABLE opening_hours ENABLE ROW LEVEL SECURITY;
ALTER TABLE special_hours ENABLE ROW LEVEL SECURITY;
ALTER TABLE integrations ENABLE ROW LEVEL SECURITY;
ALTER TABLE cron_jobs ENABLE ROW LEVEL SECURITY;

-- ============================================
-- HELPER FUNCTION: Get user's salon IDs
-- Already created in 00002, ensuring it exists
-- ============================================

-- ============================================
-- PROFILES POLICIES
-- ============================================

-- Users can read their own profile
CREATE POLICY profiles_select_own ON profiles
  FOR SELECT
  USING (auth.uid() = id);

-- Users can update their own profile
CREATE POLICY profiles_update_own ON profiles
  FOR UPDATE
  USING (auth.uid() = id);

-- Staff can read profiles of customers in their salon
CREATE POLICY profiles_select_staff ON profiles
  FOR SELECT
  USING (
    EXISTS (
      SELECT 1 FROM user_roles ur
      WHERE ur.profile_id = auth.uid()
        AND ur.role_name IN ('admin', 'manager', 'mitarbeiter')
        AND ur.salon_id IN (
          SELECT c.salon_id FROM customers c WHERE c.profile_id = profiles.id
        )
    )
  );

-- ============================================
-- SALONS POLICIES
-- ============================================

-- Public: Anyone can read active salons (for booking)
CREATE POLICY salons_select_public ON salons
  FOR SELECT
  USING (is_active = true);

-- Admin/Manager can update their salon
CREATE POLICY salons_update_staff ON salons
  FOR UPDATE
  USING (
    EXISTS (
      SELECT 1 FROM user_roles
      WHERE profile_id = auth.uid()
        AND salon_id = salons.id
        AND role_name IN ('admin', 'manager')
    )
  );

-- ============================================
-- USER_ROLES POLICIES
-- ============================================

-- Users can see their own roles
CREATE POLICY user_roles_select_own ON user_roles
  FOR SELECT
  USING (profile_id = auth.uid());

-- Admin can manage roles for their salon
CREATE POLICY user_roles_admin ON user_roles
  FOR ALL
  USING (
    EXISTS (
      SELECT 1 FROM user_roles ur
      WHERE ur.profile_id = auth.uid()
        AND ur.salon_id = user_roles.salon_id
        AND ur.role_name = 'admin'
    )
  );

-- ============================================
-- CUSTOMERS POLICIES
-- ============================================

-- Customers can see their own record
CREATE POLICY customers_select_own ON customers
  FOR SELECT
  USING (profile_id = auth.uid());

-- Customers can update their own record
CREATE POLICY customers_update_own ON customers
  FOR UPDATE
  USING (profile_id = auth.uid())
  WITH CHECK (profile_id = auth.uid());

-- Staff can see customers in their salon
CREATE POLICY customers_select_staff ON customers
  FOR SELECT
  USING (
    salon_id IN (SELECT get_user_salon_ids(auth.uid()))
    AND EXISTS (
      SELECT 1 FROM user_roles
      WHERE profile_id = auth.uid()
        AND role_name IN ('admin', 'manager', 'mitarbeiter')
    )
  );

-- Staff can manage customers in their salon
CREATE POLICY customers_manage_staff ON customers
  FOR ALL
  USING (
    salon_id IN (SELECT get_user_salon_ids(auth.uid()))
    AND EXISTS (
      SELECT 1 FROM user_roles
      WHERE profile_id = auth.uid()
        AND role_name IN ('admin', 'manager')
    )
  );

-- ============================================
-- STAFF POLICIES
-- ============================================

-- Public: Anyone can see bookable staff (for booking)
CREATE POLICY staff_select_public ON staff
  FOR SELECT
  USING (is_active = true AND is_bookable = true);

-- Staff can see all staff in their salon
CREATE POLICY staff_select_staff ON staff
  FOR SELECT
  USING (
    salon_id IN (SELECT get_user_salon_ids(auth.uid()))
  );

-- Admin can manage staff
CREATE POLICY staff_manage_admin ON staff
  FOR ALL
  USING (
    is_admin(auth.uid(), salon_id)
  );

-- ============================================
-- SERVICES POLICIES
-- ============================================

-- Public: Anyone can see active bookable services
CREATE POLICY services_select_public ON services
  FOR SELECT
  USING (is_active = true AND is_bookable_online = true);

-- Staff can see all services in their salon
CREATE POLICY services_select_staff ON services
  FOR SELECT
  USING (
    salon_id IN (SELECT get_user_salon_ids(auth.uid()))
  );

-- Admin/Manager can manage services
CREATE POLICY services_manage_staff ON services
  FOR ALL
  USING (
    EXISTS (
      SELECT 1 FROM user_roles
      WHERE profile_id = auth.uid()
        AND salon_id = services.salon_id
        AND role_name IN ('admin', 'manager')
    )
  );

-- ============================================
-- SERVICE_CATEGORIES POLICIES
-- ============================================

-- Public: Anyone can see active categories
CREATE POLICY service_categories_select_public ON service_categories
  FOR SELECT
  USING (is_active = true);

-- Admin/Manager can manage categories
CREATE POLICY service_categories_manage_staff ON service_categories
  FOR ALL
  USING (
    EXISTS (
      SELECT 1 FROM user_roles
      WHERE profile_id = auth.uid()
        AND salon_id = service_categories.salon_id
        AND role_name IN ('admin', 'manager')
    )
  );

-- ============================================
-- APPOINTMENTS POLICIES
-- ============================================

-- Customers can see their own appointments
CREATE POLICY appointments_select_own ON appointments
  FOR SELECT
  USING (
    EXISTS (
      SELECT 1 FROM customers c
      WHERE c.id = appointments.customer_id
        AND c.profile_id = auth.uid()
    )
  );

-- Customers can create appointments (via reservation)
CREATE POLICY appointments_insert_customer ON appointments
  FOR INSERT
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM customers c
      WHERE c.id = appointments.customer_id
        AND c.profile_id = auth.uid()
    )
  );

-- Customers can update their own pending appointments (cancel)
CREATE POLICY appointments_update_own ON appointments
  FOR UPDATE
  USING (
    EXISTS (
      SELECT 1 FROM customers c
      WHERE c.id = appointments.customer_id
        AND c.profile_id = auth.uid()
    )
    AND status IN ('reserved', 'requested')
  );

-- Staff can see appointments in their salon
CREATE POLICY appointments_select_staff ON appointments
  FOR SELECT
  USING (
    salon_id IN (SELECT get_user_salon_ids(auth.uid()))
    AND is_staff(auth.uid(), salon_id)
  );

-- Staff can manage appointments in their salon
CREATE POLICY appointments_manage_staff ON appointments
  FOR ALL
  USING (
    salon_id IN (SELECT get_user_salon_ids(auth.uid()))
    AND is_staff(auth.uid(), salon_id)
  );

-- ============================================
-- PRODUCTS POLICIES
-- ============================================

-- Public: Anyone can see published products
CREATE POLICY products_select_public ON products
  FOR SELECT
  USING (is_active = true AND is_published = true);

-- Staff can see all products
CREATE POLICY products_select_staff ON products
  FOR SELECT
  USING (
    salon_id IN (SELECT get_user_salon_ids(auth.uid()))
  );

-- Admin/Manager can manage products
CREATE POLICY products_manage_staff ON products
  FOR ALL
  USING (
    EXISTS (
      SELECT 1 FROM user_roles
      WHERE profile_id = auth.uid()
        AND salon_id = products.salon_id
        AND role_name IN ('admin', 'manager')
    )
  );

-- ============================================
-- ORDERS POLICIES
-- ============================================

-- Customers can see their own orders
CREATE POLICY orders_select_own ON orders
  FOR SELECT
  USING (
    EXISTS (
      SELECT 1 FROM customers c
      WHERE c.id = orders.customer_id
        AND c.profile_id = auth.uid()
    )
  );

-- Customers can create orders
CREATE POLICY orders_insert_customer ON orders
  FOR INSERT
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM customers c
      WHERE c.id = orders.customer_id
        AND c.profile_id = auth.uid()
    )
  );

-- Staff can see orders in their salon
CREATE POLICY orders_select_staff ON orders
  FOR SELECT
  USING (
    salon_id IN (SELECT get_user_salon_ids(auth.uid()))
    AND is_staff(auth.uid(), salon_id)
  );

-- Staff can manage orders
CREATE POLICY orders_manage_staff ON orders
  FOR ALL
  USING (
    salon_id IN (SELECT get_user_salon_ids(auth.uid()))
    AND is_staff(auth.uid(), salon_id)
  );

-- ============================================
-- PAYMENTS POLICIES
-- ============================================

-- Customers can see their own payments
CREATE POLICY payments_select_own ON payments
  FOR SELECT
  USING (
    reference_type = 'order' AND EXISTS (
      SELECT 1 FROM orders o
      JOIN customers c ON o.customer_id = c.id
      WHERE o.id = payments.reference_id
        AND c.profile_id = auth.uid()
    )
  );

-- Staff can see payments in their salon
CREATE POLICY payments_select_staff ON payments
  FOR SELECT
  USING (
    salon_id IN (SELECT get_user_salon_ids(auth.uid()))
    AND is_staff(auth.uid(), salon_id)
  );

-- Admin can manage payments
CREATE POLICY payments_manage_admin ON payments
  FOR ALL
  USING (
    is_admin(auth.uid(), salon_id)
  );

-- ============================================
-- VOUCHERS POLICIES
-- ============================================

-- Public: Validate voucher (limited info)
CREATE POLICY vouchers_validate_public ON vouchers
  FOR SELECT
  USING (is_active = true);

-- Staff can see all vouchers
CREATE POLICY vouchers_select_staff ON vouchers
  FOR SELECT
  USING (
    salon_id IN (SELECT get_user_salon_ids(auth.uid()))
    AND is_staff(auth.uid(), salon_id)
  );

-- Admin/Manager can manage vouchers
CREATE POLICY vouchers_manage_staff ON vouchers
  FOR ALL
  USING (
    EXISTS (
      SELECT 1 FROM user_roles
      WHERE profile_id = auth.uid()
        AND salon_id = vouchers.salon_id
        AND role_name IN ('admin', 'manager')
    )
  );

-- ============================================
-- LOYALTY POLICIES
-- ============================================

-- Customers can see their own loyalty
CREATE POLICY customer_loyalty_select_own ON customer_loyalty
  FOR SELECT
  USING (
    EXISTS (
      SELECT 1 FROM customers c
      WHERE c.id = customer_loyalty.customer_id
        AND c.profile_id = auth.uid()
    )
  );

-- Staff can see loyalty in their salon
CREATE POLICY customer_loyalty_select_staff ON customer_loyalty
  FOR SELECT
  USING (
    EXISTS (
      SELECT 1 FROM customers c
      WHERE c.id = customer_loyalty.customer_id
        AND c.salon_id IN (SELECT get_user_salon_ids(auth.uid()))
    )
  );

-- ============================================
-- NOTIFICATION PREFERENCES POLICIES
-- ============================================

-- Users can manage their own preferences
CREATE POLICY notification_prefs_own ON notification_preferences
  FOR ALL
  USING (profile_id = auth.uid());

-- ============================================
-- CONSENT RECORDS POLICIES
-- ============================================

-- Users can see their own consent records
CREATE POLICY consent_records_select_own ON consent_records
  FOR SELECT
  USING (profile_id = auth.uid());

-- Users can manage their own consent
CREATE POLICY consent_records_manage_own ON consent_records
  FOR ALL
  USING (profile_id = auth.uid());

-- ============================================
-- DATA EXPORT REQUESTS POLICIES
-- ============================================

-- Users can see and create their own requests
CREATE POLICY data_export_requests_own ON data_export_requests
  FOR ALL
  USING (profile_id = auth.uid());

-- ============================================
-- AUDIT LOGS POLICIES
-- ============================================

-- Admin can see audit logs for their salon
CREATE POLICY audit_logs_select_admin ON audit_logs
  FOR SELECT
  USING (
    is_admin(auth.uid(), salon_id)
  );

-- No one can modify audit logs (immutable)
-- INSERT is done via SECURITY DEFINER functions

-- ============================================
-- SETTINGS POLICIES
-- ============================================

-- Public settings can be read by anyone
CREATE POLICY settings_select_public ON settings
  FOR SELECT
  USING (is_public = true);

-- Staff can see settings for their salon
CREATE POLICY settings_select_staff ON settings
  FOR SELECT
  USING (
    salon_id IN (SELECT get_user_salon_ids(auth.uid()))
  );

-- Admin can manage settings
CREATE POLICY settings_manage_admin ON settings
  FOR ALL
  USING (
    is_admin(auth.uid(), salon_id)
  );

-- ============================================
-- OPENING HOURS POLICIES
-- ============================================

-- Public: Anyone can see opening hours
CREATE POLICY opening_hours_select_public ON opening_hours
  FOR SELECT
  USING (true);

-- Admin can manage opening hours
CREATE POLICY opening_hours_manage_admin ON opening_hours
  FOR ALL
  USING (
    is_admin(auth.uid(), salon_id)
  );

-- ============================================
-- SPECIAL HOURS POLICIES
-- ============================================

-- Public: Anyone can see special hours
CREATE POLICY special_hours_select_public ON special_hours
  FOR SELECT
  USING (true);

-- Admin can manage special hours
CREATE POLICY special_hours_manage_admin ON special_hours
  FOR ALL
  USING (
    is_admin(auth.uid(), salon_id)
  );

-- ============================================
-- SERVICE ACCOUNT BYPASS
-- For backend operations via service role
-- ============================================

-- Note: When using the service role key (supabase_service_role),
-- RLS is bypassed automatically. This is used for:
-- - Cron jobs
-- - Webhook handlers
-- - Admin operations
-- - Data migrations

-- ============================================
-- HQ ROLE POLICIES
-- Cross-salon access for headquarters
-- ============================================

-- HQ can see all salons
CREATE POLICY salons_select_hq ON salons
  FOR SELECT
  USING (
    has_role(auth.uid(), 'hq')
  );

-- HQ can see all customers across salons
CREATE POLICY customers_select_hq ON customers
  FOR SELECT
  USING (
    has_role(auth.uid(), 'hq')
  );

-- HQ can see all appointments across salons
CREATE POLICY appointments_select_hq ON appointments
  FOR SELECT
  USING (
    has_role(auth.uid(), 'hq')
  );

-- HQ can see all orders across salons
CREATE POLICY orders_select_hq ON orders
  FOR SELECT
  USING (
    has_role(auth.uid(), 'hq')
  );

-- HQ can see all payments across salons
CREATE POLICY payments_select_hq ON payments
  FOR SELECT
  USING (
    has_role(auth.uid(), 'hq')
  );

-- HQ can see daily sales across salons
CREATE POLICY daily_sales_select_hq ON daily_sales
  FOR SELECT
  USING (
    has_role(auth.uid(), 'hq')
  );
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
