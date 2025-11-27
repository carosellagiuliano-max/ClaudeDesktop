'use client';

import { createContext, useContext, useEffect, useState, useCallback, type ReactNode } from 'react';
import type {
  Cart,
  CartItem,
  CartDiscount,
  ShippingMethod,
  AddToCartInput,
} from '@/lib/domain/cart/types';
import {
  createEmptyCart,
  addItemToCart,
  updateCartItem,
  removeCartItem,
  clearCart,
  applyDiscount,
  removeDiscount,
  setShippingMethod,
  formatPrice,
  getItemCount,
  hasItems,
  isDigitalOnlyCart,
  isCartValidForCheckout,
} from '@/lib/domain/cart/cart';

// ============================================
// CART CONTEXT TYPES
// ============================================

interface CartContextValue {
  // State
  cart: Cart;
  isLoading: boolean;
  isOpen: boolean;

  // Actions
  addItem: (
    input: AddToCartInput,
    productData: {
      name: string;
      description?: string;
      imageUrl?: string;
      priceCents: number;
      sku?: string;
    }
  ) => void;
  updateItem: (itemId: string, quantity: number) => void;
  removeItem: (itemId: string) => void;
  clear: () => void;
  applyDiscountCode: (discount: CartDiscount) => void;
  removeDiscountCode: (code: string) => void;
  selectShipping: (method: ShippingMethod) => void;

  // UI Actions
  openCart: () => void;
  closeCart: () => void;
  toggleCart: () => void;

  // Computed
  itemCount: number;
  isEmpty: boolean;
  isDigitalOnly: boolean;
  validation: { valid: boolean; errors: string[] };

  // Helpers
  formatPrice: (cents: number) => string;
}

// ============================================
// CONTEXT
// ============================================

const CartContext = createContext<CartContextValue | undefined>(undefined);

const CART_STORAGE_KEY = 'schnittwerk_cart';

// ============================================
// PROVIDER
// ============================================

export function CartProvider({ children }: { children: ReactNode }) {
  const [cart, setCart] = useState<Cart>(createEmptyCart);
  const [isLoading, setIsLoading] = useState(true);
  const [isOpen, setIsOpen] = useState(false);

  // Load cart from localStorage on mount
  useEffect(() => {
    try {
      const stored = localStorage.getItem(CART_STORAGE_KEY);
      if (stored) {
        const parsed = JSON.parse(stored);
        // Restore dates
        parsed.createdAt = new Date(parsed.createdAt);
        parsed.updatedAt = new Date(parsed.updatedAt);
        if (parsed.expiresAt) {
          parsed.expiresAt = new Date(parsed.expiresAt);
        }

        // Check if cart is expired
        if (parsed.expiresAt && new Date(parsed.expiresAt) < new Date()) {
          // Cart expired, create new one
          setCart(createEmptyCart());
        } else {
          setCart(parsed);
        }
      }
    } catch (error) {
      console.error('Error loading cart from storage:', error);
    } finally {
      setIsLoading(false);
    }
  }, []);

  // Save cart to localStorage whenever it changes
  useEffect(() => {
    if (!isLoading) {
      try {
        localStorage.setItem(CART_STORAGE_KEY, JSON.stringify(cart));
      } catch (error) {
        console.error('Error saving cart to storage:', error);
      }
    }
  }, [cart, isLoading]);

  // ============================================
  // ACTIONS
  // ============================================

  const addItem = useCallback(
    (
      input: AddToCartInput,
      productData: {
        name: string;
        description?: string;
        imageUrl?: string;
        priceCents: number;
        sku?: string;
      }
    ) => {
      setCart((prev) => addItemToCart(prev, input, productData));
      // Open cart drawer when item is added
      setIsOpen(true);
    },
    []
  );

  const updateItem = useCallback((itemId: string, quantity: number) => {
    setCart((prev) => updateCartItem(prev, { itemId, quantity }));
  }, []);

  const removeItem = useCallback((itemId: string) => {
    setCart((prev) => removeCartItem(prev, itemId));
  }, []);

  const clear = useCallback(() => {
    setCart((prev) => clearCart(prev));
  }, []);

  const applyDiscountCode = useCallback((discount: CartDiscount) => {
    setCart((prev) => applyDiscount(prev, discount));
  }, []);

  const removeDiscountCode = useCallback((code: string) => {
    setCart((prev) => removeDiscount(prev, code));
  }, []);

  const selectShipping = useCallback((method: ShippingMethod) => {
    setCart((prev) => setShippingMethod(prev, method));
  }, []);

  // ============================================
  // UI ACTIONS
  // ============================================

  const openCart = useCallback(() => setIsOpen(true), []);
  const closeCart = useCallback(() => setIsOpen(false), []);
  const toggleCart = useCallback(() => setIsOpen((prev) => !prev), []);

  // ============================================
  // COMPUTED VALUES
  // ============================================

  const itemCount = getItemCount(cart);
  const isEmpty = !hasItems(cart);
  const isDigitalOnly = isDigitalOnlyCart(cart);
  const validation = isCartValidForCheckout(cart);

  // ============================================
  // CONTEXT VALUE
  // ============================================

  const value: CartContextValue = {
    cart,
    isLoading,
    isOpen,
    addItem,
    updateItem,
    removeItem,
    clear,
    applyDiscountCode,
    removeDiscountCode,
    selectShipping,
    openCart,
    closeCart,
    toggleCart,
    itemCount,
    isEmpty,
    isDigitalOnly,
    validation,
    formatPrice,
  };

  return <CartContext.Provider value={value}>{children}</CartContext.Provider>;
}

// ============================================
// HOOK
// ============================================

export function useCart() {
  const context = useContext(CartContext);
  if (context === undefined) {
    throw new Error('useCart must be used within a CartProvider');
  }
  return context;
}

// ============================================
// UTILITIES
// ============================================

/**
 * Clear cart from localStorage (for logout, etc.)
 */
export function clearCartStorage() {
  try {
    localStorage.removeItem(CART_STORAGE_KEY);
  } catch (error) {
    console.error('Error clearing cart storage:', error);
  }
}
