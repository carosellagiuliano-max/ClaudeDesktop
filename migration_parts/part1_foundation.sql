-- ============================================
-- SCHNITTWERK Database Schema
-- Migration: 00001_enums.sql
-- Description: All PostgreSQL ENUM types
-- ============================================

-- Appointment status enum
CREATE TYPE appointment_status AS ENUM (
  'reserved',     -- Temporarily held, awaiting payment/confirmation
  'requested',    -- Customer requested, awaiting staff approval
  'confirmed',    -- Confirmed and scheduled
  'cancelled',    -- Cancelled by customer or staff
  'completed',    -- Service was performed
  'no_show'       -- Customer did not appear
);

-- Order status enum
CREATE TYPE order_status AS ENUM (
  'pending',      -- Order created, awaiting payment
  'paid',         -- Payment received
  'shipped',      -- Order shipped (for delivery)
  'completed',    -- Order fulfilled
  'cancelled',    -- Order cancelled
  'refunded'      -- Order refunded
);

-- Payment method enum
CREATE TYPE payment_method AS ENUM (
  'stripe_card',       -- Online card payment via Stripe
  'stripe_twint',      -- Twint via Stripe (Switzerland)
  'cash',              -- Cash payment at venue
  'terminal',          -- Card terminal at venue
  'voucher',           -- Voucher/gift card
  'manual_adjustment'  -- Manual adjustment by admin
);

-- Payment status enum
CREATE TYPE payment_status AS ENUM (
  'pending',            -- Payment initiated
  'succeeded',          -- Payment successful
  'failed',             -- Payment failed
  'refunded',           -- Fully refunded
  'partially_refunded'  -- Partially refunded
);

-- Role name enum (RBAC)
CREATE TYPE role_name AS ENUM (
  'admin',        -- Full salon access
  'manager',      -- Operational access
  'mitarbeiter',  -- Staff access
  'kunde',        -- Customer access
  'hq'            -- Cross-salon access (headquarters)
);

-- Consent category enum (GDPR/DSG)
CREATE TYPE consent_category AS ENUM (
  'marketing_email',  -- Email marketing consent
  'marketing_sms',    -- SMS marketing consent
  'loyalty',          -- Loyalty program data processing
  'analytics'         -- Analytics tracking consent
);

-- Notification channel enum
CREATE TYPE notification_channel AS ENUM (
  'email',  -- Email notifications
  'sms',    -- SMS notifications
  'push'    -- Push notifications (future)
);

-- Waitlist status enum
CREATE TYPE waitlist_status AS ENUM (
  'active',     -- Actively waiting
  'notified',   -- Customer was notified of availability
  'converted',  -- Converted to booking
  'cancelled'   -- Customer cancelled waitlist entry
);

-- Blocked time type enum
CREATE TYPE blocked_time_type AS ENUM (
  'holiday',      -- Public holiday
  'vacation',     -- Staff vacation
  'sick',         -- Sick leave
  'maintenance',  -- Salon maintenance
  'other'         -- Other reason
);

-- Stock movement type enum
CREATE TYPE stock_movement_type AS ENUM (
  'purchase',     -- Purchased/received stock
  'sale',         -- Sold to customer
  'adjustment',   -- Manual adjustment
  'return',       -- Returned by customer
  'damaged',      -- Damaged/lost
  'transfer'      -- Transfer between locations
);

-- Audit action type enum
CREATE TYPE audit_action_type AS ENUM (
  'appointment_created',
  'appointment_updated',
  'appointment_cancelled',
  'appointment_no_show',
  'order_created',
  'order_updated',
  'order_refunded',
  'customer_created',
  'customer_updated',
  'customer_deleted',
  'customer_view',
  'customer_export',
  'orders_export',
  'appointments_export',
  'impersonation_start',
  'impersonation_end',
  'role_changed',
  'consent_changed',
  'settings_changed',
  'payment_processed',
  'payment_refunded'
);

-- Shipping method type enum
CREATE TYPE shipping_method_type AS ENUM (
  'shipping',  -- Physical delivery
  'pickup'     -- Pickup at salon
);

-- No-show policy enum
CREATE TYPE no_show_policy AS ENUM (
  'none',           -- No charge
  'charge_deposit', -- Charge deposit only
  'charge_full'     -- Charge full amount
);

