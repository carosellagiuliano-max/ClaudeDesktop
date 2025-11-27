'use client';

import { loadStripe, type Stripe } from '@stripe/stripe-js';

// ============================================
// STRIPE CLIENT (BROWSER)
// ============================================

let stripePromise: Promise<Stripe | null> | null = null;

/**
 * Gets or initializes the Stripe client-side instance
 */
export function getStripe(): Promise<Stripe | null> {
  if (!stripePromise) {
    const publishableKey = process.env.NEXT_PUBLIC_STRIPE_PUBLISHABLE_KEY;

    if (!publishableKey) {
      console.warn('NEXT_PUBLIC_STRIPE_PUBLISHABLE_KEY is not set');
      return Promise.resolve(null);
    }

    stripePromise = loadStripe(publishableKey);
  }

  return stripePromise;
}

// ============================================
// CHECKOUT REDIRECT
// ============================================

/**
 * Redirects to Stripe Checkout
 */
export async function redirectToCheckout(sessionId: string): Promise<{ error?: string }> {
  const stripe = await getStripe();

  if (!stripe) {
    return { error: 'Stripe konnte nicht geladen werden' };
  }

  try {
    const { error } = await stripe.redirectToCheckout({ sessionId });

    if (error) {
      return { error: error.message };
    }

    return {};
  } catch (err) {
    return {
      error: err instanceof Error ? err.message : 'Fehler beim Weiterleiten zur Zahlung',
    };
  }
}

// ============================================
// ELEMENTS APPEARANCE
// ============================================

/**
 * Stripe Elements appearance configuration for SCHNITTWERK branding
 */
export const stripeElementsAppearance = {
  theme: 'stripe' as const,
  variables: {
    colorPrimary: '#D4AF37', // Gold accent color
    colorBackground: '#ffffff',
    colorText: '#1a1a1a',
    colorDanger: '#ef4444',
    fontFamily: 'system-ui, -apple-system, sans-serif',
    borderRadius: '8px',
    spacingUnit: '4px',
  },
  rules: {
    '.Input': {
      borderColor: '#e5e7eb',
      boxShadow: 'none',
    },
    '.Input:focus': {
      borderColor: '#D4AF37',
      boxShadow: '0 0 0 1px #D4AF37',
    },
    '.Label': {
      fontWeight: '500',
    },
    '.Error': {
      color: '#ef4444',
    },
  },
};

// ============================================
// PAYMENT ELEMENT OPTIONS
// ============================================

/**
 * Default options for Stripe Payment Element
 */
export const paymentElementOptions = {
  layout: 'tabs' as const,
  defaultValues: {
    billingDetails: {
      address: {
        country: 'CH',
      },
    },
  },
  business: {
    name: 'SCHNITTWERK',
  },
};
