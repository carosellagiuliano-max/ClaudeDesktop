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
CREATE VIEW v_customer_loyalty AS
SELECT
  cl.*,
  c.first_name || ' ' || c.last_name AS customer_name,
  c.salon_id,
  lp.name AS program_name,
  lt.name AS tier_name,
  lt.points_multiplier,
  lt.discount_percent AS tier_discount_percent,
  (cl.points_balance * lp.points_value_cents / 100.0) AS points_value_chf
FROM customer_loyalty cl
JOIN customers c ON cl.customer_id = c.id
JOIN loyalty_programs lp ON cl.program_id = lp.id
LEFT JOIN loyalty_tiers lt ON cl.current_tier_id = lt.id;

COMMENT ON VIEW v_customer_loyalty IS 'Customer loyalty with tier info';

-- ============================================
-- VIEW: Recent loyalty transactions
-- ============================================
CREATE VIEW v_recent_loyalty_transactions AS
SELECT
  lt.*,
  c.first_name || ' ' || c.last_name AS customer_name,
  c.salon_id
FROM loyalty_transactions lt
JOIN customer_loyalty cl ON lt.customer_loyalty_id = cl.id
JOIN customers c ON cl.customer_id = c.id
WHERE lt.created_at >= NOW() - INTERVAL '30 days'
ORDER BY lt.created_at DESC;

COMMENT ON VIEW v_recent_loyalty_transactions IS 'Recent loyalty activity';
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
CREATE VIEW v_pending_notifications AS
SELECT
  n.*,
  p.first_name || ' ' || p.last_name AS recipient_name
FROM notifications n
LEFT JOIN profiles p ON n.profile_id = p.id
WHERE n.status = 'pending'
  OR (n.status = 'scheduled' AND n.scheduled_for <= NOW())
ORDER BY COALESCE(n.scheduled_for, n.created_at);

COMMENT ON VIEW v_pending_notifications IS 'Notifications ready to be sent';

-- ============================================
-- VIEW: Notification statistics
-- ============================================
CREATE VIEW v_notification_stats AS
SELECT
  salon_id,
  DATE(created_at) AS date,
  channel,
  status,
  COUNT(*) AS count
FROM notifications
WHERE created_at >= NOW() - INTERVAL '30 days'
GROUP BY salon_id, DATE(created_at), channel, status;

COMMENT ON VIEW v_notification_stats IS 'Notification delivery statistics';
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
          WITH deleted AS (
            DELETE FROM notifications
            WHERE salon_id = policy.salon_id
              AND created_at < NOW() - (policy.retention_days || ' days')::INTERVAL
            RETURNING id
          )
          SELECT COUNT(*) INTO deleted FROM deleted;
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
CREATE VIEW v_user_consents AS
SELECT DISTINCT ON (profile_id, category)
  profile_id,
  category,
  consented,
  consented_at,
  revoked_at,
  CASE
    WHEN revoked_at IS NOT NULL THEN false
    WHEN expires_at IS NOT NULL AND expires_at < NOW() THEN false
    ELSE consented
  END AS is_active
FROM consent_records
ORDER BY profile_id, category, consented_at DESC;

COMMENT ON VIEW v_user_consents IS 'Current consent status per user';

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
CREATE VIEW v_recent_audit_logs AS
SELECT
  al.*,
  p.first_name || ' ' || p.last_name AS actor_name
FROM audit_logs al
LEFT JOIN profiles p ON al.actor_id = p.id
WHERE al.created_at >= NOW() - INTERVAL '7 days'
ORDER BY al.created_at DESC;

COMMENT ON VIEW v_recent_audit_logs IS 'Recent audit activity';

-- ============================================
-- Insert default cron jobs
-- ============================================
INSERT INTO cron_jobs (job_name, job_type, schedule) VALUES
  ('cleanup_expired_reservations', 'cleanup_reservations', '*/5 * * * *'),
  ('send_appointment_reminders', 'send_reminders', '0 * * * *'),
  ('aggregate_daily_sales', 'aggregate_sales', '0 1 * * *'),
  ('apply_data_retention', 'data_retention', '0 3 * * 0')
ON CONFLICT (job_name) DO NOTHING;
