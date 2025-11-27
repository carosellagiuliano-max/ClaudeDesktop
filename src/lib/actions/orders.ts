'use server';

// ============================================
// SCHNITTWERK - Order Server Actions
// ============================================

import { createServerClient } from '@/lib/supabase/server';
import { revalidatePath } from 'next/cache';
import type {
  Order,
  OrderItem,
  OrderSummary,
  OrderStatus,
  CreateOrderInput,
  CreateOrderItemInput,
  UpdateOrderInput,
  OrderValidation,
  ShippingAddress,
} from '@/lib/domain/order/types';
import {
  validateOrderInput,
  validateOrderForPayment,
  calculateOrderTotals,
  getShippingCents,
  isDigitalOnlyOrder,
} from '@/lib/domain/order/order';
import { createCheckoutSession } from '@/lib/payments/stripe';

// ============================================
// TYPES
// ============================================

interface ActionResult<T> {
  data: T | null;
  error: string | null;
}

interface CreateOrderResult {
  order: Order | null;
  checkoutUrl?: string;
  error: string | null;
}

// ============================================
// CREATE ORDER
// ============================================

/**
 * Creates a new order and optionally initiates Stripe checkout
 */
export async function createOrder(
  input: CreateOrderInput & { initiatePayment?: boolean }
): Promise<CreateOrderResult> {
  const initiatePayment = input.initiatePayment ?? true;
  try {
    // Validate input
    const validation = validateOrderInput(input);
    if (!validation.valid) {
      return {
        order: null,
        error: validation.errors.join(', '),
      };
    }

    const supabase = await createServerClient();

    // Generate order number using database function
    const { data: orderNumber, error: numError } = await supabase.rpc('generate_order_number', {
      p_salon_id: input.salonId,
    });

    if (numError || !orderNumber) {
      console.error('Error generating order number:', numError);
      return { order: null, error: 'Fehler beim Erstellen der Bestellnummer' };
    }

    // Calculate totals
    const shippingCents = getShippingCents(input.shippingMethod);
    const items = input.items.map((item) => ({
      ...item,
      totalCents: item.unitPriceCents * item.quantity - (item.discountCents || 0),
      taxCents: Math.round(
        (item.unitPriceCents * item.quantity - (item.discountCents || 0)) *
          ((item.taxRate || 0.081) / (1 + (item.taxRate || 0.081)))
      ),
    }));

    const totals = calculateOrderTotals(
      items.map((item, index) => ({
        id: `temp-${index}`,
        orderId: '',
        itemType: item.itemType,
        itemName: item.itemName,
        quantity: item.quantity,
        unitPriceCents: item.unitPriceCents,
        discountCents: item.discountCents || 0,
        totalCents: item.totalCents,
        taxRate: item.taxRate,
        taxCents: item.taxCents,
      })),
      0,
      shippingCents
    );

    // Determine payment status based on payment method
    const isPayAtVenue = input.paymentMethod === 'pay_at_venue';
    const initialStatus = isPayAtVenue ? 'processing' : 'pending';
    const initialPaymentStatus = isPayAtVenue ? 'pending' : 'pending';

    // Create order in database
    const { data: order, error: orderError } = await supabase
      .from('orders')
      .insert({
        salon_id: input.salonId,
        customer_id: input.customerId,
        order_number: orderNumber,
        status: initialStatus,
        payment_status: initialPaymentStatus,
        payment_method: input.paymentMethod || 'stripe_card',
        subtotal_cents: totals.subtotalCents,
        discount_cents: totals.discountCents,
        shipping_cents: totals.shippingCents,
        tax_cents: totals.taxCents,
        total_cents: totals.totalCents,
        shipping_method: input.shippingMethod,
        shipping_address: input.shippingAddress as any,
        customer_email: input.customerEmail,
        customer_name: input.customerName,
        customer_phone: input.customerPhone,
        customer_notes: input.customerNotes,
        source: input.source || 'online',
      })
      .select()
      .single();

    if (orderError || !order) {
      console.error('Error creating order:', orderError);
      return { order: null, error: 'Fehler beim Erstellen der Bestellung' };
    }

    // Insert order items
    const orderItems = input.items.map((item, index) => ({
      order_id: order.id,
      item_type: item.itemType,
      product_id: item.productId,
      variant_id: item.variantId,
      item_name: item.itemName,
      item_sku: item.itemSku,
      item_description: item.itemDescription,
      quantity: item.quantity,
      unit_price_cents: item.unitPriceCents,
      discount_cents: item.discountCents || 0,
      total_cents: items[index].totalCents,
      tax_rate: item.taxRate || 8.1,
      tax_cents: items[index].taxCents,
      voucher_type: item.voucherType,
      recipient_email: item.recipientEmail,
      recipient_name: item.recipientName,
      personal_message: item.personalMessage,
    }));

    const { error: itemsError } = await supabase.from('order_items').insert(orderItems);

    if (itemsError) {
      console.error('Error creating order items:', itemsError);
      // Rollback order
      await supabase.from('orders').delete().eq('id', order.id);
      return { order: null, error: 'Fehler beim Erstellen der Bestellpositionen' };
    }

    // Record initial status
    await supabase.from('order_status_history').insert({
      order_id: order.id,
      new_status: initialStatus,
      notes: isPayAtVenue ? 'Bestellung erstellt - Bezahlung bei Abholung' : 'Bestellung erstellt',
    });

    // Transform to Order type
    const transformedOrder = transformDbOrder(order, orderItems);

    // Initiate payment if requested
    if (initiatePayment && totals.totalCents > 0) {
      const baseUrl = process.env.NEXT_PUBLIC_APP_URL || 'http://localhost:3000';
      const { data: session, error: stripeError } = await createCheckoutSession({
        salonId: input.salonId,
        orderId: order.id,
        customerId: input.customerId,
        customerEmail: input.customerEmail,
        lineItems: input.items.map((item) => ({
          name: item.itemName,
          description: item.itemDescription,
          quantity: item.quantity,
          unitAmountCents: item.unitPriceCents,
        })),
        successUrl: `${baseUrl}/checkout/success`,
        cancelUrl: `${baseUrl}/checkout/cancelled`,
        metadata: {
          order_number: orderNumber,
        },
      });

      if (stripeError || !session) {
        console.error('Error creating checkout session:', stripeError);
        return {
          order: transformedOrder,
          error: 'Fehler beim Erstellen der Zahlungssession',
        };
      }

      // Update order with session ID
      await supabase.from('orders').update({ stripe_session_id: session.id }).eq('id', order.id);

      return {
        order: { ...transformedOrder, stripeSessionId: session.id },
        checkoutUrl: session.url ?? undefined,
        error: null,
      };
    }

    return { order: transformedOrder, error: null };
  } catch (error) {
    console.error('createOrder error:', error);
    return {
      order: null,
      error: error instanceof Error ? error.message : 'Unbekannter Fehler',
    };
  }
}

