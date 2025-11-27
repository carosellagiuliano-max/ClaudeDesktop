import type { Metadata } from 'next';
import Link from 'next/link';
import { redirect } from 'next/navigation';
import {
  Package,
  ChevronRight,
  ShoppingBag,
  Truck,
  Clock,
  CheckCircle2,
  XCircle,
  AlertCircle,
} from 'lucide-react';
import { Button } from '@/components/ui/button';
import { Card, CardContent } from '@/components/ui/card';
import { Badge } from '@/components/ui/badge';
import { Tabs, TabsContent, TabsList, TabsTrigger } from '@/components/ui/tabs';
import { getCustomerOrders } from '@/lib/actions/orders';
import { createServerClient } from '@/lib/supabase/server';
import { formatPrice, formatDate } from '@/lib/domain/order/order';
import type { OrderStatus } from '@/lib/domain/order/types';

// ============================================
// METADATA
// ============================================

export const metadata: Metadata = {
  title: 'Meine Bestellungen',
  description: 'Übersicht über Ihre Bestellungen',
};

// ============================================
// HELPERS
// ============================================

function getStatusIcon(status: OrderStatus) {
  switch (status) {
    case 'pending':
      return <Clock className="h-4 w-4" />;
    case 'paid':
    case 'processing':
      return <Package className="h-4 w-4" />;
    case 'shipped':
      return <Truck className="h-4 w-4" />;
    case 'delivered':
    case 'completed':
      return <CheckCircle2 className="h-4 w-4" />;
    case 'cancelled':
    case 'refunded':
      return <XCircle className="h-4 w-4" />;
    default:
      return <AlertCircle className="h-4 w-4" />;
  }
}

function getStatusBadge(status: OrderStatus) {
  const statusConfig: Record<
    OrderStatus,
    { label: string; variant: 'default' | 'secondary' | 'destructive' | 'outline' }
  > = {
    pending: { label: 'Ausstehend', variant: 'outline' },
    paid: { label: 'Bezahlt', variant: 'default' },
    processing: { label: 'In Bearbeitung', variant: 'secondary' },
    shipped: { label: 'Versendet', variant: 'secondary' },
    delivered: { label: 'Zugestellt', variant: 'default' },
    completed: { label: 'Abgeschlossen', variant: 'default' },
    cancelled: { label: 'Storniert', variant: 'destructive' },
    refunded: { label: 'Erstattet', variant: 'destructive' },
  };

  const config = statusConfig[status] || { label: status, variant: 'outline' as const };

  return (
    <Badge variant={config.variant} className="gap-1">
      {getStatusIcon(status)}
      {config.label}
    </Badge>
  );
}

// ============================================
// PAGE
// ============================================

