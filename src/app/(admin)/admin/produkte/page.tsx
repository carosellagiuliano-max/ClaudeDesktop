import type { Metadata } from 'next';
import { createServerClient } from '@/lib/supabase/server';
import { AdminProductList } from '@/components/admin/admin-product-list';

// ============================================
// METADATA
// ============================================

export const metadata: Metadata = {
  title: 'Produktverwaltung',
};

// ============================================
// DATA FETCHING
// ============================================

async function getProductsData(searchParams: {
  search?: string;
  category?: string;
  page?: string;
  limit?: string;
}) {
  const supabase = await createServerClient();
  const page = parseInt(searchParams.page || '1');
  const limit = parseInt(searchParams.limit || '20');
  const offset = (page - 1) * limit;
  const search = searchParams.search || '';
  const category = searchParams.category;

  let query = supabase
    .from('products')
    .select(
      `
      id,
      name,
      slug,
      description,
      price_cents,
      compare_at_price_cents,
      stock_quantity,
      sku,
      category,
      is_active,
      image_url,
      created_at
    `,
      { count: 'exact' }
    )
    .order('name')
    .range(offset, offset + limit - 1);

  if (search) {
    query = query.or(`name.ilike.%${search}%,sku.ilike.%${search}%`);
  }

  if (category && category !== 'all') {
    query = query.eq('category', category);
  }

  const { data, count, error } = await query;

  // Get categories for filter
  const { data: categoriesData } = await supabase
    .from('products')
    .select('category')
    .not('category', 'is', null) as { data: { category: string | null }[] | null };

  const categories = [
    ...new Set(categoriesData?.map((p) => p.category).filter(Boolean)),
  ] as string[];

  if (error) {
    console.error('Error fetching products:', error);
    return { products: [], total: 0, page, limit, categories: [] };
  }

  return {
    products: data || [],
    total: count || 0,
    page,
    limit,
    categories,
  };
}

// ============================================
// ADMIN PRODUCTS PAGE
// ============================================

export default async function AdminProductsPage({
  searchParams,
}: {
  searchParams: Promise<{
    search?: string;
    category?: string;
    page?: string;
    limit?: string;
  }>;
}) {
  const params = await searchParams;
  const { products, total, page, limit, categories } =
    await getProductsData(params);

  return (
    <AdminProductList
      products={products}
      total={total}
      page={page}
      limit={limit}
      categories={categories}
      initialSearch={params.search || ''}
      initialCategory={params.category || 'all'}
    />
  );
}