// ============================================
// GET ORDER
// ============================================

/**
 * Get order by ID
 */
export async function getOrder(orderId: string): Promise<ActionResult<Order>> {
  try {
    const supabase = await createServerClient();

    const { data: order, error: orderError } = await supabase
      .from('orders')
      .select('*')
      .eq('id', orderId)
      .single();

    if (orderError || !order) {
      return { data: null, error: 'Bestellung nicht gefunden' };
    }

    // Get order items
    const { data: items, error: itemsError } = await supabase
      .from('order_items')
      .select('*')
      .eq('order_id', orderId);

    if (itemsError) {
      return { data: null, error: 'Fehler beim Laden der Bestellpositionen' };
    }

    return { data: transformDbOrder(order, items || []), error: null };
  } catch (error) {
    console.error('getOrder error:', error);
    return { data: null, error: 'Fehler beim Laden der Bestellung' };
  }
}

/**
 * Get order by order number
 */
export async function getOrderByNumber(orderNumber: string): Promise<ActionResult<Order>> {
  try {
    const supabase = await createServerClient();

    const { data: order, error: orderError } = await supabase
      .from('orders')
      .select('*')
      .eq('order_number', orderNumber)
      .single();

    if (orderError || !order) {
      return { data: null, error: 'Bestellung nicht gefunden' };
    }

    // Get order items
    const { data: items } = await supabase.from('order_items').select('*').eq('order_id', order.id);

    return { data: transformDbOrder(order, items || []), error: null };
  } catch (error) {
    console.error('getOrderByNumber error:', error);
    return { data: null, error: 'Fehler beim Laden der Bestellung' };
  }
}

