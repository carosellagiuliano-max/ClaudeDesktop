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
          className="inline-flex items-center text-sm text-muted-foreground hover:text-foreground transition-colors"
        >
          <ArrowLeft className="mr-2 h-4 w-4" />
          Zurück zum Shop
        </Link>
      </div>

      {/* Page Header */}
      <section className="container-wide mb-12">
        <div className="grid gap-12 lg:grid-cols-2 items-center">
          <div>
            <Badge className="mb-4">Das perfekte Geschenk</Badge>
            <h1 className="text-4xl md:text-5xl font-bold mb-6">
              Geschenkgutscheine
            </h1>
            <p className="text-lg text-muted-foreground mb-6">
              Verschenken Sie Entspannung, Styling und Verwöhnmomente. Unsere
              Gutscheine sind für alle Leistungen und Produkte bei SCHNITTWERK
              einlösbar.
            </p>
            <ul className="space-y-2 text-muted-foreground">
              <li className="flex items-center gap-2">
                <CheckCircle className="h-4 w-4 text-primary" />
                Wert frei wählbar (ab CHF 25)
              </li>
              <li className="flex items-center gap-2">
                <CheckCircle className="h-4 w-4 text-primary" />
                2 Jahre gültig
              </li>
              <li className="flex items-center gap-2">
                <CheckCircle className="h-4 w-4 text-primary" />
                Einlösbar für alle Leistungen & Produkte
              </li>
              <li className="flex items-center gap-2">
                <CheckCircle className="h-4 w-4 text-primary" />
                Persönliche Grußbotschaft möglich
              </li>
            </ul>
          </div>

          {/* Image Placeholder */}
          <div className="relative aspect-square bg-gradient-to-br from-primary/20 to-primary/5 rounded-2xl flex items-center justify-center">
            <Gift className="h-24 w-24 text-primary/30" />
          </div>
        </div>
      </section>

      {/* Voucher Configuration */}
      <section className="container-wide">
        <div className="grid gap-8 lg:grid-cols-3">
          {/* Configuration Form */}
          <div className="lg:col-span-2 space-y-8">
            {/* Amount Selection */}
            <Card className="border-border/50">
              <CardHeader>
                <CardTitle>1. Betrag wählen</CardTitle>
              </CardHeader>
              <CardContent>
                <div className="grid grid-cols-3 gap-3 mb-6">
                  {presetAmounts.map((amount) => (
                    <button
                      key={amount.value}
                      className="p-4 rounded-lg border border-border/50 hover:border-primary hover:bg-primary/5 transition-colors text-center"
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
                  <p className="text-xs text-muted-foreground">Mindestbetrag CHF 25</p>
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
                      className="flex items-start gap-4 p-4 rounded-lg border border-border/50 cursor-pointer hover:border-primary/50 hover:bg-primary/5 transition-colors"
                    >
                      <RadioGroupItem value={option.id} className="mt-1" />
                      <div className="flex h-10 w-10 items-center justify-center rounded-lg bg-muted">
                        <option.icon className="h-5 w-5 text-muted-foreground" />
                      </div>
                      <div className="flex-1">
                        <div className="flex items-center justify-between">
                          <span className="font-medium">{option.name}</span>
                          {option.price > 0 ? (
                            <span className="text-sm text-muted-foreground">
                              + CHF {(option.price / 100).toFixed(2)}
                            </span>
                          ) : (
                            <Badge variant="secondary" className="text-xs">
                              Kostenlos
                            </Badge>
                          )}
                        </div>
                        <p className="text-sm text-muted-foreground">
                          {option.description}
                        </p>
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
                  <p className="text-xs text-muted-foreground">
                    Maximal 200 Zeichen
                  </p>
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
                <div className="relative aspect-[3/2] bg-gradient-to-br from-primary/10 to-primary/5 rounded-lg flex items-center justify-center">
                  <div className="text-center">
                    <Gift className="h-8 w-8 text-primary mx-auto mb-2" />
                    <p className="text-sm text-muted-foreground">
                      Vorschau
                    </p>
                  </div>
                </div>

                {/* Summary */}
                <div className="space-y-3 pt-4 border-t">
                  <div className="flex justify-between text-sm">
                    <span className="text-muted-foreground">Gutscheinwert</span>
                    <span>CHF 50.00</span>
                  </div>
                  <div className="flex justify-between text-sm">
                    <span className="text-muted-foreground">Versand</span>
                    <span className="text-primary">Kostenlos</span>
                  </div>
                  <div className="flex justify-between font-semibold text-lg pt-3 border-t">
                    <span>Gesamt</span>
                    <span className="text-primary">CHF 50.00</span>
                  </div>
                </div>

                {/* Buy Button */}
                <Button className="w-full btn-glow" size="lg">
                  <ShoppingBag className="mr-2 h-4 w-4" />
                  In den Warenkorb
                </Button>

                {/* Trust Badges */}
                <div className="text-center pt-4 border-t">
                  <p className="text-xs text-muted-foreground">
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
            <h2 className="text-xl font-bold mb-6 text-center">
              Häufige Fragen
            </h2>
            <div className="grid gap-6 md:grid-cols-2 max-w-4xl mx-auto">
              <div>
                <h3 className="font-semibold mb-2">
                  Wie lange ist der Gutschein gültig?
                </h3>
                <p className="text-sm text-muted-foreground">
                  Alle Gutscheine sind 2 Jahre ab Kaufdatum gültig.
                </p>
              </div>
              <div>
                <h3 className="font-semibold mb-2">
                  Kann ich den Gutschein auch für Produkte einlösen?
                </h3>
                <p className="text-sm text-muted-foreground">
                  Ja, der Gutschein ist für alle Leistungen und Produkte
                  einlösbar.
                </p>
              </div>
              <div>
                <h3 className="font-semibold mb-2">
                  Was passiert, wenn der Gutscheinwert nicht aufgebraucht wird?
                </h3>
                <p className="text-sm text-muted-foreground">
                  Das Restguthaben bleibt erhalten und kann beim nächsten Besuch
                  eingelöst werden.
                </p>
              </div>
              <div>
                <h3 className="font-semibold mb-2">
                  Kann ich den Gutschein auch bar auszahlen lassen?
                </h3>
                <p className="text-sm text-muted-foreground">
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
