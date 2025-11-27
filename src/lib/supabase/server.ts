import { createServerClient as createSupabaseServerClient } from '@supabase/ssr';
import { cookies } from 'next/headers';
import type { Database } from '@/lib/db/types';

// ============================================
// SERVER SUPABASE CLIENT
// ============================================

export async function createServerClient() {
  const cookieStore = await cookies();
  const supabaseUrl = process.env.NEXT_PUBLIC_SUPABASE_URL!;
  const supabaseAnonKey = process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY!;

  return createSupabaseServerClient<Database>(supabaseUrl, supabaseAnonKey, {
    cookies: {
      getAll() {
        return cookieStore.getAll();
      },
      setAll(cookiesToSet) {
        try {
          cookiesToSet.forEach(({ name, value, options }) =>
            cookieStore.set(name, value, options)
          );
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

export function createServiceRoleClient() {
  const supabaseUrl = process.env.NEXT_PUBLIC_SUPABASE_URL!;
  const supabaseServiceKey = process.env.SUPABASE_SERVICE_ROLE_KEY!;

  return createSupabaseServerClient<Database>(supabaseUrl, supabaseServiceKey, {
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
