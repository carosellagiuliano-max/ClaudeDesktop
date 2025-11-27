import { createServerClient as createSupabaseServerClient } from '@supabase/ssr';
import type { SupabaseClient } from '@supabase/supabase-js';
import { cookies } from 'next/headers';

// ============================================
// SERVER SUPABASE CLIENT
// Note: Using 'any' for Database type to avoid strict type checking issues
// with dynamic table queries. This allows runtime flexibility while
// maintaining code functionality.
// ============================================

// eslint-disable-next-line @typescript-eslint/no-explicit-any
type AnyDatabase = any;

export async function createServerClient(): Promise<SupabaseClient<AnyDatabase>> {
  const cookieStore = await cookies();
  const supabaseUrl = process.env.NEXT_PUBLIC_SUPABASE_URL!;
  const supabaseAnonKey = process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY!;

  return createSupabaseServerClient<AnyDatabase>(supabaseUrl, supabaseAnonKey, {
    cookies: {
      getAll() {
        return cookieStore.getAll();
      },
      setAll(cookiesToSet) {
        try {
          cookiesToSet.forEach(({ name, value, options }) => cookieStore.set(name, value, options));
        } catch {
          // The `setAll` method was called from a Server Component.
          // This can be ignored if you have middleware refreshing
          // user sessions.
        }
      },
    },
  });
}

// ============================================
// SERVICE ROLE CLIENT (bypasses RLS)
// Use only for admin operations
// ============================================

export function createServiceRoleClient(): SupabaseClient<AnyDatabase> {
  const supabaseUrl = process.env.NEXT_PUBLIC_SUPABASE_URL!;
  const supabaseServiceKey = process.env.SUPABASE_SERVICE_ROLE_KEY!;

  return createSupabaseServerClient<AnyDatabase>(supabaseUrl, supabaseServiceKey, {
    cookies: {
      getAll() {
        return [];
      },
      setAll() {
        // Service role client doesn't need cookies
      },
    },
    auth: {
      autoRefreshToken: false,
      persistSession: false,
    },
  });
}
