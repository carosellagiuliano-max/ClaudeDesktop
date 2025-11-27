'use client';

import { Clock, Check } from 'lucide-react';
import { cn } from '@/lib/utils';
import { Button } from '@/components/ui/button';
import { Card, CardContent } from '@/components/ui/card';
import { Badge } from '@/components/ui/badge';
import { useBooking } from '../booking-context';
import type { BookableService } from '@/lib/domain/booking';

// ============================================
// SERVICE SELECTION STEP
// ============================================

interface ServiceSelectionProps {
  services: BookableService[];
  categories?: { id: string; name: string }[];
}

export function ServiceSelection({ services, categories = [] }: ServiceSelectionProps) {
  const { state, toggleService, goNext, canProceed, totalDuration, totalPrice } = useBooking();

  const formatPrice = (cents: number) => {
    return `CHF ${(cents / 100).toFixed(0)}.-`;
  };

  const formatDuration = (minutes: number) => {
    if (minutes < 60) return `${minutes} Min.`;
    const hours = Math.floor(minutes / 60);
    const mins = minutes % 60;
    return mins > 0 ? `${hours} Std. ${mins} Min.` : `${hours} Std.`;
  };

  // Group services by category
  const servicesByCategory = services.reduce(
    (acc, service) => {
      const categoryId = service.categoryId || 'other';
      if (!acc[categoryId]) {
        acc[categoryId] = [];
      }
      acc[categoryId].push(service);
      return acc;
    },
    {} as Record<string, BookableService[]>
  );

  const isSelected = (serviceId: string) => state.selectedServices.some((s) => s.id === serviceId);

  return (
    <div className="space-y-8">
      {/* Header */}
      <div>
        <h2 className="mb-2 text-2xl font-bold">Welche Leistung möchten Sie buchen?</h2>
        <p className="text-muted-foreground">Wählen Sie eine oder mehrere Leistungen aus.</p>
      </div>

      {/* Service Categories */}
      <div className="space-y-8">
        {Object.entries(servicesByCategory).map(([categoryId, categoryServices]) => {
          const category = categories.find((c) => c.id === categoryId);
          return (
            <div key={categoryId}>
              {category && <h3 className="mb-4 text-lg font-semibold">{category.name}</h3>}
              <div className="space-y-3">
                {categoryServices.map((service) => (
                  <ServiceCard
                    key={service.id}
                    service={service}
                    selected={isSelected(service.id)}
                    onToggle={() => toggleService(service)}
                    formatPrice={formatPrice}
                    formatDuration={formatDuration}
                  />
                ))}
              </div>
            </div>
          );
        })}
      </div>

      {/* Summary & Continue */}
      <div className="bg-background sticky bottom-0 border-t pt-4 pb-2">
        <div className="flex flex-col items-center justify-between gap-4 sm:flex-row">
          <div className="text-center sm:text-left">
            {state.selectedServices.length > 0 ? (
              <>
                <p className="text-muted-foreground text-sm">
                  {state.selectedServices.length} Leistung
                  {state.selectedServices.length !== 1 ? 'en' : ''} ausgewählt
                </p>
                <p className="font-semibold">
                  {formatDuration(totalDuration)} •{' '}
                  <span className="text-primary">{formatPrice(totalPrice)}</span>
                </p>
              </>
            ) : (
              <p className="text-muted-foreground text-sm">
                Bitte wählen Sie mindestens eine Leistung
              </p>
            )}
          </div>
          <Button size="lg" onClick={goNext} disabled={!canProceed} className="w-full sm:w-auto">
            Weiter
          </Button>
        </div>
      </div>
    </div>
  );
}

// ============================================
// SERVICE CARD COMPONENT
// ============================================

interface ServiceCardProps {
  service: BookableService;
  selected: boolean;
  onToggle: () => void;
  formatPrice: (cents: number) => string;
  formatDuration: (minutes: number) => string;
}

function ServiceCard({
  service,
  selected,
  onToggle,
  formatPrice,
  formatDuration,
}: ServiceCardProps) {
  return (
    <Card
      className={cn(
        'cursor-pointer border-2 transition-all',
        selected ? 'border-primary bg-primary/5' : 'border-border/50 hover:border-primary/50'
      )}
      onClick={onToggle}
    >
      <CardContent className="p-4 sm:p-6">
        <div className="flex items-start gap-4">
          {/* Checkbox */}
          <div
            className={cn(
              'mt-0.5 flex h-6 w-6 shrink-0 items-center justify-center rounded border-2',
              selected
                ? 'bg-primary border-primary text-primary-foreground'
                : 'border-muted-foreground/30'
            )}
          >
            {selected && <Check className="h-4 w-4" />}
          </div>

          {/* Content */}
          <div className="min-w-0 flex-1">
            <div className="flex items-start justify-between gap-4">
              <div>
                <h4 className="font-semibold">{service.name}</h4>
                {service.description && (
                  <p className="text-muted-foreground mt-1 text-sm">{service.description}</p>
                )}
                <div className="text-muted-foreground mt-2 flex items-center gap-3 text-sm">
                  <span className="flex items-center gap-1">
                    <Clock className="h-4 w-4" />
                    ca. {formatDuration(service.durationMinutes)}
                  </span>
                </div>
              </div>
              <div className="shrink-0 text-right">
                <span className="text-primary text-lg font-bold">
                  {formatPrice(service.currentPrice)}
                </span>
              </div>
            </div>
          </div>
        </div>
      </CardContent>
    </Card>
  );
}
