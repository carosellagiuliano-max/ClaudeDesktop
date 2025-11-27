import type { Metadata } from 'next';
import { notFound } from 'next/navigation';
import { createServerClient } from '@/lib/supabase/server';
import { AdminOrderDetailView } from '@/components/admin/admin-order-detail-view';

// ============================================
// METADATA
// ============================================

export const metadata: Metadata = {
  title: 'Bestelldetails',
};

// ============================================
// TYPES
// ============================================

interface OrderDetail {
  id: string;
  orderNumber: string;
  status: string;
  paymentStatus: string;
  paymentIntentId: string | null;
  subtotalCents: number;
  shippingCents: number;
  taxCents: number;
  totalCents: number;
  shippingMethod: string | null;
  trackingNumber: string | null;
  notes: string | null;
  createdAt: string;
  updatedAt: string;
  customer: {
    id: string;
    firstName: string;
    lastName: string;
    email: string;
    phone: string | null;
  } | null;
  shippingAddress: {
    street: string;
    city: string;
    postalCode: string;
    country: string;
  } | null;
  billingAddress: {
    street: string;
    city: string;
    postalCode: string;
    country: string;
  } | null;
}

interface OrderItem {
  id: string;
  productId: string | null;
  productName: string;
  variantName: string | null;
  quantity: number;
  unitPriceCents: number;
  totalCents: number;
  sku: string | null;
}

interface OrderEvent {
  id: string;
  eventType: string;
  description: string | null;
  createdAt: string;
  createdBy: string | null;
}

// Supabase row types
interface OrderDbRow {
  id: string;
  order_number: string;
  status: string;
  payment_status: string;
  payment_intent_id: string | null;
  subtotal_cents: number;
  shipping_cents: number | null;
  tax_cents: number | null;
  total_cents: number;
  shipping_method: string | null;
  tracking_number: string | null;
  notes: string | null;
  created_at: string;
  updated_at: string;
  shipping_address: { street: string; city: string; postalCode: string; country: string } | null;
  billing_address: { street: string; city: string; postalCode: string; country: string } | null;
  customers: {
    id: string;
    first_name: string;
    last_name: string;
    email: string;
    phone: string | null;
  } | null;
}

interface OrderItemDbRow {
  id: string;
  product_id: string | null;
  product_name: string;
  variant_name: string | null;
  quantity: number;
  unit_price_cents: number;
  total_cents: number;
  sku: string | null;
}

interface OrderEventDbRow {
  id: string;
  event_type: string;
  description: string | null;
  created_at: string;
  created_by: string | null;
}

// ============================================
// DATA FETCHING
// ============================================

async function getOrderData(orderId: string) {
  const supabase = await createServerClient();

  // Get order details
  const { data: order, error } = await supabase
    .from('orders')
    .select(`
      *,
      customers (
        id,
        first_name,
        last_name,
        email,
        phone
      )
    `)
    .eq('id', orderId)
    .single() as { data: OrderDbRow | null; error: unknown };

  if (error || !order) {
    return null;
  }

  // Get order items
  const { data: itemsData } = await supabase
    .from('order_items')
    .select(`
      id,
      product_id,
      product_name,
      variant_name,
      quantity,
      unit_price_cents,
      total_cents,
      sku
    `)
    .eq('order_id', orderId) as { data: OrderItemDbRow[] | null };

  // Get order events/history
  const { data: eventsData } = await supabase
    .from('order_events')
    .select('*')
    .eq('order_id', orderId)
    .order('created_at', { ascending: false }) as { data: OrderEventDbRow[] | null };

  // Transform data
  const orderDetail: OrderDetail = {
    id: order.id,
    orderNumber: order.order_number,
    status: order.status,
    paymentStatus: order.payment_status,
    paymentIntentId: order.payment_intent_id,
    subtotalCents: order.subtotal_cents,
    shippingCents: order.shipping_cents || 0,
    taxCents: order.tax_cents || 0,
    totalCents: order.total_cents,
    shippingMethod: order.shipping_method,
    trackingNumber: order.tracking_number,
    notes: order.notes,
    createdAt: order.created_at,
    updatedAt: order.updated_at,
    customer: order.customers ? {
      id: order.customers.id,
      firstName: order.customers.first_name,
      lastName: order.customers.last_name,
      email: order.customers.email,
      phone: order.customers.phone,
    } : null,
    shippingAddress: order.shipping_address,
    billingAddress: order.billing_address,
  };

  const items: OrderItem[] = (itemsData || []).map(item => ({
    id: item.id,
    productId: item.product_id,
    productName: item.product_name,
    variantName: item.variant_name,
    quantity: item.quantity,
    unitPriceCents: item.unit_price_cents,
    totalCents: item.total_cents,
    sku: item.sku,
  }));

  const events: OrderEvent[] = (eventsData || []).map(event => ({
    id: event.id,
    eventType: event.event_type,
    description: event.description,
    createdAt: event.created_at,
    createdBy: event.created_by,
  }));

  return {
    order: orderDetail,
    items,
    events,
  };
}

// ============================================
// ORDER DETAIL PAGE
// ============================================

interface PageProps {
  params: Promise<{ id: string }>;
}

export default async function OrderDetailPage({ params }: PageProps) {
  const { id } = await params;
  const data = await getOrderData(id);

  if (!data) {
    notFound();
  }

  return (
    <AdminOrderDetailView
      order={data.order}
      items={data.items}
      events={data.events}
    />
  );
}
