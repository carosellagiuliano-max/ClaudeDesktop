import type { Metadata } from 'next';
import Image from 'next/image';
import { Camera } from 'lucide-react';
import { Card, CardContent } from '@/components/ui/card';

// ============================================
// METADATA
// ============================================

export const metadata: Metadata = {
  title: 'Galerie',
  description:
    'Entdecken Sie unsere Arbeiten in der SCHNITTWERK Galerie. Inspirierende Haarschnitte, Colorationen und Styling aus unserem Salon in St. Gallen.',
};

// ============================================
// GALLERY DATA - TODO: Fetch from database/storage
// ============================================

const galleryCategories = [
  {
    name: 'Haarschnitte',
    slug: 'haarschnitte',
    images: [
      {
        src: '/images/gallery/haircut-1.jpg',
        alt: 'Moderner Herrenhaarschnitt',
        category: 'Herren',
      },
      {
        src: '/images/gallery/haircut-2.jpg',
        alt: 'Eleganter Bob-Schnitt',
        category: 'Damen',
      },
      {
        src: '/images/gallery/haircut-3.jpg',
        alt: 'Kurzhaarschnitt mit Textur',
        category: 'Damen',
      },
      {
        src: '/images/gallery/haircut-4.jpg',
        alt: 'Klassischer Fade',
        category: 'Herren',
      },
    ],
  },
  {
    name: 'Colorationen',
    slug: 'colorationen',
    images: [
      {
        src: '/images/gallery/color-1.jpg',
        alt: 'Natürliches Balayage',
        category: 'Balayage',
      },
      {
        src: '/images/gallery/color-2.jpg',
        alt: 'Warme Honigblond-Töne',
        category: 'Blond',
      },
      {
        src: '/images/gallery/color-3.jpg',
        alt: 'Intensives Kupfer',
        category: 'Rot',
      },
      {
        src: '/images/gallery/color-4.jpg',
        alt: 'Dimensional Highlights',
        category: 'Strähnchen',
      },
    ],
  },
  {
    name: 'Styling',
    slug: 'styling',
    images: [
      {
        src: '/images/gallery/style-1.jpg',
        alt: 'Elegante Hochsteckfrisur',
        category: 'Event',
      },
      {
        src: '/images/gallery/style-2.jpg',
        alt: 'Brautfrisur mit Accessoires',
        category: 'Braut',
      },
      {
        src: '/images/gallery/style-3.jpg',
        alt: 'Glamouröse Wellen',
        category: 'Styling',
      },
      {
        src: '/images/gallery/style-4.jpg',
        alt: 'Modernes Sleek-Styling',
        category: 'Styling',
      },
    ],
  },
];

// ============================================
// PAGE COMPONENT
// ============================================

export default function GaleriePage() {
  return (
    <div className="py-12">
      {/* Page Header */}
      <section className="container-wide mb-16">
        <div className="text-center max-w-3xl mx-auto">
          <p className="text-primary text-sm font-medium uppercase tracking-wider mb-2">
            Unsere Arbeiten
          </p>
          <h1 className="text-4xl md:text-5xl font-bold mb-6">Galerie</h1>
          <p className="text-lg text-muted-foreground">
            Lassen Sie sich von unseren Kreationen inspirieren. Jedes Bild
            erzählt eine Geschichte von Stil und Handwerkskunst.
          </p>
        </div>
      </section>

      {/* Gallery Categories */}
      <section className="container-wide space-y-16">
        {galleryCategories.map((category) => (
          <div key={category.slug} id={category.slug}>
            {/* Category Header */}
            <div className="mb-8">
              <h2 className="text-2xl font-bold mb-2">{category.name}</h2>
            </div>

            {/* Images Grid */}
            <div className="grid gap-4 sm:grid-cols-2 lg:grid-cols-4">
              {category.images.map((image, index) => (
                <Card
                  key={index}
                  className="group overflow-hidden border-border/50 cursor-pointer"
                >
                  <CardContent className="p-0 relative aspect-[3/4]">
                    {/* Placeholder - TODO: Replace with actual images */}
                    <div className="absolute inset-0 bg-gradient-to-br from-muted to-muted/50 flex items-center justify-center">
                      <Camera className="h-12 w-12 text-muted-foreground/30" />
                    </div>

                    {/* Overlay on hover */}
                    <div className="absolute inset-0 bg-charcoal/60 opacity-0 group-hover:opacity-100 transition-opacity duration-300 flex items-end p-4">
                      <div className="text-white">
                        <p className="text-xs uppercase tracking-wider text-primary mb-1">
                          {image.category}
                        </p>
                        <p className="text-sm font-medium">{image.alt}</p>
                      </div>
                    </div>
                  </CardContent>
                </Card>
              ))}
            </div>
          </div>
        ))}
      </section>

      {/* Instagram CTA */}
      <section className="container-wide mt-16 text-center">
        <Card className="bg-muted/30 border-border/50">
          <CardContent className="p-8">
            <h2 className="text-2xl font-bold mb-4">
              Mehr auf Instagram
            </h2>
            <p className="text-muted-foreground mb-6 max-w-xl mx-auto">
              Folgen Sie uns auf Instagram für tägliche Inspiration und
              einen Blick hinter die Kulissen von SCHNITTWERK.
            </p>
            <a
              href="https://instagram.com/schnittwerk"
              target="_blank"
              rel="noopener noreferrer"
              className="inline-flex items-center gap-2 text-primary hover:underline font-medium"
            >
              @schnittwerk auf Instagram →
            </a>
          </CardContent>
        </Card>
      </section>
    </div>
  );
}
