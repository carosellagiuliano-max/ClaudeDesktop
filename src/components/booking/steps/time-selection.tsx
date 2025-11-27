'use client';

import { useState, useEffect } from 'react';
import {
  Calendar,
  Clock,
  ChevronLeft,
  ChevronRight,
  AlertCircle,
  Loader2,
} from 'lucide-react';
import {
  format,
  addDays,
  startOfWeek,
  endOfWeek,
  eachDayOfInterval,
  isSameDay,
  isToday,
  isBefore,
  startOfDay,
} from 'date-fns';
import { de } from 'date-fns/locale';
import { cn } from '@/lib/utils';
import { Button } from '@/components/ui/button';
import { Card, CardContent } from '@/components/ui/card';
import { Badge } from '@/components/ui/badge';
import { Alert, AlertDescription } from '@/components/ui/alert';
import { useBooking } from '../booking-context';
import type { AvailableSlot, SlotsByDate } from '@/lib/domain/booking';
import { groupSlotsByDate } from '@/lib/domain/booking';

// ============================================
// TIME SELECTION STEP
// ============================================

interface TimeSelectionProps {
  slots: AvailableSlot[];
  isLoading?: boolean;
  error?: string | null;
  onRefreshSlots?: () => void;
}

export function TimeSelection({
  slots,
  isLoading = false,
  error = null,
  onRefreshSlots,
}: TimeSelectionProps) {
  const { state, selectSlot, goBack, goNext, canProceed } = useBooking();

  // Current view state
  const [currentWeekStart, setCurrentWeekStart] = useState(() =>
    startOfWeek(new Date(), { weekStartsOn: 1 })
  );
  const [selectedDate, setSelectedDate] = useState<Date | null>(null);

  // Group slots by date
  const slotsByDate = groupSlotsByDate(slots);

  // Get days in current week
  const weekDays = eachDayOfInterval({
    start: currentWeekStart,
    end: endOfWeek(currentWeekStart, { weekStartsOn: 1 }),
  });

  // Get slots for selected date
  const selectedDateSlots = selectedDate
    ? slotsByDate.find((d) => d.date === format(selectedDate, 'yyyy-MM-dd'))
        ?.slots || []
    : [];

  // Filter slots by selected staff if any
  const filteredSlots = state.selectedStaff
    ? selectedDateSlots.filter((s) => s.staffId === state.selectedStaff?.id)
    : selectedDateSlots;

  // Check if a date has available slots
  const hasSlots = (date: Date) => {
    const dateKey = format(date, 'yyyy-MM-dd');
    const dateSlots = slotsByDate.find((d) => d.date === dateKey);
    if (!dateSlots) return false;
    if (state.selectedStaff) {
      return dateSlots.slots.some((s) => s.staffId === state.selectedStaff?.id);
    }
    return dateSlots.slots.length > 0;
  };

  // Navigate weeks
  const goToPreviousWeek = () => {
    setCurrentWeekStart(addDays(currentWeekStart, -7));
  };

  const goToNextWeek = () => {
    setCurrentWeekStart(addDays(currentWeekStart, 7));
  };

  // Handle slot selection
  const handleSlotSelect = (slot: AvailableSlot) => {
    selectSlot(slot);
  };

  // Auto-select first available date
  useEffect(() => {
    if (!selectedDate && slotsByDate.length > 0) {
      const firstDate = new Date(slotsByDate[0].date);
      setSelectedDate(firstDate);
      // Ensure the week containing this date is visible
      setCurrentWeekStart(startOfWeek(firstDate, { weekStartsOn: 1 }));
    }
  }, [slotsByDate, selectedDate]);

  return (
    <div className="space-y-8">
      {/* Header */}
      <div>
        <h2 className="text-2xl font-bold mb-2">
          Wählen Sie Ihren Wunschtermin
        </h2>
        <p className="text-muted-foreground">
          Verfügbare Termine werden grün angezeigt.
        </p>
      </div>

      {/* Error Message */}
      {error && (
        <Alert variant="destructive">
          <AlertCircle className="h-4 w-4" />
          <AlertDescription>
            {error}
            {onRefreshSlots && (
              <Button
                variant="link"
                size="sm"
                onClick={onRefreshSlots}
                className="ml-2 h-auto p-0"
              >
                Erneut versuchen
              </Button>
            )}
          </AlertDescription>
        </Alert>
      )}

      {/* Loading State */}
      {isLoading && (
        <div className="flex items-center justify-center py-12">
          <Loader2 className="h-8 w-8 animate-spin text-primary" />
          <span className="ml-3 text-muted-foreground">
            Verfügbare Termine werden geladen...
          </span>
        </div>
      )}

      {!isLoading && !error && (
        <>
          {/* Calendar Navigation */}
          <div className="flex items-center justify-between">
            <Button
              variant="outline"
              size="icon"
              onClick={goToPreviousWeek}
              disabled={isBefore(
                currentWeekStart,
                startOfWeek(new Date(), { weekStartsOn: 1 })
              )}
            >
              <ChevronLeft className="h-4 w-4" />
            </Button>
            <span className="font-semibold">
              {format(currentWeekStart, 'MMMM yyyy', { locale: de })}
            </span>
            <Button variant="outline" size="icon" onClick={goToNextWeek}>
              <ChevronRight className="h-4 w-4" />
            </Button>
          </div>

          {/* Week Days */}
          <div className="grid grid-cols-7 gap-2">
            {weekDays.map((day) => {
              const isPast = isBefore(day, startOfDay(new Date()));
              const isAvailable = hasSlots(day);
              const isSelected = selectedDate && isSameDay(day, selectedDate);

              return (
                <button
                  key={day.toISOString()}
                  onClick={() => !isPast && isAvailable && setSelectedDate(day)}
                  disabled={isPast || !isAvailable}
                  className={cn(
                    'flex flex-col items-center p-2 sm:p-3 rounded-lg border-2 transition-all',
                    isSelected && 'border-primary bg-primary/10',
                    !isSelected && isAvailable && 'border-primary/50 hover:bg-primary/5',
                    !isSelected && !isAvailable && 'border-muted opacity-50',
                    isPast && 'opacity-30 cursor-not-allowed'
                  )}
                >
                  <span className="text-xs text-muted-foreground">
                    {format(day, 'EEE', { locale: de })}
                  </span>
                  <span
                    className={cn(
                      'text-lg font-semibold',
                      isToday(day) && 'text-primary'
                    )}
                  >
                    {format(day, 'd')}
                  </span>
                  {isAvailable && (
                    <span className="w-1.5 h-1.5 rounded-full bg-primary mt-1" />
                  )}
                </button>
              );
            })}
          </div>

          {/* Time Slots */}
          {selectedDate && (
            <div>
              <h3 className="font-semibold mb-4">
                {isToday(selectedDate)
                  ? 'Heute'
                  : format(selectedDate, 'EEEE, d. MMMM', { locale: de })}
              </h3>

              {filteredSlots.length > 0 ? (
                <div className="grid grid-cols-3 sm:grid-cols-4 md:grid-cols-6 gap-2">
                  {filteredSlots.map((slot, index) => {
                    const isSelected =
                      state.selectedSlot?.startsAt.getTime() ===
                      slot.startsAt.getTime();

                    return (
                      <button
                        key={`${slot.staffId}-${slot.startsAt.toISOString()}`}
                        onClick={() => handleSlotSelect(slot)}
                        className={cn(
                          'p-3 rounded-lg border-2 text-center transition-all',
                          isSelected
                            ? 'border-primary bg-primary text-primary-foreground'
                            : 'border-border hover:border-primary/50 hover:bg-primary/5'
                        )}
                      >
                        <span className="text-sm font-semibold">
                          {format(slot.startsAt, 'HH:mm')}
                        </span>
                        {!state.selectedStaff && !state.noStaffPreference && (
                          <span className="block text-xs opacity-70 mt-0.5">
                            {slot.staffName.split(' ')[0]}
                          </span>
                        )}
                      </button>
                    );
                  })}
                </div>
              ) : (
                <Card className="border-dashed">
                  <CardContent className="p-6 text-center">
                    <Clock className="h-8 w-8 text-muted-foreground mx-auto mb-2" />
                    <p className="text-muted-foreground">
                      Keine verfügbaren Termine an diesem Tag
                    </p>
                  </CardContent>
                </Card>
              )}
            </div>
          )}
        </>
      )}

      {/* Navigation */}
      <div className="flex justify-between pt-4 border-t">
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
