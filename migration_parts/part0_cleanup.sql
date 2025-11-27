-- ============================================
-- CLEANUP SCRIPT - Löscht alle bestehenden Objekte
-- Führe dies ZUERST aus, dann die anderen Parts
-- ============================================

-- Disable triggers temporarily
SET session_replication_role = 'replica';

-- Drop all views first (they depend on tables)
DROP VIEW IF EXISTS v_active_customers CASCADE;
DROP VIEW IF EXISTS v_bookable_staff CASCADE;
DROP VIEW IF EXISTS v_services_with_category CASCADE;
DROP VIEW IF EXISTS v_staff_services CASCADE;
DROP VIEW IF EXISTS v_upcoming_appointments CASCADE;
DROP VIEW IF EXISTS v_todays_appointments CASCADE;
DROP VIEW IF EXISTS v_order_summary CASCADE;
DROP VIEW IF EXISTS v_customer_loyalty CASCADE;
DROP VIEW IF EXISTS v_payment_summary CASCADE;

-- Drop all tables (in reverse dependency order)
DROP TABLE IF EXISTS push_subscriptions CASCADE;
DROP TABLE IF EXISTS deposit_transactions CASCADE;
DROP TABLE IF EXISTS deposit_settings CASCADE;
DROP TABLE IF EXISTS marketing_campaigns CASCADE;
DROP TABLE IF EXISTS feedback CASCADE;
DROP TABLE IF EXISTS waitlist_notifications CASCADE;
DROP TABLE IF EXISTS sms_reminders CASCADE;
DROP TABLE IF EXISTS staff_certifications CASCADE;
DROP TABLE IF EXISTS staff_availability_exceptions CASCADE;
DROP TABLE IF EXISTS payment_events CASCADE;
DROP TABLE IF EXISTS refunds CASCADE;
DROP TABLE IF EXISTS payment_methods_saved CASCADE;
DROP TABLE IF EXISTS contact_inquiries CASCADE;
DROP TABLE IF EXISTS cron_job_logs CASCADE;
DROP TABLE IF EXISTS audit_logs CASCADE;
DROP TABLE IF EXISTS settings CASCADE;
DROP TABLE IF EXISTS notification_logs CASCADE;
DROP TABLE IF EXISTS notification_preferences CASCADE;
DROP TABLE IF EXISTS notification_templates CASCADE;
DROP TABLE IF EXISTS consent_records CASCADE;
DROP TABLE IF EXISTS loyalty_transactions CASCADE;
DROP TABLE IF EXISTS loyalty_tiers CASCADE;
DROP TABLE IF EXISTS loyalty_rewards CASCADE;
DROP TABLE IF EXISTS loyalty_points CASCADE;
DROP TABLE IF EXISTS payments CASCADE;
DROP TABLE IF EXISTS order_items CASCADE;
DROP TABLE IF EXISTS orders CASCADE;
DROP TABLE IF EXISTS vouchers CASCADE;
DROP TABLE IF EXISTS gift_boxes CASCADE;
DROP TABLE IF EXISTS product_variants CASCADE;
DROP TABLE IF EXISTS products CASCADE;
DROP TABLE IF EXISTS product_categories CASCADE;
DROP TABLE IF EXISTS stock_movements CASCADE;
DROP TABLE IF EXISTS inventory CASCADE;
DROP TABLE IF EXISTS blocked_times CASCADE;
DROP TABLE IF EXISTS waitlist CASCADE;
DROP TABLE IF EXISTS appointment_addons CASCADE;
DROP TABLE IF EXISTS appointment_services CASCADE;
DROP TABLE IF EXISTS appointments CASCADE;
DROP TABLE IF EXISTS service_addon_compatibility CASCADE;
DROP TABLE IF EXISTS addon_services CASCADE;
DROP TABLE IF EXISTS staff_service_skills CASCADE;
DROP TABLE IF EXISTS service_length_variants CASCADE;
DROP TABLE IF EXISTS services CASCADE;
DROP TABLE IF EXISTS service_categories CASCADE;
DROP TABLE IF EXISTS staff_schedule_overrides CASCADE;
DROP TABLE IF EXISTS staff CASCADE;
DROP TABLE IF EXISTS customers CASCADE;
DROP TABLE IF EXISTS user_roles CASCADE;
DROP TABLE IF EXISTS roles CASCADE;
DROP TABLE IF EXISTS profiles CASCADE;
DROP TABLE IF EXISTS salons CASCADE;

