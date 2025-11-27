'use client';

import { useState } from 'react';
import Link from 'next/link';
import { usePathname } from 'next/navigation';
import {
  LayoutDashboard,
  Calendar,
  Users,
  ShoppingBag,
  Package,
  UserCog,
  Settings,
  ChevronLeft,
  ChevronRight,
  Scissors,
  LogOut,
  HelpCircle,
  Warehouse,
  BarChart3,
  Bell,
  Receipt,
  Download,
} from 'lucide-react';
import { Button } from '@/components/ui/button';
import { cn } from '@/lib/utils';
import { Tooltip, TooltipContent, TooltipProvider, TooltipTrigger } from '@/components/ui/tooltip';

// ============================================
// TYPES
// ============================================

interface AdminSidebarProps {
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
  roles?: string[];
}

// ============================================
// NAVIGATION DATA
// ============================================

const mainNavItems: NavItem[] = [
  {
    label: 'Dashboard',
    href: '/admin',
    icon: LayoutDashboard,
  },
  {
    label: 'Kalender',
    href: '/admin/kalender',
    icon: Calendar,
  },
  {
    label: 'Kunden',
    href: '/admin/kunden',
    icon: Users,
  },
  {
    label: 'Bestellungen',
    href: '/admin/bestellungen',
    icon: ShoppingBag,
  },
  {
    label: 'Produkte',
    href: '/admin/produkte',
    icon: Package,
  },
  {
    label: 'Inventar',
    href: '/admin/inventar',
    icon: Warehouse,
    roles: ['admin', 'manager', 'hq'],
  },
  {
    label: 'Team',
    href: '/admin/team',
    icon: UserCog,
    roles: ['admin', 'manager', 'hq'],
  },
  {
    label: 'Analytics',
    href: '/admin/analytics',
    icon: BarChart3,
    roles: ['admin', 'manager', 'hq'],
  },
  {
    label: 'Finanzen',
    href: '/admin/finanzen',
    icon: Receipt,
    roles: ['admin', 'hq'],
  },
  {
    label: 'Benachrichtigungen',
    href: '/admin/benachrichtigungen',
    icon: Bell,
    roles: ['admin', 'hq'],
  },
  {
    label: 'Datenexport',
    href: '/admin/export',
    icon: Download,
    roles: ['admin', 'hq'],
  },
];

const bottomNavItems: NavItem[] = [
  {
    label: 'Einstellungen',
    href: '/admin/einstellungen',
    icon: Settings,
    roles: ['admin', 'hq'],
  },
  {
    label: 'Hilfe',
    href: '/admin/hilfe',
    icon: HelpCircle,
  },
];

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
// ADMIN SIDEBAR COMPONENT
// ============================================

