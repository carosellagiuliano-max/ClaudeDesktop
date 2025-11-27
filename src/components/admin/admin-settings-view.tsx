'use client';

import { useState } from 'react';
import {
  Save,
  Building,
  Clock,
  CreditCard,
  Mail,
  Globe,
  Scissors,
  Plus,
  Edit,
  Trash2,
  CalendarClock,
  Percent,
  Receipt,
} from 'lucide-react';
import { Button } from '@/components/ui/button';
import { Input } from '@/components/ui/input';
import { Label } from '@/components/ui/label';
import { Textarea } from '@/components/ui/textarea';
import { Card, CardContent, CardHeader, CardTitle, CardDescription } from '@/components/ui/card';
import { Badge } from '@/components/ui/badge';
import { Tabs, TabsContent, TabsList, TabsTrigger } from '@/components/ui/tabs';
import { Switch } from '@/components/ui/switch';
import {
  Table,
  TableBody,
  TableCell,
  TableHead,
  TableHeader,
  TableRow,
} from '@/components/ui/table';

// ============================================
// TYPES
// ============================================

interface Salon {
  id: string;
  name: string;
  slug: string;
  email: string | null;
  phone: string | null;
  address: string | null;
  city: string | null;
  postal_code: string | null;
  website: string | null;
  description: string | null;
  opening_hours: Record<string, unknown> | null;
  is_active: boolean;
}

interface Service {
  id: string;
  name: string;
  description: string | null;
  duration_minutes: number;
  price_cents: number;
  category: string | null;
  is_active: boolean;
}

interface AdminSettingsViewProps {
  salon: Salon | null;
  services: Service[];
}

// ============================================
// CONSTANTS
// ============================================

const weekDays = [
  { key: 'monday', label: 'Montag' },
  { key: 'tuesday', label: 'Dienstag' },
  { key: 'wednesday', label: 'Mittwoch' },
  { key: 'thursday', label: 'Donnerstag' },
  { key: 'friday', label: 'Freitag' },
  { key: 'saturday', label: 'Samstag' },
  { key: 'sunday', label: 'Sonntag' },
];

// ============================================
// HELPERS
// ============================================

function formatCurrency(cents: number): string {
  return new Intl.NumberFormat('de-CH', {
    style: 'currency',
    currency: 'CHF',
  }).format(cents / 100);
}

// ============================================
// ADMIN SETTINGS VIEW
// ============================================