// ============================================
// GET ORDERS
// ============================================

/**
 * Get orders for customer
 */
export async function getCustomerOrders(
  customerId: string,
  options: {
    limit?: number;
    offset?: number;
    status?: OrderStatus;
  } = {}
): Promise<ActionResult<OrderSummary[]>> {
  try {
    const supabase = await createServerClient();
    const { limit = 20, offset = 0, status } = options;

    let query = supabase
      .from('orders')
      .select(
        `
        id,
        order_number,
        status,
        payment_status,
        total_cents,
        customer_email,
        customer_name,
        created_at,
        paid_at,
        order_items(count)
      `
      )
      .eq('customer_id', customerId)
      .order('created_at', { ascending: false })
      .range(offset, offset + limit - 1);

    if (status) {
      query = query.eq('status', status);
    }

    const { data: orders, error } = await query;

    if (error) {
      return { data: null, error: 'Fehler beim Laden der Bestellungen' };
    }

    const summaries: OrderSummary[] = (orders || []).map((order: any) => ({
      id: order.id,
      orderNumber: order.order_number,
      status: order.status,
      paymentStatus: order.payment_status,
      totalCents: order.total_cents,
      itemCount: order.order_items?.[0]?.count || 0,
      customerEmail: order.customer_email,
      customerName: order.customer_name,
      createdAt: new Date(order.created_at),
      paidAt: order.paid_at ? new Date(order.paid_at) : undefined,
    }));

    return { data: summaries, error: null };
  } catch (error) {
    console.error('getCustomerOrders error:', error);
    return { data: null, error: 'Fehler beim Laden der Bestellungen' };
  }
}

/**
 * Get orders for salon (admin)
 */
export async function getSalonOrders(
  salonId: string,
  options: {
    limit?: number;
    offset?: number;
    status?: OrderStatus;
    from?: Date;
    to?: Date;
  } = {}
): Promise<ActionResult<OrderSummary[]>> {
  try {
    const supabase = await createServerClient();
    const { limit = 50, offset = 0, status, from, to } = options;

    let query = supabase
      .from('orders')
      .select(
        `
        id,
        order_number,
        status,
        payment_status,
        total_cents,
        customer_email,
        customer_name,
        created_at,
        paid_at,
        order_items(count)
      `
      )
      .eq('salon_id', salonId)
      .order('created_at', { ascending: false })
      .range(offset, offset + limit - 1);

    if (status) {
      query = query.eq('status', status);
    }
    if (from) {
      query = query.gte('created_at', from.toISOString());
    }
    if (to) {
      query = query.lte('created_at', to.toISOString());
    }

    const { data: orders, error } = await query;

    if (error) {
      return { data: null, error: 'Fehler beim Laden der Bestellungen' };
    }

    const summaries: OrderSummary[] = (orders || []).map((order: any) => ({
      id: order.id,
      orderNumber: order.order_number,
      status: order.status,
      paymentStatus: order.payment_status,
      totalCents: order.total_cents,
      itemCount: order.order_items?.[0]?.count || 0,
      customerEmail: order.customer_email,
      customerName: order.customer_name,
      createdAt: new Date(order.created_at),
      paidAt: order.paid_at ? new Date(order.paid_at) : undefined,
    }));

    return { data: summaries, error: null };
  } catch (error) {
    console.error('getSalonOrders error:', error);
    return { data: null, error: 'Fehler beim Laden der Bestellungen' };
  }
}

// ============================================
// UPDATE ORDER
// ============================================

/**
 * Update order status
 */
