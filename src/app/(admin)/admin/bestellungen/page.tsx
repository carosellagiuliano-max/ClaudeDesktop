import type { Metadata } from 'next';
import { createServerClient } from '@/lib/supabase/server';
import { AdminOrderList } from '@/components/admin/admin-order-list';

// ============================================
// METADATA
// ============================================

export const metadata: Metadata = {
  title: 'Bestellungen',
};

// ============================================
// DATA FETCHING
// ============================================

async function getOrdersData(searchParams: {
  search?: string;
  status?: string;
  page?: string;
  limit?: string;
}) {
  const supabase = await createServerClient();
  const page = parseInt(searchParams.page || '1');
  const limit = parseInt(searchParams.limit || '20');
  const offset = (page - 1) * limit;
  const search = searchParams.search || '';
  const status = searchParams.status;

  let query = supabase
    .from('orders')
    .select(
      `
      id,
      order_number,
      status,
      payment_status,
      payment_method,
      total_cents,
      customer_email,
      customer_name,
      shipping_method,
      created_at,
      paid_at
    `,
      { count: 'exact' }
    )
    .order('created_at', { ascending: false })
    .range(offset, offset + limit - 1);

  if (search) {
    query = query.or(
      `order_number.ilike.%${search}%,customer_email.ilike.%${search}%,customer_name.ilike.%${search}%`
    );
  }

  if (status && status !== 'all') {
    query = query.eq('status', status);
  }

  const { data, count, error } = await query;

  if (error) {
    console.error('Error fetching orders:', error);
    return { orders: [], total: 0, page, limit };
  }

  return {
    orders: data || [],
    total: count || 0,
    page,
    limit,
  };
}

// ============================================
// ADMIN ORDERS PAGE
// ============================================

export default async function AdminOrdersPage({
  searchParams,
}: {
  searchParams: Promise<{
    search?: string;
    status?: string;
    page?: string;
    limit?: string;
  }>;
}) {
  const params = await searchParams;
  const { orders, total, page, limit } = await getOrdersData(params);

  return (
    <AdminOrderList
      orders={orders}
      total={total}
      page={page}
      limit={limit}
      initialSearch={params.search || ''}
      initialStatus={params.status || 'all'}
    />
  );
}
