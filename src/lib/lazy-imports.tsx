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
    <div className="border-primary h-8 w-8 animate-spin rounded-full border-4 border-t-transparent" />
  </div>
);

// ============================================
// UTILITY: Create lazy component wrapper
// ============================================

interface LazyOptions {
  loading?: ComponentType;
  ssr?: boolean;
}

// eslint-disable-next-line @typescript-eslint/no-explicit-any
export function createLazyComponent<T extends ComponentType<any>>(
  importFn: () => Promise<{ default: T } | T>,
  options: LazyOptions = {}
) {
  return dynamic(() => importFn().then((mod) => ('default' in mod ? mod.default : mod)), {
    loading: options.loading || DefaultLoading,
    ssr: options.ssr ?? false,
  });
}

// ============================================
// PREFETCH UTILITIES
// ============================================

/**
 * Prefetch a component on hover or focus
 * Use with onMouseEnter/onFocus on trigger elements
 */
// eslint-disable-next-line @typescript-eslint/no-explicit-any
export function prefetchComponent(importFn: () => Promise<any>) {
  // Trigger the dynamic import
  importFn().catch(() => {
    // Silently fail - this is just a prefetch
  });
}

// Export DefaultLoading for use in other files
export { DefaultLoading };
