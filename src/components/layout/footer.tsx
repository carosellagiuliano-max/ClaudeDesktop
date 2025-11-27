import Link from 'next/link';
import { MapPin, Phone, Mail, Clock, Instagram, Facebook } from 'lucide-react';
import { Button } from '@/components/ui/button';
import { Separator } from '@/components/ui/separator';

// ============================================
// SALON INFO - TODO: Fetch from database
// ============================================

const salonInfo = {
  name: 'SCHNITTWERK',
  tagline: 'Your Style. Your Statement.',
  address: {
    street: 'Musterstrasse 123',
    city: '9000 St. Gallen',
    country: 'Schweiz',
  },
  phone: '+41 71 123 45 67',
  email: 'info@schnittwerk.ch',
  social: {
    instagram: 'https://instagram.com/schnittwerk',
    facebook: 'https://facebook.com/schnittwerk',
  },
};

const openingHours = [
  { day: 'Montag', hours: 'Geschlossen' },
  { day: 'Dienstag', hours: '09:00 - 18:00' },
  { day: 'Mittwoch', hours: '09:00 - 18:00' },
  { day: 'Donnerstag', hours: '09:00 - 20:00' },
  { day: 'Freitag', hours: '09:00 - 18:00' },
  { day: 'Samstag', hours: '09:00 - 16:00' },
  { day: 'Sonntag', hours: 'Geschlossen' },
];

const quickLinks = [
  { label: 'Leistungen', href: '/leistungen' },
  { label: 'Online Termin', href: '/termin-buchen' },
  { label: 'Shop', href: '/shop' },
  { label: 'Gutscheine', href: '/shop/gutscheine' },
  { label: 'Kontakt', href: '/kontakt' },
];

const legalLinks = [
  { label: 'Impressum', href: '/impressum' },
  { label: 'Datenschutz', href: '/datenschutz' },
  { label: 'AGB', href: '/agb' },
];

// ============================================
// FOOTER COMPONENT
// ============================================

export function Footer() {
  const currentYear = new Date().getFullYear();

  return (
    <footer className="bg-card border-t">
      {/* Main Footer Content */}
      <div className="container-wide section-padding">
        <div className="grid gap-12 md:grid-cols-2 lg:grid-cols-4">
          {/* Brand & Description */}
          <div className="lg:col-span-1">
            <Link href="/" className="inline-block">
              <h2 className="text-gradient-gold text-2xl font-bold">{salonInfo.name}</h2>
            </Link>
            <p className="text-muted-foreground mt-2 text-sm italic">{salonInfo.tagline}</p>
            <p className="text-muted-foreground mt-4 text-sm leading-relaxed">
              Ihr Premium-Friseursalon in St. Gallen. Wir kreieren individuelle Looks mit
              Leidenschaft und Expertise.
            </p>

            {/* Social Links */}
            <div className="mt-6 flex gap-2">
              <Button
                variant="outline"
                size="icon"
                asChild
                className="hover:bg-primary hover:text-primary-foreground hover:border-primary"
              >
                <a
                  href={salonInfo.social.instagram}
                  target="_blank"
                  rel="noopener noreferrer"
                  aria-label="Instagram"
                >
                  <Instagram className="h-4 w-4" />
                </a>
              </Button>
              <Button
                variant="outline"
                size="icon"
                asChild
                className="hover:bg-primary hover:text-primary-foreground hover:border-primary"
              >
                <a
                  href={salonInfo.social.facebook}
                  target="_blank"
                  rel="noopener noreferrer"
                  aria-label="Facebook"
                >
                  <Facebook className="h-4 w-4" />
                </a>
              </Button>
            </div>
          </div>

          {/* Contact Info */}
          <div>
            <h3 className="text-foreground text-sm font-semibold tracking-wider uppercase">
              Kontakt
            </h3>
            <ul className="mt-4 space-y-4">
              <li>
                <a
                  href={`https://maps.google.com/?q=${encodeURIComponent(
                    `${salonInfo.address.street}, ${salonInfo.address.city}`
                  )}`}
                  target="_blank"
                  rel="noopener noreferrer"
                  className="text-muted-foreground hover:text-foreground flex items-start gap-3 text-sm transition-colors"
                >
                  <MapPin className="text-primary mt-0.5 h-4 w-4 shrink-0" />
                  <span>
                    {salonInfo.address.street}
                    <br />
                    {salonInfo.address.city}
                  </span>
                </a>
              </li>
              <li>
                <a
                  href={`tel:${salonInfo.phone.replace(/\s/g, '')}`}
                  className="text-muted-foreground hover:text-foreground flex items-center gap-3 text-sm transition-colors"
                >
                  <Phone className="text-primary h-4 w-4 shrink-0" />
                  {salonInfo.phone}
                </a>
              </li>
              <li>
                <a
                  href={`mailto:${salonInfo.email}`}
                  className="text-muted-foreground hover:text-foreground flex items-center gap-3 text-sm transition-colors"
                >
                  <Mail className="text-primary h-4 w-4 shrink-0" />
                  {salonInfo.email}
                </a>
              </li>
            </ul>
          </div>

          {/* Opening Hours */}
          <div>
            <h3 className="text-foreground text-sm font-semibold tracking-wider uppercase">
              Öffnungszeiten
            </h3>
            <ul className="mt-4 space-y-2">
              {openingHours.map((item) => (
                <li key={item.day} className="text-muted-foreground flex justify-between text-sm">
                  <span>{item.day}</span>
                  <span className={item.hours === 'Geschlossen' ? 'text-muted-foreground/60' : ''}>
                    {item.hours}
                  </span>
                </li>
              ))}
            </ul>
          </div>

          {/* Quick Links */}
          <div>
            <h3 className="text-foreground text-sm font-semibold tracking-wider uppercase">
              Quick Links
            </h3>
            <ul className="mt-4 space-y-2">
              {quickLinks.map((link) => (
                <li key={link.href}>
                  <Link
                    href={link.href}
                    className="text-muted-foreground hover:text-primary text-sm transition-colors"
                  >
                    {link.label}
                  </Link>
                </li>
              ))}
            </ul>

            {/* CTA Button */}
            <Button className="mt-6 w-full" asChild>
              <Link href="/termin-buchen">Jetzt Termin buchen</Link>
            </Button>
          </div>
        </div>
      </div>

      {/* Bottom Bar */}
      <div className="bg-muted/30 border-t">
        <div className="container-wide py-6">
          <div className="flex flex-col items-center justify-between gap-4 md:flex-row">
            {/* Copyright */}
            <p className="text-muted-foreground text-xs">
              © {currentYear} {salonInfo.name}. Alle Rechte vorbehalten.
            </p>

            {/* Legal Links */}
            <nav className="flex flex-wrap justify-center gap-4 md:gap-6">
              {legalLinks.map((link) => (
                <Link
                  key={link.href}
                  href={link.href}
                  className="text-muted-foreground hover:text-foreground text-xs transition-colors"
                >
                  {link.label}
                </Link>
              ))}
            </nav>
          </div>
        </div>
      </div>
    </footer>
  );
}
