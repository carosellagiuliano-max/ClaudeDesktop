import type { Metadata } from 'next';
import Link from 'next/link';
import { Clock, ArrowRight, Calendar } from 'lucide-react';
import { Button } from '@/components/ui/button';
import { Card, CardContent } from '@/components/ui/card';
import { Badge } from '@/components/ui/badge';
import { getServicesWithCategories, getAddonServices } from '@/lib/actions';

// ============================================
// METADATA
// ============================================

export const metadata: Metadata = {
  title: 'Leistungen & Preise',
  description:
    'Entdecken Sie unser umfangreiches Angebot an Friseurleistungen: Haarschnitte, Colorationen, Balayage, Styling und mehr. Transparente Preise.',
};

// ============================================
// HELPER FUNCTIONS
// ============================================

function formatPrice(cents: number, priceFrom: boolean = false): string {
  const price = `CHF ${(cents / 100).toFixed(0)}`;
  return priceFrom ? `ab ${price}` : price;
}

function formatDuration(minutes: number): string {
  if (minutes < 60) {
    return `${minutes} Min.`;
  }
  const hours = Math.floor(minutes / 60);
  const remainingMinutes = minutes % 60;
  if (remainingMinutes === 0) {
    return `${hours} Std.`;
  }
  return `${hours} Std. ${remainingMinutes} Min.`;
}

// ============================================
// PAGE COMPONENT
// ============================================

