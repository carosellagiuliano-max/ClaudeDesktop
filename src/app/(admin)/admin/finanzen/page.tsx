import type { Metadata } from 'next';
import { createServerClient } from '@/lib/supabase/server';
import { AdminFinanceView } from '@/components/admin/admin-finance-view';

// ============================================
// METADATA
// ============================================

export const metadata: Metadata = {
  title: 'Finanzen',
};

// ============================================
// TYPES
// ============================================

interface PaymentMethodStats {
  method: string;
  count: number;
  totalCents: number;
}

interface VatSummary {
  grossCents: number;
  netCents: number;
  vatCents: number;
  vatRate: number;
}

interface DailySales {
  date: string;
  orderCount: number;
  appointmentCount: number;
  orderRevenue: number;
  appointmentRevenue: number;
  totalRevenue: number;
}

interface FinanceStats {
  periodStart: string;
  periodEnd: string;
  totalRevenue: number;
  totalOrders: number;
  totalAppointments: number;
  totalRefunds: number;
  netRevenue: number;
}

// Supabase row types
interface FinanceOrderRow {
  id: string;
  total_cents: number | null;
  tax_cents: number | null;
  payment_method: string | null;
  payment_status: string;
  created_at: string;
}

interface FinanceAppointmentRow {
  id: string;
  total_price_cents: number | null;
  status: string;
  start_time: string;
}

interface RefundRow {
  amount_cents: number | null;
  created_at: string;
}

// ============================================
// DATA FETCHING
// ============================================

async function getFinanceData(period: 'month' | 'quarter' | 'year' = 'month') {
  const supabase = await createServerClient();

  const now = new Date();
  let startDate: Date;

  switch (period) {
    case 'quarter':
      const quarter = Math.floor(now.getMonth() / 3);
      startDate = new Date(now.getFullYear(), quarter * 3, 1);
      break;
    case 'year':
      startDate = new Date(now.getFullYear(), 0, 1);
      break;
    default: // month
      startDate = new Date(now.getFullYear(), now.getMonth(), 1);
  }

  const periodStart = startDate.toISOString();
  const periodEnd = now.toISOString();

  // Get orders with payment info
  const { data: ordersData } = await supabase
    .from('orders')
    .select('id, total_cents, tax_cents, payment_method, payment_status, created_at')
    .gte('created_at', periodStart)
    .lte('created_at', periodEnd) as { data: FinanceOrderRow[] | null };

  // Get completed appointments
  const { data: appointmentsData } = await supabase
    .from('appointments')
    .select('id, total_price_cents, status, start_time')
    .gte('start_time', periodStart)
    .lte('start_time', periodEnd)
    .eq('status', 'completed') as { data: FinanceAppointmentRow[] | null };

  // Get refunds
  const { data: refundsData } = await supabase
    .from('refunds')
    .select('amount_cents, created_at')
    .gte('created_at', periodStart)
    .lte('created_at', periodEnd)
    .eq('status', 'succeeded') as { data: RefundRow[] | null };

  // Calculate payment method breakdown
  const paymentMethodMap = new Map<string, PaymentMethodStats>();
  const paidOrders = (ordersData || []).filter(o => o.payment_status === 'succeeded');

  paidOrders.forEach((order) => {
    const method = order.payment_method || 'unknown';
    const existing = paymentMethodMap.get(method);
    if (existing) {
      existing.count += 1;
      existing.totalCents += order.total_cents || 0;
    } else {
      paymentMethodMap.set(method, {
        method,
        count: 1,
        totalCents: order.total_cents || 0,
      });
    }
  });

  // Add appointment payments (assumed cash/card at venue)
  const appointmentRevenue = (appointmentsData || []).reduce(
    (sum, a) => sum + (a.total_price_cents || 0),
    0
  );

  if (appointmentRevenue > 0) {
    const existing = paymentMethodMap.get('in_person');
    if (existing) {
      existing.count += appointmentsData?.length || 0;
      existing.totalCents += appointmentRevenue;
    } else {
      paymentMethodMap.set('in_person', {
        method: 'in_person',
        count: appointmentsData?.length || 0,
        totalCents: appointmentRevenue,
      });
    }
  }

  const paymentMethods = Array.from(paymentMethodMap.values())
    .sort((a, b) => b.totalCents - a.totalCents);

  // Calculate VAT summary (8.1% Swiss VAT)
  const vatRate = 0.081;
  const orderGross = paidOrders.reduce((sum, o) => sum + (o.total_cents || 0), 0);
  const orderTax = paidOrders.reduce((sum, o) => sum + (o.tax_cents || 0), 0);
  const totalGross = orderGross + appointmentRevenue;
  const totalTax = orderTax + Math.round(appointmentRevenue * vatRate / (1 + vatRate));

  const vatSummary: VatSummary = {
    grossCents: totalGross,
    netCents: totalGross - totalTax,
    vatCents: totalTax,
    vatRate: vatRate * 100,
  };

  // Calculate daily sales for chart
  const dailySalesMap = new Map<string, DailySales>();

  // Initialize days
  const dayCount = Math.ceil((now.getTime() - startDate.getTime()) / (1000 * 60 * 60 * 24));
  for (let i = 0; i <= dayCount; i++) {
    const date = new Date(startDate);
    date.setDate(startDate.getDate() + i);
    const dateKey = date.toISOString().split('T')[0];
    dailySalesMap.set(dateKey, {
      date: dateKey,
      orderCount: 0,
      appointmentCount: 0,
      orderRevenue: 0,
      appointmentRevenue: 0,
      totalRevenue: 0,
    });
  }

  // Add order data
  paidOrders.forEach((order) => {
    const dateKey = new Date(order.created_at).toISOString().split('T')[0];
    const existing = dailySalesMap.get(dateKey);
    if (existing) {
      existing.orderCount += 1;
      existing.orderRevenue += order.total_cents || 0;
      existing.totalRevenue += order.total_cents || 0;
    }
  });

  // Add appointment data
  (appointmentsData || []).forEach((apt) => {
    const dateKey = new Date(apt.start_time).toISOString().split('T')[0];
    const existing = dailySalesMap.get(dateKey);
    if (existing) {
      existing.appointmentCount += 1;
      existing.appointmentRevenue += apt.total_price_cents || 0;
      existing.totalRevenue += apt.total_price_cents || 0;
    }
  });

  const dailySales = Array.from(dailySalesMap.values())
    .sort((a, b) => a.date.localeCompare(b.date));

  // Calculate totals
  const totalRefunds = (refundsData || []).reduce(
    (sum, r) => sum + (r.amount_cents || 0),
    0
  );

  const stats: FinanceStats = {
    periodStart,
    periodEnd,
    totalRevenue: totalGross,
    totalOrders: paidOrders.length,
    totalAppointments: appointmentsData?.length || 0,
    totalRefunds,
    netRevenue: totalGross - totalRefunds,
  };

  return {
    stats,
    paymentMethods,
    vatSummary,
    dailySales,
  };
}

// ============================================
// FINANCE PAGE
// ============================================

export default async function FinancePage() {
  const { stats, paymentMethods, vatSummary, dailySales } = await getFinanceData();

  return (
    <AdminFinanceView
      stats={stats}
      paymentMethods={paymentMethods}
      vatSummary={vatSummary}
      dailySales={dailySales}
    />
  );
}
