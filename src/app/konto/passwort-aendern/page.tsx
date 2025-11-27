import type { Metadata } from 'next';
import Link from 'next/link';
import { Scissors } from 'lucide-react';
import { Card, CardContent, CardHeader, CardTitle } from '@/components/ui/card';
import { NewPasswordForm } from '@/components/auth';

// ============================================
// METADATA
// ============================================

export const metadata: Metadata = {
  title: 'Neues Passwort',
  description: 'Legen Sie ein neues Passwort für Ihr SCHNITTWERK Konto fest.',
};

// ============================================
// PAGE COMPONENT
// ============================================

export default function NewPasswordPage() {
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

        {/* New Password Card */}
        <Card className="border-border/50">
          <CardHeader className="pb-2 text-center">
            <CardTitle className="text-2xl">Neues Passwort</CardTitle>
            <p className="text-muted-foreground text-sm">Geben Sie Ihr neues Passwort ein</p>
          </CardHeader>
          <CardContent className="pt-6">
            <NewPasswordForm />
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
