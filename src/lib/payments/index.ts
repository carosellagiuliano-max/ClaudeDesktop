// ============================================
// SCHNITTWERK PAYMENTS MODULE
// ============================================

// Server-side Stripe functions (use only in API routes/server components)
export {
  stripe,
  createCheckoutSession,
  getCheckoutSession,
  createPaymentIntent,
  getPaymentIntent,
  confirmPaymentIntent,
  cancelPaymentIntent,
  createRefund,
  constructWebhookEvent,
  createStripeCustomer,
  formatChfPrice,
  chfToCents,
  centsToChf,
  calculateVat,
  type CreateCheckoutSessionParams,
  type CreatePaymentIntentParams,
  type StripeResult,
} from './stripe';

// Client-side Stripe functions (use in client components)
export {
  getStripe,
  redirectToCheckout,
  stripeElementsAppearance,
  paymentElementOptions,
} from './stripe-client';
