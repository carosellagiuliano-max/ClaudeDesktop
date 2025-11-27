'use client';

import { Clock, User, Calendar, CreditCard } from 'lucide-react';
import { format } from 'date-fns';
import { de } from 'date-fns/locale';
import { Card, CardContent, CardHeader, CardTitle } from '@/components/ui/card';
import { Separator } from '@/components/ui/separator';
import { useBooking } from './booking-context';

// ============================================
// BOOKING SUMMARY SIDEBAR
// ============================================

export function BookingSummary() {
  const { state, totalDuration, totalPrice } = useBooking();

  const formatPrice = (cents: number) => {
    return `CHF ${(cents / 100).toFixed(2)}`;
  };

  const formatDuration = (minutes: number) => {
    if (minutes < 60) return `${minutes} Min.`;
    const hours = Math.floor(minutes / 60);
    const mins = minutes % 60;
    return mins > 0 ? `${hours} Std. ${mins} Min.` : `${hours} Std.`;
  };

  return (
    <Card className="border-border/50 sticky top-24">
      <CardHeader className="pb-4">
        <CardTitle className="text-lg">Ihre Auswahl</CardTitle>
      </CardHeader>
      <CardContent className="space-y-4">
        {/* Selected Services */}
        {state.selectedServices.length > 0 ? (
          <div className="space-y-3">
            {state.selectedServices.map((service) => (
              <div key={service.id} className="flex justify-between text-sm">
                <div>
                  <p className="font-medium">{service.name}</p>
                  <p className="text-muted-foreground text-xs">{service.durationMinutes} Min.</p>
                </div>
                <span className="text-primary font-medium">
                  {formatPrice(service.currentPrice)}
                </span>
              </div>
            ))}
          </div>
        ) : (
          <p className="text-muted-foreground text-sm">Noch keine Leistung ausgewählt</p>
        )}

        <Separator />

        {/* Duration */}
        {totalDuration > 0 && (
          <div className="flex items-center gap-2 text-sm">
            <Clock className="text-muted-foreground h-4 w-4" />
            <span className="text-muted-foreground">Dauer:</span>
            <span className="font-medium">{formatDuration(totalDuration)}</span>
          </div>
        )}

        {/* Selected Staff */}
        {(state.selectedStaff || state.noStaffPreference) && (
          <div className="flex items-center gap-2 text-sm">
            <User className="text-muted-foreground h-4 w-4" />
            <span className="text-muted-foreground">Mitarbeiter:</span>
            <span className="font-medium">
              {state.noStaffPreference ? 'Keine Präferenz' : state.selectedStaff?.name}
            </span>
          </div>
        )}

        {/* Selected Slot */}
        {state.selectedSlot && (
          <div className="flex items-center gap-2 text-sm">
            <Calendar className="text-muted-foreground h-4 w-4" />
            <span className="text-muted-foreground">Termin:</span>
            <span className="font-medium">
              {format(state.selectedSlot.startsAt, 'EEE, d. MMM', {
                locale: de,
              })}{' '}
              {format(state.selectedSlot.startsAt, 'HH:mm')} Uhr
            </span>
          </div>
        )}

        {/* Payment Method (on confirm step) */}
        {state.currentStep === 'confirm' && (
          <div className="flex items-center gap-2 text-sm">
            <CreditCard className="text-muted-foreground h-4 w-4" />
            <span className="text-muted-foreground">Zahlung:</span>
            <span className="font-medium">
              {state.paymentMethod === 'online' ? 'Online bezahlen' : 'Vor Ort bezahlen'}
            </span>
          </div>
        )}

        <Separator />

        {/* Total */}
        <div className="flex items-center justify-between">
          <span className="font-semibold">Gesamt</span>
          <span className="text-primary text-xl font-bold">{formatPrice(totalPrice)}</span>
        </div>

        {/* VAT Info */}
        <p className="text-muted-foreground text-right text-xs">inkl. 8.1% MwSt.</p>
      </CardContent>
    </Card>
  );
}
