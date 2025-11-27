'use client';

import { useState } from 'react';
import { useRouter, useSearchParams } from 'next/navigation';
import {
  Search,
  MoreHorizontal,
  ShoppingBag,
  Mail,
  Eye,
  Package,
  Truck,
  ChevronLeft,
  ChevronRight,
  CreditCard,
  Store,
} from 'lucide-react';
import { Button } from '@/components/ui/button';
import { Input } from '@/components/ui/input';
import { Card, CardContent } from '@/components/ui/card';
import { Badge } from '@/components/ui/badge';
import {
  Table,
  TableBody,
  TableCell,
  TableHead,
  TableHeader,
  TableRow,
} from '@/components/ui/table';
import {
  DropdownMenu,
  DropdownMenuContent,
  DropdownMenuItem,
  DropdownMenuSeparator,
  DropdownMenuTrigger,
} from '@/components/ui/dropdown-menu';
import {
  Select,
  SelectContent,
  SelectItem,
  SelectTrigger,
  SelectValue,
} from '@/components/ui/select';

// ============================================
// TYPES
// ============================================

interface Order {
  id: string;
  order_number: string;
  status: string;
  payment_status: string;
  payment_method: string | null;
  total_cents: number;
  customer_email: string;
  customer_name: string | null;
  shipping_method: string | null;
  created_at: string;
  paid_at: string | null;
}

interface AdminOrderListProps {
  orders: Order[];
  total: number;
  page: number;
  limit: number;
  initialSearch: string;
  initialStatus: string;
}

// ============================================
// CONSTANTS
// ============================================

const statusOptions = [
  { value: 'all', label: 'Alle Status' },
  { value: 'pending', label: 'Ausstehend' },
  { value: 'paid', label: 'Bezahlt' },
  { value: 'processing', label: 'In Bearbeitung' },
  { value: 'shipped', label: 'Versendet' },
  { value: 'delivered', label: 'Geliefert' },
  { value: 'completed', label: 'Abgeschlossen' },
  { value: 'cancelled', label: 'Storniert' },
  { value: 'refunded', label: 'Erstattet' },
];

const statusConfig: Record<
  string,
  { label: string; variant: 'default' | 'secondary' | 'destructive' | 'outline' }
> = {
  pending: { label: 'Ausstehend', variant: 'secondary' },
  paid: { label: 'Bezahlt', variant: 'default' },
  processing: { label: 'In Bearbeitung', variant: 'default' },
  shipped: { label: 'Versendet', variant: 'default' },
  delivered: { label: 'Geliefert', variant: 'default' },
  completed: { label: 'Abgeschlossen', variant: 'outline' },
  cancelled: { label: 'Storniert', variant: 'destructive' },
  refunded: { label: 'Erstattet', variant: 'destructive' },
};

const paymentStatusConfig: Record<
  string,
  { label: string; variant: 'default' | 'secondary' | 'destructive' | 'outline' }
> = {
  pending: { label: 'Ausstehend', variant: 'secondary' },
  processing: { label: 'Verarbeitung', variant: 'secondary' },
  succeeded: { label: 'Erfolgreich', variant: 'default' },
  failed: { label: 'Fehlgeschlagen', variant: 'destructive' },
  refunded: { label: 'Erstattet', variant: 'outline' },
  partially_refunded: { label: 'Teilweise erstattet', variant: 'outline' },
};

const paymentMethodLabels: Record<string, string> = {
  stripe_card: 'Karte',
  stripe_twint: 'TWINT',
  cash: 'Bar',
  terminal: 'Terminal',
  voucher: 'Gutschein',
  pay_at_venue: 'Vor Ort',
};

const shippingMethodLabels: Record<string, string> = {
  standard: 'Standard',
  express: 'Express',
  pickup: 'Abholung',
  none: 'Keine',
};

// ============================================
// HELPERS
// ============================================

function formatCurrency(cents: number): string {
  return new Intl.NumberFormat('de-CH', {
    style: 'currency',
    currency: 'CHF',
  }).format(cents / 100);
}

