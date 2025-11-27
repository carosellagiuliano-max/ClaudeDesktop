'use client';

import { useState } from 'react';
import Link from 'next/link';
import {
  Calendar,
  Clock,
  User,
  MapPin,
  CreditCard,
  Wallet,
  Loader2,
  AlertCircle,
  CheckCircle,
} from 'lucide-react';
import { format } from 'date-fns';
import { de } from 'date-fns/locale';
import { cn } from '@/lib/utils';
import { Button } from '@/components/ui/button';
import { Card, CardContent, CardHeader, CardTitle } from '@/components/ui/card';
import { Input } from '@/components/ui/input';
import { Textarea } from '@/components/ui/textarea';
import { Label } from '@/components/ui/label';
import { Checkbox } from '@/components/ui/checkbox';
import { RadioGroup, RadioGroupItem } from '@/components/ui/radio-group';
import { Separator } from '@/components/ui/separator';
import { Alert, AlertDescription } from '@/components/ui/alert';
import { useBooking } from '../booking-context';

// ============================================
// CONFIRMATION STEP
// ============================================

interface ConfirmationProps {
  salonAddress?: string;
  onSubmit: () => Promise<void>;
}

export function Confirmation({
  salonAddress = 'Musterstrasse 123, 9000 St. Gallen',
  onSubmit,
}: ConfirmationProps) {
  const {
    state,
    updateCustomerInfo,
    setPaymentMethod,
    goBack,
    canProceed,
    totalPrice,
    totalDuration,
  } = useBooking();

  const [isSubmitting, setIsSubmitting] = useState(false);
  const [submitError, setSubmitError] = useState<string | null>(null);

  const formatPrice = (cents: number) => {
    return `CHF ${(cents / 100).toFixed(2)}`;
  };

  const formatDuration = (minutes: number) => {
    if (minutes < 60) return `${minutes} Min.`;
    const hours = Math.floor(minutes / 60);
    const mins = minutes % 60;
    return mins > 0 ? `${hours} Std. ${mins} Min.` : `${hours} Std.`;
  };

  const handleSubmit = async () => {
    if (!canProceed) return;

    setIsSubmitting(true);
    setSubmitError(null);

    try {
      await onSubmit();
    } catch (error) {
      setSubmitError(
        error instanceof Error
          ? error.message
          : 'Ein Fehler ist aufgetreten. Bitte versuchen Sie es erneut.'
      );
    } finally {
      setIsSubmitting(false);
    }
  };

  return (
    <div className="space-y-8">
      {/* Header */}
      <div>
        <h2 className="text-2xl font-bold mb-2">Buchung bestätigen</h2>
        <p className="text-muted-foreground">
          Überprüfen Sie Ihre Angaben und vervollständigen Sie die Buchung.
        </p>
      </div>

      <div className="grid gap-8 lg:grid-cols-2">
        {/* Left Column - Forms */}
        <div className="space-y-6">
          {/* Appointment Summary */}
          <Card className="border-border/50">
            <CardHeader className="pb-4">
              <CardTitle className="text-lg">Ihr Termin</CardTitle>
            </CardHeader>
            <CardContent className="space-y-4">
              {/* Date & Time */}
              <div className="flex items-center gap-3">
                <Calendar className="h-5 w-5 text-primary" />
                <div>
                  <p className="font-medium">
                    {state.selectedSlot &&
                      format(state.selectedSlot.startsAt, 'EEEE, d. MMMM yyyy', {
                        locale: de,
                      })}
                  </p>
                  <p className="text-sm text-muted-foreground">
                    {state.selectedSlot &&
                      format(state.selectedSlot.startsAt, 'HH:mm')}{' '}
                    -{' '}
                    {state.selectedSlot &&
                      format(state.selectedSlot.endsAt, 'HH:mm')}{' '}
                    Uhr
                  </p>
                </div>
              </div>

              {/* Staff */}
              <div className="flex items-center gap-3">
                <User className="h-5 w-5 text-primary" />
                <div>
                  <p className="font-medium">
                    {state.selectedSlot?.staffName || 'Noch nicht ausgewählt'}
                  </p>
                  <p className="text-sm text-muted-foreground">Ihr Stylist</p>
                </div>
              </div>

              {/* Location */}
              <div className="flex items-center gap-3">
                <MapPin className="h-5 w-5 text-primary" />
                <div>
                  <p className="font-medium">SCHNITTWERK</p>
                  <p className="text-sm text-muted-foreground">{salonAddress}</p>
                </div>
              </div>

              {/* Services */}
              <Separator />
              <div className="space-y-2">
                {state.selectedServices.map((service) => (
                  <div key={service.id} className="flex justify-between text-sm">
                    <span>{service.name}</span>
                    <span className="text-muted-foreground">
                      {formatPrice(service.currentPrice)}
                    </span>
                  </div>
                ))}
              </div>
              <Separator />
              <div className="flex justify-between font-semibold">
                <span>Gesamt ({formatDuration(totalDuration)})</span>
                <span className="text-primary">{formatPrice(totalPrice)}</span>
              </div>
            </CardContent>
          </Card>

          {/* Customer Info */}
          <Card className="border-border/50">
            <CardHeader className="pb-4">
              <CardTitle className="text-lg">Ihre Kontaktdaten</CardTitle>
            </CardHeader>
            <CardContent className="space-y-4">
              <div className="grid gap-4 sm:grid-cols-2">
                <div className="space-y-2">
                  <Label htmlFor="name">Name *</Label>
                  <Input
                    id="name"
                    placeholder="Vor- und Nachname"
                    value={state.customerInfo.name}
                    onChange={(e) =>
                      updateCustomerInfo({ name: e.target.value })
                    }
                    required
                  />
                </div>
                <div className="space-y-2">
                  <Label htmlFor="phone">Telefon *</Label>
                  <Input
                    id="phone"
                    type="tel"
                    placeholder="+41 79 123 45 67"
                    value={state.customerInfo.phone}
                    onChange={(e) =>
                      updateCustomerInfo({ phone: e.target.value })
                    }
                    required
                  />
                </div>
              </div>
              <div className="space-y-2">
                <Label htmlFor="email">E-Mail *</Label>
                <Input
                  id="email"
                  type="email"
                  placeholder="ihre@email.ch"
                  value={state.customerInfo.email}
                  onChange={(e) =>
                    updateCustomerInfo({ email: e.target.value })
                  }
                  required
                />
              </div>
              <div className="space-y-2">
                <Label htmlFor="notes">Anmerkungen (optional)</Label>
                <Textarea
                  id="notes"
                  placeholder="z.B. spezielle Wünsche oder Hinweise..."
                  rows={3}
                  value={state.customerInfo.notes}
                  onChange={(e) =>
                    updateCustomerInfo({ notes: e.target.value })
                  }
                />
              </div>
            </CardContent>
          </Card>
        </div>

        {/* Right Column - Payment & Confirm */}
        <div className="space-y-6">
          {/* Payment Method */}
          <Card className="border-border/50">
            <CardHeader className="pb-4">
              <CardTitle className="text-lg">Zahlungsart</CardTitle>
            </CardHeader>
            <CardContent>
              <RadioGroup
                value={state.paymentMethod}
                onValueChange={(v) =>
                  setPaymentMethod(v as 'online' | 'at_venue')
                }
                className="space-y-3"
              >
                <label
                  className={cn(
                    'flex items-start gap-4 p-4 rounded-lg border-2 cursor-pointer transition-all',
                    state.paymentMethod === 'at_venue'
                      ? 'border-primary bg-primary/5'
                      : 'border-border hover:border-primary/50'
                  )}
                >
                  <RadioGroupItem value="at_venue" className="mt-1" />
                  <div className="flex items-center gap-3 flex-1">
                    <Wallet className="h-5 w-5 text-muted-foreground" />
                    <div>
                      <p className="font-medium">Vor Ort bezahlen</p>
                      <p className="text-sm text-muted-foreground">
                        Bar, Karte oder TWINT im Salon
                      </p>
                    </div>
                  </div>
                </label>

                <label
                  className={cn(
                    'flex items-start gap-4 p-4 rounded-lg border-2 cursor-pointer transition-all',
                    state.paymentMethod === 'online'
                      ? 'border-primary bg-primary/5'
                      : 'border-border hover:border-primary/50'
                  )}
                >
                  <RadioGroupItem value="online" className="mt-1" />
                  <div className="flex items-center gap-3 flex-1">
                    <CreditCard className="h-5 w-5 text-muted-foreground" />
                    <div>
                      <p className="font-medium">Online bezahlen</p>
                      <p className="text-sm text-muted-foreground">
                        Kreditkarte oder TWINT
                      </p>
                    </div>
                  </div>
                </label>
              </RadioGroup>
            </CardContent>
          </Card>

          {/* Terms & Conditions */}
          <Card className="border-border/50">
            <CardContent className="p-6">
              <div className="flex items-start space-x-3">
                <Checkbox
                  id="terms"
                  checked={state.customerInfo.acceptTerms}
                  onCheckedChange={(checked) =>
                    updateCustomerInfo({ acceptTerms: checked as boolean })
                  }
                />
                <label
                  htmlFor="terms"
                  className="text-sm text-muted-foreground leading-relaxed cursor-pointer"
                >
                  Ich akzeptiere die{' '}
                  <Link href="/agb" className="text-primary hover:underline">
                    AGB
                  </Link>{' '}
                  und{' '}
                  <Link
                    href="/datenschutz"
                    className="text-primary hover:underline"
                  >
                    Datenschutzerklärung
                  </Link>
                  . Ich bin damit einverstanden, Terminerinnerungen per E-Mail
                  und SMS zu erhalten.
                </label>
              </div>
            </CardContent>
          </Card>

          {/* Cancellation Policy */}
          <Card className="border-border/50 bg-muted/30">
            <CardContent className="p-6">
              <h4 className="font-semibold mb-2">Stornierungsbedingungen</h4>
              <p className="text-sm text-muted-foreground">
                Kostenlose Stornierung bis 24 Stunden vor dem Termin. Bei
                späteren Absagen oder Nichterscheinen behalten wir uns vor, eine
                Ausfallentschädigung zu berechnen.
              </p>
            </CardContent>
          </Card>

          {/* Error Message */}
          {submitError && (
            <Alert variant="destructive">
              <AlertCircle className="h-4 w-4" />
              <AlertDescription>{submitError}</AlertDescription>
            </Alert>
          )}

          {/* Submit Button */}
          <Button
            size="lg"
            className="w-full btn-glow"
            onClick={handleSubmit}
            disabled={!canProceed || isSubmitting}
          >
            {isSubmitting ? (
              <>
                <Loader2 className="mr-2 h-5 w-5 animate-spin" />
                Buchung wird verarbeitet...
              </>
            ) : (
              <>
                <CheckCircle className="mr-2 h-5 w-5" />
                Termin verbindlich buchen
              </>
            )}
          </Button>
        </div>
      </div>

      {/* Back Button */}
      <div className="pt-4 border-t">
        <Button variant="outline" onClick={goBack} disabled={isSubmitting}>
          Zurück
        </Button>
      </div>
    </div>
  );
}
