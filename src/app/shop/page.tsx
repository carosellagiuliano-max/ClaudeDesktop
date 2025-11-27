import type { Metadata } from 'next';
import Link from 'next/link';
import { ShoppingBag, Gift, Star, ArrowRight, Package } from 'lucide-react';
import { Button } from '@/components/ui/button';
import { Card, CardContent } from '@/components/ui/card';
import { Badge } from '@/components/ui/badge';

// ============================================
// METADATA
// ============================================

export const metadata: Metadata = {
  title: 'Shop',
  description:
    'Entdecken Sie professionelle Haarpflegeprodukte und Geschenkgutscheine im SCHNITTWERK Online-Shop. Premium-Qualität für Ihr Haar.',
};

// ============================================
// PRODUCT DATA - TODO: Fetch from database
// ============================================

const productCategories = [
  {
    name: 'Haarpflege',
    slug: 'haarpflege',
    description: 'Professionelle Pflege für gesundes, glänzendes Haar',
    icon: Package,
  },
  {
    name: 'Styling',
    slug: 'styling',
    description: 'Perfekte Produkte für jeden Look',
    icon: Star,
  },
  {
    name: 'Geschenkgutscheine',
    slug: 'gutscheine',
    description: 'Das perfekte Geschenk für jeden Anlass',
    icon: Gift,
    highlight: true,
  },
];

const featuredProducts = [
  {
    name: 'Repair Shampoo',
    brand: 'Olaplex',
    price: 3200,
    originalPrice: null,
    image: '/images/products/shampoo.jpg',
    category: 'Haarpflege',
    badge: 'Bestseller',
  },
  {
    name: 'Styling Cream',
    brand: 'Kevin Murphy',
    price: 3800,
    originalPrice: null,
    image: '/images/products/cream.jpg',
    category: 'Styling',
    badge: null,
  },
  {
    name: 'Heat Protect Spray',
    brand: 'ghd',
    price: 2500,
    originalPrice: 2900,
    image: '/images/products/spray.jpg',
    category: 'Styling',
    badge: 'Sale',
  },
  {
    name: 'Hair Oil',
    brand: 'Moroccanoil',
    price: 4500,
    originalPrice: null,
    image: '/images/products/oil.jpg',
    category: 'Haarpflege',
    badge: 'Neu',
  },
];

// ============================================
// HELPER FUNCTIONS
// ============================================

function formatPrice(cents: number): string {
  return `CHF ${(cents / 100).toFixed(2)}`;
}

// ============================================
// PAGE COMPONENT
// ============================================

