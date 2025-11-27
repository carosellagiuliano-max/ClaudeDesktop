import type { Metadata } from 'next';
import Link from 'next/link';
import { XCircle, ArrowLeft, ShoppingBag, MessageCircle } from 'lucide-react';
import { Button } from '@/components/ui/button';
import { Card, CardContent } from '@/components/ui/card';

// ============================================
// METADATA
// ============================================

export const metadata: Metadata = {
  title: 'Zahlung abgebrochen',
  description: 'Die Zahlung wurde abgebrochen.',
  robots: { index: false, follow: false },
};

// ============================================
// PAGE
// ============================================

export default function CheckoutCancelledPage() {
  return (
    <div className="container max-w-2xl py-12 md:py-20">
      {/* Icon */}
      <div className="mb-8 flex justify-center">
        <div className="relative">
          <div className="bg-destructive/20 absolute inset-0 rounded-full blur-2xl" />
          <div className="bg-destructive/10 relative flex h-24 w-24 items-center justify-center rounded-full">
            <XCircle className="text-destructive h-12 w-12" />
          </div>
        </div>
      </div>

      {/* Title */}
      <div className="mb-8 text-center">
        <h1 className="mb-3 text-3xl font-bold">Zahlung abgebrochen</h1>
        <p className="text-muted-foreground text-lg">
          Die Zahlung wurde abgebrochen. Keine Sorge, es wurden keine Kosten erhoben.
        </p>
      </div>

      {/* Info Card */}
      <Card className="mb-8">
        <CardContent className="p-6">
          <h2 className="mb-3 font-semibold">Was ist passiert?</h2>
          <p className="text-muted-foreground mb-4 text-sm">
            Die Zahlung wurde nicht abgeschlossen. Dies kann verschiedene Gründe haben:
          </p>
          <ul className="text-muted-foreground space-y-2 text-sm">
            <li className="flex items-start gap-2">
              <span className="text-primary mt-0.5">•</span>
              Sie haben die Zahlung selbst abgebrochen
            </li>
            <li className="flex items-start gap-2">
              <span className="text-primary mt-0.5">•</span>
              Es gab ein technisches Problem
            </li>
            <li className="flex items-start gap-2">
              <span className="text-primary mt-0.5">•</span>
              Die Zahlung wurde von Ihrer Bank abgelehnt
            </li>
          </ul>
        </CardContent>
      </Card>

      {/* Cart Notice */}
      <Card className="bg-muted/50 mb-8">
        <CardContent className="p-6">
          <div className="flex gap-4">
            <div className="bg-primary/10 flex h-10 w-10 flex-shrink-0 items-center justify-center rounded-full">
              <ShoppingBag className="text-primary h-5 w-5" />
            </div>
            <div>
              <h3 className="mb-1 font-medium">Ihr Warenkorb ist noch verfügbar</h3>
              <p className="text-muted-foreground text-sm">
                Ihre ausgewählten Artikel wurden nicht gelöscht. Sie können die Bestellung jederzeit
                erneut versuchen.
              </p>
            </div>
          </div>
        </CardContent>
      </Card>

      {/* Actions */}
      <div className="flex flex-col gap-4 sm:flex-row">
        <Button asChild className="flex-1">
          <Link href="/warenkorb">
            <ArrowLeft className="mr-2 h-4 w-4" />
            Zurück zum Warenkorb
          </Link>
        </Button>
        <Button variant="outline" asChild className="flex-1">
          <Link href="/shop">Weiter einkaufen</Link>
        </Button>
      </div>

      {/* Help Section */}
      <div className="mt-12 text-center">
        <p className="text-muted-foreground mb-4 text-sm">
          Haben Sie Fragen oder benötigen Sie Hilfe?
        </p>
        <Button variant="ghost" asChild>
          <Link href="/kontakt">
            <MessageCircle className="mr-2 h-4 w-4" />
            Kontaktieren Sie uns
          </Link>
        </Button>
      </div>
    </div>
  );
}
