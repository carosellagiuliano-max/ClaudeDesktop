-- ============================================
-- SCHNITTWERK Database Migration - PART A
-- Tables, Functions, Triggers, Indexes
-- Run this FIRST
-- ============================================

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

-- ============================================
-- VIEW: Active bookable staff
-- ============================================

-- ============================================
-- SCHNITTWERK Database Schema
-- Migration: 00004_services.sql
-- Description: Service categories, services, and staff skills
-- ============================================

-- ============================================
-- SERVICE_CATEGORIES TABLE
-- Groups services for easier navigation
-- ============================================
CREATE TABLE service_categories (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  salon_id UUID NOT NULL REFERENCES salons(id) ON DELETE CASCADE,

  -- Category Info
  name TEXT NOT NULL,
  slug TEXT NOT NULL,
  description TEXT,
  icon TEXT,

  -- Display
  sort_order INTEGER DEFAULT 0,

  -- Status
  is_active BOOLEAN NOT NULL DEFAULT true,

  -- Timestamps
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),

  -- Constraints
  CONSTRAINT unique_category_slug_per_salon UNIQUE (salon_id, slug)
);

COMMENT ON TABLE service_categories IS 'Service categories for grouping';
COMMENT ON COLUMN service_categories.slug IS 'URL-friendly unique identifier within salon';
COMMENT ON COLUMN service_categories.icon IS 'Icon identifier or emoji';

-- Indexes
CREATE INDEX idx_service_categories_salon ON service_categories(salon_id);

-- Apply updated_at trigger
CREATE TRIGGER update_service_categories_updated_at
  BEFORE UPDATE ON service_categories
  FOR EACH ROW
  EXECUTE FUNCTION update_updated_at_column();

-- ============================================
-- SERVICES TABLE
-- Bookable services offered by the salon
-- ============================================
CREATE TABLE services (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  salon_id UUID NOT NULL REFERENCES salons(id) ON DELETE CASCADE,
  category_id UUID REFERENCES service_categories(id) ON DELETE SET NULL,

  -- Service Info
  name TEXT NOT NULL,
  slug TEXT NOT NULL,
  description TEXT,
  short_description TEXT,

  -- Duration (in minutes)
  duration_minutes INTEGER NOT NULL,
  buffer_before_minutes INTEGER DEFAULT 0,
  buffer_after_minutes INTEGER DEFAULT 0,

  -- Pricing (in CHF cents for precision)
  price_cents INTEGER NOT NULL,
  price_from BOOLEAN DEFAULT false,

  -- For variable pricing based on hair length
  -- NULL means fixed price, otherwise links to length variants
  has_length_variants BOOLEAN DEFAULT false,

  -- Booking settings
  is_bookable_online BOOLEAN DEFAULT true,
  requires_deposit BOOLEAN DEFAULT false,
  deposit_amount_cents INTEGER,

  -- Display
  sort_order INTEGER DEFAULT 0,
  image_url TEXT,

  -- Status
  is_active BOOLEAN NOT NULL DEFAULT true,

  -- Timestamps
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),

  -- Constraints
  CONSTRAINT unique_service_slug_per_salon UNIQUE (salon_id, slug),
  CONSTRAINT positive_duration CHECK (duration_minutes > 0),
  CONSTRAINT positive_price CHECK (price_cents >= 0)
);

COMMENT ON TABLE services IS 'Bookable salon services';
COMMENT ON COLUMN services.duration_minutes IS 'Total service duration';
COMMENT ON COLUMN services.buffer_before_minutes IS 'Preparation time before service';
COMMENT ON COLUMN services.buffer_after_minutes IS 'Cleanup time after service';
COMMENT ON COLUMN services.price_cents IS 'Price in CHF cents (e.g., 4500 = 45.00 CHF)';
COMMENT ON COLUMN services.price_from IS 'If true, price displayed as "ab X CHF"';
COMMENT ON COLUMN services.has_length_variants IS 'If true, service has different prices per hair length';

-- Indexes
CREATE INDEX idx_services_salon ON services(salon_id);
CREATE INDEX idx_services_category ON services(category_id);
CREATE INDEX idx_services_bookable ON services(salon_id, is_bookable_online) WHERE is_active = true;

