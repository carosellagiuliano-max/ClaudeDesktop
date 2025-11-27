'use client';

import { useState } from 'react';
import {
  Receipt,
  CreditCard,
  Banknote,
  Wallet,
  TrendingUp,
  Download,
  FileSpreadsheet,
  Building,
} from 'lucide-react';
import { Button } from '@/components/ui/button';
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from '@/components/ui/card';
import {
  Table,
  TableBody,
  TableCell,
  TableHead,
  TableHeader,
  TableRow,
} from '@/components/ui/table';
import { Progress } from '@/components/ui/progress';
import { Separator } from '@/components/ui/separator';
import { toast } from 'sonner';

// ============================================
// TYPES
// ============================================

interface PaymentMethodStats {
  method: string;
  count: number;
  totalCents: number;
}

interface VatSummary {
  grossCents: number;
  netCents: number;
  vatCents: number;
  vatRate: number;
}

interface DailySales {
  date: string;
  orderCount: number;
  appointmentCount: number;
  orderRevenue: number;
  appointmentRevenue: number;
  totalRevenue: number;
}

interface FinanceStats {
  periodStart: string;
  periodEnd: string;
  totalRevenue: number;
  totalOrders: number;
  totalAppointments: number;
  totalRefunds: number;
  netRevenue: number;
}

interface AdminFinanceViewProps {
  stats: FinanceStats;
  paymentMethods: PaymentMethodStats[];
  vatSummary: VatSummary;
  dailySales: DailySales[];
}

// ============================================
// HELPERS
// ============================================

function formatPrice(cents: number): string {
  return new Intl.NumberFormat('de-CH', {
    style: 'currency',
    currency: 'CHF',
  }).format(cents / 100);
}

function formatDate(dateString: string): string {
  return new Intl.DateTimeFormat('de-CH', {
    day: '2-digit',
    month: '2-digit',
    year: 'numeric',
  }).format(new Date(dateString));
}

function getPaymentMethodLabel(method: string): string {
  const labels: Record<string, string> = {
    stripe_card: 'Kreditkarte (Online)',
    stripe_twint: 'TWINT (Online)',
    card: 'Karte (Terminal)',
    cash: 'Bargeld',
    terminal: 'Kartenterminal',
    voucher: 'Gutschein',
    pay_at_venue: 'Zahlung vor Ort',
    in_person: 'Vor Ort (Termine)',
    unknown: 'Unbekannt',
  };
  return labels[method] || method;
}

function getPaymentMethodIcon(method: string) {
  switch (method) {
    case 'stripe_card':
    case 'card':
    case 'terminal':
      return CreditCard;
    case 'cash':
      return Banknote;
    case 'voucher':
      return Wallet;
    default:
      return CreditCard;
  }
}

// ============================================
// COMPONENT
// ============================================