export function AdminSidebar({ user }: AdminSidebarProps) {
  const pathname = usePathname();
  const [isCollapsed, setIsCollapsed] = useState(false);

  const isAllowed = (item: NavItem) => {
    if (!item.roles) return true;
    return item.roles.includes(user.role);
  };

  const isActive = (href: string) => {
    if (href === '/admin') {
      return pathname === '/admin';
    }
    return pathname.startsWith(href);
  };

  return (
    <TooltipProvider delayDuration={0}>
      <aside
        className={cn(
          'bg-card flex h-full flex-col border-r transition-all duration-300',
          isCollapsed ? 'w-16' : 'w-64'
        )}
      >
        {/* Logo / Brand */}
        <div className="flex h-16 items-center justify-between border-b px-4">
          {!isCollapsed && (
            <Link href="/admin" className="flex items-center gap-2">
              <Scissors className="text-primary h-6 w-6" />
              <span className="text-lg font-bold">SCHNITTWERK</span>
            </Link>
          )}
          {isCollapsed && (
            <Link href="/admin" className="mx-auto">
              <Scissors className="text-primary h-6 w-6" />
            </Link>
          )}
          <Button
            variant="ghost"
            size="icon"
            onClick={() => setIsCollapsed(!isCollapsed)}
            className={cn('h-8 w-8', isCollapsed && 'mx-auto')}
            aria-label={isCollapsed ? 'Sidebar erweitern' : 'Sidebar einklappen'}
          >
            {isCollapsed ? (
              <ChevronRight className="h-4 w-4" />
            ) : (
              <ChevronLeft className="h-4 w-4" />
            )}
          </Button>
        </div>

        {/* Main Navigation */}
        <nav className="flex-1 space-y-1 p-2">
          {mainNavItems.filter(isAllowed).map((item) => {
            const Icon = item.icon;
            const active = isActive(item.href);

            if (isCollapsed) {
              return (
                <Tooltip key={item.href}>
                  <TooltipTrigger asChild>
                    <Link
                      href={item.href}
                      className={cn(
                        'mx-auto flex h-10 w-10 items-center justify-center rounded-md transition-colors',
                        active
                          ? 'bg-primary text-primary-foreground'
                          : 'text-muted-foreground hover:bg-muted hover:text-foreground'
                      )}
                    >
                      <Icon className="h-5 w-5" />
                    </Link>
                  </TooltipTrigger>
                  <TooltipContent side="right" sideOffset={10}>
                    {item.label}
                  </TooltipContent>
                </Tooltip>
              );
            }

            return (
              <Link
                key={item.href}
                href={item.href}
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

        {/* Bottom Navigation */}
        <div className="space-y-1 border-t p-2">
          {bottomNavItems.filter(isAllowed).map((item) => {
            const Icon = item.icon;
            const active = isActive(item.href);

            if (isCollapsed) {
              return (
                <Tooltip key={item.href}>
                  <TooltipTrigger asChild>
                    <Link
                      href={item.href}
                      className={cn(
                        'mx-auto flex h-10 w-10 items-center justify-center rounded-md transition-colors',
                        active
                          ? 'bg-primary text-primary-foreground'
                          : 'text-muted-foreground hover:bg-muted hover:text-foreground'
                      )}
                    >
                      <Icon className="h-5 w-5" />
                    </Link>
                  </TooltipTrigger>
                  <TooltipContent side="right" sideOffset={10}>
                    {item.label}
                  </TooltipContent>
                </Tooltip>
              );
            }

            return (
              <Link
                key={item.href}
                href={item.href}
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
        </div>

        {/* User Info & Logout */}
        <div className="border-t p-3">
          {!isCollapsed ? (
            <div className="flex items-center gap-3">
              <div className="bg-primary/10 text-primary flex h-9 w-9 items-center justify-center rounded-full">
                <span className="text-sm font-medium">{user.name.charAt(0).toUpperCase()}</span>
              </div>
              <div className="min-w-0 flex-1">
                <p className="truncate text-sm font-medium">{user.name}</p>
                <p className="text-muted-foreground text-xs">
                  {roleLabels[user.role] || user.role}
                </p>
              </div>
              <Tooltip>
                <TooltipTrigger asChild>
                  <form action="/api/auth/signout" method="POST">
                    <Button
                      type="submit"
                      variant="ghost"
                      size="icon"
                      className="text-muted-foreground hover:text-foreground h-8 w-8"
                    >
                      <LogOut className="h-4 w-4" />
                    </Button>
                  </form>
                </TooltipTrigger>
                <TooltipContent side="right">Abmelden</TooltipContent>
              </Tooltip>
            </div>
          ) : (
            <Tooltip>
              <TooltipTrigger asChild>
                <form action="/api/auth/signout" method="POST">
                  <Button
                    type="submit"
                    variant="ghost"
                    size="icon"
                    className="text-muted-foreground hover:text-foreground mx-auto flex h-10 w-10"
                  >
                    <LogOut className="h-5 w-5" />
                  </Button>
                </form>
              </TooltipTrigger>
              <TooltipContent side="right" sideOffset={10}>
                Abmelden ({user.name})
              </TooltipContent>
            </Tooltip>
          )}
        </div>
      </aside>
    </TooltipProvider>
  );
}