export function AdminSettingsView({ salon, services }: AdminSettingsViewProps) {
  const [isSaving, setIsSaving] = useState(false);

  // Booking rules state
  const [bookingRules, setBookingRules] = useState({
    minNoticeHours: 24,
    maxAdvanceDays: 90,
    bufferMinutes: 15,
    allowSameDayBooking: false,
    requirePhoneForBooking: true,
  });

  // VAT settings state
  const [vatSettings, setVatSettings] = useState({
    vatRate: 8.1,
    showVatOnInvoice: true,
    vatNumber: '',
  });

  // Deposit settings state
  const [depositSettings, setDepositSettings] = useState({
    requireDeposit: false,
    depositPercent: 20,
    depositMinAmount: 2000, // cents
    refundableUntilHours: 48,
  });

  const handleSave = async () => {
    setIsSaving(true);
    // TODO: Implement save functionality
    await new Promise((resolve) => setTimeout(resolve, 1000));
    setIsSaving(false);
  };

  return (
    <Tabs defaultValue="general" className="space-y-6">
      <TabsList className="flex-wrap h-auto gap-1">
        <TabsTrigger value="general">
          <Building className="h-4 w-4 mr-2" />
          Allgemein
        </TabsTrigger>
        <TabsTrigger value="hours">
          <Clock className="h-4 w-4 mr-2" />
          Öffnungszeiten
        </TabsTrigger>
        <TabsTrigger value="booking">
          <CalendarClock className="h-4 w-4 mr-2" />
          Buchungsregeln
        </TabsTrigger>
        <TabsTrigger value="services">
          <Scissors className="h-4 w-4 mr-2" />
          Leistungen
        </TabsTrigger>
        <TabsTrigger value="payments">
          <CreditCard className="h-4 w-4 mr-2" />
          Zahlungen
        </TabsTrigger>
        <TabsTrigger value="notifications">
          <Mail className="h-4 w-4 mr-2" />
          Benachrichtigungen
        </TabsTrigger>
      </TabsList>

      {/* General Settings */}
      <TabsContent value="general">
        <Card>
          <CardHeader>
            <CardTitle>Salon-Informationen</CardTitle>
            <CardDescription>
              Grundlegende Informationen über Ihren Salon
            </CardDescription>
          </CardHeader>
          <CardContent className="space-y-4">
            <div className="grid gap-4 md:grid-cols-2">
              <div className="space-y-2">
                <Label htmlFor="name">Salon Name</Label>
                <Input
                  id="name"
                  defaultValue={salon?.name || ''}
                  placeholder="SCHNITTWERK"
                />
              </div>
              <div className="space-y-2">
                <Label htmlFor="email">E-Mail</Label>
                <Input
                  id="email"
                  type="email"
                  defaultValue={salon?.email || ''}
                  placeholder="kontakt@salon.ch"
                />
              </div>
              <div className="space-y-2">
                <Label htmlFor="phone">Telefon</Label>
                <Input
                  id="phone"
                  defaultValue={salon?.phone || ''}
                  placeholder="+41 71 123 45 67"
                />
              </div>
              <div className="space-y-2">
                <Label htmlFor="website">Website</Label>
                <Input
                  id="website"
                  defaultValue={salon?.website || ''}
                  placeholder="https://www.salon.ch"
                />
              </div>
            </div>

            <div className="space-y-2">
              <Label htmlFor="address">Adresse</Label>
              <Input
                id="address"
                defaultValue={salon?.address || ''}
                placeholder="Musterstrasse 1"
              />
            </div>

            <div className="grid gap-4 md:grid-cols-2">
              <div className="space-y-2">
                <Label htmlFor="postal_code">PLZ</Label>
                <Input
                  id="postal_code"
                  defaultValue={salon?.postal_code || ''}
                  placeholder="9000"
                />
              </div>
              <div className="space-y-2">
                <Label htmlFor="city">Stadt</Label>
                <Input
                  id="city"
                  defaultValue={salon?.city || ''}
                  placeholder="St. Gallen"
                />
              </div>
            </div>

            <div className="space-y-2">
              <Label htmlFor="description">Beschreibung</Label>
              <Textarea
                id="description"
                defaultValue={salon?.description || ''}
                placeholder="Kurze Beschreibung des Salons..."
                rows={4}
              />
            </div>

            <div className="flex justify-end">
              <Button onClick={handleSave} disabled={isSaving}>
                <Save className="h-4 w-4 mr-2" />
                {isSaving ? 'Speichern...' : 'Speichern'}
              </Button>
            </div>
          </CardContent>
        </Card>
      </TabsContent>

      {/* Opening Hours */}
      <TabsContent value="hours">
        <Card>
          <CardHeader>
            <CardTitle>Öffnungszeiten</CardTitle>
            <CardDescription>
              Legen Sie die Öffnungszeiten Ihres Salons fest
            </CardDescription>
          </CardHeader>
          <CardContent>
            <div className="space-y-4">
              {weekDays.map((day) => (
                <div
                  key={day.key}
                  className="flex items-center justify-between py-2 border-b last:border-0"
                >
                  <div className="flex items-center gap-4">
                    <Switch id={`${day.key}-open`} defaultChecked={day.key !== 'sunday'} />
                    <Label htmlFor={`${day.key}-open`} className="w-24">
                      {day.label}
                    </Label>
                  </div>
                  <div className="flex items-center gap-2">
                    <Input
                      type="time"
                      defaultValue="09:00"
                      className="w-28"
                    />
                    <span className="text-muted-foreground">bis</span>
                    <Input
                      type="time"
                      defaultValue="18:00"
                      className="w-28"
                    />
                  </div>
                </div>
              ))}
            </div>
            <div className="flex justify-end mt-6">
              <Button onClick={handleSave} disabled={isSaving}>
                <Save className="h-4 w-4 mr-2" />
                {isSaving ? 'Speichern...' : 'Speichern'}
              </Button>
            </div>
          </CardContent>
        </Card>
      </TabsContent>

      {/* Booking Rules */}
      <TabsContent value="booking">
        <div className="space-y-6">
          {/* Booking Time Rules */}
          <Card>
            <CardHeader>
              <CardTitle>Zeitliche Regeln</CardTitle>
              <CardDescription>
                Legen Sie fest, wann Kunden Termine buchen können
              </CardDescription>
            </CardHeader>
            <CardContent className="space-y-6">
              <div className="grid gap-4 md:grid-cols-2">
                <div className="space-y-2">
                  <Label htmlFor="minNotice">Mindestvorlaufzeit (Stunden)</Label>
                  <Input
                    id="minNotice"
                    type="number"
                    min="0"
                    max="168"
                    value={bookingRules.minNoticeHours}
                    onChange={(e) =>
                      setBookingRules({
                        ...bookingRules,
                        minNoticeHours: parseInt(e.target.value) || 0,
                      })
                    }
                  />
                  <p className="text-xs text-muted-foreground">
                    Wie viele Stunden im Voraus muss gebucht werden?
                  </p>
                </div>
                <div className="space-y-2">
                  <Label htmlFor="maxAdvance">Max. Vorausbuchung (Tage)</Label>
                  <Input
                    id="maxAdvance"
                    type="number"
                    min="1"
                    max="365"
                    value={bookingRules.maxAdvanceDays}
                    onChange={(e) =>
                      setBookingRules({
                        ...bookingRules,
                        maxAdvanceDays: parseInt(e.target.value) || 30,
                      })
                    }
                  />
                  <p className="text-xs text-muted-foreground">
                    Wie weit im Voraus können Termine gebucht werden?
                  </p>
                </div>
                <div className="space-y-2">
                  <Label htmlFor="buffer">Pufferzeit zwischen Terminen (Min.)</Label>
                  <Input
                    id="buffer"
                    type="number"
                    min="0"
                    max="60"
                    step="5"
                    value={bookingRules.bufferMinutes}
                    onChange={(e) =>
                      setBookingRules({
                        ...bookingRules,
                        bufferMinutes: parseInt(e.target.value) || 0,
                      })
                    }
                  />
                  <p className="text-xs text-muted-foreground">
                    Zeit zwischen zwei aufeinanderfolgenden Terminen
                  </p>
                </div>
              </div>

              <div className="space-y-4 pt-4 border-t">
                <div className="flex items-center justify-between p-3 border rounded-lg">
                  <div>
                    <p className="font-medium">Same-Day Buchungen</p>
                    <p className="text-sm text-muted-foreground">
                      Termine am selben Tag erlauben
                    </p>
                  </div>
                  <Switch
                    checked={bookingRules.allowSameDayBooking}
                    onCheckedChange={(checked) =>
                      setBookingRules({ ...bookingRules, allowSameDayBooking: checked })
                    }
                  />
                </div>
                <div className="flex items-center justify-between p-3 border rounded-lg">
                  <div>
                    <p className="font-medium">Telefonnummer erforderlich</p>
                    <p className="text-sm text-muted-foreground">
                      Kunden müssen eine Telefonnummer angeben
                    </p>
                  </div>
                  <Switch
                    checked={bookingRules.requirePhoneForBooking}
                    onCheckedChange={(checked) =>
                      setBookingRules({ ...bookingRules, requirePhoneForBooking: checked })
                    }
                  />
                </div>
              </div>

              <div className="flex justify-end">
                <Button onClick={handleSave} disabled={isSaving}>
                  <Save className="h-4 w-4 mr-2" />
                  {isSaving ? 'Speichern...' : 'Speichern'}
                </Button>
              </div>
            </CardContent>
          </Card>

          {/* Deposit Settings */}
          <Card>
            <CardHeader>
              <CardTitle>Anzahlungen</CardTitle>
              <CardDescription>
                Konfigurieren Sie Anzahlungen für Terminbuchungen
              </CardDescription>
            </CardHeader>
            <CardContent className="space-y-6">
              <div className="flex items-center justify-between p-3 border rounded-lg">
                <div>
                  <p className="font-medium">Anzahlung aktivieren</p>
                  <p className="text-sm text-muted-foreground">
                    Kunden müssen bei der Buchung eine Anzahlung leisten
                  </p>
                </div>
                <Switch
                  checked={depositSettings.requireDeposit}
                  onCheckedChange={(checked) =>
                    setDepositSettings({ ...depositSettings, requireDeposit: checked })
                  }
                />
              </div>

              {depositSettings.requireDeposit && (
                <div className="grid gap-4 md:grid-cols-2 animate-in fade-in slide-in-from-top-2">
                  <div className="space-y-2">
                    <Label htmlFor="depositPercent">Anzahlung (%)</Label>
                    <Input
                      id="depositPercent"
                      type="number"
                      min="1"
                      max="100"
                      value={depositSettings.depositPercent}
                      onChange={(e) =>
                        setDepositSettings({
                          ...depositSettings,
                          depositPercent: parseInt(e.target.value) || 20,
                        })
                      }
                    />
                    <p className="text-xs text-muted-foreground">
                      Prozentsatz des Terminpreises
                    </p>
                  </div>
                  <div className="space-y-2">
                    <Label htmlFor="depositMin">Mindestanzahlung (CHF)</Label>
                    <Input
                      id="depositMin"
                      type="number"
                      min="0"
                      step="0.5"
                      value={depositSettings.depositMinAmount / 100}
                      onChange={(e) =>
                        setDepositSettings({
                          ...depositSettings,
                          depositMinAmount: Math.round(parseFloat(e.target.value) * 100) || 0,
                        })
                      }
                    />
                    <p className="text-xs text-muted-foreground">
                      Mindestbetrag für Anzahlung
                    </p>
                  </div>
                  <div className="space-y-2 md:col-span-2">
                    <Label htmlFor="refundHours">Rückerstattungsfrist (Stunden)</Label>
                    <Input
                      id="refundHours"
                      type="number"
                      min="0"
                      max="168"
                      value={depositSettings.refundableUntilHours}
                      onChange={(e) =>
                        setDepositSettings({
                          ...depositSettings,
                          refundableUntilHours: parseInt(e.target.value) || 24,
                        })
                      }
                    />
                    <p className="text-xs text-muted-foreground">
                      Bis wie viele Stunden vor dem Termin ist eine vollständige Rückerstattung möglich?
                    </p>
                  </div>
                </div>
              )}

              <div className="flex justify-end">
                <Button onClick={handleSave} disabled={isSaving}>
                  <Save className="h-4 w-4 mr-2" />
                  {isSaving ? 'Speichern...' : 'Speichern'}
                </Button>
              </div>
            </CardContent>
          </Card>
        </div>
      </TabsContent>

      {/* Services */}
      <TabsContent value="services">
        <Card>
          <CardHeader className="flex flex-row items-center justify-between">
            <div>
              <CardTitle>Leistungen</CardTitle>
              <CardDescription>
                Verwalten Sie die angebotenen Dienstleistungen
              </CardDescription>
            </div>
            <Button>
              <Plus className="h-4 w-4 mr-2" />
              Neue Leistung
            </Button>
          </CardHeader>
          <CardContent className="p-0">
            <Table>
              <TableHeader>
                <TableRow>
                  <TableHead>Name</TableHead>
                  <TableHead>Kategorie</TableHead>
                  <TableHead className="text-center">Dauer</TableHead>
                  <TableHead className="text-right">Preis</TableHead>
                  <TableHead>Status</TableHead>
                  <TableHead className="w-[80px]"></TableHead>
                </TableRow>
              </TableHeader>
              <TableBody>
                {services.length === 0 ? (
                  <TableRow>
                    <TableCell colSpan={6} className="text-center py-8">
                      <p className="text-muted-foreground">
                        Keine Leistungen vorhanden
                      </p>
                    </TableCell>
                  </TableRow>
                ) : (
                  services.map((service) => (
                    <TableRow key={service.id}>
                      <TableCell>
                        <div>
                          <p className="font-medium">{service.name}</p>
                          {service.description && (
                            <p className="text-xs text-muted-foreground line-clamp-1">
                              {service.description}
                            </p>
                          )}
                        </div>
                      </TableCell>
                      <TableCell>
                        {service.category && (
                          <Badge variant="secondary">{service.category}</Badge>
                        )}
                      </TableCell>
                      <TableCell className="text-center">
                        {service.duration_minutes} Min.
                      </TableCell>
                      <TableCell className="text-right font-medium">
                        {formatCurrency(service.price_cents)}
                      </TableCell>
                      <TableCell>
                        <Badge variant={service.is_active ? 'default' : 'outline'}>
                          {service.is_active ? 'Aktiv' : 'Inaktiv'}
                        </Badge>
                      </TableCell>
                      <TableCell>
                        <div className="flex items-center gap-1">
                          <Button variant="ghost" size="icon">
                            <Edit className="h-4 w-4" />
                          </Button>
                          <Button variant="ghost" size="icon">
                            <Trash2 className="h-4 w-4" />
                          </Button>
                        </div>
                      </TableCell>
                    </TableRow>
                  ))
                )}
              </TableBody>
            </Table>
          </CardContent>
        </Card>
      </TabsContent>

      {/* Payments */}
      <TabsContent value="payments">
        <div className="space-y-6">
          {/* Stripe Settings */}
          <Card>
            <CardHeader>
              <CardTitle>Zahlungseinstellungen</CardTitle>
              <CardDescription>
                Konfigurieren Sie die Zahlungsmethoden
              </CardDescription>
            </CardHeader>
            <CardContent className="space-y-6">
              <div className="flex items-center justify-between p-4 border rounded-lg">
                <div className="flex items-center gap-4">
                  <CreditCard className="h-8 w-8 text-primary" />
                  <div>
                    <h4 className="font-medium">Stripe</h4>
                    <p className="text-sm text-muted-foreground">
                      Kreditkarten und TWINT akzeptieren
                    </p>
                  </div>
                </div>
                <div className="flex items-center gap-2">
                  <Badge variant="default">Verbunden</Badge>
                  <Button variant="outline" size="sm">
                    Konfigurieren
                  </Button>
                </div>
              </div>

              <div className="space-y-4">
                <h4 className="font-medium">Akzeptierte Zahlungsmethoden</h4>
                <div className="space-y-2">
                  <div className="flex items-center justify-between p-3 border rounded-lg">
                    <span>Kreditkarten (Visa, Mastercard, Amex)</span>
                    <Switch defaultChecked />
                  </div>
                  <div className="flex items-center justify-between p-3 border rounded-lg">
                    <span>TWINT</span>
                    <Switch defaultChecked />
                  </div>
                  <div className="flex items-center justify-between p-3 border rounded-lg">
                    <span>Bezahlung vor Ort</span>
                    <Switch defaultChecked />
                  </div>
                </div>
              </div>

              <div className="flex justify-end">
                <Button onClick={handleSave} disabled={isSaving}>
                  <Save className="h-4 w-4 mr-2" />
                  {isSaving ? 'Speichern...' : 'Speichern'}
                </Button>
              </div>
            </CardContent>
          </Card>

          {/* VAT Settings */}
          <Card>
            <CardHeader>
              <CardTitle className="flex items-center gap-2">
                <Percent className="h-5 w-5" />
                Mehrwertsteuer (MwSt)
              </CardTitle>
              <CardDescription>
                Konfigurieren Sie die MwSt-Einstellungen für Rechnungen
              </CardDescription>
            </CardHeader>
            <CardContent className="space-y-6">
              <div className="grid gap-4 md:grid-cols-2">
                <div className="space-y-2">
                  <Label htmlFor="vatRate">MwSt-Satz (%)</Label>
                  <Input
                    id="vatRate"
                    type="number"
                    min="0"
                    max="25"
                    step="0.1"
                    value={vatSettings.vatRate}
                    onChange={(e) =>
                      setVatSettings({
                        ...vatSettings,
                        vatRate: parseFloat(e.target.value) || 0,
                      })
                    }
                  />
                  <p className="text-xs text-muted-foreground">
                    Schweizer Normalsatz: 8.1%
                  </p>
                </div>
                <div className="space-y-2">
                  <Label htmlFor="vatNumber">MwSt-Nummer (UID)</Label>
                  <Input
                    id="vatNumber"
                    placeholder="CHE-123.456.789 MWST"
                    value={vatSettings.vatNumber}
                    onChange={(e) =>
                      setVatSettings({ ...vatSettings, vatNumber: e.target.value })
                    }
                  />
                  <p className="text-xs text-muted-foreground">
                    Ihre Unternehmens-Identifikationsnummer
                  </p>
                </div>
              </div>

              <div className="flex items-center justify-between p-3 border rounded-lg">
                <div>
                  <p className="font-medium">MwSt auf Rechnungen anzeigen</p>
                  <p className="text-sm text-muted-foreground">
                    MwSt-Betrag separat auf Rechnungen ausweisen
                  </p>
                </div>
                <Switch
                  checked={vatSettings.showVatOnInvoice}
                  onCheckedChange={(checked) =>
                    setVatSettings({ ...vatSettings, showVatOnInvoice: checked })
                  }
                />
              </div>

              <div className="flex justify-end">
                <Button onClick={handleSave} disabled={isSaving}>
                  <Save className="h-4 w-4 mr-2" />
                  {isSaving ? 'Speichern...' : 'Speichern'}
                </Button>
              </div>
            </CardContent>
          </Card>
        </div>
      </TabsContent>

      {/* Notifications */}
      <TabsContent value="notifications">
        <Card>
          <CardHeader>
            <CardTitle>E-Mail-Benachrichtigungen</CardTitle>
            <CardDescription>
              Konfigurieren Sie automatische Benachrichtigungen
            </CardDescription>
          </CardHeader>
          <CardContent className="space-y-4">
            <div className="space-y-2">
              <div className="flex items-center justify-between p-3 border rounded-lg">
                <div>
                  <p className="font-medium">Terminbestätigung</p>
                  <p className="text-sm text-muted-foreground">
                    E-Mail an Kunden nach Buchung
                  </p>
                </div>
                <Switch defaultChecked />
              </div>
              <div className="flex items-center justify-between p-3 border rounded-lg">
                <div>
                  <p className="font-medium">Terminerinnerung</p>
                  <p className="text-sm text-muted-foreground">
                    24 Stunden vor dem Termin
                  </p>
                </div>
                <Switch defaultChecked />
              </div>
              <div className="flex items-center justify-between p-3 border rounded-lg">
                <div>
                  <p className="font-medium">Bestellbestätigung</p>
                  <p className="text-sm text-muted-foreground">
                    E-Mail nach erfolgreicher Bestellung
                  </p>
                </div>
                <Switch defaultChecked />
              </div>
              <div className="flex items-center justify-between p-3 border rounded-lg">
                <div>
                  <p className="font-medium">Versandbestätigung</p>
                  <p className="text-sm text-muted-foreground">
                    E-Mail bei Versand der Bestellung
                  </p>
                </div>
                <Switch defaultChecked />
              </div>
            </div>

            <div className="flex justify-end">
              <Button onClick={handleSave} disabled={isSaving}>
                <Save className="h-4 w-4 mr-2" />
                {isSaving ? 'Speichern...' : 'Speichern'}
              </Button>
            </div>
          </CardContent>
        </Card>
      </TabsContent>
    </Tabs>
  );
}