COMMENT ON TYPE appointment_status IS 'Status of salon appointments';
COMMENT ON TYPE order_status IS 'Status of shop orders';
COMMENT ON TYPE payment_method IS 'Accepted payment methods';
COMMENT ON TYPE payment_status IS 'Status of payment transactions';
COMMENT ON TYPE role_name IS 'User roles for RBAC';
COMMENT ON TYPE consent_category IS 'GDPR/DSG consent categories';
COMMENT ON TYPE notification_channel IS 'Communication channels';
COMMENT ON TYPE waitlist_status IS 'Status of waitlist entries';
COMMENT ON TYPE blocked_time_type IS 'Types of blocked time periods';
COMMENT ON TYPE stock_movement_type IS 'Types of inventory movements';
COMMENT ON TYPE audit_action_type IS 'Types of auditable actions';
COMMENT ON TYPE shipping_method_type IS 'Types of shipping/delivery';
COMMENT ON TYPE no_show_policy IS 'Policy for no-show handling';
-- ============================================
-- SCHNITTWERK Database Schema
-- Migration: 00002_core_tables.sql
-- Description: Core tables (salons, profiles, roles, user_roles)
-- ============================================

-- ============================================
-- SALONS TABLE
-- ============================================
CREATE TABLE salons (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name TEXT NOT NULL,
  slug TEXT NOT NULL UNIQUE,

  -- Contact & Location
  address TEXT,
  zip_code TEXT,
  city TEXT,
  country TEXT DEFAULT 'Schweiz',
  phone TEXT,
  email TEXT,
  website TEXT,

  -- Business Info
  timezone TEXT NOT NULL DEFAULT 'Europe/Zurich',
  currency TEXT NOT NULL DEFAULT 'CHF',
  default_vat_rate DECIMAL(5,2) DEFAULT 8.1,

  -- Configuration (JSON)
  settings_json JSONB DEFAULT '{}',
  theme_config JSONB DEFAULT '{}',

  -- Status
  is_active BOOLEAN NOT NULL DEFAULT true,

  -- Timestamps
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

COMMENT ON TABLE salons IS 'Physical salon locations';
COMMENT ON COLUMN salons.slug IS 'URL-friendly unique identifier';
COMMENT ON COLUMN salons.settings_json IS 'Salon-specific settings as JSON';
COMMENT ON COLUMN salons.theme_config IS 'Branding/theme configuration';

-- ============================================
-- PROFILES TABLE
-- Links to Supabase auth.users
-- ============================================
CREATE TABLE profiles (
  id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  email TEXT NOT NULL,

  -- Personal Info
  first_name TEXT,
  last_name TEXT,
  display_name TEXT,
  phone TEXT,
  avatar_url TEXT,

  -- Preferences
  preferred_language TEXT DEFAULT 'de',

  -- Status
  is_active BOOLEAN NOT NULL DEFAULT true,
  email_verified BOOLEAN DEFAULT false,
  phone_verified BOOLEAN DEFAULT false,

  -- Timestamps
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

COMMENT ON TABLE profiles IS 'User profiles linked to auth.users';
COMMENT ON COLUMN profiles.id IS 'References auth.users.id';
COMMENT ON COLUMN profiles.display_name IS 'Computed or custom display name';

-- ============================================
-- ROLES TABLE
-- Static role definitions
-- ============================================
CREATE TABLE roles (
  role_name role_name PRIMARY KEY,
  description TEXT,
  permissions JSONB DEFAULT '{}',
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

COMMENT ON TABLE roles IS 'Role definitions with permissions';
COMMENT ON COLUMN roles.permissions IS 'JSON object defining role permissions';

-- Insert default roles
INSERT INTO roles (role_name, description, permissions) VALUES
  ('admin', 'Full salon access - can manage everything', '{"all": true}'),
  ('manager', 'Operational access - can manage daily operations', '{"appointments": true, "customers": true, "orders": true, "staff": true, "inventory": true, "analytics": true}'),
  ('mitarbeiter', 'Staff access - can view calendar and customers', '{"appointments": true, "customers": {"read": true}, "own_calendar": true}'),
  ('kunde', 'Customer access - can view own data', '{"own_profile": true, "own_appointments": true, "own_orders": true}'),
  ('hq', 'Cross-salon access - headquarters view', '{"cross_salon": true, "analytics": true, "read_all": true}');

-- ============================================
-- USER_ROLES TABLE
-- Maps users to roles per salon
-- ============================================
CREATE TABLE user_roles (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  profile_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
  salon_id UUID REFERENCES salons(id) ON DELETE CASCADE,
  role_name role_name NOT NULL,

  -- Metadata
  assigned_by UUID REFERENCES profiles(id),
  assigned_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),

  -- Timestamps
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),

  -- Constraints
  CONSTRAINT unique_user_role_per_salon UNIQUE (profile_id, salon_id, role_name)
);

COMMENT ON TABLE user_roles IS 'User role assignments per salon';
COMMENT ON COLUMN user_roles.salon_id IS 'NULL for global roles like HQ';
COMMENT ON COLUMN user_roles.assigned_by IS 'Who assigned this role';

-- Create index for fast role lookups
CREATE INDEX idx_user_roles_profile ON user_roles(profile_id);
CREATE INDEX idx_user_roles_salon ON user_roles(salon_id);
CREATE INDEX idx_user_roles_role ON user_roles(role_name);

-- ============================================
-- TRIGGER: Auto-update updated_at
-- ============================================
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Apply trigger to salons
CREATE TRIGGER update_salons_updated_at
  BEFORE UPDATE ON salons
  FOR EACH ROW
  EXECUTE FUNCTION update_updated_at_column();

-- Apply trigger to profiles
CREATE TRIGGER update_profiles_updated_at
  BEFORE UPDATE ON profiles
  FOR EACH ROW
  EXECUTE FUNCTION update_updated_at_column();

-- ============================================
-- TRIGGER: Auto-create profile on auth.users insert
-- ============================================
CREATE OR REPLACE FUNCTION handle_new_user()
RETURNS TRIGGER AS $$
BEGIN
  INSERT INTO public.profiles (id, email, first_name, last_name)
  VALUES (
    NEW.id,
    NEW.email,
    NEW.raw_user_meta_data->>'first_name',
    NEW.raw_user_meta_data->>'last_name'
  );
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Trigger on auth.users
CREATE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW
  EXECUTE FUNCTION handle_new_user();

-- ============================================
-- HELPER FUNCTION: Get user's salon IDs
-- ============================================
CREATE OR REPLACE FUNCTION get_user_salon_ids(user_id UUID)
RETURNS SETOF UUID AS $$
  SELECT DISTINCT salon_id
  FROM user_roles
  WHERE profile_id = user_id
    AND salon_id IS NOT NULL;
$$ LANGUAGE sql SECURITY DEFINER STABLE;

-- ============================================
-- HELPER FUNCTION: Check if user has role
-- ============================================
CREATE OR REPLACE FUNCTION has_role(user_id UUID, check_role role_name, check_salon_id UUID DEFAULT NULL)
RETURNS BOOLEAN AS $$
  SELECT EXISTS (
    SELECT 1 FROM user_roles
    WHERE profile_id = user_id
      AND role_name = check_role
      AND (check_salon_id IS NULL OR salon_id = check_salon_id OR salon_id IS NULL)
  );
$$ LANGUAGE sql SECURITY DEFINER STABLE;

-- ============================================
-- HELPER FUNCTION: Check if user is staff (admin/manager/mitarbeiter)
-- ============================================
CREATE OR REPLACE FUNCTION is_staff(user_id UUID, check_salon_id UUID)
RETURNS BOOLEAN AS $$
  SELECT EXISTS (
    SELECT 1 FROM user_roles
    WHERE profile_id = user_id
      AND salon_id = check_salon_id
      AND role_name IN ('admin', 'manager', 'mitarbeiter')
  );
$$ LANGUAGE sql SECURITY DEFINER STABLE;

-- ============================================
-- HELPER FUNCTION: Check if user is admin
-- ============================================
CREATE OR REPLACE FUNCTION is_admin(user_id UUID, check_salon_id UUID)
RETURNS BOOLEAN AS $$
  SELECT EXISTS (
    SELECT 1 FROM user_roles
    WHERE profile_id = user_id
      AND salon_id = check_salon_id
      AND role_name = 'admin'
  );
$$ LANGUAGE sql SECURITY DEFINER STABLE;
-- ============================================
-- SCHNITTWERK Database Schema
-- Migration: 00003_customer_staff.sql
-- Description: Customer and Staff tables
-- ============================================

-- ============================================
-- CUSTOMERS TABLE
-- Salon-specific customer records
-- ============================================
CREATE TABLE customers (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  salon_id UUID NOT NULL REFERENCES salons(id) ON DELETE CASCADE,
  profile_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,

  -- Personal Info (denormalized for salon-specific data)
  first_name TEXT NOT NULL,
  last_name TEXT NOT NULL,
  birthday DATE,

  -- Contact preferences (can differ from profile)
  preferred_contact TEXT DEFAULT 'email',

  -- Customer notes (internal, only staff can see)
  notes TEXT,
  hair_notes TEXT,

  -- Marketing preferences
  accepts_marketing BOOLEAN DEFAULT false,

  -- Status
  is_active BOOLEAN NOT NULL DEFAULT true,

  -- Timestamps
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  last_visit_at TIMESTAMPTZ,

  -- Constraints
  CONSTRAINT unique_customer_per_salon UNIQUE (salon_id, profile_id)
);

COMMENT ON TABLE customers IS 'Salon-specific customer records';
COMMENT ON COLUMN customers.profile_id IS 'Links to profiles table (auth user)';
COMMENT ON COLUMN customers.notes IS 'Internal notes visible only to staff';
COMMENT ON COLUMN customers.hair_notes IS 'Hair-specific notes (color history, preferences)';
COMMENT ON COLUMN customers.last_visit_at IS 'Updated after each completed appointment';

-- Indexes for customers
CREATE INDEX idx_customers_salon ON customers(salon_id);
CREATE INDEX idx_customers_profile ON customers(profile_id);
CREATE INDEX idx_customers_name ON customers(salon_id, last_name, first_name);
CREATE INDEX idx_customers_last_visit ON customers(salon_id, last_visit_at);

-- Apply updated_at trigger
CREATE TRIGGER update_customers_updated_at
  BEFORE UPDATE ON customers
  FOR EACH ROW
  EXECUTE FUNCTION update_updated_at_column();

-- ============================================
-- STAFF TABLE
-- Staff members per salon
-- ============================================
CREATE TABLE staff (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  salon_id UUID NOT NULL REFERENCES salons(id) ON DELETE CASCADE,
  profile_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,

  -- Staff Info
  display_name TEXT NOT NULL,
  job_title TEXT,
  bio TEXT,
  avatar_url TEXT,

  -- Booking settings
  is_bookable BOOLEAN NOT NULL DEFAULT true,
  booking_lead_time_minutes INTEGER DEFAULT 60,
  max_daily_appointments INTEGER,

  -- Work schedule (JSON for flexibility)
  -- Format: { "mon": [{"start": "09:00", "end": "18:00"}], ... }
  default_schedule JSONB DEFAULT '{}',

  -- Display order (for UI sorting)
  sort_order INTEGER DEFAULT 0,

  -- Commission settings
  commission_rate DECIMAL(5,2),

  -- Status
  is_active BOOLEAN NOT NULL DEFAULT true,

  -- Timestamps
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),

  -- Constraints
  CONSTRAINT unique_staff_per_salon UNIQUE (salon_id, profile_id)
);

