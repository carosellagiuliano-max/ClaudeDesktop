'use client';

import { useState } from 'react';
import Link from 'next/link';
import { usePathname } from 'next/navigation';
import {
  Bell,
  Search,
  Menu,
  X,
  LayoutDashboard,
  Calendar,
  Users,
  ShoppingBag,
  Package,
  UserCog,
  Settings,
  LogOut,
  User,
  ExternalLink,
  Scissors,
} from 'lucide-react';
import { Button } from '@/components/ui/button';
import { Input } from '@/components/ui/input';
import {
  DropdownMenu,
  DropdownMenuContent,
  DropdownMenuItem,
  DropdownMenuLabel,
  DropdownMenuSeparator,
  DropdownMenuTrigger,
} from '@/components/ui/dropdown-menu';
import { Sheet, SheetContent, SheetHeader, SheetTitle, SheetTrigger } from '@/components/ui/sheet';
import { Badge } from '@/components/ui/badge';
import { cn } from '@/lib/utils';

// ============================================
// TYPES
// ============================================

interface AdminHeaderProps {
  user: {
    name: string;
    email: string;
    role: string;
  };
}

interface NavItem {
  label: string;
  href: string;
  icon: React.ComponentType<{ className?: string }>;
}

// ============================================
// MOBILE NAVIGATION DATA
// ============================================

const mobileNavItems: NavItem[] = [
  { label: 'Dashboard', href: '/admin', icon: LayoutDashboard },
  { label: 'Kalender', href: '/admin/kalender', icon: Calendar },
  { label: 'Kunden', href: '/admin/kunden', icon: Users },
  { label: 'Bestellungen', href: '/admin/bestellungen', icon: ShoppingBag },
  { label: 'Produkte', href: '/admin/produkte', icon: Package },
  { label: 'Team', href: '/admin/team', icon: UserCog },
  { label: 'Einstellungen', href: '/admin/einstellungen', icon: Settings },
];

// ============================================
// PAGE TITLES
// ============================================

const pageTitles: Record<string, string> = {
  '/admin': 'Dashboard',
  '/admin/kalender': 'Kalender',
  '/admin/kunden': 'Kundenverwaltung',
  '/admin/bestellungen': 'Bestellungen',
  '/admin/produkte': 'Produktverwaltung',
  '/admin/team': 'Team & Mitarbeiter',
  '/admin/einstellungen': 'Einstellungen',
  '/admin/hilfe': 'Hilfe & Support',
};

// ============================================
// ROLE LABELS
// ============================================

const roleLabels: Record<string, string> = {
  admin: 'Administrator',
  manager: 'Manager',
  staff: 'Mitarbeiter',
  hq: 'Hauptverwaltung',
};

// ============================================
// ADMIN HEADER COMPONENT
// ============================================

