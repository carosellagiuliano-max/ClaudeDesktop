import type { Metadata } from 'next';
import { redirect } from 'next/navigation';
import Link from 'next/link';
import { Scissors } from 'lucide-react';
import { createServerClient } from '@/lib/supabase/server';
import { AdminLoginForm } from '@/components/admin/admin-login-form';

// ============================================
// METADATA
// ============================================

export const metadata: Metadata = {
  title: 'Admin Login | SCHNITTWERK',
  robots: { index: false, follow: false },
};

// ============================================
// ADMIN LOGIN PAGE
// ============================================

export default async function AdminLoginPage({
  searchParams,
}: {
  searchParams: Promise<{ error?: string; message?: string }>;
}) {
  // Check if already authenticated
  const supabase = await createServerClient();
  const {
    data: { user },
  } = await supabase.auth.getUser();

  if (user) {
    // Check if user is admin/staff
    const { data: staffMember } = await supabase
      .from('staff')
      .select('role')
      .eq('user_id', user.id)
      .single();

    if (staffMember) {
      redirect('/admin');
    }
  }

  const params = await searchParams;
  const error = params.error;
  const message = params.message;

  return (
    <div className="min-h-screen flex flex-col items-center justify-center bg-gradient-to-b from-background to-muted/30 p-4">
      {/* Logo */}
      <Link href="/" className="flex items-center gap-2 mb-8">
        <Scissors className="h-8 w-8 text-primary" />
        <span className="text-2xl font-bold">SCHNITTWERK</span>
      </Link>

      {/* Login Card */}
      <div className="w-full max-w-sm">
        <div className="bg-card rounded-lg border shadow-lg p-6">
          <div className="text-center mb-6">
            <h1 className="text-xl font-semibold">Admin-Bereich</h1>
            <p className="text-sm text-muted-foreground mt-1">
              Melden Sie sich an, um fortzufahren
            </p>
          </div>

          {/* Error Messages */}
          {error === 'unauthorized' && (
            <div className="mb-4 p-3 rounded-md bg-destructive/10 text-destructive text-sm">
              Sie haben keine Berechtigung für den Admin-Bereich.
            </div>
          )}
          {error === 'invalid_credentials' && (
            <div className="mb-4 p-3 rounded-md bg-destructive/10 text-destructive text-sm">
              E-Mail oder Passwort ist ungültig.
            </div>
          )}
          {message && (
            <div className="mb-4 p-3 rounded-md bg-primary/10 text-primary text-sm">
              {message}
            </div>
          )}

          {/* Login Form */}
          <AdminLoginForm />
        </div>

        {/* Back to Website */}
        <p className="text-center mt-6 text-sm text-muted-foreground">
          <Link href="/" className="hover:text-foreground transition-colors">
            Zurück zur Website
          </Link>
        </p>
      </div>
    </div>
  );
}