COMMENT ON TABLE staff IS 'Staff members who can be booked';
COMMENT ON COLUMN staff.display_name IS 'Name shown to customers';
COMMENT ON COLUMN staff.is_bookable IS 'Whether staff accepts online bookings';
COMMENT ON COLUMN staff.default_schedule IS 'Default weekly schedule as JSON';
COMMENT ON COLUMN staff.commission_rate IS 'Percentage for commission tracking';

-- Indexes for staff
CREATE INDEX idx_staff_salon ON staff(salon_id);
CREATE INDEX idx_staff_profile ON staff(profile_id);
CREATE INDEX idx_staff_bookable ON staff(salon_id, is_bookable) WHERE is_active = true;

-- Apply updated_at trigger
CREATE TRIGGER update_staff_updated_at
  BEFORE UPDATE ON staff
  FOR EACH ROW
  EXECUTE FUNCTION update_updated_at_column();

-- ============================================
-- STAFF_SCHEDULE_OVERRIDES TABLE
-- Daily schedule overrides (vacations, special days)
-- ============================================
CREATE TABLE staff_schedule_overrides (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  staff_id UUID NOT NULL REFERENCES staff(id) ON DELETE CASCADE,

  -- Date range
  date DATE NOT NULL,

  -- Override type
  override_type blocked_time_type NOT NULL DEFAULT 'other',

  -- If not fully blocked, custom hours
  -- NULL means fully blocked, otherwise custom hours
  custom_hours JSONB,

  -- Notes
  notes TEXT,

  -- Timestamps
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),

  -- Constraints
  CONSTRAINT unique_staff_date_override UNIQUE (staff_id, date)
);

