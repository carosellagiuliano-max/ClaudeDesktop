'use server';

import { createServerClient } from '@/lib/db/client';
import { unstable_cache } from 'next/cache';

// ============================================
// PRODUCTS DATA SERVER ACTIONS
// ============================================

// Default salon ID for SCHNITTWERK (from seed data)
const DEFAULT_SALON_ID = '550e8400-e29b-41d4-a716-446655440001';

export type ProductCategory = {
  id: string;
  name: string;
  slug: string;
  description: string | null;
  sortOrder: number;
};

export type Product = {
  id: string;
  categoryId: string;
  name: string;
  slug: string;
  description: string | null;
  brand: string | null;
  sku: string | null;
  priceCents: number;
  stockQuantity: number;
  imageUrl: string | null;
  isFeatured: boolean;
  isActive: boolean;
  sortOrder: number;
};

export type ProductWithCategory = Product & {
  category: ProductCategory | null;
};

// ============================================
// GET PRODUCT CATEGORIES
// ============================================

export const getProductCategories = unstable_cache(
  async (salonId: string = DEFAULT_SALON_ID): Promise<ProductCategory[]> => {
    const supabase = createServerClient();

    const { data, error } = await supabase
      .from('product_categories')
      .select('*')
      .eq('salon_id', salonId)
      .order('sort_order', { ascending: true });

    if (error || !data) {
      console.error('Error fetching product categories:', error);
      return [];
    }

    return data.map((cat) => ({
      id: cat.id,
      name: cat.name,
      slug: cat.slug,
      description: cat.description,
      sortOrder: cat.sort_order,
    }));
  },
  ['product-categories'],
  { revalidate: 3600, tags: ['products'] }
);

// ============================================
// GET PRODUCTS
// ============================================

export const getProducts = unstable_cache(
  async (salonId: string = DEFAULT_SALON_ID): Promise<Product[]> => {
    const supabase = createServerClient();

    const { data, error } = await supabase
      .from('products')
      .select('*')
      .eq('salon_id', salonId)
      .eq('is_active', true)
      .order('sort_order', { ascending: true });

    if (error || !data) {
      console.error('Error fetching products:', error);
      return [];
    }

    return data.map((prod) => ({
      id: prod.id,
      categoryId: prod.category_id,
      name: prod.name,
      slug: prod.slug,
      description: prod.description,
      brand: prod.brand,
      sku: prod.sku,
      priceCents: prod.price_cents,
      stockQuantity: prod.stock_quantity,
      imageUrl: prod.image_url,
      isFeatured: prod.is_featured || false,
      isActive: prod.is_active,
      sortOrder: prod.sort_order,
    }));
  },
  ['products'],
  { revalidate: 3600, tags: ['products'] }
);

// ============================================
// GET PRODUCTS WITH CATEGORIES
// ============================================

export const getProductsWithCategories = unstable_cache(
  async (salonId: string = DEFAULT_SALON_ID): Promise<ProductWithCategory[]> => {
    const [products, categories] = await Promise.all([
      getProducts(salonId),
      getProductCategories(salonId),
    ]);

    const categoryMap = new Map(categories.map((c) => [c.id, c]));

    return products.map((prod) => ({
      ...prod,
      category: categoryMap.get(prod.categoryId) || null,
    }));
  },
  ['products-with-categories'],
  { revalidate: 3600, tags: ['products'] }
);

// ============================================
// GET FEATURED PRODUCTS
// ============================================

export const getFeaturedProducts = unstable_cache(
  async (salonId: string = DEFAULT_SALON_ID): Promise<ProductWithCategory[]> => {
    const products = await getProductsWithCategories(salonId);
    return products.filter((p) => p.isFeatured);
  },
  ['featured-products'],
  { revalidate: 3600, tags: ['products'] }
);

// ============================================
// GET PRODUCT BY SLUG
// ============================================

export async function getProductBySlug(
  slug: string,
  salonId: string = DEFAULT_SALON_ID
): Promise<ProductWithCategory | null> {
  const products = await getProductsWithCategories(salonId);
  return products.find((p) => p.slug === slug) || null;
}

// ============================================
// GET PRODUCTS BY CATEGORY
// ============================================

export async function getProductsByCategory(
  categorySlug: string,
  salonId: string = DEFAULT_SALON_ID
): Promise<ProductWithCategory[]> {
  const products = await getProductsWithCategories(salonId);
  return products.filter((p) => p.category?.slug === categorySlug);
}