export default async function LeistungenPage() {
  // Fetch services from database
  const [categories, addons] = await Promise.all([getServicesWithCategories(), getAddonServices()]);

  return (
    <div className="py-12">
      {/* Page Header */}
      <section className="container-wide mb-16">
        <div className="mx-auto max-w-3xl text-center">
          <p className="text-primary mb-2 text-sm font-medium tracking-wider uppercase">
            Unser Angebot
          </p>
          <h1 className="mb-6 text-4xl font-bold md:text-5xl">Leistungen & Preise</h1>
          <p className="text-muted-foreground text-lg">
            Von klassischen Haarschnitten bis zu modernen Farbtechniken – entdecken Sie unser
            umfangreiches Angebot. Alle Preise verstehen sich inklusive Beratung.
          </p>
        </div>
      </section>

      {/* Service Categories */}
      <section className="container-wide space-y-16">
        {categories.map((category) => (
          <div key={category.slug} id={category.slug}>
            {/* Category Header */}
            <div className="mb-8">
              <h2 className="mb-2 text-2xl font-bold">{category.name}</h2>
              {category.description && (
                <p className="text-muted-foreground">{category.description}</p>
              )}
            </div>

            {/* Services Grid */}
            <div className="grid gap-4 md:grid-cols-2">
              {category.services.map((service) => (
                <Card key={service.id} className="card-hover border-border/50">
                  <CardContent className="p-6">
                    <div className="flex items-start justify-between gap-4">
                      <div className="flex-1">
                        <div className="mb-1 flex items-center gap-2">
                          <h3 className="font-semibold">{service.name}</h3>
                          {service.hasLengthVariants && (
                            <Badge variant="secondary" className="text-xs">
                              Längenvarianten
                            </Badge>
                          )}
                        </div>
                        {service.description && (
                          <p className="text-muted-foreground mb-3 text-sm">
                            {service.description}
                          </p>
                        )}
                        <div className="text-muted-foreground flex items-center gap-2 text-sm">
                          <Clock className="h-4 w-4" />
                          {service.hasLengthVariants
                            ? `${formatDuration(service.lengthVariants?.[0]?.durationMinutes || service.durationMinutes)} - ${formatDuration(service.lengthVariants?.[service.lengthVariants.length - 1]?.durationMinutes || service.durationMinutes)}`
                            : formatDuration(service.durationMinutes)}
                        </div>

                        {/* Length Variants */}
                        {service.hasLengthVariants &&
                          service.lengthVariants &&
                          service.lengthVariants.length > 0 && (
                            <div className="border-border/50 mt-3 border-t pt-3">
                              <div className="space-y-1">
                                {service.lengthVariants.map((variant) => (
                                  <div key={variant.id} className="flex justify-between text-sm">
                                    <span className="text-muted-foreground">{variant.name}</span>
                                    <span className="font-medium">
                                      {formatPrice(variant.priceCents)}
                                    </span>
                                  </div>
                                ))}
                              </div>
                            </div>
                          )}
                      </div>
                      {!service.hasLengthVariants && (
                        <div className="text-right">
                          <p className="text-primary text-xl font-bold">
                            {formatPrice(service.priceCents, service.priceFrom)}
                          </p>
                        </div>
                      )}
                    </div>
                  </CardContent>
                </Card>
              ))}
            </div>
          </div>
        ))}

        {/* Addon Services */}
        {addons.length > 0 && (
          <div id="zusatzleistungen">
            <div className="mb-8">
              <h2 className="mb-2 text-2xl font-bold">Zusatzleistungen</h2>
              <p className="text-muted-foreground">Ergänzen Sie Ihren Termin mit diesen Extras</p>
            </div>

            <div className="grid gap-4 md:grid-cols-2 lg:grid-cols-3">
              {addons.map((addon) => (
                <Card key={addon.id} className="card-hover border-border/50">
                  <CardContent className="p-6">
                    <div className="flex items-start justify-between gap-4">
                      <div className="flex-1">
                        <h3 className="mb-1 font-semibold">{addon.name}</h3>
                        {addon.description && (
                          <p className="text-muted-foreground mb-2 text-sm">{addon.description}</p>
                        )}
                        <div className="text-muted-foreground flex items-center gap-2 text-sm">
                          <Clock className="h-4 w-4" />+{formatDuration(addon.durationMinutes)}
                        </div>
                      </div>
                      <div className="text-right">
                        <p className="text-primary text-lg font-bold">
                          +{formatPrice(addon.priceCents)}
                        </p>
                      </div>
                    </div>
                  </CardContent>
                </Card>
              ))}
            </div>
          </div>
        )}
      </section>

      {/* Additional Info */}
      <section className="container-wide mt-16">
        <Card className="bg-muted/30 border-border/50">
          <CardContent className="p-8">
            <div className="grid gap-8 md:grid-cols-2">
              <div>
                <h3 className="mb-3 font-semibold">Hinweise</h3>
                <ul className="text-muted-foreground space-y-2 text-sm">
                  <li>• Alle Preise in CHF inkl. MwSt.</li>
                  <li>• Aufpreise für Überlänge möglich</li>
                  <li>• Terminabsagen bitte 24h im Voraus</li>
                  <li>• Bezahlung bar, Karte oder TWINT</li>
                </ul>
              </div>
              <div>
                <h3 className="mb-3 font-semibold">Geschenkgutscheine</h3>
                <p className="text-muted-foreground mb-4 text-sm">
                  Verschenken Sie Wellness für die Haare! Unsere Gutscheine sind in beliebiger Höhe
                  erhältlich.
                </p>
                <Button variant="outline" size="sm" asChild>
                  <Link href="/shop/gutscheine">
                    Gutschein kaufen
                    <ArrowRight className="ml-2 h-4 w-4" />
                  </Link>
                </Button>
              </div>
            </div>
          </CardContent>
        </Card>
      </section>

      {/* CTA */}
      <section className="container-wide mt-16 text-center">
        <h2 className="mb-4 text-2xl font-bold">Gefunden was Sie suchen?</h2>
        <p className="text-muted-foreground mx-auto mb-8 max-w-xl">
          Buchen Sie jetzt Ihren Wunschtermin online – schnell und unkompliziert.
        </p>
        <Button size="lg" className="btn-glow" asChild>
          <Link href="/termin-buchen">
            <Calendar className="mr-2 h-5 w-5" />
            Termin buchen
          </Link>
        </Button>
      </section>
    </div>
  );
}