export async function updateOrderStatus(
  orderId: string,
  newStatus: OrderStatus,
  changedBy?: string,
  notes?: string
): Promise<ActionResult<Order>> {
  try {
    const supabase = await createServerClient();

    // Get current order
    const { data: currentOrder, error: fetchError } = await supabase
      .from('orders')
      .select('status')
      .eq('id', orderId)
      .single();

    if (fetchError || !currentOrder) {
      return { data: null, error: 'Bestellung nicht gefunden' };
    }

    // Update order
    const updateData: any = {
      status: newStatus,
      updated_at: new Date().toISOString(),
    };

    // Set timestamps based on status
    if (newStatus === 'shipped') {
      updateData.shipped_at = new Date().toISOString();
    } else if (newStatus === 'delivered') {
      updateData.delivered_at = new Date().toISOString();
    } else if (newStatus === 'completed') {
      updateData.completed_at = new Date().toISOString();
    } else if (newStatus === 'cancelled') {
      updateData.cancelled_at = new Date().toISOString();
    }

    const { data: order, error: updateError } = await supabase
      .from('orders')
      .update(updateData)
      .eq('id', orderId)
      .select()
      .single();

    if (updateError || !order) {
      return { data: null, error: 'Fehler beim Aktualisieren der Bestellung' };
    }

    // Record status change
    await supabase.from('order_status_history').insert({
      order_id: orderId,
      previous_status: currentOrder.status,
      new_status: newStatus,
      changed_by: changedBy,
      notes,
    });

    // Get items
    const { data: items } = await supabase.from('order_items').select('*').eq('order_id', orderId);

    revalidatePath('/admin/orders');
    revalidatePath(`/konto/bestellungen/${orderId}`);

    return { data: transformDbOrder(order, items || []), error: null };
  } catch (error) {
    console.error('updateOrderStatus error:', error);
    return { data: null, error: 'Fehler beim Aktualisieren des Status' };
  }
}

/**
 * Add tracking number to order
 */
export async function addTrackingNumber(
  orderId: string,
  trackingNumber: string
): Promise<ActionResult<Order>> {
  try {
    const supabase = await createServerClient();

    const { data: order, error } = await supabase
      .from('orders')
      .update({
        tracking_number: trackingNumber,
        status: 'shipped',
        shipped_at: new Date().toISOString(),
        updated_at: new Date().toISOString(),
      })
      .eq('id', orderId)
      .select()
      .single();

    if (error || !order) {
      return { data: null, error: 'Fehler beim Hinzufügen der Sendungsnummer' };
    }

    const { data: items } = await supabase.from('order_items').select('*').eq('order_id', orderId);

    revalidatePath('/admin/orders');

    return { data: transformDbOrder(order, items || []), error: null };
  } catch (error) {
    console.error('addTrackingNumber error:', error);
    return { data: null, error: 'Fehler beim Hinzufügen der Sendungsnummer' };
  }
}

// ============================================
// CANCEL ORDER
// ============================================

/**
 * Cancel an order
 */
export async function cancelOrder(orderId: string, reason: string): Promise<ActionResult<Order>> {
  try {
    const supabase = await createServerClient();

    const { data: order, error } = await supabase
      .from('orders')
      .update({
        status: 'cancelled',
        cancellation_reason: reason,
        cancelled_at: new Date().toISOString(),
        updated_at: new Date().toISOString(),
      })
      .eq('id', orderId)
      .in('status', ['pending', 'paid', 'processing'])
      .select()
      .single();

    if (error || !order) {
      return {
        data: null,
        error: 'Bestellung kann nicht storniert werden',
      };
    }

    // Record cancellation
    await supabase.from('order_status_history').insert({
      order_id: orderId,
      new_status: 'cancelled',
      notes: `Storniert: ${reason}`,
    });

    const { data: items } = await supabase.from('order_items').select('*').eq('order_id', orderId);

    revalidatePath('/admin/orders');

    return { data: transformDbOrder(order, items || []), error: null };
  } catch (error) {
    console.error('cancelOrder error:', error);
    return { data: null, error: 'Fehler beim Stornieren der Bestellung' };
  }
}

// ============================================
// APPLY VOUCHER
// ============================================

/**
 * Apply voucher to order
 */
export async function applyVoucherToOrder(
  orderId: string,
  voucherCode: string
): Promise<ActionResult<{ discountCents: number }>> {
  try {
    const supabase = await createServerClient();

    // Get order
    const { data: order, error: orderError } = await supabase
      .from('orders')
      .select('*')
      .eq('id', orderId)
      .single();

    if (orderError || !order) {
      return { data: null, error: 'Bestellung nicht gefunden' };
    }

    // Validate voucher using database function
    const { data: voucherResult, error: voucherError } = await supabase.rpc('validate_voucher', {
      p_salon_id: order.salon_id,
      p_code: voucherCode,
    });

    if (voucherError || !voucherResult?.[0]?.is_valid) {
      return {
        data: null,
        error: voucherResult?.[0]?.invalid_reason || 'Ungültiger Gutscheincode',
      };
    }

    const voucher = voucherResult[0];

    // Apply discount using database function
    const { data: discountResult, error: applyError } = await supabase.rpc(
      'apply_voucher_to_order',
      { p_order_id: orderId, p_voucher_code: voucherCode }
    );

    if (applyError) {
      return { data: null, error: 'Fehler beim Anwenden des Gutscheins' };
    }

    revalidatePath('/checkout');

    return { data: { discountCents: discountResult || 0 }, error: null };
  } catch (error) {
    console.error('applyVoucherToOrder error:', error);
    return { data: null, error: 'Fehler beim Anwenden des Gutscheins' };
  }
}

