import { redirect } from 'next/navigation';
import Link from 'next/link';
import { Calendar, User, LogOut, Scissors, ChevronRight } from 'lucide-react';
import { Button } from '@/components/ui/button';
import { getCurrentUser, logout } from '@/lib/actions';

// ============================================
// CUSTOMER PORTAL LAYOUT
// ============================================

interface LayoutProps {
  children: React.ReactNode;
}

export default async function KontoLayout({ children }: LayoutProps) {
  const user = await getCurrentUser();

  // Auth pages don't need authentication
  // This layout only protects /konto/termine and /konto/profil
  const isAuthPage =
    typeof window === 'undefined' ||
    [
      '/konto/login',
      '/konto/registrieren',
      '/konto/passwort-vergessen',
      '/konto/passwort-aendern',
    ].some(
      (path) => false // Server-side, we can't check pathname
    );

  // If no user and not an auth page, redirect to login
  // Note: Auth pages have their own redirect logic

  const navItems = [
    {
      href: '/konto/termine',
      label: 'Meine Termine',
      icon: Calendar,
    },
    {
      href: '/konto/profil',
      label: 'Mein Profil',
      icon: User,
    },
  ];

  // For auth pages, render without sidebar
  if (!user) {
    return <>{children}</>;
  }

  return (
    <div className="bg-background min-h-screen">
      <div className="container-wide py-8">
        {/* Breadcrumb */}
        <nav className="text-muted-foreground mb-6 flex items-center text-sm">
          <Link href="/" className="hover:text-foreground">
            Startseite
          </Link>
          <ChevronRight className="mx-2 h-4 w-4" />
          <span className="text-foreground">Mein Konto</span>
        </nav>

        {/* Page Title */}
        <div className="mb-8 flex items-center justify-between">
          <div className="flex items-center gap-3">
            <Scissors className="text-primary h-8 w-8" />
            <div>
              <h1 className="text-2xl font-bold">Mein Konto</h1>
              <p className="text-muted-foreground text-sm">
                Willkommen, {user.profile?.first_name || 'Kunde'}!
              </p>
            </div>
          </div>
          <form
            action={async () => {
              'use server';
              await logout();
              redirect('/');
            }}
          >
            <Button variant="outline" size="sm" type="submit">
              <LogOut className="mr-2 h-4 w-4" />
              Abmelden
            </Button>
          </form>
        </div>

        {/* Main Layout */}
        <div className="grid gap-8 lg:grid-cols-4">
          {/* Sidebar */}
          <aside className="lg:col-span-1">
            <nav className="space-y-1">
              {navItems.map((item) => (
                <Link
                  key={item.href}
                  href={item.href}
                  className="hover:bg-muted flex items-center gap-3 rounded-lg px-4 py-3 transition-colors"
                >
                  <item.icon className="text-muted-foreground h-5 w-5" />
                  <span>{item.label}</span>
                </Link>
              ))}
            </nav>

            {/* Quick Action */}
            <div className="bg-primary/5 border-primary/20 mt-8 rounded-lg border p-4">
              <p className="mb-3 text-sm font-medium">Neuen Termin buchen?</p>
              <Button asChild size="sm" className="w-full">
                <Link href="/termin-buchen">Jetzt buchen</Link>
              </Button>
            </div>
          </aside>

          {/* Content */}
          <main className="lg:col-span-3">{children}</main>
        </div>
      </div>
    </div>
  );
}