export default function ShopPage() {
  return (
    <div className="py-12">
      {/* Page Header */}
      <section className="container-wide mb-16">
        <div className="text-center max-w-3xl mx-auto">
          <p className="text-primary text-sm font-medium uppercase tracking-wider mb-2">
            Premium Produkte
          </p>
          <h1 className="text-4xl md:text-5xl font-bold mb-6">Shop</h1>
          <p className="text-lg text-muted-foreground">
            Entdecken Sie unsere handverlesene Auswahl an professionellen
            Haarpflegeprodukten – dieselben, die wir im Salon verwenden.
          </p>
        </div>
      </section>

      {/* Category Cards */}
      <section className="container-wide mb-16">
        <div className="grid gap-6 md:grid-cols-3">
          {productCategories.map((category) => (
            <Link key={category.slug} href={`/shop/${category.slug}`}>
              <Card
                className={`h-full card-hover border-border/50 ${
                  category.highlight ? 'bg-primary/5 border-primary/20' : ''
                }`}
              >
                <CardContent className="p-6">
                  <div className="flex items-start gap-4">
                    <div
                      className={`flex h-12 w-12 shrink-0 items-center justify-center rounded-xl ${
                        category.highlight
                          ? 'bg-primary text-primary-foreground'
                          : 'bg-primary/10'
                      }`}
                    >
                      <category.icon
                        className={`h-6 w-6 ${
                          category.highlight ? '' : 'text-primary'
                        }`}
                      />
                    </div>
                    <div>
                      <h3 className="font-semibold text-lg mb-1">
                        {category.name}
                      </h3>
                      <p className="text-sm text-muted-foreground">
                        {category.description}
                      </p>
                    </div>
                  </div>
                </CardContent>
              </Card>
            </Link>
          ))}
        </div>
      </section>

      {/* Featured Products */}
      <section className="container-wide mb-16">
        <div className="flex items-center justify-between mb-8">
          <div>
            <h2 className="text-2xl font-bold">Beliebte Produkte</h2>
            <p className="text-muted-foreground">
              Unsere meistverkauften Produkte
            </p>
          </div>
          <Button variant="ghost" asChild>
            <Link href="/shop/alle">
              Alle Produkte
              <ArrowRight className="ml-2 h-4 w-4" />
            </Link>
          </Button>
        </div>

        <div className="grid gap-6 sm:grid-cols-2 lg:grid-cols-4">
          {featuredProducts.map((product, index) => (
            <Card
              key={index}
              className="group overflow-hidden border-border/50 cursor-pointer"
            >
              {/* Image */}
              <div className="relative aspect-square bg-gradient-to-br from-muted to-muted/50">
                <div className="absolute inset-0 flex items-center justify-center">
                  <ShoppingBag className="h-12 w-12 text-muted-foreground/20" />
                </div>

                {/* Badge */}
                {product.badge && (
                  <div className="absolute top-3 left-3">
                    <Badge
                      variant={
                        product.badge === 'Sale' ? 'destructive' : 'secondary'
                      }
                    >
                      {product.badge}
                    </Badge>
                  </div>
                )}

                {/* Quick Add overlay */}
                <div className="absolute inset-0 bg-charcoal/60 opacity-0 group-hover:opacity-100 transition-opacity duration-300 flex items-center justify-center">
                  <Button size="sm" variant="secondary">
                    <ShoppingBag className="mr-2 h-4 w-4" />
                    In den Warenkorb
                  </Button>
                </div>
              </div>

              {/* Content */}
              <CardContent className="p-4">
                <p className="text-xs text-muted-foreground uppercase tracking-wider mb-1">
                  {product.brand}
                </p>
                <h3 className="font-semibold mb-2">{product.name}</h3>
                <div className="flex items-center gap-2">
                  <span className="text-lg font-bold text-primary">
                    {formatPrice(product.price)}
                  </span>
                  {product.originalPrice && (
                    <span className="text-sm text-muted-foreground line-through">
                      {formatPrice(product.originalPrice)}
                    </span>
                  )}
                </div>
              </CardContent>
            </Card>
          ))}
        </div>
      </section>

      {/* Gift Voucher CTA */}
      <section className="container-wide">
        <Card className="bg-gradient-to-br from-primary/10 to-primary/5 border-primary/20 overflow-hidden">
          <CardContent className="p-8 md:p-12">
            <div className="grid gap-8 md:grid-cols-2 items-center">
              <div>
                <Badge className="mb-4">Geschenkidee</Badge>
                <h2 className="text-2xl md:text-3xl font-bold mb-4">
                  Geschenkgutscheine
                </h2>
                <p className="text-muted-foreground mb-6">
                  Verschenken Sie Wellness für die Haare! Unsere Gutscheine sind
                  in beliebiger Höhe erhältlich und können für alle Leistungen
                  und Produkte eingelöst werden.
                </p>
                <ul className="space-y-2 text-sm text-muted-foreground mb-6">
                  <li className="flex items-center gap-2">
                    <Gift className="h-4 w-4 text-primary" />
                    Wert frei wählbar (ab CHF 25)
                  </li>
                  <li className="flex items-center gap-2">
                    <Gift className="h-4 w-4 text-primary" />
                    Digital oder als Geschenkkarte
                  </li>
                  <li className="flex items-center gap-2">
                    <Gift className="h-4 w-4 text-primary" />
                    2 Jahre gültig
                  </li>
                </ul>
                <Button asChild>
                  <Link href="/shop/gutscheine">
                    <Gift className="mr-2 h-4 w-4" />
                    Gutschein kaufen
                  </Link>
                </Button>
              </div>

              {/* Image Placeholder */}
              <div className="relative aspect-[4/3] bg-gradient-to-br from-primary/20 to-primary/10 rounded-xl flex items-center justify-center">
                <Gift className="h-20 w-20 text-primary/30" />
              </div>
            </div>
          </CardContent>
        </Card>
      </section>

      {/* Info Section */}
      <section className="container-wide mt-16">
        <div className="grid gap-6 md:grid-cols-3">
          <Card className="border-border/50">
            <CardContent className="p-6 text-center">
              <Package className="h-8 w-8 text-primary mx-auto mb-3" />
              <h3 className="font-semibold mb-1">Versandkostenfrei</h3>
              <p className="text-sm text-muted-foreground">
                Ab CHF 50 Bestellwert
              </p>
            </CardContent>
          </Card>
          <Card className="border-border/50">
            <CardContent className="p-6 text-center">
              <Star className="h-8 w-8 text-primary mx-auto mb-3" />
              <h3 className="font-semibold mb-1">Profi-Qualität</h3>
              <p className="text-sm text-muted-foreground">
                Dieselben Produkte wie im Salon
              </p>
            </CardContent>
          </Card>
          <Card className="border-border/50">
            <CardContent className="p-6 text-center">
              <ShoppingBag className="h-8 w-8 text-primary mx-auto mb-3" />
              <h3 className="font-semibold mb-1">Click & Collect</h3>
              <p className="text-sm text-muted-foreground">
                Kostenlos im Salon abholen
              </p>
            </CardContent>
          </Card>
        </div>
      </section>
    </div>
  );
}
