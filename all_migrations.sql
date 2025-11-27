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
CREATE VIEW v_services_with_category AS
SELECT
  s.*,
  sc.name AS category_name,
  sc.slug AS category_slug,
  sc.icon AS category_icon,
  (s.price_cents::DECIMAL / 100) AS price_chf,
  s.duration_minutes + COALESCE(s.buffer_before_minutes, 0) + COALESCE(s.buffer_after_minutes, 0) AS total_duration_minutes
FROM services s
LEFT JOIN service_categories sc ON s.category_id = sc.id
WHERE s.is_active = true;

COMMENT ON VIEW v_services_with_category IS 'Active services with category information';

-- ============================================
-- VIEW: Staff with their services
-- ============================================
CREATE VIEW v_staff_services AS
SELECT
  s.id AS staff_id,
  s.salon_id,
  s.display_name AS staff_name,
  sv.id AS service_id,
  sv.name AS service_name,
  COALESCE(ssk.custom_price_cents, sv.price_cents) AS effective_price_cents,
  COALESCE(ssk.custom_duration_minutes, sv.duration_minutes) AS effective_duration_minutes,
  ssk.skill_level
FROM staff s
JOIN staff_service_skills ssk ON s.id = ssk.staff_id
JOIN services sv ON ssk.service_id = sv.id
WHERE s.is_active = true AND sv.is_active = true;

COMMENT ON VIEW v_staff_services IS 'Staff members with their assignable services';

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
CREATE VIEW v_upcoming_appointments AS
SELECT
  a.*,
  c.first_name AS customer_first_name,
  c.last_name AS customer_last_name,
  c.first_name || ' ' || c.last_name AS customer_name,
  s.display_name AS staff_name,
  (a.total_cents::DECIMAL / 100) AS total_chf
FROM appointments a
JOIN customers c ON a.customer_id = c.id
JOIN staff s ON a.staff_id = s.id
WHERE a.status IN ('confirmed', 'reserved', 'requested')
  AND a.start_time >= NOW();

COMMENT ON VIEW v_upcoming_appointments IS 'Future appointments with customer and staff info';

-- ============================================
-- VIEW: Today's appointments
-- ============================================
CREATE VIEW v_todays_appointments AS
SELECT
  a.*,
  c.first_name || ' ' || c.last_name AS customer_name,
  p.phone AS customer_phone,
  s.display_name AS staff_name
FROM appointments a
JOIN customers c ON a.customer_id = c.id
JOIN profiles p ON c.profile_id = p.id
JOIN staff s ON a.staff_id = s.id
WHERE DATE(a.start_time AT TIME ZONE 'Europe/Zurich') = CURRENT_DATE
  AND a.status IN ('confirmed', 'reserved')
ORDER BY a.start_time;

COMMENT ON VIEW v_todays_appointments IS 'Today''s scheduled appointments';

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

-- Product search by name
CREATE INDEX IF NOT EXISTS idx_products_name_search
ON products USING gin (name gin_trgm_ops);

-- Note: Requires pg_trgm extension. Uncomment after enabling:
-- CREATE EXTENSION IF NOT EXISTS pg_trgm;

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
