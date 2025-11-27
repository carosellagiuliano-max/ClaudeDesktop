/**
 * SCHNITTWERK - Lazy Import Utilities
 * Dynamic imports for code splitting and performance optimization
 */

import dynamic from 'next/dynamic';
import { ComponentType } from 'react';

// ============================================
// LOADING COMPONENTS
// ============================================

const DefaultLoading = () => (
  <div className="flex items-center justify-center p-8">
    <div className="h-8 w-8 animate-spin rounded-full border-4 border-primary border-t-transparent" />
  </div>
);

// ============================================
// HEAVY COMPONENTS - LAZY LOADED
// ============================================

/**
 * Calendar components (heavy due to date-fns)
 */
export const LazyCalendarView = dynamic(
  () => import('@/components/admin/calendar-view').then((mod) => mod.CalendarView),
  {
    loading: DefaultLoading,
    ssr: false,
  }
);

export const LazyCustomerCalendar = dynamic(
  () => import('@/components/customer/customer-calendar-view').then((mod) => mod.CustomerCalendarView),
  {
    loading: DefaultLoading,
    ssr: false,
  }
);

/**
 * Charts and analytics (heavy due to recharts)
 */
export const LazyAnalyticsDashboard = dynamic(
  () => import('@/components/admin/analytics-dashboard'),
  {
    loading: DefaultLoading,
    ssr: false,
  }
);

export const LazyFinancialOverview = dynamic(
  () => import('@/components/admin/financial-overview'),
  {
    loading: DefaultLoading,
    ssr: false,
  }
);

/**
 * Rich text editors
 */
export const LazyRichTextEditor = dynamic(
  () => import('@/components/ui/rich-text-editor'),
  {
    loading: DefaultLoading,
    ssr: false,
  }
);

/**
 * Image handling components
 */
export const LazyImageUploader = dynamic(
  () => import('@/components/admin/image-uploader'),
  {
    loading: DefaultLoading,
    ssr: false,
  }
);

export const LazyImageGallery = dynamic(
  () => import('@/components/gallery/image-gallery'),
  {
    loading: DefaultLoading,
    ssr: false,
  }
);

/**
 * PDF generation
 */
export const LazyInvoicePDF = dynamic(
  () => import('@/components/pdf/invoice-pdf'),
  {
    loading: DefaultLoading,
    ssr: false,
  }
);

/**
 * Maps (if using Google Maps or similar)
 */
export const LazyLocationMap = dynamic(
  () => import('@/components/maps/location-map'),
  {
    loading: DefaultLoading,
    ssr: false,
  }
);

// ============================================
// DIALOG COMPONENTS - LAZY LOADED
// ============================================

/**
 * Admin dialogs
 */
export const LazyAddCustomerModal = dynamic(
  () => import('@/components/admin/add-customer-modal'),
  { ssr: false }
);

export const LazyCustomerDetailModal = dynamic(
  () => import('@/components/admin/customer-detail-modal'),
  { ssr: false }
);

export const LazyEditEmployeeModal = dynamic(
  () => import('@/components/admin/edit-employee-modal'),
  { ssr: false }
);

/**
 * Booking dialogs
 */
export const LazyAppointmentBookingDialog = dynamic(
  () => import('@/components/booking/appointment-booking-dialog'),
  { ssr: false }
);

export const LazyStripeCheckoutDialog = dynamic(
  () => import('@/components/booking/stripe-checkout-dialog'),
  { ssr: false }
);

// ============================================
// PAGE SECTIONS - LAZY LOADED
// ============================================

/**
 * Heavy page sections
 */
export const LazyGoogleReviews = dynamic(
  () => import('@/components/sections/google-reviews').then((mod) => mod.GoogleReviews),
  {
    loading: DefaultLoading,
    ssr: true, // SSR for SEO
  }
);

// ============================================
// UTILITY: Create lazy component wrapper
// ============================================

interface LazyOptions {
  loading?: ComponentType;
  ssr?: boolean;
}

export function createLazyComponent<T extends ComponentType<any>>(
  importFn: () => Promise<{ default: T } | T>,
  options: LazyOptions = {}
) {
  return dynamic(
    () => importFn().then((mod) => ('default' in mod ? mod.default : mod)),
    {
      loading: options.loading || DefaultLoading,
      ssr: options.ssr ?? false,
    }
  );
}

// ============================================
// PREFETCH UTILITIES
// ============================================

/**
 * Prefetch a component on hover or focus
 * Use with onMouseEnter/onFocus on trigger elements
 */
export function prefetchComponent(importFn: () => Promise<any>) {
  // Trigger the dynamic import
  importFn().catch(() => {
    // Silently fail - this is just a prefetch
  });
}

/**
 * Prefetch common routes on idle
 */
export function prefetchCommonRoutes() {
  if (typeof window === 'undefined') return;

  // Use requestIdleCallback if available
  const prefetch = () => {
    // Prefetch common dynamic imports
    import('@/components/booking/appointment-booking-dialog').catch(() => {});
    import('@/components/booking/stripe-checkout-dialog').catch(() => {});
  };

  if ('requestIdleCallback' in window) {
    (window as any).requestIdleCallback(prefetch);
  } else {
    setTimeout(prefetch, 2000);
  }
}
