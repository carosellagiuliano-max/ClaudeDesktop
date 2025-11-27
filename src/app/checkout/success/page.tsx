import type { Metadata } from 'next';
import Link from 'next/link';
import { CheckCircle2, Package, ArrowRight, Mail } from 'lucide-react';
import { Button } from '@/components/ui/button';
import { Card, CardContent } from '@/components/ui/card';
import { Separator } from '@/components/ui/separator';
import { getOrder } from '@/lib/actions/orders';
import { getCheckoutSession } from '@/lib/payments/stripe';
import { formatPrice } from '@/lib/domain/order/order';

// ============================================
// METADATA
// ============================================

export const metadata: Metadata = {
  title: 'Bestellung erfolgreich',
  description: 'Ihre Bestellung wurde erfolgreich aufgegeben.',
  robots: { index: false, follow: false },
};

// ============================================
// PAGE
// ============================================

interface PageProps {
  searchParams: Promise<{ session_id?: string }>;
}

export default async function CheckoutSuccessPage({ searchParams }: PageProps) {
  const params = await searchParams;
  const sessionId = params.session_id;

  // Try to get order details from Stripe session
  let order = null;
  let orderNumber = '';

  if (sessionId) {
    const { data: session } = await getCheckoutSession(sessionId);
    if (session?.metadata?.order_id) {
      const { data: orderData } = await getOrder(session.metadata.order_id);
      order = orderData;
      orderNumber = order?.orderNumber || '';
    }
  }

  return (
    <div className="container max-w-2xl py-12 md:py-20">
      {/* Success Icon */}
      <div className="mb-8 flex justify-center">
        <div className="relative">
          <div className="absolute inset-0 rounded-full bg-green-500/20 blur-2xl" />
          <div className="relative flex h-24 w-24 items-center justify-center rounded-full bg-green-500/10">
            <CheckCircle2 className="h-12 w-12 text-green-500" />
          </div>
        </div>
      </div>

      {/* Title */}
      <div className="mb-8 text-center">
        <h1 className="mb-3 text-3xl font-bold">Vielen Dank für Ihre Bestellung!</h1>
        <p className="text-muted-foreground text-lg">
          Ihre Bestellung wurde erfolgreich aufgenommen.
        </p>
      </div>

      {/* Order Details Card */}
      <Card className="mb-8">
        <CardContent className="p-6">
          {order ? (
            <>
              <div className="mb-4 flex items-center justify-between">
                <div>
                  <p className="text-muted-foreground text-sm">Bestellnummer</p>
                  <p className="font-mono text-xl font-semibold">{order.orderNumber}</p>
                </div>
                <div className="bg-primary/10 flex h-12 w-12 items-center justify-center rounded-full">
                  <Package className="text-primary h-6 w-6" />
                </div>
              </div>

              <Separator className="my-4" />

              {/* Order Items */}
              <div className="mb-4 space-y-3">
                {order.items.map((item) => (
                  <div key={item.id} className="flex justify-between text-sm">
                    <span>
                      {item.quantity}x {item.itemName}
                    </span>
                    <span className="font-medium">{formatPrice(item.totalCents)}</span>
                  </div>
                ))}
              </div>

              <Separator className="my-4" />

              {/* Totals */}
              <div className="space-y-2">
                <div className="flex justify-between text-sm">
                  <span className="text-muted-foreground">Zwischensumme</span>
                  <span>{formatPrice(order.subtotalCents)}</span>
                </div>
                {order.shippingCents > 0 && (
                  <div className="flex justify-between text-sm">
                    <span className="text-muted-foreground">Versand</span>
                    <span>{formatPrice(order.shippingCents)}</span>
                  </div>
                )}
                {order.voucherDiscountCents > 0 && (
                  <div className="flex justify-between text-sm text-green-600">
                    <span>Gutschein</span>
                    <span>-{formatPrice(order.voucherDiscountCents)}</span>
                  </div>
                )}
                <div className="flex justify-between border-t pt-2 text-lg font-semibold">
                  <span>Gesamtbetrag</span>
                  <span>{formatPrice(order.totalCents)}</span>
                </div>
                <p className="text-muted-foreground text-right text-xs">
                  inkl. {formatPrice(order.taxCents)} MwSt.
                </p>
              </div>
            </>
          ) : (
            <div className="py-4 text-center">
              <p className="text-muted-foreground">Bestelldetails werden per E-Mail zugesendet.</p>
            </div>
          )}
        </CardContent>
      </Card>

      {/* Confirmation Notice */}
      <Card className="bg-muted/50 mb-8">
        <CardContent className="p-6">
          <div className="flex gap-4">
            <div className="bg-primary/10 flex h-10 w-10 flex-shrink-0 items-center justify-center rounded-full">
              <Mail className="text-primary h-5 w-5" />
            </div>
            <div>
              <h3 className="mb-1 font-medium">Bestätigung per E-Mail</h3>
              <p className="text-muted-foreground text-sm">
                Wir haben Ihnen eine Bestellbestätigung an{' '}
                {order?.customerEmail ? (
                  <span className="text-foreground font-medium">{order.customerEmail}</span>
                ) : (
                  'Ihre E-Mail-Adresse'
                )}{' '}
                gesendet.
              </p>
            </div>
          </div>
        </CardContent>
      </Card>

      {/* Next Steps */}
      <div className="space-y-4">
        <h2 className="text-lg font-semibold">Nächste Schritte</h2>
        <div className="grid gap-4">
          {order?.shippingMethod === 'pickup' ? (
            <Card>
              <CardContent className="p-4">
                <h3 className="mb-1 font-medium">Abholung im Salon</h3>
                <p className="text-muted-foreground text-sm">
                  Sie können Ihre Bestellung zu unseren Öffnungszeiten im Salon abholen. Bringen Sie
                  bitte Ihre Bestellnummer mit.
                </p>
              </CardContent>
            </Card>
          ) : order?.shippingMethod && order.shippingMethod !== 'none' ? (
            <Card>
              <CardContent className="p-4">
                <h3 className="mb-1 font-medium">Versand</h3>
                <p className="text-muted-foreground text-sm">
                  Ihre Bestellung wird innerhalb von 1-2 Werktagen versendet. Sie erhalten eine
                  E-Mail mit der Sendungsverfolgung.
                </p>
              </CardContent>
            </Card>
          ) : null}

          {order?.items.some((item) => item.itemType === 'voucher') && (
            <Card>
              <CardContent className="p-4">
                <h3 className="mb-1 font-medium">Gutschein</h3>
                <p className="text-muted-foreground text-sm">
                  Der Gutschein wird per E-Mail an den Empfänger gesendet. Sie können den Gutschein
                  auch selbst ausdrucken.
                </p>
              </CardContent>
            </Card>
          )}
        </div>
      </div>

      {/* Actions */}
      <div className="mt-8 flex flex-col gap-4 sm:flex-row">
        <Button asChild className="flex-1">
          <Link href="/konto/bestellungen">
            Bestellungen ansehen
            <ArrowRight className="ml-2 h-4 w-4" />
          </Link>
        </Button>
        <Button variant="outline" asChild className="flex-1">
          <Link href="/shop">Weiter einkaufen</Link>
        </Button>
      </div>
    </div>
  );
}
