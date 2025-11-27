import type { Metadata } from 'next';
import Link from 'next/link';
import { redirect } from 'next/navigation';
import { Scissors } from 'lucide-react';
import { Card, CardContent, CardHeader, CardTitle } from '@/components/ui/card';
import { LoginForm } from '@/components/auth';
import { getCurrentUser } from '@/lib/actions';

// ============================================
// METADATA
// ============================================

export const metadata: Metadata = {
  title: 'Anmelden',
  description: 'Melden Sie sich bei Ihrem SCHNITTWERK Kundenkonto an.',
};

// ============================================
// PAGE COMPONENT
// ============================================

interface PageProps {
  searchParams: Promise<{ redirect?: string }>;
}

export default async function LoginPage({ searchParams }: PageProps) {
  // Check if already logged in
  const user = await getCurrentUser();
  if (user) {
    redirect('/konto');
  }

  const params = await searchParams;

  return (
    <div className="flex min-h-[80vh] items-center justify-center px-4 py-12">
      <div className="w-full max-w-md">
        {/* Logo */}
        <div className="mb-8 text-center">
          <Link href="/" className="inline-flex items-center gap-2">
            <Scissors className="text-primary h-8 w-8" />
            <span className="text-2xl font-bold">SCHNITTWERK</span>
          </Link>
        </div>

        {/* Login Card */}
        <Card className="border-border/50">
          <CardHeader className="pb-2 text-center">
            <CardTitle className="text-2xl">Willkommen zurück</CardTitle>
            <p className="text-muted-foreground text-sm">Melden Sie sich bei Ihrem Konto an</p>
          </CardHeader>
          <CardContent className="pt-6">
            <LoginForm redirectTo={params.redirect} />
          </CardContent>
        </Card>

        {/* Footer */}
        <p className="text-muted-foreground mt-8 text-center text-sm">
          <Link href="/" className="hover:text-primary">
            Zurück zur Startseite
          </Link>
        </p>
      </div>
    </div>
  );
}
