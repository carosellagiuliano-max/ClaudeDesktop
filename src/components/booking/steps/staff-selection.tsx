'use client';

import { User, Check } from 'lucide-react';
import { cn } from '@/lib/utils';
import { Button } from '@/components/ui/button';
import { Card, CardContent } from '@/components/ui/card';
import { RadioGroup, RadioGroupItem } from '@/components/ui/radio-group';
import { useBooking } from '../booking-context';
import type { BookableStaff } from '@/lib/domain/booking';

// ============================================
// STAFF SELECTION STEP
// ============================================

interface StaffSelectionProps {
  staff: BookableStaff[];
}

export function StaffSelection({ staff }: StaffSelectionProps) {
  const { state, selectStaff, setNoPreference, goBack, goNext, canProceed } = useBooking();

  // Filter staff that can perform all selected services
  const qualifiedStaff = staff.filter((s) =>
    state.selectedServices.every((service) => s.serviceIds.includes(service.id))
  );

  const handleStaffSelect = (staffMember: BookableStaff | null) => {
    if (staffMember) {
      selectStaff(staffMember);
      setNoPreference(false);
    } else {
      selectStaff(null);
      setNoPreference(true);
    }
  };

  const isSelected = (staffId: string | null) => {
    if (staffId === null) {
      return state.noStaffPreference;
    }
    return state.selectedStaff?.id === staffId;
  };

  return (
    <div className="space-y-8">
      {/* Header */}
      <div>
        <h2 className="mb-2 text-2xl font-bold">Bei wem möchten Sie den Termin?</h2>
        <p className="text-muted-foreground">
          Wählen Sie Ihren bevorzugten Stylisten oder lassen Sie sich überraschen.
        </p>
      </div>

      {/* Staff Grid */}
      <div className="grid gap-4 sm:grid-cols-2 lg:grid-cols-3">
        {/* No Preference Option */}
        <Card
          className={cn(
            'cursor-pointer border-2 transition-all',
            isSelected(null)
              ? 'border-primary bg-primary/5'
              : 'border-border/50 hover:border-primary/50'
          )}
          onClick={() => handleStaffSelect(null)}
        >
          <CardContent className="p-6 text-center">
            <div className="relative mx-auto mb-4">
              <div className="bg-muted mx-auto flex h-20 w-20 items-center justify-center rounded-full">
                <User className="text-muted-foreground h-10 w-10" />
              </div>
              {isSelected(null) && (
                <div className="bg-primary text-primary-foreground absolute -top-1 -right-1 flex h-6 w-6 items-center justify-center rounded-full">
                  <Check className="h-4 w-4" />
                </div>
              )}
            </div>
            <h3 className="font-semibold">Keine Präferenz</h3>
            <p className="text-muted-foreground mt-1 text-sm">Ersten verfügbaren Termin</p>
          </CardContent>
        </Card>

        {/* Staff Members */}
        {qualifiedStaff.map((staffMember) => (
          <Card
            key={staffMember.id}
            className={cn(
              'cursor-pointer border-2 transition-all',
              isSelected(staffMember.id)
                ? 'border-primary bg-primary/5'
                : 'border-border/50 hover:border-primary/50'
            )}
            onClick={() => handleStaffSelect(staffMember)}
          >
            <CardContent className="p-6 text-center">
              <div className="relative mx-auto mb-4">
                {staffMember.imageUrl ? (
                  <img
                    src={staffMember.imageUrl}
                    alt={staffMember.name}
                    className="mx-auto h-20 w-20 rounded-full object-cover"
                  />
                ) : (
                  <div className="bg-muted mx-auto flex h-20 w-20 items-center justify-center rounded-full">
                    <User className="text-muted-foreground h-10 w-10" />
                  </div>
                )}
                {isSelected(staffMember.id) && (
                  <div className="bg-primary text-primary-foreground absolute -top-1 -right-1 flex h-6 w-6 items-center justify-center rounded-full">
                    <Check className="h-4 w-4" />
                  </div>
                )}
              </div>
              <h3 className="font-semibold">{staffMember.name}</h3>
            </CardContent>
          </Card>
        ))}
      </div>

      {/* No qualified staff message */}
      {qualifiedStaff.length === 0 && (
        <Card className="border-destructive/50 bg-destructive/5">
          <CardContent className="p-6 text-center">
            <p className="text-destructive text-sm">
              Leider ist für die gewählten Leistungen kein Mitarbeiter verfügbar. Bitte passen Sie
              Ihre Auswahl an.
            </p>
          </CardContent>
        </Card>
      )}

      {/* Navigation */}
      <div className="flex justify-between border-t pt-4">
        <Button variant="outline" onClick={goBack}>
          Zurück
        </Button>
        <Button onClick={goNext} disabled={!canProceed}>
          Weiter
        </Button>
      </div>
    </div>
  );
}
