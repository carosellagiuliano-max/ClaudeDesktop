'use client';

import { useState, useEffect } from 'react';
import Link from 'next/link';
import { usePathname } from 'next/navigation';
import {
  Menu,
  X,
  Phone,
  Instagram,
  ShoppingBag,
  User,
  Calendar,
} from 'lucide-react';
import { Button } from '@/components/ui/button';
import { Sheet, SheetContent, SheetTrigger } from '@/components/ui/sheet';
import { cn } from '@/lib/utils';

// ============================================
// TYPES
// ============================================

interface NavItem {
  label: string;
  href: string;
  external?: boolean;
}

// ============================================
// NAVIGATION DATA
// TODO: Fetch from database via salon settings
// ============================================

const navigation: NavItem[] = [
  { label: 'Home', href: '/' },
  { label: 'Leistungen', href: '/leistungen' },
  { label: 'Galerie', href: '/galerie' },
  { label: 'Über uns', href: '/ueber-uns' },
  { label: 'Team', href: '/team' },
  { label: 'Kontakt', href: '/kontakt' },
  { label: 'Shop', href: '/shop' },
];

// Salon contact info - TODO: Fetch from database
const salonInfo = {
  name: 'SCHNITTWERK',
  phone: '+41 71 123 45 67',
  instagram: 'https://instagram.com/schnittwerk',
};

// ============================================
// HEADER COMPONENT
// ============================================

