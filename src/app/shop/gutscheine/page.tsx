import type { Metadata } from 'next';
import Link from 'next/link';
import { Gift, Mail, Printer, ShoppingBag, CheckCircle, ArrowLeft } from 'lucide-react';
import { Button } from '@/components/ui/button';
import { Card, CardContent, CardHeader, CardTitle } from '@/components/ui/card';
import { Badge } from '@/components/ui/badge';
import { Input } from '@/components/ui/input';
import { Label } from '@/components/ui/label';
import { RadioGroup, RadioGroupItem } from '@/components/ui/radio-group';
import { Textarea } from '@/components/ui/textarea';

// ============================================
// METADATA
// ============================================

export const metadata: Metadata = {
  title: 'Geschenkgutscheine',
  description:
    'Verschenken Sie Wellness für die Haare mit einem SCHNITTWERK Gutschein. Digital oder als Geschenkkarte – das perfekte Geschenk.',
};

// ============================================
// VOUCHER DATA
// ============================================

const presetAmounts = [
  { value: 2500, label: 'CHF 25' },
  { value: 5000, label: 'CHF 50' },
  { value: 7500, label: 'CHF 75' },
  { value: 10000, label: 'CHF 100' },
  { value: 15000, label: 'CHF 150' },
  { value: 20000, label: 'CHF 200' },
];

const deliveryOptions = [
  {
    id: 'email',
    name: 'Digital per E-Mail',
    description: 'Sofort versandfertig als PDF',
    icon: Mail,
    price: 0,
  },
  {
    id: 'print',
    name: 'Zum Selbstdrucken',
    description: 'Hochwertiges PDF zum Ausdrucken',
    icon: Printer,
    price: 0,
  },
  {
    id: 'card',
    name: 'Geschenkkarte',
    description: 'Elegante Karte per Post (2-3 Tage)',
    icon: Gift,
    price: 500,
  },
];

// ============================================
// PAGE COMPONENT
// ============================================