COMMENT ON TABLE staff_schedule_overrides IS 'Daily schedule exceptions for staff';
COMMENT ON COLUMN staff_schedule_overrides.custom_hours IS 'Custom hours if partially available, NULL if fully blocked';

-- Indexes
CREATE INDEX idx_staff_overrides_staff ON staff_schedule_overrides(staff_id);
CREATE INDEX idx_staff_overrides_date ON staff_schedule_overrides(date);
CREATE INDEX idx_staff_overrides_range ON staff_schedule_overrides(staff_id, date);

-- ============================================
-- HELPER FUNCTION: Get customer full name
-- ============================================
CREATE OR REPLACE FUNCTION get_customer_full_name(customer_id UUID)
RETURNS TEXT AS $$
  SELECT first_name || ' ' || last_name
  FROM customers
  WHERE id = customer_id;
$$ LANGUAGE sql STABLE;

-- ============================================
-- HELPER FUNCTION: Get staff display name
-- ============================================
CREATE OR REPLACE FUNCTION get_staff_display_name(staff_member_id UUID)
RETURNS TEXT AS $$
  SELECT display_name
  FROM staff
  WHERE id = staff_member_id;
$$ LANGUAGE sql STABLE;

-- ============================================
-- HELPER FUNCTION: Check if staff is available on date
-- ============================================
CREATE OR REPLACE FUNCTION is_staff_available_on_date(staff_member_id UUID, check_date DATE)
RETURNS BOOLEAN AS $$
DECLARE
  staff_record RECORD;
  override_record RECORD;
  day_of_week TEXT;