export function Header() {
  const pathname = usePathname();
  const [isScrolled, setIsScrolled] = useState(false);
  const [isMobileMenuOpen, setIsMobileMenuOpen] = useState(false);

  // Track scroll for header background
  useEffect(() => {
    const handleScroll = () => {
      setIsScrolled(window.scrollY > 10);
    };

    window.addEventListener('scroll', handleScroll, { passive: true });
    return () => window.removeEventListener('scroll', handleScroll);
  }, []);

  // Close mobile menu on route change
  useEffect(() => {
    setIsMobileMenuOpen(false);
  }, [pathname]);

  return (
    <header
      className={cn(
        'fixed top-0 left-0 right-0 z-50 transition-all duration-300',
        isScrolled
          ? 'bg-background/95 backdrop-blur-md shadow-sm border-b border-border/50'
          : 'bg-transparent'
      )}
    >
      <div className="container-wide">
        <div className="flex h-16 items-center justify-between lg:h-20">
          {/* Logo */}
          <Link
            href="/"
            className="flex items-center gap-2 text-xl font-bold tracking-tight lg:text-2xl"
          >
            <span className="text-gradient-gold">{salonInfo.name}</span>
          </Link>

          {/* Desktop Navigation */}
          <nav className="hidden lg:flex lg:items-center lg:gap-1">
            {navigation.map((item) => (
              <Link
                key={item.href}
                href={item.href}
                className={cn(
                  'px-4 py-2 text-sm font-medium transition-colors rounded-md',
                  pathname === item.href
                    ? 'text-primary bg-primary/10'
                    : 'text-foreground/80 hover:text-foreground hover:bg-muted'
                )}
              >
                {item.label}
              </Link>
            ))}
          </nav>

          {/* Desktop Actions */}
          <div className="hidden lg:flex lg:items-center lg:gap-2">
            {/* Phone */}
            <Button
              variant="ghost"
              size="sm"
              asChild
              className="text-foreground/80 hover:text-foreground"
            >
              <a href={`tel:${salonInfo.phone.replace(/\s/g, '')}`}>
                <Phone className="h-4 w-4 mr-2" />
                <span className="hidden xl:inline">{salonInfo.phone}</span>
              </a>
            </Button>

            {/* Instagram */}
            <Button
              variant="ghost"
              size="icon"
              asChild
              className="text-foreground/80 hover:text-foreground"
            >
              <a
                href={salonInfo.instagram}
                target="_blank"
                rel="noopener noreferrer"
                aria-label="Instagram"
              >
                <Instagram className="h-4 w-4" />
              </a>
            </Button>

            {/* Cart */}
            <Button
              variant="ghost"
              size="icon"
              asChild
              className="relative text-foreground/80 hover:text-foreground"
            >
              <Link href="/warenkorb" aria-label="Warenkorb">
                <ShoppingBag className="h-4 w-4" />
                {/* Cart counter - TODO: Connect to cart context */}
                {/* <span className="absolute -top-1 -right-1 h-4 w-4 rounded-full bg-primary text-[10px] font-medium text-primary-foreground flex items-center justify-center">
                  2
                </span> */}
              </Link>
            </Button>

            {/* Login */}
            <Button
              variant="ghost"
              size="icon"
              asChild
              className="text-foreground/80 hover:text-foreground"
            >
              <Link href="/login" aria-label="Anmelden">
                <User className="h-4 w-4" />
              </Link>
            </Button>

            {/* Book Appointment CTA */}
            <Button asChild className="ml-2 btn-glow">
              <Link href="/termin-buchen">
                <Calendar className="h-4 w-4 mr-2" />
                Termin buchen
              </Link>
            </Button>
          </div>

          {/* Mobile Menu */}
          <div className="flex items-center gap-2 lg:hidden">
            {/* Mobile Cart */}
            <Button
              variant="ghost"
              size="icon"
              asChild
              className="relative text-foreground/80"
            >
              <Link href="/warenkorb" aria-label="Warenkorb">
                <ShoppingBag className="h-5 w-5" />
              </Link>
            </Button>

            {/* Mobile Menu Trigger */}
            <Sheet open={isMobileMenuOpen} onOpenChange={setIsMobileMenuOpen}>
              <SheetTrigger asChild>
                <Button
                  variant="ghost"
                  size="icon"
                  aria-label="Menu öffnen"
                >
                  <Menu className="h-5 w-5" />
                </Button>
              </SheetTrigger>
              <SheetContent side="right" className="w-80">
                <div className="flex flex-col h-full">
                  {/* Mobile Navigation */}
                  <nav className="flex flex-col gap-1 py-6">
                    {navigation.map((item) => (
                      <Link
                        key={item.href}
                        href={item.href}
                        className={cn(
                          'px-4 py-3 text-base font-medium transition-colors rounded-lg',
                          pathname === item.href
                            ? 'text-primary bg-primary/10'
                            : 'text-foreground/80 hover:text-foreground hover:bg-muted'
                        )}
                      >
                        {item.label}
                      </Link>
                    ))}
                  </nav>

                  {/* Mobile Actions */}
                  <div className="mt-auto space-y-3 border-t pt-6">
                    {/* Phone */}
                    <Button
                      variant="outline"
                      className="w-full justify-start"
                      asChild
                    >
                      <a href={`tel:${salonInfo.phone.replace(/\s/g, '')}`}>
                        <Phone className="h-4 w-4 mr-3" />
                        {salonInfo.phone}
                      </a>
                    </Button>

                    {/* Instagram */}
                    <Button
                      variant="outline"
                      className="w-full justify-start"
                      asChild
                    >
                      <a
                        href={salonInfo.instagram}
                        target="_blank"
                        rel="noopener noreferrer"
                      >
                        <Instagram className="h-4 w-4 mr-3" />
                        Instagram
                      </a>
                    </Button>

                    {/* Login */}
                    <Button
                      variant="outline"
                      className="w-full justify-start"
                      asChild
                    >
                      <Link href="/login">
                        <User className="h-4 w-4 mr-3" />
                        Anmelden
                      </Link>
                    </Button>

                    {/* Book Appointment CTA */}
                    <Button className="w-full" asChild>
                      <Link href="/termin-buchen">
                        <Calendar className="h-4 w-4 mr-2" />
                        Termin buchen
                      </Link>
                    </Button>
                  </div>
                </div>
              </SheetContent>
            </Sheet>
          </div>
        </div>
      </div>
    </header>
  );
}
