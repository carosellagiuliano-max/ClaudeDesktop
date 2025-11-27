-- ============================================
-- SCHNITTWERK Clean Migration - PART B
-- All Views (run after Part A)
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

CREATE VIEW v_bookable_staff AS
SELECT
  s.*,
  p.email,
  p.phone AS profile_phone
FROM staff s
JOIN profiles p ON s.profile_id = p.id
WHERE s.is_active = true AND s.is_bookable = true;

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

CREATE VIEW v_low_stock_products AS
SELECT
  p.*,
  (p.price_cents::DECIMAL / 100) AS price_chf
FROM products p
WHERE p.is_active = true
  AND p.track_inventory = true
  AND p.stock_quantity <= p.low_stock_threshold;

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

CREATE VIEW v_recent_orders AS
SELECT *
FROM v_orders_with_details
WHERE created_at >= NOW() - INTERVAL '30 days'
ORDER BY created_at DESC;

CREATE VIEW v_payment_summary AS
SELECT
  p.*,
  (p.amount_cents::DECIMAL / 100) AS amount_chf,
  o.order_number,
  c.first_name || ' ' || c.last_name AS customer_name
FROM payments p
LEFT JOIN orders o ON p.reference_type = 'order' AND p.reference_id = o.id
LEFT JOIN customers c ON o.customer_id = c.id;

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

CREATE VIEW v_pending_notifications AS
SELECT
  n.*,
  p.first_name || ' ' || p.last_name AS recipient_name
FROM notifications n
LEFT JOIN profiles p ON n.profile_id = p.id
WHERE n.status = 'pending'
  OR (n.status = 'scheduled' AND n.scheduled_for <= NOW())
ORDER BY COALESCE(n.scheduled_for, n.created_at);

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

CREATE VIEW v_recent_audit_logs AS
SELECT
  al.*,
  p.first_name || ' ' || p.last_name AS actor_name
FROM audit_logs al
LEFT JOIN profiles p ON al.actor_id = p.id
WHERE al.created_at >= NOW() - INTERVAL '7 days'
ORDER BY al.created_at DESC;

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

