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
    <div className="from-background to-muted/30 flex min-h-screen flex-col items-center justify-center bg-gradient-to-b p-4">
      {/* Logo */}
      <Link href="/" className="mb-8 flex items-center gap-2">
        <Scissors className="text-primary h-8 w-8" />
        <span className="text-2xl font-bold">SCHNITTWERK</span>
      </Link>

      {/* Login Card */}
      <div className="w-full max-w-sm">
        <div className="bg-card rounded-lg border p-6 shadow-lg">
          <div className="mb-6 text-center">
            <h1 className="text-xl font-semibold">Admin-Bereich</h1>
            <p className="text-muted-foreground mt-1 text-sm">
              Melden Sie sich an, um fortzufahren
            </p>
          </div>

          {/* Error Messages */}
          {error === 'unauthorized' && (
            <div className="bg-destructive/10 text-destructive mb-4 rounded-md p-3 text-sm">
              Sie haben keine Berechtigung für den Admin-Bereich.
            </div>
          )}
          {error === 'invalid_credentials' && (
            <div className="bg-destructive/10 text-destructive mb-4 rounded-md p-3 text-sm">
              E-Mail oder Passwort ist ungültig.
            </div>
          )}
          {message && (
            <div className="bg-primary/10 text-primary mb-4 rounded-md p-3 text-sm">{message}</div>
          )}

          {/* Login Form */}
          <AdminLoginForm />
        </div>

        {/* Back to Website */}
        <p className="text-muted-foreground mt-6 text-center text-sm">
          <Link href="/" className="hover:text-foreground transition-colors">
            Zurück zur Website
          </Link>
        </p>
      </div>
    </div>
  );
}
