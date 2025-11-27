'use server';

import { createServerClient } from '@/lib/db/client';
import { revalidatePath } from 'next/cache';
import { z } from 'zod';
import { sendCancellationEmail } from '@/lib/email';

// ============================================
// CUSTOMER SERVER ACTIONS
// ============================================

const DEFAULT_SALON_ID = '550e8400-e29b-41d4-a716-446655440001';

// ============================================
// GET CUSTOMER APPOINTMENTS
// ============================================

export interface CustomerAppointment {
  id: string;
  startsAt: Date;
  endsAt: Date;
  status: 'reserved' | 'confirmed' | 'cancelled' | 'completed' | 'no_show';
  totalPriceCents: number;
  staffName: string;
  staffAvatar?: string;
  services: {
    name: string;
    durationMinutes: number;
    priceCents: number;
  }[];
  createdAt: Date;
  canCancel: boolean;
}

export async function getCustomerAppointments(customerId: string): Promise<CustomerAppointment[]> {
  const supabase = createServerClient();

  const { data, error } = await supabase
    .from('appointments')
    .select(
      `
      id,
      start_time,
      end_time,
      status,
      total_cents,
      created_at,
      staff:staff_id (display_name, avatar_url),
      appointment_services (
        service_name,
        duration_minutes,
        price_cents
      )
    `
    )
    .eq('customer_id', customerId)
    .order('start_time', { ascending: false });

  if (error) {
    console.error('Error fetching appointments:', error);
    return [];
  }

  const now = new Date();
  const cancellationDeadlineHours = 24;

  return (data || []).map((a) => {
    const startsAt = new Date(a.start_time);
    const hoursUntilAppointment = (startsAt.getTime() - now.getTime()) / (1000 * 60 * 60);
    const canCancel =
      ['reserved', 'confirmed'].includes(a.status) &&
      hoursUntilAppointment > cancellationDeadlineHours;

    return {
      id: a.id,
      startsAt,
      endsAt: new Date(a.end_time),
      status: a.status,
      totalPriceCents: a.total_cents,
      staffName: (a.staff as any)?.display_name || 'Unbekannt',
      staffAvatar: (a.staff as any)?.avatar_url || undefined,
      services: (a.appointment_services || []).map((s: any) => ({
        name: s.service_name,
        durationMinutes: s.duration_minutes,
        priceCents: s.price_cents,
      })),
      createdAt: new Date(a.created_at),
      canCancel,
    };
  });
}

// ============================================
// GET UPCOMING APPOINTMENTS
// ============================================

export async function getUpcomingAppointments(customerId: string): Promise<CustomerAppointment[]> {
  const supabase = createServerClient();
  const now = new Date().toISOString();

  const { data, error } = await supabase
    .from('appointments')
    .select(
      `
      id,
      start_time,
      end_time,
      status,
      total_cents,
      created_at,
      staff:staff_id (display_name, avatar_url),
      appointment_services (
        service_name,
        duration_minutes,
        price_cents
      )
    `
    )
    .eq('customer_id', customerId)
    .gte('start_time', now)
    .in('status', ['reserved', 'confirmed'])
    .order('start_time', { ascending: true });

  if (error) {
    console.error('Error fetching upcoming appointments:', error);
    return [];
  }

  const cancellationDeadlineHours = 24;

  return (data || []).map((a) => {
    const startsAt = new Date(a.start_time);
    const hoursUntilAppointment = (startsAt.getTime() - new Date().getTime()) / (1000 * 60 * 60);
    const canCancel =
      ['reserved', 'confirmed'].includes(a.status) &&
      hoursUntilAppointment > cancellationDeadlineHours;

    return {
      id: a.id,
      startsAt,
      endsAt: new Date(a.end_time),
      status: a.status,
      totalPriceCents: a.total_cents,
      staffName: (a.staff as any)?.display_name || 'Unbekannt',
      staffAvatar: (a.staff as any)?.avatar_url || undefined,
      services: (a.appointment_services || []).map((s: any) => ({
        name: s.service_name,
        durationMinutes: s.duration_minutes,
        priceCents: s.price_cents,
      })),
      createdAt: new Date(a.created_at),
      canCancel,
    };
  });
}

// ============================================
// CANCEL APPOINTMENT
// ============================================

export type CancelResult = {
  success: boolean;
  error?: string;
};

