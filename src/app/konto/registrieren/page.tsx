import type { Metadata } from 'next';
import Link from 'next/link';
import { redirect } from 'next/navigation';
import { Scissors } from 'lucide-react';
import { Card, CardContent, CardHeader, CardTitle } from '@/components/ui/card';
import { RegisterForm } from '@/components/auth';
import { getCurrentUser } from '@/lib/actions';

// ============================================
// METADATA
// ============================================

export const metadata: Metadata = {
  title: 'Registrieren',
  description: 'Erstellen Sie Ihr SCHNITTWERK Kundenkonto und buchen Sie Termine online.',
};

// ============================================
// PAGE COMPONENT
// ============================================

export default async function RegisterPage() {
  // Check if already logged in
  const user = await getCurrentUser();
  if (user) {
    redirect('/konto');
  }

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

        {/* Register Card */}
        <Card className="border-border/50">
          <CardHeader className="pb-2 text-center">
            <CardTitle className="text-2xl">Konto erstellen</CardTitle>
            <p className="text-muted-foreground text-sm">
              Registrieren Sie sich für exklusive Vorteile
            </p>
          </CardHeader>
          <CardContent className="pt-6">
            <RegisterForm />
          </CardContent>
        </Card>

        {/* Benefits */}
        <Card className="border-border/50 bg-muted/30 mt-6">
          <CardContent className="p-4">
            <p className="mb-2 text-sm font-medium">Mit einem Konto können Sie:</p>
            <ul className="text-muted-foreground space-y-1 text-sm">
              <li>- Termine online buchen und verwalten</li>
              <li>- Ihre Buchungshistorie einsehen</li>
              <li>- Schneller buchen mit gespeicherten Daten</li>
              <li>- Exklusive Angebote erhalten</li>
            </ul>
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
