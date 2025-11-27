import Link from 'next/link';
import { MapPin, Clock, Sparkles, ArrowRight, Star, Calendar } from 'lucide-react';
import { Button } from '@/components/ui/button';
import { Card, CardContent } from '@/components/ui/card';

// ============================================
// HOMEPAGE
// ============================================

export default function HomePage() {
  return (
    <>
      {/* Hero Section */}
      <HeroSection />

      {/* Info Cards */}
      <InfoCardsSection />

      {/* Services Preview */}
      <ServicesPreviewSection />

      {/* Reviews Section */}
      <ReviewsSection />

      {/* CTA Section */}
      <CTASection />
    </>
  );
}

// ============================================
// HERO SECTION
// ============================================

function HeroSection() {
  return (
    <section className="relative flex min-h-[80vh] items-center justify-center overflow-hidden">
      {/* Background Image/Gradient */}
      <div className="from-charcoal via-charcoal/95 to-charcoal/90 absolute inset-0 bg-gradient-to-br">
        {/* TODO: Add actual hero image */}
        <div className="absolute inset-0 bg-[url('/images/hero-pattern.svg')] opacity-5" />
      </div>

      {/* Content */}
      <div className="container-wide relative py-20 text-center">
        <div className="animate-fade-in mx-auto max-w-3xl">
          {/* Tagline */}
          <p className="text-gold mb-4 text-sm font-medium tracking-widest uppercase">
            Premium Friseursalon St. Gallen
          </p>

          {/* Headline */}
          <h1 className="mb-6 text-4xl leading-tight font-bold text-white md:text-5xl lg:text-6xl">
            Your Style. <span className="text-gradient-gold">Your Statement.</span>
          </h1>

          {/* Description */}
          <p className="mx-auto mb-10 max-w-2xl text-lg leading-relaxed text-white/80 md:text-xl">
            Willkommen bei SCHNITTWERK – wo Stil auf Handwerk trifft. Erleben Sie erstklassige
            Haarkunst in entspannter Atmosphäre.
          </p>

          {/* CTA Buttons */}
          <div className="flex flex-col justify-center gap-4 sm:flex-row">
            <Button size="lg" className="btn-glow text-base" asChild>
              <Link href="/termin-buchen">
                <Calendar className="mr-2 h-5 w-5" />
                Termin buchen
              </Link>
            </Button>
            <Button
              size="lg"
              variant="outline"
              className="border-white/30 text-base text-white hover:bg-white/10"
              asChild
            >
              <Link href="/leistungen">
                Unsere Leistungen
                <ArrowRight className="ml-2 h-4 w-4" />
              </Link>
            </Button>
          </div>
        </div>
      </div>

      {/* Scroll Indicator */}
      <div className="absolute bottom-8 left-1/2 -translate-x-1/2 animate-bounce">
        <div className="flex h-10 w-6 items-start justify-center rounded-full border-2 border-white/30 p-2">
          <div className="h-2 w-1 rounded-full bg-white/50" />
        </div>
      </div>
    </section>
  );
}

// ============================================
// INFO CARDS SECTION
// ============================================

function InfoCardsSection() {
  const infoCards = [
    {
      icon: MapPin,
      title: 'Standort',
      description: 'Musterstrasse 123, 9000 St. Gallen',
      link: {
        href: 'https://maps.google.com/?q=Musterstrasse+123,+9000+St.+Gallen',
        label: 'Route anzeigen',
        external: true,
      },
    },
    {
      icon: Clock,
      title: 'Öffnungszeiten',
      description: 'Di–Fr 09:00–18:00, Sa 09:00–16:00',
      link: {
        href: '/kontakt#oeffnungszeiten',
        label: 'Alle Zeiten',
      },
    },
    {
      icon: Sparkles,
      title: 'Premium Services',
      description: 'Balayage, Colorationen, Styling',
      link: {
        href: '/leistungen',
        label: 'Mehr erfahren',
      },
    },
  ];

  return (
    <section className="section-padding bg-background">
      <div className="container-wide">
        <div className="grid gap-6 md:grid-cols-3">
          {infoCards.map((card) => (
            <Card key={card.title} className="card-hover border-border/50 bg-card">
              <CardContent className="p-6">
                <div className="flex items-start gap-4">
                  <div className="bg-primary/10 flex h-12 w-12 shrink-0 items-center justify-center rounded-xl">
                    <card.icon className="text-primary h-6 w-6" />
                  </div>
                  <div className="flex-1">
                    <h3 className="text-foreground font-semibold">{card.title}</h3>
                    <p className="text-muted-foreground mt-1 text-sm">{card.description}</p>
                    <Link
                      href={card.link.href}
                      target={card.link.external ? '_blank' : undefined}
                      rel={card.link.external ? 'noopener noreferrer' : undefined}
                      className="text-primary mt-3 inline-flex items-center text-sm font-medium hover:underline"
                    >
                      {card.link.label}
                      <ArrowRight className="ml-1 h-3 w-3" />
                    </Link>
                  </div>
                </div>
              </CardContent>
            </Card>
          ))}
        </div>
      </div>
    </section>
  );
}

