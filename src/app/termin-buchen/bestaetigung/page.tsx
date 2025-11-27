import type { Metadata } from 'next';
import Link from 'next/link';
import {
  CheckCircle,
  Calendar,
  Clock,
  User,
  MapPin,
  Mail,
  Phone,
  Home,
} from 'lucide-react';
import { format } from 'date-fns';
import { de } from 'date-fns/locale';
import { Button } from '@/components/ui/button';
import { Card, CardContent } from '@/components/ui/card';
import { Separator } from '@/components/ui/separator';
import { createServerClient } from '@/lib/db/client';
import { getSalon } from '@/lib/actions';

// ============================================
// METADATA
// ============================================

export const metadata: Metadata = {
  title: 'Buchung bestätigt',
  description: 'Ihre Terminbuchung bei SCHNITTWERK wurde erfolgreich bestätigt.',
};

// ============================================
// PAGE COMPONENT
// ============================================

interface PageProps {
  searchParams: Promise<{ id?: string; nr?: string }>;
}

export default async function BookingConfirmationPage({ searchParams }: PageProps) {
  const params = await searchParams;
  const appointmentId = params.id;
  const bookingNumber = params.nr || 'SW-' + Date.now().toString(36).toUpperCase();

  // Fetch salon data
  const salon = await getSalon();

  // Fetch appointment details if ID provided
  let appointment: any = null;
  if (appointmentId) {
    const supabase = createServerClient();
    const { data } = await supabase
      .from('appointments')
      .select(`
        id,
        start_time,
        end_time,
        total_cents,
        customer_name,
        customer_email,
        customer_phone,
        staff:staff_id (display_name),
        appointment_services (
          service_name,
          duration_minutes,
          price_cents
        )
      `)
      .eq('id', appointmentId)
      .single();

    appointment = data;
  }

  const formatPrice = (cents: number) => `CHF ${(cents / 100).toFixed(2)}`;

  // Default data if no appointment found
  const displayData = appointment
    ? {
        bookingNumber,
        date: format(new Date(appointment.start_time), 'EEEE, d. MMMM yyyy', { locale: de }),
        time: `${format(new Date(appointment.start_time), 'HH:mm')} - ${format(new Date(appointment.end_time), 'HH:mm')} Uhr`,
        staff: appointment.staff?.display_name || 'Ihr Stylist',
        services: appointment.appointment_services?.map((s: any) => s.service_name) || [],
        totalPrice: formatPrice(appointment.total_cents || 0),
        customerEmail: appointment.customer_email || 'Ihre E-Mail',
      }
    : {
        bookingNumber,
        date: 'Datum wird bestätigt',
        time: 'Zeit wird bestätigt',
        staff: 'Wird zugewiesen',
        services: ['Leistungen werden bestätigt'],
        totalPrice: 'Wird bestätigt',
        customerEmail: 'Ihre E-Mail',
      };

  return (
    <div className="py-12">
      <div className="container-wide max-w-2xl">
        {/* Success Header */}
        <div className="text-center mb-8">
          <div className="inline-flex h-20 w-20 items-center justify-center rounded-full bg-green-100 dark:bg-green-900/30 mb-6">
            <CheckCircle className="h-10 w-10 text-green-600 dark:text-green-400" />
          </div>
          <h1 className="text-3xl font-bold mb-2">Buchung bestätigt!</h1>
          <p className="text-muted-foreground">
            Vielen Dank für Ihre Buchung bei {salon?.name || 'SCHNITTWERK'}.
          </p>
        </div>

        {/* Booking Details */}
        <Card className="border-border/50 mb-8">
          <CardContent className="p-6 sm:p-8">
            {/* Booking Number */}
            <div className="text-center mb-6 pb-6 border-b">
              <p className="text-sm text-muted-foreground mb-1">
                Buchungsnummer
              </p>
              <p className="text-2xl font-bold text-primary">
                {displayData.bookingNumber}
              </p>
            </div>

            {/* Details Grid */}
            <div className="space-y-4">
              {/* Date & Time */}
              <div className="flex items-start gap-4">
                <Calendar className="h-5 w-5 text-primary mt-0.5" />
                <div>
                  <p className="font-medium">{displayData.date}</p>
                  <p className="text-sm text-muted-foreground">
                    {displayData.time}
                  </p>
                </div>
              </div>

              {/* Staff */}
              <div className="flex items-start gap-4">
                <User className="h-5 w-5 text-primary mt-0.5" />
                <div>
                  <p className="font-medium">{displayData.staff}</p>
                  <p className="text-sm text-muted-foreground">Ihr Stylist</p>
                </div>
              </div>

              {/* Location */}
              <div className="flex items-start gap-4">
                <MapPin className="h-5 w-5 text-primary mt-0.5" />
                <div>
                  <p className="font-medium">{salon?.name || 'SCHNITTWERK'}</p>
                  <p className="text-sm text-muted-foreground">
                    {salon?.address}, {salon?.zipCode} {salon?.city}
                  </p>
                </div>
              </div>

              <Separator />

              {/* Services */}
              <div>
                <p className="text-sm text-muted-foreground mb-2">
                  Gebuchte Leistungen
                </p>
                <ul className="space-y-1">
                  {displayData.services.map((service: string, idx: number) => (
                    <li key={idx} className="font-medium">
                      {service}
                    </li>
                  ))}
                </ul>
              </div>

              <Separator />

              {/* Total */}
              <div className="flex justify-between items-center">
                <span className="font-medium">Gesamtbetrag</span>
                <span className="text-xl font-bold text-primary">
                  {displayData.totalPrice}
                </span>
              </div>
            </div>
          </CardContent>
        </Card>

        {/* Confirmation Email Notice */}
        <Card className="border-border/50 bg-muted/30 mb-8">
          <CardContent className="p-6">
            <div className="flex items-start gap-4">
              <Mail className="h-5 w-5 text-primary mt-0.5" />
              <div>
                <p className="font-medium mb-1">Bestätigung per E-Mail</p>
                <p className="text-sm text-muted-foreground">
                  Wir haben Ihnen eine Bestätigung an{' '}
                  <span className="font-medium">{displayData.customerEmail}</span>{' '}
                  gesendet. Bitte überprüfen Sie auch Ihren Spam-Ordner.
                </p>
              </div>
            </div>
          </CardContent>
        </Card>

        {/* Important Notes */}
        <Card className="border-border/50 mb-8">
          <CardContent className="p-6">
            <h3 className="font-semibold mb-4">Wichtige Hinweise</h3>
            <ul className="space-y-3 text-sm text-muted-foreground">
              <li className="flex items-start gap-2">
                <Clock className="h-4 w-4 text-primary mt-0.5 shrink-0" />
                Bitte erscheinen Sie pünktlich zu Ihrem Termin.
              </li>
              <li className="flex items-start gap-2">
                <Calendar className="h-4 w-4 text-primary mt-0.5 shrink-0" />
                Kostenlose Stornierung bis 24 Stunden vor dem Termin möglich.
              </li>
              <li className="flex items-start gap-2">
                <Phone className="h-4 w-4 text-primary mt-0.5 shrink-0" />
                Bei Fragen erreichen Sie uns unter {salon?.phone || '+41 71 222 81 82'}.
              </li>
            </ul>
          </CardContent>
        </Card>

        {/* Actions */}
        <div className="flex flex-col sm:flex-row gap-4 justify-center">
          <Button variant="outline" asChild>
            <Link href="/">
              <Home className="mr-2 h-4 w-4" />
              Zur Startseite
            </Link>
          </Button>
          <Button asChild>
            <Link href="/kontakt">
              <Phone className="mr-2 h-4 w-4" />
              Kontakt
            </Link>
          </Button>
        </div>
      </div>
    </div>
  );
}