// ============================================
// HELPERS
// ============================================

/**
 * Transform database order to Order type
 */
function transformDbOrder(dbOrder: any, dbItems: any[]): Order {
  return {
    id: dbOrder.id,
    salonId: dbOrder.salon_id,
    customerId: dbOrder.customer_id,
    orderNumber: dbOrder.order_number,
    status: dbOrder.status,
    paymentStatus: dbOrder.payment_status || 'pending',
    paymentMethod: dbOrder.payment_method,
    subtotalCents: dbOrder.subtotal_cents,
    discountCents: dbOrder.discount_cents || 0,
    shippingCents: dbOrder.shipping_cents || 0,
    taxCents: dbOrder.tax_cents || 0,
    totalCents: dbOrder.total_cents,
    taxRate: dbOrder.tax_rate,
    voucherId: dbOrder.voucher_id,
    voucherDiscountCents: dbOrder.voucher_discount_cents || 0,
    shippingMethod: dbOrder.shipping_method,
    shippingAddress: dbOrder.shipping_address,
    trackingNumber: dbOrder.tracking_number,
    pickupDate: dbOrder.pickup_date,
    pickupTime: dbOrder.pickup_time,
    customerEmail: dbOrder.customer_email,
    customerName: dbOrder.customer_name,
    customerPhone: dbOrder.customer_phone,
    customerNotes: dbOrder.customer_notes,
    internalNotes: dbOrder.internal_notes,
    stripeSessionId: dbOrder.stripe_session_id,
    stripePaymentIntentId: dbOrder.stripe_payment_intent_id,
    stripeChargeId: dbOrder.stripe_charge_id,
    paymentError: dbOrder.payment_error,
    refundedAmountCents: dbOrder.refunded_amount_cents || 0,
    hasDispute: dbOrder.has_dispute || false,
    disputeReason: dbOrder.dispute_reason,
    source: dbOrder.source || 'online',
    createdAt: new Date(dbOrder.created_at),
    updatedAt: new Date(dbOrder.updated_at),
    paidAt: dbOrder.paid_at ? new Date(dbOrder.paid_at) : undefined,
    shippedAt: dbOrder.shipped_at ? new Date(dbOrder.shipped_at) : undefined,
    deliveredAt: dbOrder.delivered_at ? new Date(dbOrder.delivered_at) : undefined,
    completedAt: dbOrder.completed_at ? new Date(dbOrder.completed_at) : undefined,
    cancelledAt: dbOrder.cancelled_at ? new Date(dbOrder.cancelled_at) : undefined,
    refundedAt: dbOrder.refunded_at ? new Date(dbOrder.refunded_at) : undefined,
    items: dbItems.map(transformDbOrderItem),
  };
}

/**
 * Transform database order item to OrderItem type
 */
function transformDbOrderItem(dbItem: any): OrderItem {
  return {
    id: dbItem.id,
    orderId: dbItem.order_id,
    itemType: dbItem.item_type,
    productId: dbItem.product_id,
    variantId: dbItem.variant_id,
    itemName: dbItem.item_name,
    itemSku: dbItem.item_sku,
    itemDescription: dbItem.item_description,
    quantity: dbItem.quantity,
    unitPriceCents: dbItem.unit_price_cents,
    discountCents: dbItem.discount_cents || 0,
    totalCents: dbItem.total_cents,
    taxRate: dbItem.tax_rate,
    taxCents: dbItem.tax_cents || 0,
    voucherId: dbItem.voucher_id,
    voucherType: dbItem.voucher_type,
    recipientEmail: dbItem.recipient_email,
    recipientName: dbItem.recipient_name,
    personalMessage: dbItem.personal_message,
  };
}
