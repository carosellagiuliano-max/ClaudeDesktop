'use client';

import { useState } from 'react';
import {
  Download,
  Upload,
  FileSpreadsheet,
  Users,
  Calendar,
  Package,
  ShoppingBag,
  Receipt,
  Star,
  Loader2,
  AlertCircle,
  CheckCircle,
} from 'lucide-react';
import { Button } from '@/components/ui/button';
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from '@/components/ui/card';
import {
  Select,
  SelectContent,
  SelectItem,
  SelectTrigger,
  SelectValue,
} from '@/components/ui/select';
import { Input } from '@/components/ui/input';
import { Label } from '@/components/ui/label';
import { Separator } from '@/components/ui/separator';
import {
  Dialog,
  DialogContent,
  DialogDescription,
  DialogFooter,
  DialogHeader,
  DialogTitle,
} from '@/components/ui/dialog';
import { Alert, AlertDescription, AlertTitle } from '@/components/ui/alert';
import { toast } from 'sonner';

// ============================================
// TYPES
// ============================================

interface ExportOption {
  id: string;
  name: string;
  description: string;
  icon: React.ElementType;
  endpoint: string;
  filters?: {
    dateRange?: boolean;
    status?: string[];
  };
}

// ============================================
// EXPORT OPTIONS
// ============================================

const exportOptions: ExportOption[] = [
  {
    id: 'customers',
    name: 'Kunden',
    description: 'Kundendaten inkl. Kontaktinformationen',
    icon: Users,
    endpoint: '/api/admin/export/customers',
    filters: { dateRange: true },
  },
  {
    id: 'appointments',
    name: 'Termine',
    description: 'Alle Termine mit Details',
    icon: Calendar,
    endpoint: '/api/admin/export/appointments',
    filters: {
      dateRange: true,
      status: ['pending', 'confirmed', 'completed', 'cancelled', 'no_show'],
    },
  },
  {
    id: 'orders',
    name: 'Bestellungen',
    description: 'Shop-Bestellungen und Umsätze',
    icon: ShoppingBag,
    endpoint: '/api/admin/export/orders',
    filters: {
      dateRange: true,
      status: ['pending', 'processing', 'shipped', 'delivered', 'cancelled', 'refunded'],
    },
  },
  {
    id: 'products',
    name: 'Produkte',
    description: 'Produktkatalog mit Preisen und Bestand',
    icon: Package,
    endpoint: '/api/admin/export/products',
  },
  {
    id: 'services',
    name: 'Dienstleistungen',
    description: 'Alle Services mit Preisen und Dauer',
    icon: FileSpreadsheet,
    endpoint: '/api/admin/export/services',
  },
  {
    id: 'transactions',
    name: 'Transaktionen',
    description: 'Zahlungstransaktionen für Buchhaltung',
    icon: Receipt,
    endpoint: '/api/admin/export/transactions',
    filters: { dateRange: true },
  },
  {
    id: 'loyalty',
    name: 'Treuepunkte',
    description: 'Punktekonten und Transaktionen',
    icon: Star,
    endpoint: '/api/admin/export/loyalty',
  },
];

// ============================================
// COMPONENT
// ============================================

