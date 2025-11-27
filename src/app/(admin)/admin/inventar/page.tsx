import type { Metadata } from 'next';
import { createServerClient } from '@/lib/supabase/server';
import { AdminInventoryView } from '@/components/admin/admin-inventory-view';

// ============================================
// METADATA
// ============================================

export const metadata: Metadata = {
  title: 'Inventar',
};

// ============================================
// TYPES
// ============================================

interface InventoryProduct {
  id: string;
  name: string;
  sku: string | null;
  stockQuantity: number;
  lowStockThreshold: number;
  trackInventory: boolean;
  priceCents: number;
  categoryName: string | null;
  isActive: boolean;
  isLowStock: boolean;
}

interface StockMovement {
  id: string;
  productId: string;
  productName: string;
  movementType: string;
  quantity: number;
  previousQuantity: number;
  newQuantity: number;
  notes: string | null;
  createdBy: string | null;
  createdAt: string;
}

interface InventoryStats {
  totalProducts: number;
  lowStockCount: number;
  outOfStockCount: number;
  totalValue: number;
}

// Supabase row types
interface ProductDbRow {
  id: string;
  name: string;
  sku: string | null;
  stock_quantity: number | null;
  low_stock_threshold: number | null;
  track_inventory: boolean | null;
  price_cents: number;
  cost_price_cents: number | null;
  is_active: boolean;
  product_categories: {
    name: string;
  } | null;
}

interface StockMovementDbRow {
  id: string;
  product_id: string;
  movement_type: string;
  quantity: number;
  previous_quantity: number;
  new_quantity: number;
  notes: string | null;
  created_at: string;
  products: {
    name: string;
  } | null;
  profiles: {
    display_name: string;
  } | null;
}

// ============================================
// DATA FETCHING
// ============================================

async function getInventoryData() {
  const supabase = await createServerClient();

  // Get products with inventory data
  const { data: productsData } = (await supabase
    .from('products')
    .select(
      `
      id,
      name,
      sku,
      stock_quantity,
      low_stock_threshold,
      track_inventory,
      price_cents,
      cost_price_cents,
      is_active,
      product_categories (
        name
      )
    `
    )
    .eq('is_active', true)
    .order('stock_quantity', { ascending: true })) as { data: ProductDbRow[] | null };

  // Get recent stock movements
  const { data: movementsData } = (await supabase
    .from('stock_movements')
    .select(
      `
      id,
      product_id,
      movement_type,
      quantity,
      previous_quantity,
      new_quantity,
      notes,
      created_at,
      products (
        name
      ),
      profiles (
        display_name
      )
    `
    )
    .order('created_at', { ascending: false })
    .limit(50)) as { data: StockMovementDbRow[] | null };

  // Get low stock products count (threshold of 5)
  const { count: lowStockCount } = await supabase
    .from('products')
    .select('id', { count: 'exact', head: true })
    .eq('is_active', true)
    .eq('track_inventory', true)
    .lte('stock_quantity', 5);

  // Get out of stock count
  const { count: outOfStockCount } = await supabase
    .from('products')
    .select('id', { count: 'exact', head: true })
    .eq('is_active', true)
    .eq('track_inventory', true)
    .lte('stock_quantity', 0);

  // Transform products
  const products: InventoryProduct[] = (productsData || []).map((p) => ({
    id: p.id,
    name: p.name,
    sku: p.sku,
    stockQuantity: p.stock_quantity || 0,
    lowStockThreshold: p.low_stock_threshold || 5,
    trackInventory: p.track_inventory ?? true,
    priceCents: p.price_cents,
    categoryName: p.product_categories?.name || null,
    isActive: p.is_active,
    isLowStock: (p.stock_quantity || 0) <= (p.low_stock_threshold || 5),
  }));

  // Transform movements
  const movements: StockMovement[] = (movementsData || []).map((m) => ({
    id: m.id,
    productId: m.product_id,
    productName: m.products?.name || 'Unbekannt',
    movementType: m.movement_type,
    quantity: m.quantity,
    previousQuantity: m.previous_quantity,
    newQuantity: m.new_quantity,
    notes: m.notes,
    createdBy: m.profiles?.display_name || null,
    createdAt: m.created_at,
  }));

  // Calculate total inventory value (at cost price or sale price)
  const totalValue = (productsData || []).reduce((sum, p) => {
    const qty = p.stock_quantity || 0;
    const price = p.cost_price_cents || p.price_cents || 0;
    return sum + qty * price;
  }, 0);

  const stats: InventoryStats = {
    totalProducts: products.length,
    lowStockCount: lowStockCount || 0,
    outOfStockCount: outOfStockCount || 0,
    totalValue,
  };

  return {
    products,
    movements,
    stats,
  };
}

// ============================================
// INVENTORY PAGE
// ============================================

export default async function InventoryPage() {
  const { products, movements, stats } = await getInventoryData();

  return <AdminInventoryView products={products} movements={movements} stats={stats} />;
}
