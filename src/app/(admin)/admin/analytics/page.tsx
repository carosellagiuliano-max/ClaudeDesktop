import type { Metadata } from 'next';
import { createServerClient } from '@/lib/supabase/server';
import { AdminAnalyticsView } from '@/components/admin/admin-analytics-view';

// ============================================
// METADATA
// ============================================

export const metadata: Metadata = {
  title: 'Analytics',
};

// ============================================
// TYPES
// ============================================

interface RevenueData {
  date: string;
  revenue: number;
  orders: number;
  appointments: number;
}

interface TopProduct {
  id: string;
  name: string;
  totalSold: number;
  revenue: number;
}

interface TopService {
  id: string;
  name: string;
  bookings: number;
  revenue: number;
}

interface AnalyticsStats {
  totalRevenue: number;
  totalOrders: number;
  totalAppointments: number;
  averageOrderValue: number;
  newCustomers: number;
  returningCustomers: number;
  cancelRate: number;
}

// Supabase row types
interface OrderRow {
  id: string;
  total_cents: number | null;
  created_at: string;
  status: string;
  payment_status: string;
}

interface AppointmentRow {
  id: string;
  start_time: string;
  status: string;
  total_price_cents: number | null;
}

interface OrderItemRow {
  product_id: string | null;
  quantity: number | null;
  total_cents: number | null;
  products: {
    id: string;
    name: string;
  } | null;
}

interface ServiceBookingRow {
  services: {
    id: string;
    name: string;
    price_cents: number | null;
  } | null;
}

// ============================================
// DATA FETCHING
// ============================================

async function getAnalyticsData() {
  const supabase = await createServerClient();

  const now = new Date();
  const thirtyDaysAgo = new Date(now);
  thirtyDaysAgo.setDate(now.getDate() - 30);
  const startDate = thirtyDaysAgo.toISOString();

  // Get orders for last 30 days
  const { data: ordersData } = (await supabase
    .from('orders')
    .select('id, total_cents, created_at, status, payment_status')
    .gte('created_at', startDate)
    .eq('payment_status', 'succeeded')) as { data: OrderRow[] | null };

  // Get appointments for last 30 days
  const { data: appointmentsData } = (await supabase
    .from('appointments')
    .select('id, start_time, status, total_price_cents')
    .gte('start_time', startDate)) as { data: AppointmentRow[] | null };

  // Get new customers this month
  const startOfMonth = new Date(now.getFullYear(), now.getMonth(), 1).toISOString();
  const { count: newCustomersCount } = await supabase
    .from('customers')
    .select('id', { count: 'exact', head: true })
    .gte('created_at', startOfMonth);

  // Get top products by sales
  const { data: topProductsData } = (await supabase
    .from('order_items')
    .select(
      `
      product_id,
      quantity,
      total_cents,
      products (
        id,
        name
      )
    `
    )
    .not('product_id', 'is', null)
    .gte('created_at', startDate)) as { data: OrderItemRow[] | null };

  // Get top services by bookings
  const { data: topServicesData } = (await supabase
    .from('appointments')
    .select(
      `
      services (
        id,
        name,
        price_cents
      )
    `
    )
    .gte('start_time', startDate)
    .in('status', ['confirmed', 'completed'])) as { data: ServiceBookingRow[] | null };

  // Aggregate daily revenue data
  const revenueByDate = new Map<string, RevenueData>();

  // Initialize last 30 days
  for (let i = 0; i < 30; i++) {
    const date = new Date(now);
    date.setDate(now.getDate() - i);
    const dateKey = date.toISOString().split('T')[0];
    revenueByDate.set(dateKey, {
      date: dateKey,
      revenue: 0,
      orders: 0,
      appointments: 0,
    });
  }

  // Add order data
  (ordersData || []).forEach((order) => {
    const dateKey = new Date(order.created_at).toISOString().split('T')[0];
    const existing = revenueByDate.get(dateKey);
    if (existing) {
      existing.revenue += order.total_cents || 0;
      existing.orders += 1;
    }
  });

  // Add appointment data
  (appointmentsData || []).forEach((apt) => {
    const dateKey = new Date(apt.start_time).toISOString().split('T')[0];
    const existing = revenueByDate.get(dateKey);
    if (existing) {
      if (apt.status === 'completed') {
        existing.revenue += apt.total_price_cents || 0;
      }
      existing.appointments += 1;
    }
  });

  const revenueData = Array.from(revenueByDate.values()).sort((a, b) =>
    a.date.localeCompare(b.date)
  );

  // Calculate stats
  const totalRevenue = revenueData.reduce((sum, d) => sum + d.revenue, 0);
  const totalOrders = ordersData?.length || 0;
  const totalAppointments = appointmentsData?.length || 0;
  const cancelledAppointments =
    appointmentsData?.filter((a) => a.status === 'cancelled').length || 0;

  // Aggregate top products
  const productSales = new Map<string, TopProduct>();
  (topProductsData || []).forEach((item) => {
    if (!item.products?.id) return;
    const existing = productSales.get(item.products.id);
    if (existing) {
      existing.totalSold += item.quantity || 0;
      existing.revenue += item.total_cents || 0;
    } else {
      productSales.set(item.products.id, {
        id: item.products.id,
        name: item.products.name,
        totalSold: item.quantity || 0,
        revenue: item.total_cents || 0,
      });
    }
  });

  const topProducts = Array.from(productSales.values())
    .sort((a, b) => b.revenue - a.revenue)
    .slice(0, 10);

  // Aggregate top services
  const serviceBookings = new Map<string, TopService>();
  (topServicesData || []).forEach((apt) => {
    if (!apt.services?.id) return;
    const existing = serviceBookings.get(apt.services.id);
    if (existing) {
      existing.bookings += 1;
      existing.revenue += apt.services.price_cents || 0;
    } else {
      serviceBookings.set(apt.services.id, {
        id: apt.services.id,
        name: apt.services.name,
        bookings: 1,
        revenue: apt.services.price_cents || 0,
      });
    }
  });

  const topServices = Array.from(serviceBookings.values())
    .sort((a, b) => b.bookings - a.bookings)
    .slice(0, 10);

  const stats: AnalyticsStats = {
    totalRevenue,
    totalOrders,
    totalAppointments,
    averageOrderValue: totalOrders > 0 ? Math.round(totalRevenue / totalOrders) : 0,
    newCustomers: newCustomersCount || 0,
    returningCustomers: 0, // Would need more complex query
    cancelRate:
      totalAppointments > 0 ? Math.round((cancelledAppointments / totalAppointments) * 100) : 0,
  };

  return {
    stats,
    revenueData,
    topProducts,
    topServices,
  };
}

// ============================================
// ANALYTICS PAGE
// ============================================

export default async function AnalyticsPage() {
  const { stats, revenueData, topProducts, topServices } = await getAnalyticsData();

  return (
    <AdminAnalyticsView
      stats={stats}
      revenueData={revenueData}
      topProducts={topProducts}
      topServices={topServices}
    />
  );
}
