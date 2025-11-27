import type { Metadata } from 'next';
import { BookingFlow } from '@/components/booking';
import { getBookingPageData } from '@/lib/actions';
import { Card, CardContent } from '@/components/ui/card';
import { AlertCircle } from 'lucide-react';

// ============================================
// METADATA
// ============================================

export const metadata: Metadata = {
  title: 'Termin buchen',
  description:
    'Buchen Sie Ihren Friseurtermin online bei SCHNITTWERK St. Gallen. Schnell, einfach und bequem – wählen Sie Ihren Wunschtermin.',
};

// ============================================
// PAGE COMPONENT
// ============================================

export default async function TerminBuchenPage() {
  // Fetch booking data from database
  const bookingData = await getBookingPageData();

  if (!bookingData) {
    return (
      <div className="container-wide py-16">
        <Card className="mx-auto max-w-md">
          <CardContent className="p-8 text-center">
            <AlertCircle className="text-destructive mx-auto mb-4 h-12 w-12" />
            <h2 className="mb-2 text-xl font-bold">Buchung nicht verfügbar</h2>
            <p className="text-muted-foreground">
              Die Online-Buchung ist derzeit nicht verfügbar. Bitte kontaktieren Sie uns
              telefonisch.
            </p>
          </CardContent>
        </Card>
      </div>
    );
  }

  return (
    <BookingFlow
      salonId={bookingData.salonId}
      services={bookingData.services}
      staff={bookingData.staff}
      categories={bookingData.categories}
      openingHours={bookingData.openingHours}
      staffWorkingHours={bookingData.staffWorkingHours}
      staffAbsences={[]}
      blockedTimes={[]}
      existingAppointments={[]}
      salonAddress={bookingData.salonAddress}
    />
  );
}
