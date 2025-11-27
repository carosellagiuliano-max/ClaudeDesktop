import type { Metadata } from 'next';
import { createServerClient } from '@/lib/supabase/server';
import { AdminSettingsView } from '@/components/admin/admin-settings-view';

// ============================================
// METADATA
// ============================================

export const metadata: Metadata = {
  title: 'Einstellungen',
};

// ============================================
// DATA FETCHING
// ============================================

async function getSettingsData() {
  const supabase = await createServerClient();

  // Get salon settings
  const { data: salonData } = await supabase
    .from('salons')
    .select('*')
    .single();

  // Get services
  const { data: servicesData } = await supabase
    .from('services')
    .select('*')
    .order('name');

  return {
    salon: salonData,
    services: servicesData || [],
  };
}

// ============================================
// ADMIN SETTINGS PAGE
// ============================================

export default async function AdminSettingsPage() {
  const { salon, services } = await getSettingsData();

  return <AdminSettingsView salon={salon} services={services} />;
}