export async function cancelAppointment(
  appointmentId: string,
  customerId: string
): Promise<CancelResult> {
  const supabase = createServerClient();

  try {
    // Get appointment with full details for email
    const { data: appointment, error: fetchError } = await supabase
      .from('appointments')
      .select(
        `
        id,
        start_time,
        status,
        customer_id,
        customer_name,
        customer_email,
        booking_number,
        salon_id,
        staff:staff_id (display_name),
        appointment_services (service_name)
      `
      )
      .eq('id', appointmentId)
      .single();

    if (fetchError || !appointment) {
      return { success: false, error: 'Termin nicht gefunden.' };
    }

    // Verify ownership
    if (appointment.customer_id !== customerId) {
      return { success: false, error: 'Keine Berechtigung.' };
    }

    // Check status
    if (!['reserved', 'confirmed'].includes(appointment.status)) {
      return { success: false, error: 'Termin kann nicht mehr storniert werden.' };
    }

    // Check cancellation deadline (24 hours)
    const startsAt = new Date(appointment.start_time);
    const hoursUntil = (startsAt.getTime() - Date.now()) / (1000 * 60 * 60);

    if (hoursUntil < 24) {
      return {
        success: false,
        error: 'Stornierung nur bis 24 Stunden vor dem Termin möglich.',
      };
    }

    // Cancel appointment
    const { error: updateError } = await supabase
      .from('appointments')
      .update({
        status: 'cancelled',
        cancelled_at: new Date().toISOString(),
        cancellation_reason: 'Kunde hat storniert',
      })
      .eq('id', appointmentId);

    if (updateError) {
      console.error('Error cancelling appointment:', updateError);
      return { success: false, error: 'Fehler beim Stornieren.' };
    }

    // Send cancellation email
    if (appointment.customer_email) {
      const { data: salon } = await supabase
        .from('salons')
        .select('name, address, zip_code, city, phone')
        .eq('id', appointment.salon_id)
        .single();

      if (salon) {
        await sendCancellationEmail({
          customerName: appointment.customer_name || 'Kunde',
          customerEmail: appointment.customer_email,
          bookingNumber: appointment.booking_number || appointmentId.slice(0, 8).toUpperCase(),
          startsAt,
          staffName: (appointment.staff as any)?.display_name || 'Ihr Stylist',
          services: (appointment.appointment_services || []).map((s: any) => ({
            name: s.service_name,
          })),
          salonName: salon.name,
          salonAddress: `${salon.address}, ${salon.zip_code} ${salon.city}`,
          salonPhone: salon.phone || '+41 71 222 81 82',
          cancelledBy: 'customer',
          reason: 'Stornierung durch Kunde',
        }).catch((err) => {
          console.error('Failed to send cancellation email:', err);
        });
      }
    }

    revalidatePath('/konto/termine');
    return { success: true };
  } catch (error) {
    console.error('Cancel error:', error);
    return { success: false, error: 'Ein unerwarteter Fehler ist aufgetreten.' };
  }
}

// ============================================
// GET CUSTOMER PROFILE
// ============================================

export interface CustomerProfile {
  id: string;
  email: string;
  firstName: string;
  lastName: string;
  phone?: string;
  avatarUrl?: string;
  createdAt: Date;
}

export async function getCustomerProfile(userId: string): Promise<CustomerProfile | null> {
  const supabase = createServerClient();

  const { data, error } = await supabase.from('profiles').select('*').eq('id', userId).single();

  if (error || !data) {
    console.error('Error fetching profile:', error);
    return null;
  }

  return {
    id: data.id,
    email: data.email,
    firstName: data.first_name || '',
    lastName: data.last_name || '',
    phone: data.phone || undefined,
    avatarUrl: data.avatar_url || undefined,
    createdAt: new Date(data.created_at),
  };
}

// ============================================
// UPDATE CUSTOMER PROFILE
// ============================================

const updateProfileSchema = z.object({
  firstName: z.string().min(2, 'Vorname muss mindestens 2 Zeichen lang sein'),
  lastName: z.string().min(2, 'Nachname muss mindestens 2 Zeichen lang sein'),
  phone: z.string().optional(),
});

export type UpdateProfileResult = {
  success: boolean;
  error?: string;
};

export async function updateCustomerProfile(
  userId: string,
  formData: FormData
): Promise<UpdateProfileResult> {
  const supabase = createServerClient();

  try {
    const validatedFields = updateProfileSchema.safeParse({
      firstName: formData.get('firstName'),
      lastName: formData.get('lastName'),
      phone: formData.get('phone'),
    });

    if (!validatedFields.success) {
      const errors = validatedFields.error.flatten().fieldErrors;
      const firstError = Object.values(errors)[0]?.[0] || 'Validierungsfehler';
      return { success: false, error: firstError };
    }

    const { firstName, lastName, phone } = validatedFields.data;

    const { error } = await supabase
      .from('profiles')
      .update({
        first_name: firstName,
        last_name: lastName,
        phone: phone || null,
        updated_at: new Date().toISOString(),
      })
      .eq('id', userId);

    if (error) {
      console.error('Error updating profile:', error);
      return { success: false, error: 'Profil konnte nicht aktualisiert werden.' };
    }

    revalidatePath('/konto/profil');
    return { success: true };
  } catch (error) {
    console.error('Update profile error:', error);
    return { success: false, error: 'Ein unerwarteter Fehler ist aufgetreten.' };
  }
}
