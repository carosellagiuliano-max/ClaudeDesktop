import { createClient, SupabaseClient } from '@supabase/supabase-js';

// Note: Using 'any' for Database type to avoid strict type checking issues
// with dynamic table queries.
// eslint-disable-next-line @typescript-eslint/no-explicit-any
type AnyDatabase = any;

// Environment validation
const supabaseUrl = process.env.NEXT_PUBLIC_SUPABASE_URL;
const supabaseAnonKey = process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY;

if (!supabaseUrl) {
  throw new Error('Missing NEXT_PUBLIC_SUPABASE_URL environment variable');
}

if (!supabaseAnonKey) {
  throw new Error('Missing NEXT_PUBLIC_SUPABASE_ANON_KEY environment variable');
}

// Client-side Supabase client (uses anon key, respects RLS)
export const supabase = createClient<AnyDatabase>(supabaseUrl, supabaseAnonKey, {
  auth: {
    autoRefreshToken: true,
    persistSession: true,
    detectSessionInUrl: true,
  },
});

// Server-side Supabase client (uses service role key, bypasses RLS)
// Only use this for admin operations and background jobs
export function createServerClient(): SupabaseClient<AnyDatabase> {
  const supabaseServiceKey = process.env.SUPABASE_SERVICE_ROLE_KEY;

  if (!supabaseServiceKey) {
    throw new Error('Missing SUPABASE_SERVICE_ROLE_KEY environment variable');
  }

  return createClient<AnyDatabase>(supabaseUrl, supabaseServiceKey, {
    auth: {
      autoRefreshToken: false,
      persistSession: false,
    },
  });
}

// Type export for convenience
export type SupabaseClientType = typeof supabase;