-- Apply updated_at trigger
CREATE TRIGGER update_services_updated_at
  BEFORE UPDATE ON services
  FOR EACH ROW
  EXECUTE FUNCTION update_updated_at_column();

-- ============================================
-- SERVICE_LENGTH_VARIANTS TABLE
-- Different prices based on hair length
-- ============================================
CREATE TABLE service_length_variants (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  service_id UUID NOT NULL REFERENCES services(id) ON DELETE CASCADE,

  -- Length Info
  name TEXT NOT NULL,
  description TEXT,

  -- Overrides
  duration_minutes INTEGER,
  price_cents INTEGER NOT NULL,

  -- Display
  sort_order INTEGER DEFAULT 0,

  -- Timestamps
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),

  -- Constraints
  CONSTRAINT positive_variant_price CHECK (price_cents >= 0)
);

COMMENT ON TABLE service_length_variants IS 'Hair length variants for services';
COMMENT ON COLUMN service_length_variants.name IS 'E.g., "Kurz", "Mittel", "Lang"';
COMMENT ON COLUMN service_length_variants.duration_minutes IS 'Override duration, NULL uses service default';

-- Indexes
CREATE INDEX idx_service_variants_service ON service_length_variants(service_id);

-- ============================================
-- STAFF_SERVICE_SKILLS TABLE
-- Maps which staff can perform which services
-- ============================================
CREATE TABLE staff_service_skills (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  staff_id UUID NOT NULL REFERENCES staff(id) ON DELETE CASCADE,
  service_id UUID NOT NULL REFERENCES services(id) ON DELETE CASCADE,

  -- Skill level (optional, for future use)
  skill_level INTEGER DEFAULT 3 CHECK (skill_level BETWEEN 1 AND 5),

  -- Custom pricing (NULL = use service default)
  custom_price_cents INTEGER,
  custom_duration_minutes INTEGER,

  -- Timestamps
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),

  -- Constraints
  CONSTRAINT unique_staff_service UNIQUE (staff_id, service_id)
);

COMMENT ON TABLE staff_service_skills IS 'Staff skills and service assignments';
COMMENT ON COLUMN staff_service_skills.skill_level IS 'Skill level 1-5 (5 = expert)';
COMMENT ON COLUMN staff_service_skills.custom_price_cents IS 'Staff-specific price override';

-- Indexes
CREATE INDEX idx_staff_skills_staff ON staff_service_skills(staff_id);
CREATE INDEX idx_staff_skills_service ON staff_service_skills(service_id);

-- ============================================
-- ADDON_SERVICES TABLE
-- Optional add-on services that can be booked with main service
-- ============================================
CREATE TABLE addon_services (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  salon_id UUID NOT NULL REFERENCES salons(id) ON DELETE CASCADE,

  -- Addon Info
  name TEXT NOT NULL,
  description TEXT,

  -- Duration & Price
  duration_minutes INTEGER DEFAULT 0,
  price_cents INTEGER NOT NULL,

  -- Display
  sort_order INTEGER DEFAULT 0,

  -- Status
  is_active BOOLEAN NOT NULL DEFAULT true,

  -- Timestamps
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),

  -- Constraints
  CONSTRAINT positive_addon_price CHECK (price_cents >= 0)
);

COMMENT ON TABLE addon_services IS 'Add-on services (treatments, etc.)';
COMMENT ON COLUMN addon_services.duration_minutes IS 'Additional time needed, 0 if concurrent';

-- Indexes
CREATE INDEX idx_addon_services_salon ON addon_services(salon_id);

-- Apply updated_at trigger
CREATE TRIGGER update_addon_services_updated_at
  BEFORE UPDATE ON addon_services
  FOR EACH ROW
  EXECUTE FUNCTION update_updated_at_column();

-- ============================================
-- SERVICE_ADDON_COMPATIBILITY TABLE
-- Defines which addons can be used with which services
-- ============================================
CREATE TABLE service_addon_compatibility (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  service_id UUID NOT NULL REFERENCES services(id) ON DELETE CASCADE,
  addon_service_id UUID NOT NULL REFERENCES addon_services(id) ON DELETE CASCADE,

  -- Timestamps
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),

  -- Constraints
  CONSTRAINT unique_service_addon UNIQUE (service_id, addon_service_id)
);

