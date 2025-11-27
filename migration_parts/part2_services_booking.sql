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
