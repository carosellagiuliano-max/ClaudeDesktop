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
        <div className="mx-auto max-w-3xl text-center">
          <p className="text-primary mb-2 text-sm font-medium tracking-wider uppercase">
            Premium Produkte
          </p>
          <h1 className="mb-6 text-4xl font-bold md:text-5xl">Shop</h1>
          <p className="text-muted-foreground text-lg">
            Entdecken Sie unsere handverlesene Auswahl an professionellen Haarpflegeprodukten –
            dieselben, die wir im Salon verwenden.
          </p>
        </div>
      </section>

      {/* Category Cards */}
      <section className="container-wide mb-16">
        <div className="grid gap-6 md:grid-cols-3">
          {productCategories.map((category) => (
            <Link key={category.slug} href={`/shop/${category.slug}`}>
              <Card
                className={`card-hover border-border/50 h-full ${
                  category.highlight ? 'bg-primary/5 border-primary/20' : ''
                }`}
              >
                <CardContent className="p-6">
                  <div className="flex items-start gap-4">
                    <div
                      className={`flex h-12 w-12 shrink-0 items-center justify-center rounded-xl ${
                        category.highlight ? 'bg-primary text-primary-foreground' : 'bg-primary/10'
                      }`}
                    >
                      <category.icon
                        className={`h-6 w-6 ${category.highlight ? '' : 'text-primary'}`}
                      />
                    </div>
                    <div>
                      <h3 className="mb-1 text-lg font-semibold">{category.name}</h3>
                      <p className="text-muted-foreground text-sm">{category.description}</p>
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
        <div className="mb-8 flex items-center justify-between">
          <div>
            <h2 className="text-2xl font-bold">Beliebte Produkte</h2>
            <p className="text-muted-foreground">Unsere meistverkauften Produkte</p>
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
            <Card key={index} className="group border-border/50 cursor-pointer overflow-hidden">
              {/* Image */}
              <div className="from-muted to-muted/50 relative aspect-square bg-gradient-to-br">
                <div className="absolute inset-0 flex items-center justify-center">
                  <ShoppingBag className="text-muted-foreground/20 h-12 w-12" />
                </div>

                {/* Badge */}
                {product.badge && (
                  <div className="absolute top-3 left-3">
                    <Badge variant={product.badge === 'Sale' ? 'destructive' : 'secondary'}>
                      {product.badge}
                    </Badge>
                  </div>
                )}

                {/* Quick Add overlay */}
                <div className="bg-charcoal/60 absolute inset-0 flex items-center justify-center opacity-0 transition-opacity duration-300 group-hover:opacity-100">
                  <Button size="sm" variant="secondary">
                    <ShoppingBag className="mr-2 h-4 w-4" />
                    In den Warenkorb
                  </Button>
                </div>
              </div>

              {/* Content */}
              <CardContent className="p-4">
                <p className="text-muted-foreground mb-1 text-xs tracking-wider uppercase">
                  {product.brand}
                </p>
                <h3 className="mb-2 font-semibold">{product.name}</h3>
                <div className="flex items-center gap-2">
                  <span className="text-primary text-lg font-bold">
                    {formatPrice(product.price)}
                  </span>
                  {product.originalPrice && (
                    <span className="text-muted-foreground text-sm line-through">
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
        <Card className="from-primary/10 to-primary/5 border-primary/20 overflow-hidden bg-gradient-to-br">
          <CardContent className="p-8 md:p-12">
            <div className="grid items-center gap-8 md:grid-cols-2">
              <div>
                <Badge className="mb-4">Geschenkidee</Badge>
                <h2 className="mb-4 text-2xl font-bold md:text-3xl">Geschenkgutscheine</h2>
                <p className="text-muted-foreground mb-6">
                  Verschenken Sie Wellness für die Haare! Unsere Gutscheine sind in beliebiger Höhe
                  erhältlich und können für alle Leistungen und Produkte eingelöst werden.
                </p>
                <ul className="text-muted-foreground mb-6 space-y-2 text-sm">
                  <li className="flex items-center gap-2">
                    <Gift className="text-primary h-4 w-4" />
                    Wert frei wählbar (ab CHF 25)
                  </li>
                  <li className="flex items-center gap-2">
                    <Gift className="text-primary h-4 w-4" />
                    Digital oder als Geschenkkarte
                  </li>
                  <li className="flex items-center gap-2">
                    <Gift className="text-primary h-4 w-4" />2 Jahre gültig
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
              <div className="from-primary/20 to-primary/10 relative flex aspect-[4/3] items-center justify-center rounded-xl bg-gradient-to-br">
                <Gift className="text-primary/30 h-20 w-20" />
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
              <Package className="text-primary mx-auto mb-3 h-8 w-8" />
              <h3 className="mb-1 font-semibold">Versandkostenfrei</h3>
              <p className="text-muted-foreground text-sm">Ab CHF 50 Bestellwert</p>
            </CardContent>
          </Card>
          <Card className="border-border/50">
            <CardContent className="p-6 text-center">
              <Star className="text-primary mx-auto mb-3 h-8 w-8" />
              <h3 className="mb-1 font-semibold">Profi-Qualität</h3>
              <p className="text-muted-foreground text-sm">Dieselben Produkte wie im Salon</p>
            </CardContent>
          </Card>
          <Card className="border-border/50">
            <CardContent className="p-6 text-center">
              <ShoppingBag className="text-primary mx-auto mb-3 h-8 w-8" />
              <h3 className="mb-1 font-semibold">Click & Collect</h3>
              <p className="text-muted-foreground text-sm">Kostenlos im Salon abholen</p>
            </CardContent>
          </Card>
        </div>
      </section>
    </div>
  );
}