COMMENT ON TABLE service_addon_compatibility IS 'Maps which addons work with which services';

-- Indexes
CREATE INDEX idx_addon_compat_service ON service_addon_compatibility(service_id);
CREATE INDEX idx_addon_compat_addon ON service_addon_compatibility(addon_service_id);

-- ============================================
-- VIEW: Services with category info
-- ============================================

-- ============================================
-- VIEW: Staff with their services
-- ============================================

-- ============================================
-- HELPER FUNCTION: Get service total duration
-- ============================================
CREATE OR REPLACE FUNCTION get_service_total_duration(service_id_param UUID)
RETURNS INTEGER AS $$
  SELECT duration_minutes + COALESCE(buffer_before_minutes, 0) + COALESCE(buffer_after_minutes, 0)
  FROM services
  WHERE id = service_id_param;
$$ LANGUAGE sql STABLE;

-- ============================================
-- HELPER FUNCTION: Get service price in CHF
-- ============================================
CREATE OR REPLACE FUNCTION get_service_price_chf(service_id_param UUID)
RETURNS DECIMAL(10,2) AS $$
  SELECT (price_cents::DECIMAL / 100)
  FROM services
  WHERE id = service_id_param;
$$ LANGUAGE sql STABLE;

-- ============================================
-- HELPER FUNCTION: Can staff perform service?
-- ============================================
CREATE OR REPLACE FUNCTION can_staff_perform_service(staff_id_param UUID, service_id_param UUID)
RETURNS BOOLEAN AS $$
  SELECT EXISTS (
    SELECT 1
    FROM staff_service_skills
    WHERE staff_id = staff_id_param AND service_id = service_id_param
  );
$$ LANGUAGE sql STABLE;

-- ============================================
-- HELPER FUNCTION: Get staff who can perform service
-- ============================================
CREATE OR REPLACE FUNCTION get_staff_for_service(service_id_param UUID)
RETURNS TABLE (
  staff_id UUID,
  display_name TEXT,
  effective_price_cents INTEGER,
  effective_duration_minutes INTEGER
) AS $$
  SELECT
    s.id AS staff_id,
    s.display_name,
    COALESCE(ssk.custom_price_cents, sv.price_cents) AS effective_price_cents,
    COALESCE(ssk.custom_duration_minutes, sv.duration_minutes) AS effective_duration_minutes
  FROM staff s
  JOIN staff_service_skills ssk ON s.id = ssk.staff_id
  JOIN services sv ON ssk.service_id = sv.id
  WHERE sv.id = service_id_param
    AND s.is_active = true
    AND s.is_bookable = true
    AND sv.is_active = true;
$$ LANGUAGE sql STABLE;
-- ============================================
-- SCHNITTWERK Database Schema
-- Migration: 00005_booking.sql
-- Description: Appointments, booking slots, waitlist
-- ============================================

-- ============================================
-- APPOINTMENTS TABLE
-- Core booking records
-- ============================================
CREATE TABLE appointments (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  salon_id UUID NOT NULL REFERENCES salons(id) ON DELETE CASCADE,
  customer_id UUID NOT NULL REFERENCES customers(id) ON DELETE CASCADE,
  staff_id UUID NOT NULL REFERENCES staff(id) ON DELETE RESTRICT,

  -- Timing
  start_time TIMESTAMPTZ NOT NULL,
  end_time TIMESTAMPTZ NOT NULL,
  duration_minutes INTEGER NOT NULL,

  -- Status
  status appointment_status NOT NULL DEFAULT 'reserved',

  -- Reservation tracking (for temporary holds)
  reserved_at TIMESTAMPTZ,
  reservation_expires_at TIMESTAMPTZ,

  -- Confirmation tracking
  confirmed_at TIMESTAMPTZ,
  confirmed_by UUID REFERENCES profiles(id),

  -- Cancellation tracking
  cancelled_at TIMESTAMPTZ,
  cancelled_by UUID REFERENCES profiles(id),
  cancellation_reason TEXT,

  -- Completion tracking
  completed_at TIMESTAMPTZ,
  completed_by UUID REFERENCES profiles(id),

  -- No-show tracking
  marked_no_show_at TIMESTAMPTZ,
  marked_no_show_by UUID REFERENCES profiles(id),

  -- Pricing (snapshot at booking time)
  subtotal_cents INTEGER NOT NULL DEFAULT 0,
  discount_cents INTEGER DEFAULT 0,
  total_cents INTEGER NOT NULL DEFAULT 0,

  -- Customer notes (visible to customer)
  customer_notes TEXT,

  -- Internal notes (staff only)
  internal_notes TEXT,

  -- Source tracking
  booked_online BOOLEAN DEFAULT true,
  created_by UUID REFERENCES profiles(id),

  -- Timestamps
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),

  -- Constraints
  CONSTRAINT valid_appointment_times CHECK (end_time > start_time),
  CONSTRAINT positive_duration CHECK (duration_minutes > 0)
);