// ============================================
// SERVICES PREVIEW SECTION
// ============================================

function ServicesPreviewSection() {
  const services = [
    {
      name: 'Herrenhaarschnitt',
      price: 'ab CHF 45',
      duration: '30 Min.',
    },
    {
      name: 'Damenhaarschnitt',
      price: 'ab CHF 75',
      duration: '45 Min.',
    },
    {
      name: 'Coloration',
      price: 'ab CHF 95',
      duration: '90 Min.',
    },
    {
      name: 'Balayage',
      price: 'ab CHF 180',
      duration: '150 Min.',
    },
  ];

  return (
    <section className="section-padding bg-muted/30">
      <div className="container-wide">
        {/* Section Header */}
        <div className="mb-12 text-center">
          <p className="text-primary mb-2 text-sm font-medium tracking-wider uppercase">
            Unsere Leistungen
          </p>
          <h2 className="text-foreground mb-4 text-3xl font-bold">Beliebte Services</h2>
          <p className="text-muted-foreground mx-auto max-w-2xl">
            Von klassischen Haarschnitten bis zu modernen Farbtechniken – entdecken Sie unser
            umfangreiches Angebot.
          </p>
        </div>

        {/* Services Grid */}
        <div className="mb-10 grid gap-4 sm:grid-cols-2 lg:grid-cols-4">
          {services.map((service) => (
            <Card key={service.name} className="card-hover border-border/50 bg-card">
              <CardContent className="p-6 text-center">
                <h3 className="text-foreground mb-2 font-semibold">{service.name}</h3>
                <p className="text-primary mb-1 text-2xl font-bold">{service.price}</p>
                <p className="text-muted-foreground text-sm">{service.duration}</p>
              </CardContent>
            </Card>
          ))}
        </div>

        {/* CTA */}
        <div className="text-center">
          <Button variant="outline" size="lg" asChild>
            <Link href="/leistungen">
              Alle Leistungen ansehen
              <ArrowRight className="ml-2 h-4 w-4" />
            </Link>
          </Button>
        </div>
      </div>
    </section>
  );
}

// ============================================
// REVIEWS SECTION
// ============================================

function ReviewsSection() {
  const reviews = [
    {
      name: 'Sarah M.',
      rating: 5,
      text: 'Absolut bester Friseursalon in St. Gallen! Das Team ist super freundlich und das Ergebnis immer perfekt.',
    },
    {
      name: 'Thomas K.',
      rating: 5,
      text: 'Professionelle Beratung und erstklassiges Handwerk. Hier fühlt man sich wirklich gut aufgehoben.',
    },
    {
      name: 'Nina B.',
      rating: 5,
      text: 'Meine Balayage ist fantastisch geworden! Kann SCHNITTWERK nur empfehlen.',
    },
  ];

  return (
    <section className="section-padding bg-background">
      <div className="container-wide">
        {/* Section Header */}
        <div className="mb-12 text-center">
          <p className="text-primary mb-2 text-sm font-medium tracking-wider uppercase">
            Kundenstimmen
          </p>
          <h2 className="text-foreground mb-4 text-3xl font-bold">Was unsere Kunden sagen</h2>
        </div>

        {/* Reviews Grid */}
        <div className="grid gap-6 md:grid-cols-3">
          {reviews.map((review, index) => (
            <Card key={index} className="border-border/50 bg-card">
              <CardContent className="p-6">
                {/* Stars */}
                <div className="mb-4 flex gap-1">
                  {Array.from({ length: review.rating }).map((_, i) => (
                    <Star key={i} className="fill-primary text-primary h-4 w-4" />
                  ))}
                </div>

                {/* Review Text */}
                <p className="text-foreground/80 mb-4 italic">&ldquo;{review.text}&rdquo;</p>

                {/* Author */}
                <p className="text-foreground text-sm font-medium">{review.name}</p>
              </CardContent>
            </Card>
          ))}
        </div>

        {/* Google Reviews Link */}
        <div className="mt-8 text-center">
          <Link
            href="https://g.page/schnittwerk-stgallen/review"
            target="_blank"
            rel="noopener noreferrer"
            className="text-muted-foreground hover:text-foreground text-sm transition-colors"
          >
            Mehr Bewertungen auf Google →
          </Link>
        </div>
      </div>
    </section>
  );
}

// ============================================
// CTA SECTION
// ============================================

function CTASection() {
  return (
    <section className="bg-charcoal py-20 text-white">
      <div className="container-wide text-center">
        <h2 className="mb-4 text-3xl font-bold md:text-4xl">Bereit für Ihren neuen Look?</h2>
        <p className="mx-auto mb-8 max-w-xl text-white/70">
          Buchen Sie jetzt Ihren Termin online – schnell, einfach und bequem. Wir freuen uns auf
          Sie!
        </p>
        <Button size="lg" className="btn-glow" asChild>
          <Link href="/termin-buchen">
            <Calendar className="mr-2 h-5 w-5" />
            Jetzt Termin buchen
          </Link>
        </Button>
      </div>
    </section>
  );
}
