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
