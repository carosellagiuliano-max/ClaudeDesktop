import { createBrowserClient as createSupabaseBrowserClient } from '@supabase/ssr';
import type { SupabaseClient } from '@supabase/supabase-js';

// ============================================
// BROWSER SUPABASE CLIENT
// Note: Using 'any' for Database type to avoid strict type checking issues
// with dynamic table queries.
// ============================================

// eslint-disable-next-line @typescript-eslint/no-explicit-any
type AnyDatabase = any;

export function createBrowserClient(): SupabaseClient<AnyDatabase> {
  const supabaseUrl = process.env.NEXT_PUBLIC_SUPABASE_URL!;
  const supabaseAnonKey = process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY!;

  return createSupabaseBrowserClient<AnyDatabase>(supabaseUrl, supabaseAnonKey);
}
