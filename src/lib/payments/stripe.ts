import Stripe from 'stripe';
import { logger } from '../logging/logger';

// ============================================
// STRIPE CLIENT INITIALIZATION
// ============================================

const stripeSecretKey = process.env.STRIPE_SECRET_KEY;

if (!stripeSecretKey && typeof window === 'undefined') {
  logger.warn('STRIPE_SECRET_KEY is not set');
}

export const stripe = stripeSecretKey
  ? new Stripe(stripeSecretKey, {
      apiVersion: '2025-11-17.clover',
      typescript: true,
    })
  : null;

// ============================================
// TYPES
// ============================================

export interface CreateCheckoutSessionParams {
  salonId: string;
  orderId: string;
  customerId?: string;
  customerEmail?: string;
  lineItems: Array<{
    name: string;
    description?: string;
    quantity: number;
    unitAmountCents: number;
  }>;
  successUrl: string;
  cancelUrl: string;
  metadata?: Record<string, string>;
}

export interface CreatePaymentIntentParams {
  amountCents: number;
  currency?: string;
  customerId?: string;
  orderId: string;
  salonId: string;
  metadata?: Record<string, string>;
}

export interface StripeResult<T> {
  data: T | null;
  error: string | null;
}

// ============================================
// CHECKOUT SESSION
// ============================================

/**
 * Creates a Stripe Checkout session for product/voucher purchases
 */
export async function createCheckoutSession(
  params: CreateCheckoutSessionParams
): Promise<StripeResult<Stripe.Checkout.Session>> {
  if (!stripe) {
    return { data: null, error: 'Stripe ist nicht konfiguriert' };
  }

  const {
    salonId,
    orderId,
    customerId,
    customerEmail,
    lineItems,
    successUrl,
    cancelUrl,
    metadata = {},
  } = params;

  try {
    const session = await stripe.checkout.sessions.create({
      payment_method_types: ['card'],
      mode: 'payment',
      customer_email: customerEmail,
      line_items: lineItems.map((item) => ({
        price_data: {
          currency: 'chf',
          product_data: {
            name: item.name,
            description: item.description,
          },
          unit_amount: item.unitAmountCents,
        },
        quantity: item.quantity,
      })),
      success_url: `${successUrl}?session_id={CHECKOUT_SESSION_ID}`,
      cancel_url: cancelUrl,
      metadata: {
        salon_id: salonId,
        order_id: orderId,
        customer_id: customerId || '',
        ...metadata,
      },
    });

    logger.info('Checkout session created', {
      sessionId: session.id,
      orderId,
      salonId,
    });

    return { data: session, error: null };
  } catch (err) {
    const message = err instanceof Error ? err.message : 'Fehler beim Erstellen der Checkout-Session';
    logger.error('Failed to create checkout session', err instanceof Error ? err : undefined, { orderId });
    return { data: null, error: message };
  }
}

/**
 * Retrieves a Checkout session by ID
 */
export async function getCheckoutSession(
  sessionId: string
): Promise<StripeResult<Stripe.Checkout.Session>> {
  if (!stripe) {
    return { data: null, error: 'Stripe ist nicht konfiguriert' };
  }

  try {
    const session = await stripe.checkout.sessions.retrieve(sessionId, {
      expand: ['line_items', 'payment_intent'],
    });

    return { data: session, error: null };
  } catch (err) {
    const message = err instanceof Error ? err.message : 'Fehler beim Abrufen der Session';
    return { data: null, error: message };
  }
}

// ============================================
// PAYMENT INTENTS
// ============================================

/**
 * Creates a Payment Intent for custom payment flows
 */
export async function createPaymentIntent(
  params: CreatePaymentIntentParams
): Promise<StripeResult<Stripe.PaymentIntent>> {
  if (!stripe) {
    return { data: null, error: 'Stripe ist nicht konfiguriert' };
  }

  const {
    amountCents,
    currency = 'chf',
    customerId,
    orderId,
    salonId,
    metadata = {},
  } = params;

  try {
    const paymentIntent = await stripe.paymentIntents.create({
      amount: amountCents,
      currency,
      automatic_payment_methods: {
        enabled: true,
      },
      metadata: {
        salon_id: salonId,
        order_id: orderId,
        customer_id: customerId || '',
        ...metadata,
      },
    });

    logger.info('Payment intent created', {
      paymentIntentId: paymentIntent.id,
      orderId,
      amount: amountCents,
    });

    return { data: paymentIntent, error: null };
  } catch (err) {
    const message = err instanceof Error ? err.message : 'Fehler beim Erstellen des Payment Intents';
    logger.error('Failed to create payment intent', err instanceof Error ? err : undefined, { orderId });
    return { data: null, error: message };
  }
}

/**
 * Retrieves a Payment Intent by ID
 */