export function AdminExportView() {
  const [selectedExport, setSelectedExport] = useState<ExportOption | null>(null);
  const [dateFrom, setDateFrom] = useState('');
  const [dateTo, setDateTo] = useState('');
  const [statusFilter, setStatusFilter] = useState<string>('all');
  const [isExporting, setIsExporting] = useState(false);

  // Import state
  const [isImportDialogOpen, setIsImportDialogOpen] = useState(false);
  const [importType, setImportType] = useState<string>('');
  const [importFile, setImportFile] = useState<File | null>(null);
  const [isImporting, setIsImporting] = useState(false);
  const [importResult, setImportResult] = useState<{
    success: boolean;
    message: string;
    imported?: number;
    errors?: string[];
  } | null>(null);

  // Handle export
  const handleExport = async (option: ExportOption) => {
    setIsExporting(true);
    setSelectedExport(option);

    try {
      const params = new URLSearchParams();
      if (dateFrom) params.append('from', dateFrom);
      if (dateTo) params.append('to', dateTo);
      if (statusFilter && statusFilter !== 'all') params.append('status', statusFilter);

      const response = await fetch(`${option.endpoint}?${params.toString()}`);

      if (!response.ok) {
        throw new Error('Export fehlgeschlagen');
      }

      const blob = await response.blob();
      const url = window.URL.createObjectURL(blob);
      const a = document.createElement('a');
      a.href = url;
      a.download = `${option.id}_${new Date().toISOString().split('T')[0]}.csv`;
      document.body.appendChild(a);
      a.click();
      window.URL.revokeObjectURL(url);
      a.remove();

      toast.success(`${option.name} exportiert`);
    } catch (error) {
      toast.error('Export fehlgeschlagen');
    } finally {
      setIsExporting(false);
      setSelectedExport(null);
    }
  };

  // Handle import
  const handleImport = async () => {
    if (!importFile || !importType) {
      toast.error('Bitte Datei und Typ auswählen');
      return;
    }

    setIsImporting(true);
    setImportResult(null);

    try {
      const formData = new FormData();
      formData.append('file', importFile);
      formData.append('type', importType);

      const response = await fetch('/api/admin/import', {
        method: 'POST',
        body: formData,
      });

      const result = await response.json();

      if (!response.ok) {
        setImportResult({
          success: false,
          message: result.error || 'Import fehlgeschlagen',
          errors: result.errors,
        });
      } else {
        setImportResult({
          success: true,
          message: 'Import erfolgreich',
          imported: result.imported,
        });
        toast.success(`${result.imported} Einträge importiert`);
      }
    } catch (error) {
      setImportResult({
        success: false,
        message: 'Fehler beim Import',
      });
    } finally {
      setIsImporting(false);
    }
  };

  return (
    <div className="space-y-6">
      {/* Header */}
      <div className="flex items-center justify-between">
        <div>
          <h1 className="text-2xl font-bold">Datenexport</h1>
          <p className="text-muted-foreground">
            Exportieren und importieren Sie Daten im CSV-Format
          </p>
        </div>
        <Button variant="outline" onClick={() => setIsImportDialogOpen(true)}>
          <Upload className="mr-2 h-4 w-4" />
          Daten importieren
        </Button>
      </div>

      {/* Date Range Filter */}
      <Card>
        <CardHeader>
          <CardTitle>Filter</CardTitle>
          <CardDescription>Optionale Filter für den Export</CardDescription>
        </CardHeader>
        <CardContent>
          <div className="grid gap-4 md:grid-cols-3">
            <div className="space-y-2">
              <Label htmlFor="dateFrom">Von Datum</Label>
              <Input
                id="dateFrom"
                type="date"
                value={dateFrom}
                onChange={(e) => setDateFrom(e.target.value)}
              />
            </div>
            <div className="space-y-2">
              <Label htmlFor="dateTo">Bis Datum</Label>
              <Input
                id="dateTo"
                type="date"
                value={dateTo}
                onChange={(e) => setDateTo(e.target.value)}
              />
            </div>
            <div className="space-y-2">
              <Label htmlFor="status">Status</Label>
              <Select value={statusFilter} onValueChange={setStatusFilter}>
                <SelectTrigger id="status">
                  <SelectValue placeholder="Alle" />
                </SelectTrigger>
                <SelectContent>
                  <SelectItem value="all">Alle</SelectItem>
                  <SelectItem value="pending">Ausstehend</SelectItem>
                  <SelectItem value="confirmed">Bestätigt</SelectItem>
                  <SelectItem value="completed">Abgeschlossen</SelectItem>
                  <SelectItem value="cancelled">Storniert</SelectItem>
                </SelectContent>
              </Select>
            </div>
          </div>
        </CardContent>
      </Card>

      {/* Export Options */}
      <div className="grid gap-4 md:grid-cols-2 lg:grid-cols-3">
        {exportOptions.map((option) => {
          const Icon = option.icon;
          const isCurrentlyExporting = isExporting && selectedExport?.id === option.id;

          return (
            <Card key={option.id} className="hover:border-primary/50 transition-colors">
              <CardHeader>
                <div className="flex items-start justify-between">
                  <div className="p-2 bg-primary/10 rounded-lg">
                    <Icon className="h-6 w-6 text-primary" />
                  </div>
                </div>
                <CardTitle className="text-lg">{option.name}</CardTitle>
                <CardDescription>{option.description}</CardDescription>
              </CardHeader>
              <CardContent>
                <Button
                  className="w-full"
                  onClick={() => handleExport(option)}
                  disabled={isExporting}
                >
                  {isCurrentlyExporting ? (
                    <>
                      <Loader2 className="mr-2 h-4 w-4 animate-spin" />
                      Exportieren...
                    </>
                  ) : (
                    <>
                      <Download className="mr-2 h-4 w-4" />
                      Als CSV exportieren
                    </>
                  )}
                </Button>
              </CardContent>
            </Card>
          );
        })}
      </div>

      {/* Import Dialog */}
      <Dialog open={isImportDialogOpen} onOpenChange={setIsImportDialogOpen}>
        <DialogContent className="sm:max-w-md">
          <DialogHeader>
            <DialogTitle>Daten importieren</DialogTitle>
            <DialogDescription>
              Laden Sie eine CSV-Datei hoch, um Daten zu importieren
            </DialogDescription>
          </DialogHeader>
          <div className="space-y-4 py-4">
            <div className="space-y-2">
              <Label htmlFor="importType">Import-Typ</Label>
              <Select value={importType} onValueChange={setImportType}>
                <SelectTrigger id="importType">
                  <SelectValue placeholder="Typ auswählen" />
                </SelectTrigger>
                <SelectContent>
                  <SelectItem value="customers">Kunden</SelectItem>
                  <SelectItem value="products">Produkte</SelectItem>
                  <SelectItem value="services">Dienstleistungen</SelectItem>
                </SelectContent>
              </Select>
            </div>
            <div className="space-y-2">
              <Label htmlFor="importFile">CSV-Datei</Label>
              <Input
                id="importFile"
                type="file"
                accept=".csv"
                onChange={(e) => setImportFile(e.target.files?.[0] || null)}
              />
              <p className="text-xs text-muted-foreground">
                Die erste Zeile muss die Spaltenüberschriften enthalten
              </p>
            </div>

            {importResult && (
              <Alert variant={importResult.success ? 'default' : 'destructive'}>
                {importResult.success ? (
                  <CheckCircle className="h-4 w-4" />
                ) : (
                  <AlertCircle className="h-4 w-4" />
                )}
                <AlertTitle>
                  {importResult.success ? 'Import erfolgreich' : 'Import fehlgeschlagen'}
                </AlertTitle>
                <AlertDescription>
                  {importResult.message}
                  {importResult.imported && (
                    <p className="mt-1">{importResult.imported} Einträge importiert</p>
                  )}
                  {importResult.errors && importResult.errors.length > 0 && (
                    <ul className="mt-2 list-disc pl-4 text-sm">
                      {importResult.errors.slice(0, 5).map((err, i) => (
                        <li key={i}>{err}</li>
                      ))}
                      {importResult.errors.length > 5 && (
                        <li>...und {importResult.errors.length - 5} weitere Fehler</li>
                      )}
                    </ul>
                  )}
                </AlertDescription>
              </Alert>
            )}
          </div>
          <DialogFooter>
            <Button variant="outline" onClick={() => setIsImportDialogOpen(false)}>
              Abbrechen
            </Button>
            <Button
              onClick={handleImport}
              disabled={isImporting || !importFile || !importType}
            >
              {isImporting ? (
                <>
                  <Loader2 className="mr-2 h-4 w-4 animate-spin" />
                  Importieren...
                </>
              ) : (
                <>
                  <Upload className="mr-2 h-4 w-4" />
                  Importieren
                </>
              )}
            </Button>
          </DialogFooter>
        </DialogContent>
      </Dialog>
    </div>
  );
}