export default function GutscheinePage() {
  return (
    <div className="py-12">
      {/* Back Link */}
      <div className="container-wide mb-8">
        <Link
          href="/shop"
          className="text-muted-foreground hover:text-foreground inline-flex items-center text-sm transition-colors"
        >
          <ArrowLeft className="mr-2 h-4 w-4" />
          Zurück zum Shop
        </Link>
      </div>

      {/* Page Header */}
      <section className="container-wide mb-12">
        <div className="grid items-center gap-12 lg:grid-cols-2">
          <div>
            <Badge className="mb-4">Das perfekte Geschenk</Badge>
            <h1 className="mb-6 text-4xl font-bold md:text-5xl">Geschenkgutscheine</h1>
            <p className="text-muted-foreground mb-6 text-lg">
              Verschenken Sie Entspannung, Styling und Verwöhnmomente. Unsere Gutscheine sind für
              alle Leistungen und Produkte bei SCHNITTWERK einlösbar.
            </p>
            <ul className="text-muted-foreground space-y-2">
              <li className="flex items-center gap-2">
                <CheckCircle className="text-primary h-4 w-4" />
                Wert frei wählbar (ab CHF 25)
              </li>
              <li className="flex items-center gap-2">
                <CheckCircle className="text-primary h-4 w-4" />2 Jahre gültig
              </li>
              <li className="flex items-center gap-2">
                <CheckCircle className="text-primary h-4 w-4" />
                Einlösbar für alle Leistungen & Produkte
              </li>
              <li className="flex items-center gap-2">
                <CheckCircle className="text-primary h-4 w-4" />
                Persönliche Grußbotschaft möglich
              </li>
            </ul>
          </div>

          {/* Image Placeholder */}
          <div className="from-primary/20 to-primary/5 relative flex aspect-square items-center justify-center rounded-2xl bg-gradient-to-br">
            <Gift className="text-primary/30 h-24 w-24" />
          </div>
        </div>
      </section>

      {/* Voucher Configuration */}
      <section className="container-wide">
        <div className="grid gap-8 lg:grid-cols-3">
          {/* Configuration Form */}
          <div className="space-y-8 lg:col-span-2">
            {/* Amount Selection */}
            <Card className="border-border/50">
              <CardHeader>
                <CardTitle>1. Betrag wählen</CardTitle>
              </CardHeader>
              <CardContent>
                <div className="mb-6 grid grid-cols-3 gap-3">
                  {presetAmounts.map((amount) => (
                    <button
                      key={amount.value}
                      className="border-border/50 hover:border-primary hover:bg-primary/5 rounded-lg border p-4 text-center transition-colors"
                    >
                      <span className="text-lg font-semibold">{amount.label}</span>
                    </button>
                  ))}
                </div>
                <div className="space-y-2">
                  <Label htmlFor="customAmount">Oder eigenen Betrag eingeben</Label>
                  <div className="flex items-center gap-2">
                    <span className="text-muted-foreground">CHF</span>
                    <Input
                      id="customAmount"
                      type="number"
                      min="25"
                      step="5"
                      placeholder="z.B. 125"
                      className="w-32"
                    />
                  </div>
                  <p className="text-muted-foreground text-xs">Mindestbetrag CHF 25</p>
                </div>
              </CardContent>
            </Card>

            {/* Delivery Option */}
            <Card className="border-border/50">
              <CardHeader>
                <CardTitle>2. Versandart wählen</CardTitle>
              </CardHeader>
              <CardContent>
                <RadioGroup defaultValue="email" className="space-y-3">
                  {deliveryOptions.map((option) => (
                    <label
                      key={option.id}
                      className="border-border/50 hover:border-primary/50 hover:bg-primary/5 flex cursor-pointer items-start gap-4 rounded-lg border p-4 transition-colors"
                    >
                      <RadioGroupItem value={option.id} className="mt-1" />
                      <div className="bg-muted flex h-10 w-10 items-center justify-center rounded-lg">
                        <option.icon className="text-muted-foreground h-5 w-5" />
                      </div>
                      <div className="flex-1">
                        <div className="flex items-center justify-between">
                          <span className="font-medium">{option.name}</span>
                          {option.price > 0 ? (
                            <span className="text-muted-foreground text-sm">
                              + CHF {(option.price / 100).toFixed(2)}
                            </span>
                          ) : (
                            <Badge variant="secondary" className="text-xs">
                              Kostenlos
                            </Badge>
                          )}
                        </div>
                        <p className="text-muted-foreground text-sm">{option.description}</p>
                      </div>
                    </label>
                  ))}
                </RadioGroup>
              </CardContent>
            </Card>

            {/* Personalization */}
            <Card className="border-border/50">
              <CardHeader>
                <CardTitle>3. Personalisieren (optional)</CardTitle>
              </CardHeader>
              <CardContent className="space-y-6">
                <div className="grid gap-4 sm:grid-cols-2">
                  <div className="space-y-2">
                    <Label htmlFor="recipientName">Name des Beschenkten</Label>
                    <Input id="recipientName" placeholder="z.B. Anna" />
                  </div>
                  <div className="space-y-2">
                    <Label htmlFor="senderName">Ihr Name</Label>
                    <Input id="senderName" placeholder="z.B. Max" />
                  </div>
                </div>
                <div className="space-y-2">
                  <Label htmlFor="message">Persönliche Nachricht</Label>
                  <Textarea
                    id="message"
                    placeholder="z.B. Alles Gute zum Geburtstag! Gönn dir etwas Schönes..."
                    rows={3}
                  />
                  <p className="text-muted-foreground text-xs">Maximal 200 Zeichen</p>
                </div>
              </CardContent>
            </Card>
          </div>

          {/* Order Summary */}
          <div>
            <Card className="border-border/50 sticky top-24">
              <CardHeader>
                <CardTitle>Zusammenfassung</CardTitle>
              </CardHeader>
              <CardContent className="space-y-6">
                {/* Preview */}
                <div className="from-primary/10 to-primary/5 relative flex aspect-[3/2] items-center justify-center rounded-lg bg-gradient-to-br">
                  <div className="text-center">
                    <Gift className="text-primary mx-auto mb-2 h-8 w-8" />
                    <p className="text-muted-foreground text-sm">Vorschau</p>
                  </div>
                </div>

                {/* Summary */}
                <div className="space-y-3 border-t pt-4">
                  <div className="flex justify-between text-sm">
                    <span className="text-muted-foreground">Gutscheinwert</span>
                    <span>CHF 50.00</span>
                  </div>
                  <div className="flex justify-between text-sm">
                    <span className="text-muted-foreground">Versand</span>
                    <span className="text-primary">Kostenlos</span>
                  </div>
                  <div className="flex justify-between border-t pt-3 text-lg font-semibold">
                    <span>Gesamt</span>
                    <span className="text-primary">CHF 50.00</span>
                  </div>
                </div>

                {/* Buy Button */}
                <Button className="btn-glow w-full" size="lg">
                  <ShoppingBag className="mr-2 h-4 w-4" />
                  In den Warenkorb
                </Button>

                {/* Trust Badges */}
                <div className="border-t pt-4 text-center">
                  <p className="text-muted-foreground text-xs">
                    Sichere Zahlung mit Karte oder TWINT
                  </p>
                </div>
              </CardContent>
            </Card>
          </div>
        </div>
      </section>

      {/* FAQ */}
      <section className="container-wide mt-16">
        <Card className="bg-muted/30 border-border/50">
          <CardContent className="p-8">
            <h2 className="mb-6 text-center text-xl font-bold">Häufige Fragen</h2>
            <div className="mx-auto grid max-w-4xl gap-6 md:grid-cols-2">
              <div>
                <h3 className="mb-2 font-semibold">Wie lange ist der Gutschein gültig?</h3>
                <p className="text-muted-foreground text-sm">
                  Alle Gutscheine sind 2 Jahre ab Kaufdatum gültig.
                </p>
              </div>
              <div>
                <h3 className="mb-2 font-semibold">
                  Kann ich den Gutschein auch für Produkte einlösen?
                </h3>
                <p className="text-muted-foreground text-sm">
                  Ja, der Gutschein ist für alle Leistungen und Produkte einlösbar.
                </p>
              </div>
              <div>
                <h3 className="mb-2 font-semibold">
                  Was passiert, wenn der Gutscheinwert nicht aufgebraucht wird?
                </h3>
                <p className="text-muted-foreground text-sm">
                  Das Restguthaben bleibt erhalten und kann beim nächsten Besuch eingelöst werden.
                </p>
              </div>
              <div>
                <h3 className="mb-2 font-semibold">
                  Kann ich den Gutschein auch bar auszahlen lassen?
                </h3>
                <p className="text-muted-foreground text-sm">
                  Nein, eine Barauszahlung ist leider nicht möglich.
                </p>
              </div>
            </div>
          </CardContent>
        </Card>
      </section>
    </div>
  );
}
