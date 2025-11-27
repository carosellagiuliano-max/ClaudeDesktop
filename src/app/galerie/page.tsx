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
        <div className="mx-auto max-w-3xl text-center">
          <p className="text-primary mb-2 text-sm font-medium tracking-wider uppercase">
            Unsere Arbeiten
          </p>
          <h1 className="mb-6 text-4xl font-bold md:text-5xl">Galerie</h1>
          <p className="text-muted-foreground text-lg">
            Lassen Sie sich von unseren Kreationen inspirieren. Jedes Bild erzählt eine Geschichte
            von Stil und Handwerkskunst.
          </p>
        </div>
      </section>

      {/* Gallery Categories */}
      <section className="container-wide space-y-16">
        {galleryCategories.map((category) => (
          <div key={category.slug} id={category.slug}>
            {/* Category Header */}
            <div className="mb-8">
              <h2 className="mb-2 text-2xl font-bold">{category.name}</h2>
            </div>

            {/* Images Grid */}
            <div className="grid gap-4 sm:grid-cols-2 lg:grid-cols-4">
              {category.images.map((image, index) => (
                <Card key={index} className="group border-border/50 cursor-pointer overflow-hidden">
                  <CardContent className="relative aspect-[3/4] p-0">
                    {/* Placeholder - TODO: Replace with actual images */}
                    <div className="from-muted to-muted/50 absolute inset-0 flex items-center justify-center bg-gradient-to-br">
                      <Camera className="text-muted-foreground/30 h-12 w-12" />
                    </div>

                    {/* Overlay on hover */}
                    <div className="bg-charcoal/60 absolute inset-0 flex items-end p-4 opacity-0 transition-opacity duration-300 group-hover:opacity-100">
                      <div className="text-white">
                        <p className="text-primary mb-1 text-xs tracking-wider uppercase">
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
            <h2 className="mb-4 text-2xl font-bold">Mehr auf Instagram</h2>
            <p className="text-muted-foreground mx-auto mb-6 max-w-xl">
              Folgen Sie uns auf Instagram für tägliche Inspiration und einen Blick hinter die
              Kulissen von SCHNITTWERK.
            </p>
            <a
              href="https://instagram.com/schnittwerk"
              target="_blank"
              rel="noopener noreferrer"
              className="text-primary inline-flex items-center gap-2 font-medium hover:underline"
            >
              @schnittwerk auf Instagram →
            </a>
          </CardContent>
        </Card>
      </section>
    </div>
  );
}