export async function getPaymentIntent(
  paymentIntentId: string
): Promise<StripeResult<Stripe.PaymentIntent>> {
  if (!stripe) {
    return { data: null, error: 'Stripe ist nicht konfiguriert' };
  }

  try {
    const paymentIntent = await stripe.paymentIntents.retrieve(paymentIntentId);
    return { data: paymentIntent, error: null };
  } catch (err) {
    const message = err instanceof Error ? err.message : 'Fehler beim Abrufen des Payment Intents';
    return { data: null, error: message };
  }
}

/**
 * Confirms a Payment Intent
 */
export async function confirmPaymentIntent(
  paymentIntentId: string,
  paymentMethodId: string
): Promise<StripeResult<Stripe.PaymentIntent>> {
  if (!stripe) {
    return { data: null, error: 'Stripe ist nicht konfiguriert' };
  }

  try {
    const paymentIntent = await stripe.paymentIntents.confirm(paymentIntentId, {
      payment_method: paymentMethodId,
    });

    return { data: paymentIntent, error: null };
  } catch (err) {
    const message = err instanceof Error ? err.message : 'Fehler beim Bestätigen der Zahlung';
    return { data: null, error: message };
  }
}

/**
 * Cancels a Payment Intent
 */
export async function cancelPaymentIntent(
  paymentIntentId: string
): Promise<StripeResult<Stripe.PaymentIntent>> {
  if (!stripe) {
    return { data: null, error: 'Stripe ist nicht konfiguriert' };
  }

  try {
    const paymentIntent = await stripe.paymentIntents.cancel(paymentIntentId);
    return { data: paymentIntent, error: null };
  } catch (err) {
    const message = err instanceof Error ? err.message : 'Fehler beim Stornieren des Payment Intents';
    return { data: null, error: message };
  }
}

// ============================================
// REFUNDS
// ============================================

/**
 * Creates a refund for a payment
 */
export async function createRefund(
  paymentIntentId: string,
  amountCents?: number,
  reason?: 'duplicate' | 'fraudulent' | 'requested_by_customer'
): Promise<StripeResult<Stripe.Refund>> {
  if (!stripe) {
    return { data: null, error: 'Stripe ist nicht konfiguriert' };
  }

  try {
    const refund = await stripe.refunds.create({
      payment_intent: paymentIntentId,
      amount: amountCents,
      reason,
    });

    logger.info('Refund created', {
      refundId: refund.id,
      paymentIntentId,
      amount: amountCents,
    });

    return { data: refund, error: null };
  } catch (err) {
    const message = err instanceof Error ? err.message : 'Fehler beim Erstellen der Rückerstattung';
    logger.error('Failed to create refund', err instanceof Error ? err : undefined, { paymentIntentId });
    return { data: null, error: message };
  }
}

// ============================================
// WEBHOOK HANDLING
// ============================================

/**
 * Verifies and constructs a Stripe webhook event
 */
export function constructWebhookEvent(
  payload: string | Buffer,
  signature: string,
  webhookSecret: string
): StripeResult<Stripe.Event> {
  if (!stripe) {
    return { data: null, error: 'Stripe ist nicht konfiguriert' };
  }

  try {
    const event = stripe.webhooks.constructEvent(payload, signature, webhookSecret);
    return { data: event, error: null };
  } catch (err) {
    const message = err instanceof Error ? err.message : 'Ungültige Webhook-Signatur';
    logger.error('Webhook signature verification failed', err instanceof Error ? err : undefined);
    return { data: null, error: message };
  }
}

// ============================================
// CUSTOMERS
// ============================================

/**
 * Creates a Stripe Customer
 */
export async function createStripeCustomer(
  email: string,
  name: string,
  metadata?: Record<string, string>
): Promise<StripeResult<Stripe.Customer>> {
  if (!stripe) {
    return { data: null, error: 'Stripe ist nicht konfiguriert' };
  }

  try {
    const customer = await stripe.customers.create({
      email,
      name,
      metadata,
    });

    return { data: customer, error: null };
  } catch (err) {
    const message = err instanceof Error ? err.message : 'Fehler beim Erstellen des Kunden';
    return { data: null, error: message };
  }
}

// ============================================
// PRICE UTILITIES
// ============================================

/**
 * Formats amount in cents to CHF display format
 */
export function formatChfPrice(amountCents: number): string {
  return new Intl.NumberFormat('de-CH', {
    style: 'currency',
    currency: 'CHF',
  }).format(amountCents / 100);
}

/**
 * Converts CHF to cents
 */
export function chfToCents(chf: number): number {
  return Math.round(chf * 100);
}

/**
 * Converts cents to CHF
 */
export function centsToChf(cents: number): number {
  return cents / 100;
}

/**
 * Calculates Swiss VAT (8.1%)
 */
export function calculateVat(amountCents: number, vatRate: number = 0.081): {
  netCents: number;
  vatCents: number;
  grossCents: number;
} {
  const netCents = Math.round(amountCents / (1 + vatRate));
  const vatCents = amountCents - netCents;

  return {
    netCents,
    vatCents,
    grossCents: amountCents,
  };
}