-- Drop all custom types (ENUMs)
DROP TYPE IF EXISTS appointment_status CASCADE;
DROP TYPE IF EXISTS order_status CASCADE;
DROP TYPE IF EXISTS payment_method CASCADE;
DROP TYPE IF EXISTS payment_status CASCADE;
DROP TYPE IF EXISTS role_name CASCADE;
DROP TYPE IF EXISTS consent_category CASCADE;
DROP TYPE IF EXISTS notification_channel CASCADE;
DROP TYPE IF EXISTS waitlist_status CASCADE;
DROP TYPE IF EXISTS blocked_time_type CASCADE;
DROP TYPE IF EXISTS stock_movement_type CASCADE;
DROP TYPE IF EXISTS audit_action_type CASCADE;
DROP TYPE IF EXISTS shipping_method_type CASCADE;
DROP TYPE IF EXISTS no_show_policy CASCADE;
DROP TYPE IF EXISTS voucher_status CASCADE;
DROP TYPE IF EXISTS gift_box_status CASCADE;
DROP TYPE IF EXISTS product_type CASCADE;
DROP TYPE IF EXISTS loyalty_tier_type CASCADE;
DROP TYPE IF EXISTS loyalty_transaction_type CASCADE;
DROP TYPE IF EXISTS notification_type CASCADE;
DROP TYPE IF EXISTS reminder_status CASCADE;
DROP TYPE IF EXISTS campaign_status CASCADE;
DROP TYPE IF EXISTS feedback_type CASCADE;

-- Drop all custom functions
DROP FUNCTION IF EXISTS update_updated_at_column() CASCADE;
DROP FUNCTION IF EXISTS handle_new_user() CASCADE;
DROP FUNCTION IF EXISTS get_user_salon_ids(UUID) CASCADE;
DROP FUNCTION IF EXISTS has_role(UUID, role_name, UUID) CASCADE;
DROP FUNCTION IF EXISTS is_staff(UUID, UUID) CASCADE;
DROP FUNCTION IF EXISTS is_admin(UUID, UUID) CASCADE;
DROP FUNCTION IF EXISTS get_customer_full_name(UUID) CASCADE;
DROP FUNCTION IF EXISTS get_staff_display_name(UUID) CASCADE;
DROP FUNCTION IF EXISTS is_staff_available_on_date(UUID, DATE) CASCADE;
DROP FUNCTION IF EXISTS get_service_total_duration(UUID) CASCADE;
DROP FUNCTION IF EXISTS get_service_price_chf(UUID) CASCADE;
DROP FUNCTION IF EXISTS can_staff_perform_service(UUID, UUID) CASCADE;
DROP FUNCTION IF EXISTS get_staff_for_service(UUID) CASCADE;
DROP FUNCTION IF EXISTS is_slot_available(UUID, UUID, TIMESTAMPTZ, TIMESTAMPTZ, UUID) CASCADE;
DROP FUNCTION IF EXISTS get_available_slots(UUID, UUID, DATE, INTEGER, INTEGER) CASCADE;
DROP FUNCTION IF EXISTS create_reservation(UUID, UUID, UUID, TIMESTAMPTZ, INTEGER, INTEGER) CASCADE;
DROP FUNCTION IF EXISTS confirm_appointment(UUID, UUID) CASCADE;
DROP FUNCTION IF EXISTS cancel_appointment(UUID, UUID, TEXT) CASCADE;
DROP FUNCTION IF EXISTS cleanup_expired_reservations() CASCADE;
DROP FUNCTION IF EXISTS calculate_order_total(UUID) CASCADE;
DROP FUNCTION IF EXISTS get_customer_loyalty_points(UUID) CASCADE;
DROP FUNCTION IF EXISTS add_loyalty_points(UUID, INTEGER, TEXT, UUID) CASCADE;
DROP FUNCTION IF EXISTS redeem_loyalty_points(UUID, INTEGER, TEXT, UUID) CASCADE;

-- Re-enable triggers
SET session_replication_role = 'origin';

-- Confirm cleanup
SELECT 'Cleanup completed successfully!' AS status;