COMMENT ON TABLE appointments IS 'Customer appointment bookings';
COMMENT ON COLUMN appointments.reserved_at IS 'When temporary reservation was created';
COMMENT ON COLUMN appointments.reservation_expires_at IS 'When reservation expires if not confirmed';
COMMENT ON COLUMN appointments.subtotal_cents IS 'Sum of all services before discounts';
COMMENT ON COLUMN appointments.booked_online IS 'Whether booked via online system or in-person';

-- Indexes for appointments
CREATE INDEX idx_appointments_salon ON appointments(salon_id);
CREATE INDEX idx_appointments_customer ON appointments(customer_id);
CREATE INDEX idx_appointments_staff ON appointments(staff_id);
CREATE INDEX idx_appointments_status ON appointments(salon_id, status);
CREATE INDEX idx_appointments_date ON appointments(salon_id, start_time);
CREATE INDEX idx_appointments_staff_date ON appointments(staff_id, start_time);
CREATE INDEX idx_appointments_reservation_expiry ON appointments(reservation_expires_at)
  WHERE status = 'reserved';

-- Apply updated_at trigger
CREATE TRIGGER update_appointments_updated_at
  BEFORE UPDATE ON appointments
  FOR EACH ROW
  EXECUTE FUNCTION update_updated_at_column();

