import type { Metadata } from 'next';
import Link from 'next/link';
import { MapPin, Phone, Mail, Clock, Instagram, Facebook, Calendar } from 'lucide-react';
import { Button } from '@/components/ui/button';
import { Card, CardContent, CardHeader, CardTitle } from '@/components/ui/card';
import { getSalon, getOpeningHours } from '@/lib/actions';
import { ContactForm } from '@/components/forms/contact-form';

// ============================================
// METADATA
// ============================================

export const metadata: Metadata = {
  title: 'Kontakt',
  description:
    'Kontaktieren Sie SCHNITTWERK in St. Gallen. Adresse, Öffnungszeiten, Telefon und Kontaktformular. Wir freuen uns auf Ihre Nachricht.',
};

// ============================================
// HELPER FUNCTIONS
// ============================================

function formatOpeningTime(time: string | null): string {
  if (!time) return '';
  // Convert "08:30:00" or "08:30" to "08:30"
  return time.substring(0, 5);
}

// ============================================
// PAGE COMPONENT
// ============================================

export default async function KontaktPage() {
  const [salon, openingHours] = await Promise.all([getSalon(), getOpeningHours()]);

  const googleMapsUrl = salon
    ? `https://maps.google.com/?q=${encodeURIComponent(
        `${salon.address}, ${salon.zipCode} ${salon.city}`
      )}`
    : '#';

  return (
    <div className="py-12">
      {/* Page Header */}
      <section className="container-wide mb-16">
        <div className="mx-auto max-w-3xl text-center">
          <p className="text-primary mb-2 text-sm font-medium tracking-wider uppercase">
            Wir sind für Sie da
          </p>
          <h1 className="mb-6 text-4xl font-bold md:text-5xl">Kontakt</h1>
          <p className="text-muted-foreground text-lg">
            Haben Sie Fragen oder möchten Sie einen Termin vereinbaren? Wir freuen uns, von Ihnen zu
            hören.
          </p>
        </div>
      </section>

      {/* Contact Content */}
      <section className="container-wide">
        <div className="grid gap-8 lg:grid-cols-3">
          {/* Contact Info */}
          <div className="space-y-6">
            {/* Address Card */}
            <Card className="border-border/50">
              <CardContent className="p-6">
                <div className="flex items-start gap-4">
                  <div className="bg-primary/10 flex h-10 w-10 shrink-0 items-center justify-center rounded-lg">
                    <MapPin className="text-primary h-5 w-5" />
                  </div>
                  <div>
                    <h3 className="mb-1 font-semibold">Adresse</h3>
                    <p className="text-muted-foreground text-sm">
                      {salon?.address}
                      <br />
                      {salon?.zipCode} {salon?.city}
                    </p>
                    <a
                      href={googleMapsUrl}
                      target="_blank"
                      rel="noopener noreferrer"
                      className="text-primary mt-2 inline-block text-sm hover:underline"
                    >
                      Route anzeigen →
                    </a>
                  </div>
                </div>
              </CardContent>
            </Card>

            {/* Phone Card */}
            <Card className="border-border/50">
              <CardContent className="p-6">
                <div className="flex items-start gap-4">
                  <div className="bg-primary/10 flex h-10 w-10 shrink-0 items-center justify-center rounded-lg">
                    <Phone className="text-primary h-5 w-5" />
                  </div>
                  <div>
                    <h3 className="mb-1 font-semibold">Telefon</h3>
                    {salon?.phone && (
                      <a
                        href={`tel:${salon.phone.replace(/\s/g, '')}`}
                        className="text-muted-foreground hover:text-foreground text-sm transition-colors"
                      >
                        {salon.phone}
                      </a>
                    )}
                  </div>
                </div>
              </CardContent>
            </Card>

            {/* Email Card */}
            <Card className="border-border/50">
              <CardContent className="p-6">
                <div className="flex items-start gap-4">
                  <div className="bg-primary/10 flex h-10 w-10 shrink-0 items-center justify-center rounded-lg">
                    <Mail className="text-primary h-5 w-5" />
                  </div>
                  <div>
                    <h3 className="mb-1 font-semibold">E-Mail</h3>
                    {salon?.email && (
                      <a
                        href={`mailto:${salon.email}`}
                        className="text-muted-foreground hover:text-foreground text-sm transition-colors"
                      >
                        {salon.email}
                      </a>
                    )}
                  </div>
                </div>
              </CardContent>
            </Card>

            {/* Social Media */}
            <Card className="border-border/50">
              <CardContent className="p-6">
                <h3 className="mb-3 font-semibold">Social Media</h3>
                <div className="flex gap-2">
                  <Button variant="outline" size="icon" asChild>
                    <a
                      href="https://instagram.com/schnittwerk.sg"
                      target="_blank"
                      rel="noopener noreferrer"
                      aria-label="Instagram"
                    >
                      <Instagram className="h-4 w-4" />
                    </a>
                  </Button>
                  <Button variant="outline" size="icon" asChild>
                    <a
                      href="https://facebook.com/schnittwerk"
                      target="_blank"
                      rel="noopener noreferrer"
                      aria-label="Facebook"
                    >
                      <Facebook className="h-4 w-4" />
                    </a>
                  </Button>
                </div>
              </CardContent>
            </Card>
          </div>

          {/* Contact Form */}
          <Card className="border-border/50 lg:col-span-2">
            <CardHeader>
              <CardTitle>Nachricht senden</CardTitle>
            </CardHeader>
            <CardContent>
              <ContactForm />
            </CardContent>
          </Card>
        </div>
      </section>

      {/* Opening Hours Section */}
      <section id="oeffnungszeiten" className="container-wide mt-16">
        <Card className="border-border/50">
          <CardContent className="p-8">
            <div className="grid gap-8 md:grid-cols-2">
              {/* Hours */}
              <div>
                <div className="mb-6 flex items-center gap-3">
                  <div className="bg-primary/10 flex h-10 w-10 items-center justify-center rounded-lg">
                    <Clock className="text-primary h-5 w-5" />
                  </div>
                  <h2 className="text-xl font-bold">Öffnungszeiten</h2>
                </div>
                <ul className="space-y-3">
                  {openingHours.map((item) => (
                    <li
                      key={item.dayOfWeek}
                      className="border-border/50 flex justify-between border-b py-2 last:border-0"
                    >
                      <span className="font-medium">{item.dayName}</span>
                      <span
                        className={
                          !item.isOpen ? 'text-muted-foreground/60' : 'text-muted-foreground'
                        }
                      >
                        {item.isOpen
                          ? `${formatOpeningTime(item.openTime)} - ${formatOpeningTime(item.closeTime)}`
                          : 'Geschlossen'}
                      </span>
                    </li>
                  ))}
                </ul>
              </div>

              {/* Map Placeholder */}
              <div className="bg-muted relative aspect-video min-h-[300px] overflow-hidden rounded-xl md:aspect-auto">
                <iframe
                  src={`https://www.google.com/maps/embed/v1/place?key=AIzaSyBFw0Qbyq9zTFTd-tUY6dZWTgaQzuU17R8&q=${encodeURIComponent(
                    salon ? `${salon.address}, ${salon.zipCode} ${salon.city}` : 'St. Gallen'
                  )}`}
                  width="100%"
                  height="100%"
                  style={{ border: 0, minHeight: '300px' }}
                  allowFullScreen
                  loading="lazy"
                  referrerPolicy="no-referrer-when-downgrade"
                  className="absolute inset-0"
                />
              </div>
            </div>
          </CardContent>
        </Card>
      </section>

      {/* CTA */}
      <section className="container-wide mt-16 text-center">
        <h2 className="mb-4 text-2xl font-bold">Lieber direkt buchen?</h2>
        <p className="text-muted-foreground mx-auto mb-8 max-w-xl">
          Sparen Sie sich das Warten – buchen Sie Ihren Wunschtermin bequem online.
        </p>
        <Button size="lg" className="btn-glow" asChild>
          <Link href="/termin-buchen">
            <Calendar className="mr-2 h-5 w-5" />
            Online Termin buchen
          </Link>
        </Button>
      </section>
    </div>
  );
}