function formatDate(dateString: string): string {
  return new Date(dateString).toLocaleDateString('de-CH', {
    day: '2-digit',
    month: '2-digit',
    year: 'numeric',
    hour: '2-digit',
    minute: '2-digit',
  });
}

// ============================================
// ADMIN ORDER LIST
// ============================================

export function AdminOrderList({
  orders,
  total,
  page,
  limit,
  initialSearch,
  initialStatus,
}: AdminOrderListProps) {
  const router = useRouter();
  const searchParams = useSearchParams();
  const [search, setSearch] = useState(initialSearch);
  const [status, setStatus] = useState(initialStatus);

  const totalPages = Math.ceil(total / limit);

  const handleSearch = (e: React.FormEvent) => {
    e.preventDefault();
    const params = new URLSearchParams(searchParams);
    if (search) {
      params.set('search', search);
    } else {
      params.delete('search');
    }
    params.set('page', '1');
    router.push(`/admin/bestellungen?${params.toString()}`);
  };

  const handleStatusChange = (value: string) => {
    setStatus(value);
    const params = new URLSearchParams(searchParams);
    if (value && value !== 'all') {
      params.set('status', value);
    } else {
      params.delete('status');
    }
    params.set('page', '1');
    router.push(`/admin/bestellungen?${params.toString()}`);
  };

  const handlePageChange = (newPage: number) => {
    const params = new URLSearchParams(searchParams);
    params.set('page', newPage.toString());
    router.push(`/admin/bestellungen?${params.toString()}`);
  };

  const handleViewOrder = (order: Order) => {
    router.push(`/admin/bestellungen/${order.id}`);
  };

  return (
    <div className="space-y-4">
      {/* Header */}
      <div className="flex flex-col gap-4 sm:flex-row sm:items-center sm:justify-between">
        <div>
          <p className="text-muted-foreground text-sm">{total} Bestellungen insgesamt</p>
        </div>
        <div className="flex flex-wrap items-center gap-2">
          <form onSubmit={handleSearch} className="flex gap-2">
            <div className="relative">
              <Search className="text-muted-foreground absolute top-2.5 left-2.5 h-4 w-4" />
              <Input
                type="search"
                placeholder="Suchen..."
                value={search}
                onChange={(e) => setSearch(e.target.value)}
                className="w-48 pl-8"
              />
            </div>
            <Button type="submit" variant="secondary">
              Suchen
            </Button>
          </form>
          <Select value={status} onValueChange={handleStatusChange}>
            <SelectTrigger className="w-40">
              <SelectValue />
            </SelectTrigger>
            <SelectContent>
              {statusOptions.map((option) => (
                <SelectItem key={option.value} value={option.value}>
                  {option.label}
                </SelectItem>
              ))}
            </SelectContent>
          </Select>
        </div>
      </div>

      {/* Orders Table */}
      <Card>
        <CardContent className="p-0">
          <Table>
            <TableHeader>
              <TableRow>
                <TableHead>Bestellung</TableHead>
                <TableHead>Kunde</TableHead>
                <TableHead>Status</TableHead>
                <TableHead>Zahlung</TableHead>
                <TableHead>Versand</TableHead>
                <TableHead className="text-right">Betrag</TableHead>
                <TableHead>Datum</TableHead>
                <TableHead className="w-[50px]"></TableHead>
              </TableRow>
            </TableHeader>
            <TableBody>
              {orders.length === 0 ? (
                <TableRow>
                  <TableCell colSpan={8} className="py-8 text-center">
                    <div className="flex flex-col items-center gap-2">
                      <ShoppingBag className="text-muted-foreground h-8 w-8" />
                      <p className="text-muted-foreground">Keine Bestellungen gefunden</p>
                    </div>
                  </TableCell>
                </TableRow>
              ) : (
                orders.map((order) => {
                  const orderStatus = statusConfig[order.status] || {
                    label: order.status,
                    variant: 'secondary' as const,
                  };
                  const paymentStatus = paymentStatusConfig[order.payment_status] || {
                    label: order.payment_status,
                    variant: 'secondary' as const,
                  };

                  return (
                    <TableRow key={order.id}>
                      <TableCell>
                        <button
                          onClick={() => handleViewOrder(order)}
                          className="hover:text-primary font-medium transition-colors"
                        >
                          #{order.order_number}
                        </button>
                      </TableCell>
                      <TableCell>
                        <div>
                          {order.customer_name && (
                            <p className="font-medium">{order.customer_name}</p>
                          )}
                          <a
                            href={`mailto:${order.customer_email}`}
                            className="text-muted-foreground hover:text-foreground flex items-center gap-1 text-xs"
                          >
                            <Mail className="h-3 w-3" />
                            {order.customer_email}
                          </a>
                        </div>
                      </TableCell>
                      <TableCell>
                        <Badge variant={orderStatus.variant}>{orderStatus.label}</Badge>
                      </TableCell>
                      <TableCell>
                        <div className="flex flex-col gap-1">
                          <Badge variant={paymentStatus.variant} className="w-fit">
                            {paymentStatus.label}
                          </Badge>
                          {order.payment_method && (
                            <span className="text-muted-foreground flex items-center gap-1 text-xs">
                              {order.payment_method === 'pay_at_venue' ? (
                                <Store className="h-3 w-3" />
                              ) : (
                                <CreditCard className="h-3 w-3" />
                              )}
                              {paymentMethodLabels[order.payment_method] || order.payment_method}
                            </span>
                          )}
                        </div>
                      </TableCell>
                      <TableCell>
                        {order.shipping_method && (
                          <span className="flex items-center gap-1 text-sm">
                            {order.shipping_method === 'pickup' ? (
                              <Package className="h-3 w-3" />
                            ) : (
                              <Truck className="h-3 w-3" />
                            )}
                            {shippingMethodLabels[order.shipping_method] || order.shipping_method}
                          </span>
                        )}
                      </TableCell>
                      <TableCell className="text-right font-medium">
                        {formatCurrency(order.total_cents)}
                      </TableCell>
                      <TableCell className="text-muted-foreground text-sm">
                        {formatDate(order.created_at)}
                      </TableCell>
                      <TableCell>
                        <DropdownMenu>
                          <DropdownMenuTrigger asChild>
                            <Button variant="ghost" size="icon">
                              <MoreHorizontal className="h-4 w-4" />
                            </Button>
                          </DropdownMenuTrigger>
                          <DropdownMenuContent align="end">
                            <DropdownMenuItem onClick={() => handleViewOrder(order)}>
                              <Eye className="mr-2 h-4 w-4" />
                              Details anzeigen
                            </DropdownMenuItem>
                            <DropdownMenuSeparator />
                            <DropdownMenuItem>
                              <Package className="mr-2 h-4 w-4" />
                              Als versendet markieren
                            </DropdownMenuItem>
                            <DropdownMenuItem>
                              <Truck className="mr-2 h-4 w-4" />
                              Sendungsverfolgung hinzufügen
                            </DropdownMenuItem>
                          </DropdownMenuContent>
                        </DropdownMenu>
                      </TableCell>
                    </TableRow>
                  );
                })
              )}
            </TableBody>
          </Table>
        </CardContent>
      </Card>

      {/* Pagination */}
      {totalPages > 1 && (
        <div className="flex items-center justify-between">
          <p className="text-muted-foreground text-sm">
            Seite {page} von {totalPages}
          </p>
          <div className="flex items-center gap-2">
            <Button
              variant="outline"
              size="icon"
              disabled={page <= 1}
              onClick={() => handlePageChange(page - 1)}
            >
              <ChevronLeft className="h-4 w-4" />
            </Button>
            <Button
              variant="outline"
              size="icon"
              disabled={page >= totalPages}
              onClick={() => handlePageChange(page + 1)}
            >
              <ChevronRight className="h-4 w-4" />
            </Button>
          </div>
        </div>
      )}
    </div>
  );
}