-- ============================================
-- APPOINTMENT_SERVICES TABLE
-- Services included in an appointment (many-to-many)
-- ============================================
CREATE TABLE appointment_services (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  appointment_id UUID NOT NULL REFERENCES appointments(id) ON DELETE CASCADE,
  service_id UUID NOT NULL REFERENCES services(id) ON DELETE RESTRICT,

  -- Service details (snapshot at booking)
  service_name TEXT NOT NULL,
  duration_minutes INTEGER NOT NULL,
  price_cents INTEGER NOT NULL,

  -- Length variant if applicable
  length_variant_id UUID REFERENCES service_length_variants(id),
  length_variant_name TEXT,

  -- Display order
  sort_order INTEGER DEFAULT 0,

  -- Timestamps
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

COMMENT ON TABLE appointment_services IS 'Services booked within an appointment';
COMMENT ON COLUMN appointment_services.service_name IS 'Snapshot of service name at booking time';
COMMENT ON COLUMN appointment_services.price_cents IS 'Snapshot of price at booking time';

-- Indexes
CREATE INDEX idx_appt_services_appointment ON appointment_services(appointment_id);
CREATE INDEX idx_appt_services_service ON appointment_services(service_id);

-- ============================================
-- APPOINTMENT_ADDONS TABLE
-- Add-on services for appointments
-- ============================================
CREATE TABLE appointment_addons (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  appointment_id UUID NOT NULL REFERENCES appointments(id) ON DELETE CASCADE,
  addon_service_id UUID NOT NULL REFERENCES addon_services(id) ON DELETE RESTRICT,

  -- Addon details (snapshot at booking)
  addon_name TEXT NOT NULL,
  duration_minutes INTEGER DEFAULT 0,
  price_cents INTEGER NOT NULL,

  -- Timestamps
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

COMMENT ON TABLE appointment_addons IS 'Add-on services for appointments';

-- Indexes
CREATE INDEX idx_appt_addons_appointment ON appointment_addons(appointment_id);

-- ============================================
-- WAITLIST TABLE
-- Customers waiting for cancelled slots
-- ============================================
CREATE TABLE waitlist (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  salon_id UUID NOT NULL REFERENCES salons(id) ON DELETE CASCADE,
  customer_id UUID NOT NULL REFERENCES customers(id) ON DELETE CASCADE,

  -- Preferred settings
  preferred_staff_id UUID REFERENCES staff(id),
  preferred_service_id UUID REFERENCES services(id),

  -- Date range preferences
  preferred_date_from DATE NOT NULL,
  preferred_date_to DATE NOT NULL,

  -- Time preferences (stored as JSON for flexibility)
  -- Format: { "time_slots": ["morning", "afternoon", "evening"] }
  time_preferences JSONB DEFAULT '{"time_slots": ["morning", "afternoon"]}',

  -- Status
  status waitlist_status NOT NULL DEFAULT 'active',

  -- Notification tracking
  notified_at TIMESTAMPTZ,
  notified_count INTEGER DEFAULT 0,

  -- Conversion tracking
  converted_appointment_id UUID REFERENCES appointments(id),
  converted_at TIMESTAMPTZ,

  -- Notes
  notes TEXT,

  -- Timestamps
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),

  -- Constraints
  CONSTRAINT valid_date_range CHECK (preferred_date_to >= preferred_date_from)
);

COMMENT ON TABLE waitlist IS 'Customers waiting for available slots';
COMMENT ON COLUMN waitlist.time_preferences IS 'Preferred time slots as JSON';
COMMENT ON COLUMN waitlist.notified_count IS 'Number of times customer was notified';

-- Indexes
CREATE INDEX idx_waitlist_salon ON waitlist(salon_id);
CREATE INDEX idx_waitlist_customer ON waitlist(customer_id);
CREATE INDEX idx_waitlist_active ON waitlist(salon_id, status) WHERE status = 'active';
CREATE INDEX idx_waitlist_dates ON waitlist(preferred_date_from, preferred_date_to);

-- Apply updated_at trigger
CREATE TRIGGER update_waitlist_updated_at
  BEFORE UPDATE ON waitlist
  FOR EACH ROW
  EXECUTE FUNCTION update_updated_at_column();

-- ============================================
-- BLOCKED_TIMES TABLE
-- Salon-wide blocked times (holidays, maintenance)
-- ============================================
CREATE TABLE blocked_times (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  salon_id UUID NOT NULL REFERENCES salons(id) ON DELETE CASCADE,

  -- Time range
  start_time TIMESTAMPTZ NOT NULL,
  end_time TIMESTAMPTZ NOT NULL,

  -- Type and reason
  block_type blocked_time_type NOT NULL DEFAULT 'other',
  reason TEXT,

  -- Recurring (for annual holidays)
  is_recurring BOOLEAN DEFAULT false,
  recurrence_rule TEXT,

  -- Timestamps
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  created_by UUID REFERENCES profiles(id),

  -- Constraints
  CONSTRAINT valid_blocked_times CHECK (end_time > start_time)
);

COMMENT ON TABLE blocked_times IS 'Salon-wide blocked time periods';
COMMENT ON COLUMN blocked_times.recurrence_rule IS 'RRULE for recurring blocks (e.g., annual holidays)';

-- Indexes
CREATE INDEX idx_blocked_times_salon ON blocked_times(salon_id);
CREATE INDEX idx_blocked_times_range ON blocked_times(salon_id, start_time, end_time);

-- ============================================
-- VIEW: Upcoming appointments
-- ============================================

-- ============================================
-- VIEW: Today's appointments
-- ============================================

-- ============================================
-- FUNCTION: Check slot availability
-- ============================================
CREATE OR REPLACE FUNCTION is_slot_available(
  p_salon_id UUID,
  p_staff_id UUID,
  p_start_time TIMESTAMPTZ,
  p_end_time TIMESTAMPTZ,
  p_exclude_appointment_id UUID DEFAULT NULL
)
RETURNS BOOLEAN AS $$
DECLARE
  conflict_count INTEGER;
  is_blocked BOOLEAN;
BEGIN
  -- Check for conflicting appointments
  SELECT COUNT(*) INTO conflict_count
  FROM appointments
  WHERE salon_id = p_salon_id
    AND staff_id = p_staff_id
    AND status IN ('reserved', 'requested', 'confirmed')
    AND (p_exclude_appointment_id IS NULL OR id != p_exclude_appointment_id)
    AND (
      (start_time <= p_start_time AND end_time > p_start_time)
      OR (start_time < p_end_time AND end_time >= p_end_time)
      OR (start_time >= p_start_time AND end_time <= p_end_time)
    );

  IF conflict_count > 0 THEN
    RETURN false;
  END IF;

  -- Check for salon-wide blocked times
  SELECT EXISTS (
    SELECT 1 FROM blocked_times
    WHERE salon_id = p_salon_id
      AND (
        (start_time <= p_start_time AND end_time > p_start_time)
        OR (start_time < p_end_time AND end_time >= p_end_time)
        OR (start_time >= p_start_time AND end_time <= p_end_time)
      )
  ) INTO is_blocked;

  IF is_blocked THEN
    RETURN false;
  END IF;

  -- Check for staff schedule override (vacation, sick)
  SELECT EXISTS (
    SELECT 1 FROM staff_schedule_overrides
    WHERE staff_id = p_staff_id
      AND date = DATE(p_start_time AT TIME ZONE 'Europe/Zurich')
      AND custom_hours IS NULL  -- NULL means fully blocked
  ) INTO is_blocked;

  RETURN NOT is_blocked;
END;
$$ LANGUAGE plpgsql STABLE;

-- ============================================
-- FUNCTION: Get available slots for date
-- ============================================
CREATE OR REPLACE FUNCTION get_available_slots(
  p_salon_id UUID,
  p_staff_id UUID,
  p_date DATE,
  p_duration_minutes INTEGER,
  p_slot_granularity_minutes INTEGER DEFAULT 15
)
RETURNS TABLE (
  slot_start TIMESTAMPTZ,
  slot_end TIMESTAMPTZ
) AS $$
DECLARE
  staff_record RECORD;
  day_of_week TEXT;
  schedule_slots JSONB;
  slot_item JSONB;
  current_start TIME;
  current_end TIME;
  slot_time TIMESTAMPTZ;
  slot_end_time TIMESTAMPTZ;
BEGIN
  -- Get staff and their schedule
  SELECT * INTO staff_record FROM staff WHERE id = p_staff_id AND is_active = true;
  IF NOT FOUND OR NOT staff_record.is_bookable THEN
    RETURN;
  END IF;

  -- Get day of week
  day_of_week := LOWER(TO_CHAR(p_date, 'Dy'));

  -- Check for override first
  DECLARE
    override_record RECORD;
  BEGIN
    SELECT * INTO override_record
    FROM staff_schedule_overrides
    WHERE staff_id = p_staff_id AND date = p_date;

    IF FOUND THEN
      IF override_record.custom_hours IS NULL THEN
        -- Fully blocked
        RETURN;
      ELSE
        schedule_slots := override_record.custom_hours;
      END IF;
    ELSE
      -- Use default schedule
      IF NOT staff_record.default_schedule ? day_of_week THEN
        RETURN;
      END IF;
      schedule_slots := staff_record.default_schedule -> day_of_week;
    END IF;
  END;

  -- Iterate through schedule slots
  FOR slot_item IN SELECT * FROM jsonb_array_elements(schedule_slots)
  LOOP
    current_start := (slot_item->>'start')::TIME;
    current_end := (slot_item->>'end')::TIME;

    -- Generate slots at granularity intervals
    slot_time := (p_date + current_start) AT TIME ZONE 'Europe/Zurich';
    WHILE (slot_time + (p_duration_minutes || ' minutes')::INTERVAL) <=
          ((p_date + current_end) AT TIME ZONE 'Europe/Zurich')
    LOOP
      slot_end_time := slot_time + (p_duration_minutes || ' minutes')::INTERVAL;

      -- Check if slot is available
      IF is_slot_available(p_salon_id, p_staff_id, slot_time, slot_end_time) THEN
        slot_start := slot_time;
        slot_end := slot_end_time;
        RETURN NEXT;
      END IF;

      slot_time := slot_time + (p_slot_granularity_minutes || ' minutes')::INTERVAL;
    END LOOP;
  END LOOP;
END;
$$ LANGUAGE plpgsql STABLE;

-- ============================================
-- FUNCTION: Create reservation (temporary hold)
-- ============================================
CREATE OR REPLACE FUNCTION create_reservation(
  p_salon_id UUID,
  p_customer_id UUID,
  p_staff_id UUID,
  p_start_time TIMESTAMPTZ,
  p_duration_minutes INTEGER,
  p_timeout_minutes INTEGER DEFAULT 15
)
RETURNS UUID AS $$
DECLARE
  new_appointment_id UUID;
  end_time TIMESTAMPTZ;
BEGIN
  end_time := p_start_time + (p_duration_minutes || ' minutes')::INTERVAL;

  -- Check availability
  IF NOT is_slot_available(p_salon_id, p_staff_id, p_start_time, end_time) THEN
    RAISE EXCEPTION 'Slot is not available';
  END IF;

  -- Create reservation
  INSERT INTO appointments (
    salon_id, customer_id, staff_id,
    start_time, end_time, duration_minutes,
    status, reserved_at, reservation_expires_at
  ) VALUES (
    p_salon_id, p_customer_id, p_staff_id,
    p_start_time, end_time, p_duration_minutes,
    'reserved', NOW(), NOW() + (p_timeout_minutes || ' minutes')::INTERVAL
  )
  RETURNING id INTO new_appointment_id;

  RETURN new_appointment_id;
END;
$$ LANGUAGE plpgsql;

-- ============================================
-- FUNCTION: Confirm appointment
-- ============================================
CREATE OR REPLACE FUNCTION confirm_appointment(
  p_appointment_id UUID,
  p_confirmed_by UUID DEFAULT NULL
)
RETURNS BOOLEAN AS $$
DECLARE
  appt_record RECORD;
BEGIN
  -- Get and lock appointment
  SELECT * INTO appt_record
  FROM appointments
  WHERE id = p_appointment_id
  FOR UPDATE;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Appointment not found';
  END IF;

  IF appt_record.status NOT IN ('reserved', 'requested') THEN
    RAISE EXCEPTION 'Appointment cannot be confirmed from status %', appt_record.status;
  END IF;

  -- Update to confirmed
  UPDATE appointments
  SET
    status = 'confirmed',
    confirmed_at = NOW(),
    confirmed_by = p_confirmed_by,
    reservation_expires_at = NULL
  WHERE id = p_appointment_id;

  RETURN true;
END;
$$ LANGUAGE plpgsql;

-- ============================================
-- FUNCTION: Cancel appointment
-- ============================================
CREATE OR REPLACE FUNCTION cancel_appointment(
  p_appointment_id UUID,
  p_cancelled_by UUID,
  p_reason TEXT DEFAULT NULL
)
RETURNS BOOLEAN AS $$
DECLARE
  appt_record RECORD;
BEGIN
  -- Get and lock appointment
  SELECT * INTO appt_record
  FROM appointments
  WHERE id = p_appointment_id
  FOR UPDATE;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Appointment not found';
  END IF;

  IF appt_record.status IN ('cancelled', 'completed', 'no_show') THEN
    RAISE EXCEPTION 'Appointment cannot be cancelled from status %', appt_record.status;
  END IF;

  -- Update to cancelled
  UPDATE appointments
  SET
    status = 'cancelled',
    cancelled_at = NOW(),
    cancelled_by = p_cancelled_by,
    cancellation_reason = p_reason
  WHERE id = p_appointment_id;

  RETURN true;
END;
$$ LANGUAGE plpgsql;

-- ============================================
-- FUNCTION: Cleanup expired reservations
-- (Should be called via cron job)
-- ============================================
CREATE OR REPLACE FUNCTION cleanup_expired_reservations()
RETURNS INTEGER AS $$
DECLARE
  deleted_count INTEGER;
BEGIN
  WITH deleted AS (
    DELETE FROM appointments
    WHERE status = 'reserved'
      AND reservation_expires_at < NOW()
    RETURNING id
  )
  SELECT COUNT(*) INTO deleted_count FROM deleted;

  RETURN deleted_count;
END;
$$ LANGUAGE plpgsql;
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

-- ============================================
-- VIEW: Low stock products
-- ============================================

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
