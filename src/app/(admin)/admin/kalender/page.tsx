import type { Metadata } from 'next';
import { createServerClient } from '@/lib/supabase/server';
import { AdminCalendarView } from '@/components/admin/admin-calendar-view';

// ============================================
// METADATA
// ============================================

export const metadata: Metadata = {
  title: 'Kalender',
};

// ============================================
// DATA FETCHING
// ============================================

async function getCalendarData() {
  const supabase = await createServerClient();

  // Get all staff members
  const { data: staffData } = await supabase
    .from('staff')
    .select('id, display_name, color, is_active')
    .eq('is_active', true)
    .order('display_name');

  // Get all services
  const { data: servicesData } = await supabase
    .from('services')
    .select('id, name, duration_minutes, price_cents, is_active')
    .eq('is_active', true)
    .order('name');

  return {
    staff: staffData || [],
    services: servicesData || [],
  };
}

// ============================================
// ADMIN CALENDAR PAGE
// ============================================

export default async function AdminCalendarPage() {
  const { staff, services } = await getCalendarData();

  return <AdminCalendarView staff={staff} services={services} />;
}