export function AdminFinanceView({
  stats,
  paymentMethods,
  vatSummary,
  dailySales,
}: AdminFinanceViewProps) {
  const [isExporting, setIsExporting] = useState(false);

  const totalPaymentAmount = paymentMethods.reduce((sum, p) => sum + p.totalCents, 0);

  // Export accounting CSV
  const handleExportAccounting = () => {
    setIsExporting(true);

    try {
      // Generate detailed CSV for accounting
      const headers = [
        'Datum',
        'Bestellungen',
        'Termine',
        'Bestellungen (CHF)',
        'Termine (CHF)',
        'Gesamt (CHF)',
      ];

      const rows = dailySales.map((d) => [
        d.date,
        d.orderCount.toString(),
        d.appointmentCount.toString(),
        (d.orderRevenue / 100).toFixed(2),
        (d.appointmentRevenue / 100).toFixed(2),
        (d.totalRevenue / 100).toFixed(2),
      ]);

      // Add summary rows
      rows.push([]);
      rows.push(['ZUSAMMENFASSUNG', '', '', '', '', '']);
      rows.push(['Bruttoumsatz', '', '', '', '', (vatSummary.grossCents / 100).toFixed(2)]);
      rows.push([
        `MwSt (${vatSummary.vatRate}%)`,
        '',
        '',
        '',
        '',
        (vatSummary.vatCents / 100).toFixed(2),
      ]);
      rows.push(['Nettoumsatz', '', '', '', '', (vatSummary.netCents / 100).toFixed(2)]);
      rows.push(['Rückerstattungen', '', '', '', '', (stats.totalRefunds / 100).toFixed(2)]);
      rows.push(['Netto nach Erstattungen', '', '', '', '', (stats.netRevenue / 100).toFixed(2)]);

      const csvContent = [headers, ...rows]
        .map((row) => row.map((cell) => `"${cell}"`).join(','))
        .join('\n');

      const blob = new Blob([csvContent], { type: 'text/csv;charset=utf-8;' });
      const url = URL.createObjectURL(blob);
      const link = document.createElement('a');
      link.href = url;
      link.download = `buchhaltung-${formatDate(stats.periodStart)}-${formatDate(stats.periodEnd)}.csv`;
      link.click();
      URL.revokeObjectURL(url);

      toast.success('Buchhaltungs-Export erstellt');
    } catch (error) {
      toast.error('Fehler beim Export');
    } finally {
      setIsExporting(false);
    }
  };

  // Export VAT report
  const handleExportVat = () => {
    const content = `MEHRWERTSTEUER-ÜBERSICHT
========================
Zeitraum: ${formatDate(stats.periodStart)} - ${formatDate(stats.periodEnd)}

Bruttoumsatz:     ${formatPrice(vatSummary.grossCents)}
MwSt-Satz:        ${vatSummary.vatRate}%
MwSt-Betrag:      ${formatPrice(vatSummary.vatCents)}
Nettoumsatz:      ${formatPrice(vatSummary.netCents)}

Rückerstattungen: ${formatPrice(stats.totalRefunds)}
Netto-Ergebnis:   ${formatPrice(stats.netRevenue)}

---
Erstellt am: ${formatDate(new Date().toISOString())}
    `.trim();

    const blob = new Blob([content], { type: 'text/plain;charset=utf-8;' });
    const url = URL.createObjectURL(blob);
    const link = document.createElement('a');
    link.href = url;
    link.download = `mwst-${formatDate(stats.periodStart)}-${formatDate(stats.periodEnd)}.txt`;
    link.click();
    URL.revokeObjectURL(url);

    toast.success('MwSt-Export erstellt');
  };

  return (
    <div className="space-y-6">
      {/* Header */}
      <div className="flex items-center justify-between">
        <div>
          <h1 className="text-2xl font-bold">Finanzen</h1>
          <p className="text-muted-foreground">
            Zeitraum: {formatDate(stats.periodStart)} - {formatDate(stats.periodEnd)}
          </p>
        </div>
        <div className="flex gap-2">
          <Button variant="outline" onClick={handleExportVat}>
            <Receipt className="mr-2 h-4 w-4" />
            MwSt-Export
          </Button>
          <Button onClick={handleExportAccounting} disabled={isExporting}>
            <FileSpreadsheet className="mr-2 h-4 w-4" />
            Buchhaltung
          </Button>
        </div>
      </div>

      {/* Stats Cards */}
      <div className="grid gap-4 md:grid-cols-4">
        <Card>
          <CardHeader className="flex flex-row items-center justify-between space-y-0 pb-2">
            <CardTitle className="text-sm font-medium">Bruttoumsatz</CardTitle>
            <TrendingUp className="text-muted-foreground h-4 w-4" />
          </CardHeader>
          <CardContent>
            <div className="text-2xl font-bold">{formatPrice(stats.totalRevenue)}</div>
            <p className="text-muted-foreground text-xs">
              {stats.totalOrders} Bestellungen, {stats.totalAppointments} Termine
            </p>
          </CardContent>
        </Card>

        <Card>
          <CardHeader className="flex flex-row items-center justify-between space-y-0 pb-2">
            <CardTitle className="text-sm font-medium">MwSt ({vatSummary.vatRate}%)</CardTitle>
            <Building className="text-muted-foreground h-4 w-4" />
          </CardHeader>
          <CardContent>
            <div className="text-2xl font-bold">{formatPrice(vatSummary.vatCents)}</div>
            <p className="text-muted-foreground text-xs">abzuführen</p>
          </CardContent>
        </Card>

        <Card>
          <CardHeader className="flex flex-row items-center justify-between space-y-0 pb-2">
            <CardTitle className="text-sm font-medium">Rückerstattungen</CardTitle>
            <Receipt className="h-4 w-4 text-red-500" />
          </CardHeader>
          <CardContent>
            <div className="text-2xl font-bold text-red-600">
              -{formatPrice(stats.totalRefunds)}
            </div>
            <p className="text-muted-foreground text-xs">erstattet</p>
          </CardContent>
        </Card>

        <Card>
          <CardHeader className="flex flex-row items-center justify-between space-y-0 pb-2">
            <CardTitle className="text-sm font-medium">Netto-Ergebnis</CardTitle>
            <Wallet className="h-4 w-4 text-green-500" />
          </CardHeader>
          <CardContent>
            <div className="text-2xl font-bold text-green-600">{formatPrice(stats.netRevenue)}</div>
            <p className="text-muted-foreground text-xs">nach Erstattungen</p>
          </CardContent>
        </Card>
      </div>

      <div className="grid gap-6 md:grid-cols-2">
        {/* Payment Methods */}
        <Card>
          <CardHeader>
            <CardTitle>Umsatz nach Zahlungsart</CardTitle>
            <CardDescription>Aufschlüsselung der Zahlungsmethoden</CardDescription>
          </CardHeader>
          <CardContent className="space-y-4">
            {paymentMethods.length === 0 ? (
              <p className="text-muted-foreground py-8 text-center">
                Keine Zahlungen in diesem Zeitraum
              </p>
            ) : (
              paymentMethods.map((pm) => {
                const Icon = getPaymentMethodIcon(pm.method);
                const percentage =
                  totalPaymentAmount > 0
                    ? Math.round((pm.totalCents / totalPaymentAmount) * 100)
                    : 0;

                return (
                  <div key={pm.method} className="space-y-2">
                    <div className="flex items-center justify-between">
                      <div className="flex items-center gap-2">
                        <Icon className="text-muted-foreground h-4 w-4" />
                        <span className="font-medium">{getPaymentMethodLabel(pm.method)}</span>
                        <span className="text-muted-foreground text-sm">({pm.count}x)</span>
                      </div>
                      <span className="font-medium">{formatPrice(pm.totalCents)}</span>
                    </div>
                    <Progress value={percentage} className="h-2" />
                  </div>
                );
              })
            )}
          </CardContent>
        </Card>

        {/* VAT Summary */}
        <Card>
          <CardHeader>
            <CardTitle>MwSt-Übersicht</CardTitle>
            <CardDescription>Mehrwertsteuer-Berechnung (Schweiz)</CardDescription>
          </CardHeader>
          <CardContent>
            <Table>
              <TableBody>
                <TableRow>
                  <TableCell className="font-medium">Bruttoumsatz</TableCell>
                  <TableCell className="text-right">{formatPrice(vatSummary.grossCents)}</TableCell>
                </TableRow>
                <TableRow>
                  <TableCell className="font-medium">MwSt-Satz</TableCell>
                  <TableCell className="text-right">{vatSummary.vatRate}%</TableCell>
                </TableRow>
                <TableRow>
                  <TableCell className="font-medium">MwSt-Betrag</TableCell>
                  <TableCell className="text-muted-foreground text-right">
                    {formatPrice(vatSummary.vatCents)}
                  </TableCell>
                </TableRow>
                <TableRow>
                  <TableCell colSpan={2}>
                    <Separator />
                  </TableCell>
                </TableRow>
                <TableRow>
                  <TableCell className="font-medium">Nettoumsatz</TableCell>
                  <TableCell className="text-right font-bold">
                    {formatPrice(vatSummary.netCents)}
                  </TableCell>
                </TableRow>
              </TableBody>
            </Table>

            <div className="bg-muted mt-4 rounded-lg p-4">
              <p className="text-muted-foreground text-sm">
                Die MwSt wird nach dem Schweizer Normalsatz von {vatSummary.vatRate}% berechnet. Für
                den offiziellen MwSt-Ausweis verwenden Sie bitte den MwSt-Export.
              </p>
            </div>
          </CardContent>
        </Card>
      </div>

      {/* Daily Sales Table */}
      <Card>
        <CardHeader>
          <CardTitle>Tagesumsätze</CardTitle>
          <CardDescription>Detaillierte Aufstellung nach Tag</CardDescription>
        </CardHeader>
        <CardContent>
          <div className="max-h-96 overflow-auto">
            <Table>
              <TableHeader>
                <TableRow>
                  <TableHead>Datum</TableHead>
                  <TableHead className="text-right">Bestellungen</TableHead>
                  <TableHead className="text-right">Termine</TableHead>
                  <TableHead className="text-right">Shop-Umsatz</TableHead>
                  <TableHead className="text-right">Termin-Umsatz</TableHead>
                  <TableHead className="text-right">Gesamt</TableHead>
                </TableRow>
              </TableHeader>
              <TableBody>
                {dailySales
                  .filter((d) => d.totalRevenue > 0)
                  .reverse()
                  .map((day) => (
                    <TableRow key={day.date}>
                      <TableCell className="font-medium">{formatDate(day.date)}</TableCell>
                      <TableCell className="text-right">{day.orderCount}</TableCell>
                      <TableCell className="text-right">{day.appointmentCount}</TableCell>
                      <TableCell className="text-right">{formatPrice(day.orderRevenue)}</TableCell>
                      <TableCell className="text-right">
                        {formatPrice(day.appointmentRevenue)}
                      </TableCell>
                      <TableCell className="text-right font-medium">
                        {formatPrice(day.totalRevenue)}
                      </TableCell>
                    </TableRow>
                  ))}
                {dailySales.filter((d) => d.totalRevenue > 0).length === 0 && (
                  <TableRow>
                    <TableCell colSpan={6} className="h-24 text-center">
                      Keine Umsätze in diesem Zeitraum
                    </TableCell>
                  </TableRow>
                )}
              </TableBody>
            </Table>
          </div>
        </CardContent>
      </Card>
    </div>
  );
}