export default async function OrderHistoryPage() {
  // Get current user
  const supabase = await createServerClient();
  const {
    data: { user },
  } = await supabase.auth.getUser();

  if (!user) {
    redirect('/konto/login?redirect=/konto/bestellungen');
  }

  // Get customer ID from user metadata or profile
  const { data: customer } = await supabase
    .from('customers')
    .select('id')
    .eq('user_id', user.id)
    .single();

  if (!customer) {
    return (
      <div className="container max-w-4xl py-8">
        <div className="text-center py-12">
          <AlertCircle className="h-12 w-12 mx-auto text-muted-foreground mb-4" />
          <h1 className="text-2xl font-bold mb-2">Kein Kundenprofil gefunden</h1>
          <p className="text-muted-foreground mb-6">
            Bitte vervollständigen Sie Ihr Profil, um Bestellungen zu sehen.
          </p>
          <Button asChild>
            <Link href="/konto/profil">Profil vervollständigen</Link>
          </Button>
        </div>
      </div>
    );
  }

  // Get all orders
  const { data: allOrders } = await getCustomerOrders(customer.id, { limit: 100 });

  // Separate active and past orders
  const activeStatuses: OrderStatus[] = ['pending', 'paid', 'processing', 'shipped'];
  const activeOrders = allOrders?.filter((o) => activeStatuses.includes(o.status)) || [];
  const pastOrders = allOrders?.filter((o) => !activeStatuses.includes(o.status)) || [];

  const hasOrders = (allOrders?.length || 0) > 0;

  return (
    <div className="container max-w-4xl py-8">
      <div className="mb-8">
        <h1 className="text-3xl font-bold mb-2">Meine Bestellungen</h1>
        <p className="text-muted-foreground">
          Übersicht über alle Ihre Bestellungen
        </p>
      </div>

      {!hasOrders ? (
        // Empty State
        <Card>
          <CardContent className="py-12">
            <div className="text-center">
              <div className="h-16 w-16 rounded-full bg-muted flex items-center justify-center mx-auto mb-4">
                <ShoppingBag className="h-8 w-8 text-muted-foreground" />
              </div>
              <h2 className="text-xl font-semibold mb-2">Noch keine Bestellungen</h2>
              <p className="text-muted-foreground mb-6">
                Sie haben noch keine Bestellungen aufgegeben.
              </p>
              <Button asChild>
                <Link href="/shop">Zum Shop</Link>
              </Button>
            </div>
          </CardContent>
        </Card>
      ) : (
        <Tabs defaultValue="active" className="space-y-6">
          <TabsList>
            <TabsTrigger value="active">
              Aktiv ({activeOrders.length})
            </TabsTrigger>
            <TabsTrigger value="past">
              Vergangene ({pastOrders.length})
            </TabsTrigger>
          </TabsList>

          {/* Active Orders */}
          <TabsContent value="active" className="space-y-4">
            {activeOrders.length === 0 ? (
              <Card>
                <CardContent className="py-8 text-center">
                  <p className="text-muted-foreground">
                    Keine aktiven Bestellungen
                  </p>
                </CardContent>
              </Card>
            ) : (
              activeOrders.map((order) => (
                <OrderCard key={order.id} order={order} />
              ))
            )}
          </TabsContent>

          {/* Past Orders */}
          <TabsContent value="past" className="space-y-4">
            {pastOrders.length === 0 ? (
              <Card>
                <CardContent className="py-8 text-center">
                  <p className="text-muted-foreground">
                    Keine vergangenen Bestellungen
                  </p>
                </CardContent>
              </Card>
            ) : (
              pastOrders.map((order) => (
                <OrderCard key={order.id} order={order} />
              ))
            )}
          </TabsContent>
        </Tabs>
      )}
    </div>
  );
}

// ============================================
// ORDER CARD COMPONENT
// ============================================

interface OrderCardProps {
  order: {
    id: string;
    orderNumber: string;
    status: OrderStatus;
    totalCents: number;
    itemCount: number;
    createdAt: Date;
    paidAt?: Date;
  };
}

function OrderCard({ order }: OrderCardProps) {
  return (
    <Card className="hover:shadow-md transition-shadow">
      <CardContent className="p-4">
        <Link href={`/konto/bestellungen/${order.id}`}>
          <div className="flex items-center justify-between">
            <div className="flex-1">
              <div className="flex items-center gap-3 mb-2">
                <span className="font-mono font-semibold">{order.orderNumber}</span>
                {getStatusBadge(order.status)}
              </div>
              <div className="flex items-center gap-4 text-sm text-muted-foreground">
                <span>{formatDate(order.createdAt)}</span>
                <span>•</span>
                <span>{order.itemCount} Artikel</span>
              </div>
            </div>
            <div className="flex items-center gap-4">
              <div className="text-right">
                <p className="font-semibold">{formatPrice(order.totalCents)}</p>
                {order.paidAt && (
                  <p className="text-xs text-muted-foreground">
                    Bezahlt am {formatDate(order.paidAt)}
                  </p>
                )}
              </div>
              <ChevronRight className="h-5 w-5 text-muted-foreground" />
            </div>
          </div>
        </Link>
      </CardContent>
    </Card>
  );
}