export function AdminHeader({ user }: AdminHeaderProps) {
  const pathname = usePathname();
  const [isMobileMenuOpen, setIsMobileMenuOpen] = useState(false);
  const [notificationCount] = useState(3); // TODO: Fetch from API

  // Get current page title
  const getPageTitle = () => {
    // Check for exact match first
    if (pageTitles[pathname]) {
      return pageTitles[pathname];
    }
    // Check for partial matches (for sub-pages)
    for (const [path, title] of Object.entries(pageTitles)) {
      if (pathname.startsWith(path) && path !== '/admin') {
        return title;
      }
    }
    return 'Admin';
  };

  const isActive = (href: string) => {
    if (href === '/admin') {
      return pathname === '/admin';
    }
    return pathname.startsWith(href);
  };

  return (
    <header className="bg-background sticky top-0 z-40 flex h-16 items-center gap-4 border-b px-4 lg:px-6">
      {/* Mobile Menu Button */}
      <Sheet open={isMobileMenuOpen} onOpenChange={setIsMobileMenuOpen}>
        <SheetTrigger asChild>
          <Button variant="ghost" size="icon" className="lg:hidden">
            <Menu className="h-5 w-5" />
            <span className="sr-only">Menu öffnen</span>
          </Button>
        </SheetTrigger>
        <SheetContent side="left" className="w-72 p-0">
          <SheetHeader className="border-b px-4 py-3">
            <SheetTitle className="flex items-center gap-2">
              <Scissors className="text-primary h-5 w-5" />
              SCHNITTWERK Admin
            </SheetTitle>
          </SheetHeader>
          <nav className="flex flex-col gap-1 p-2">
            {mobileNavItems.map((item) => {
              const Icon = item.icon;
              const active = isActive(item.href);
              return (
                <Link
                  key={item.href}
                  href={item.href}
                  onClick={() => setIsMobileMenuOpen(false)}
                  className={cn(
                    'flex items-center gap-3 rounded-md px-3 py-2 transition-colors',
                    active
                      ? 'bg-primary text-primary-foreground'
                      : 'text-muted-foreground hover:bg-muted hover:text-foreground'
                  )}
                >
                  <Icon className="h-5 w-5" />
                  <span className="text-sm font-medium">{item.label}</span>
                </Link>
              );
            })}
          </nav>
          <div className="absolute right-0 bottom-0 left-0 border-t p-4">
            <div className="mb-3 flex items-center gap-3">
              <div className="bg-primary/10 text-primary flex h-9 w-9 items-center justify-center rounded-full">
                <span className="text-sm font-medium">{user.name.charAt(0).toUpperCase()}</span>
              </div>
              <div className="flex-1">
                <p className="text-sm font-medium">{user.name}</p>
                <p className="text-muted-foreground text-xs">
                  {roleLabels[user.role] || user.role}
                </p>
              </div>
            </div>
            <form action="/api/auth/signout" method="POST">
              <Button variant="outline" className="w-full" type="submit">
                <LogOut className="mr-2 h-4 w-4" />
                Abmelden
              </Button>
            </form>
          </div>
        </SheetContent>
      </Sheet>

      {/* Page Title */}
      <div className="flex-1">
        <h1 className="text-lg font-semibold lg:text-xl">{getPageTitle()}</h1>
      </div>

      {/* Search (Desktop) */}
      <div className="hidden md:flex md:w-64 lg:w-80">
        <div className="relative w-full">
          <Search className="text-muted-foreground absolute top-2.5 left-2.5 h-4 w-4" />
          <Input type="search" placeholder="Suchen..." className="bg-muted/50 w-full pl-8" />
        </div>
      </div>

      {/* Actions */}
      <div className="flex items-center gap-2">
        {/* Search (Mobile) */}
        <Button variant="ghost" size="icon" className="md:hidden">
          <Search className="h-5 w-5" />
          <span className="sr-only">Suchen</span>
        </Button>

        {/* View Website */}
        <Button variant="ghost" size="icon" asChild className="hidden sm:flex">
          <Link href="/" target="_blank" rel="noopener noreferrer">
            <ExternalLink className="h-5 w-5" />
            <span className="sr-only">Website öffnen</span>
          </Link>
        </Button>

        {/* Notifications */}
        <DropdownMenu>
          <DropdownMenuTrigger asChild>
            <Button variant="ghost" size="icon" className="relative">
              <Bell className="h-5 w-5" />
              {notificationCount > 0 && (
                <Badge
                  variant="destructive"
                  className="absolute -top-1 -right-1 flex h-5 w-5 items-center justify-center p-0 text-xs"
                >
                  {notificationCount}
                </Badge>
              )}
              <span className="sr-only">Benachrichtigungen</span>
            </Button>
          </DropdownMenuTrigger>
          <DropdownMenuContent align="end" className="w-80">
            <DropdownMenuLabel>Benachrichtigungen</DropdownMenuLabel>
            <DropdownMenuSeparator />
            <div className="max-h-80 overflow-y-auto">
              {/* Notification Items */}
              <DropdownMenuItem className="flex flex-col items-start gap-1 p-3">
                <span className="font-medium">Neuer Termin</span>
                <span className="text-muted-foreground text-xs">
                  Max Mustermann hat einen Termin für morgen gebucht.
                </span>
                <span className="text-muted-foreground text-xs">Vor 5 Minuten</span>
              </DropdownMenuItem>
              <DropdownMenuItem className="flex flex-col items-start gap-1 p-3">
                <span className="font-medium">Neue Bestellung</span>
                <span className="text-muted-foreground text-xs">
                  Bestellung #1234 wurde aufgegeben (CHF 89.00)
                </span>
                <span className="text-muted-foreground text-xs">Vor 15 Minuten</span>
              </DropdownMenuItem>
              <DropdownMenuItem className="flex flex-col items-start gap-1 p-3">
                <span className="font-medium">Termin storniert</span>
                <span className="text-muted-foreground text-xs">
                  Anna Schmidt hat ihren Termin für heute storniert.
                </span>
                <span className="text-muted-foreground text-xs">Vor 30 Minuten</span>
              </DropdownMenuItem>
            </div>
            <DropdownMenuSeparator />
            <DropdownMenuItem className="justify-center">
              <Link href="/admin/benachrichtigungen" className="text-primary text-sm">
                Alle anzeigen
              </Link>
            </DropdownMenuItem>
          </DropdownMenuContent>
        </DropdownMenu>

        {/* User Menu */}
        <DropdownMenu>
          <DropdownMenuTrigger asChild>
            <Button variant="ghost" size="icon" className="relative">
              <div className="bg-primary/10 text-primary flex h-8 w-8 items-center justify-center rounded-full">
                <span className="text-sm font-medium">{user.name.charAt(0).toUpperCase()}</span>
              </div>
            </Button>
          </DropdownMenuTrigger>
          <DropdownMenuContent align="end" className="w-56">
            <DropdownMenuLabel className="font-normal">
              <div className="flex flex-col space-y-1">
                <p className="text-sm font-medium">{user.name}</p>
                <p className="text-muted-foreground text-xs">{user.email}</p>
                <Badge variant="secondary" className="mt-1 w-fit">
                  {roleLabels[user.role] || user.role}
                </Badge>
              </div>
            </DropdownMenuLabel>
            <DropdownMenuSeparator />
            <DropdownMenuItem asChild>
              <Link href="/admin/profil">
                <User className="mr-2 h-4 w-4" />
                Profil
              </Link>
            </DropdownMenuItem>
            <DropdownMenuItem asChild>
              <Link href="/admin/einstellungen">
                <Settings className="mr-2 h-4 w-4" />
                Einstellungen
              </Link>
            </DropdownMenuItem>
            <DropdownMenuSeparator />
            <DropdownMenuItem asChild>
              <Link href="/" target="_blank">
                <ExternalLink className="mr-2 h-4 w-4" />
                Website öffnen
              </Link>
            </DropdownMenuItem>
            <DropdownMenuSeparator />
            <form action="/api/auth/signout" method="POST">
              <DropdownMenuItem asChild>
                <button type="submit" className="w-full cursor-pointer">
                  <LogOut className="mr-2 h-4 w-4" />
                  Abmelden
                </button>
              </DropdownMenuItem>
            </form>
          </DropdownMenuContent>
        </DropdownMenu>
      </div>
    </header>
  );
}
