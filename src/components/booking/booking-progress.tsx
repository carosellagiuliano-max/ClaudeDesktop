'use client';

import { Check } from 'lucide-react';
import { cn } from '@/lib/utils';
import { useBooking, type BookingStep } from './booking-context';

// ============================================
// BOOKING PROGRESS INDICATOR
// ============================================

interface Step {
  id: BookingStep;
  label: string;
  shortLabel: string;
}

const STEPS: Step[] = [
  { id: 'services', label: 'Leistungen', shortLabel: '1' },
  { id: 'staff', label: 'Mitarbeiter', shortLabel: '2' },
  { id: 'time', label: 'Termin', shortLabel: '3' },
  { id: 'confirm', label: 'Bestätigung', shortLabel: '4' },
];

export function BookingProgress() {
  const { state, goToStep } = useBooking();
  const currentIndex = STEPS.findIndex((s) => s.id === state.currentStep);

  const canNavigateTo = (step: BookingStep): boolean => {
    const targetIndex = STEPS.findIndex((s) => s.id === step);
    // Can only go back, not forward (forward requires validation)
    return targetIndex < currentIndex;
  };

  return (
    <div className="w-full">
      {/* Desktop Progress */}
      <div className="hidden items-center justify-between sm:flex">
        {STEPS.map((step, index) => {
          const isCompleted = index < currentIndex;
          const isCurrent = step.id === state.currentStep;
          const canClick = canNavigateTo(step.id);

          return (
            <div key={step.id} className="flex flex-1 items-center">
              {/* Step Circle */}
              <button
                onClick={() => canClick && goToStep(step.id)}
                disabled={!canClick}
                className={cn(
                  'flex h-10 w-10 items-center justify-center rounded-full border-2 transition-colors',
                  isCompleted && 'bg-primary border-primary text-primary-foreground',
                  isCurrent && 'border-primary text-primary bg-primary/10',
                  !isCompleted && !isCurrent && 'border-muted-foreground/30 text-muted-foreground',
                  canClick && 'hover:border-primary/70 cursor-pointer'
                )}
              >
                {isCompleted ? (
                  <Check className="h-5 w-5" />
                ) : (
                  <span className="text-sm font-medium">{index + 1}</span>
                )}
              </button>

              {/* Step Label */}
              <span
                className={cn(
                  'ml-3 text-sm font-medium whitespace-nowrap',
                  isCurrent && 'text-foreground',
                  !isCurrent && 'text-muted-foreground'
                )}
              >
                {step.label}
              </span>

              {/* Connector Line */}
              {index < STEPS.length - 1 && (
                <div
                  className={cn(
                    'mx-4 h-0.5 flex-1',
                    index < currentIndex ? 'bg-primary' : 'bg-border'
                  )}
                />
              )}
            </div>
          );
        })}
      </div>

      {/* Mobile Progress */}
      <div className="sm:hidden">
        <div className="mb-2 flex items-center justify-between">
          <span className="text-sm font-medium">
            Schritt {currentIndex + 1} von {STEPS.length}
          </span>
          <span className="text-muted-foreground text-sm">{STEPS[currentIndex].label}</span>
        </div>
        <div className="flex gap-1">
          {STEPS.map((step, index) => (
            <div
              key={step.id}
              className={cn(
                'h-1.5 flex-1 rounded-full transition-colors',
                index <= currentIndex ? 'bg-primary' : 'bg-muted'
              )}
            />
          ))}
        </div>
      </div>
    </div>
  );
}