BEGIN
  -- Get staff record
  SELECT * INTO staff_record FROM staff WHERE id = staff_member_id AND is_active = true;
  IF NOT FOUND THEN
    RETURN false;
  END IF;

  -- Check if not bookable
  IF NOT staff_record.is_bookable THEN
    RETURN false;
  END IF;

  -- Check for override (vacation, sick, etc.)
  SELECT * INTO override_record
  FROM staff_schedule_overrides
  WHERE staff_id = staff_member_id AND date = check_date;

  IF FOUND AND override_record.custom_hours IS NULL THEN
    -- Fully blocked
    RETURN false;
  END IF;

  -- Check default schedule for day of week
  day_of_week := LOWER(TO_CHAR(check_date, 'Dy'));

  IF staff_record.default_schedule ? day_of_week THEN
    RETURN true;
  END IF;

  RETURN false;
END;
$$ LANGUAGE plpgsql STABLE;

-- ============================================
-- VIEW: Active customers with computed fields
-- ============================================
CREATE VIEW v_active_customers AS
SELECT
  c.*,
  c.first_name || ' ' || c.last_name AS full_name,
  p.email,
  p.phone AS profile_phone,
  (
    SELECT COUNT(*)
    FROM appointments a
    WHERE a.customer_id = c.id
    AND a.status = 'completed'
  ) AS total_appointments,
  (
    SELECT MAX(a.start_time)
    FROM appointments a
    WHERE a.customer_id = c.id
    AND a.status = 'completed'
  ) AS last_appointment_date
FROM customers c
JOIN profiles p ON c.profile_id = p.id
WHERE c.is_active = true;

COMMENT ON VIEW v_active_customers IS 'Active customers with computed statistics';

-- ============================================
-- VIEW: Active bookable staff
-- ============================================
CREATE VIEW v_bookable_staff AS
SELECT
  s.*,
  p.email,
  p.phone AS profile_phone
FROM staff s
JOIN profiles p ON s.profile_id = p.id
WHERE s.is_active = true AND s.is_bookable = true;

COMMENT ON VIEW v_bookable_staff IS 'Staff members available for booking';
