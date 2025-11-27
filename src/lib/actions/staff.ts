'use server';

import { createServerClient } from '@/lib/db/client';
import { unstable_cache } from 'next/cache';

// ============================================
// STAFF DATA SERVER ACTIONS
// ============================================

// Default salon ID for SCHNITTWERK (from seed data)
const DEFAULT_SALON_ID = '550e8400-e29b-41d4-a716-446655440001';

export type StaffMember = {
  id: string;
  displayName: string;
  jobTitle: string | null;
  bio: string | null;
  avatarUrl: string | null;
  isBookable: boolean;
  sortOrder: number;
  specialties: string[];
};

export type StaffWorkingHours = {
  staffId: string;
  dayOfWeek: number;
  startTime: string;
  endTime: string;
};

export type StaffAbsence = {
  staffId: string;
  startDate: string;
  endDate: string;
  reason: string | null;
};

// ============================================
// GET STAFF MEMBERS
// ============================================

export const getStaffMembers = unstable_cache(
  async (salonId: string = DEFAULT_SALON_ID): Promise<StaffMember[]> => {
    const supabase = createServerClient();

    const { data, error } = await supabase
      .from('staff')
      .select(
        `
        id,
        display_name,
        job_title,
        bio,
        avatar_url,
        is_bookable,
        sort_order,
        specialties
      `
      )
      .eq('salon_id', salonId)
      .eq('is_active', true)
      .order('sort_order', { ascending: true });

    if (error || !data) {
      console.error('Error fetching staff:', error);
      return [];
    }

    return data.map((member) => ({
      id: member.id,
      displayName: member.display_name,
      jobTitle: member.job_title,
      bio: member.bio,
      avatarUrl: member.avatar_url,
      isBookable: member.is_bookable,
      sortOrder: member.sort_order,
      specialties: member.specialties || [],
    }));
  },
  ['staff-members'],
  { revalidate: 3600, tags: ['staff'] }
);

// ============================================
// GET BOOKABLE STAFF (for booking flow)
// ============================================

export const getBookableStaff = unstable_cache(
  async (salonId: string = DEFAULT_SALON_ID): Promise<StaffMember[]> => {
    const allStaff = await getStaffMembers(salonId);
    return allStaff.filter((member) => member.isBookable);
  },
  ['bookable-staff'],
  { revalidate: 3600, tags: ['staff'] }
);

// ============================================
// GET STAFF WORKING HOURS
// ============================================

export const getStaffWorkingHours = unstable_cache(
  async (salonId: string = DEFAULT_SALON_ID): Promise<StaffWorkingHours[]> => {
    const supabase = createServerClient();

    const { data, error } = await supabase
      .from('staff_working_hours')
      .select(
        `
        staff_id,
        day_of_week,
        start_time,
        end_time
      `
      )
      .eq('salon_id', salonId);

    if (error || !data) {
      console.error('Error fetching staff working hours:', error);
      return [];
    }

    return data.map((row) => ({
      staffId: row.staff_id,
      dayOfWeek: row.day_of_week,
      startTime: row.start_time,
      endTime: row.end_time,
    }));
  },
  ['staff-working-hours'],
  { revalidate: 3600, tags: ['staff'] }
);

// ============================================
// GET STAFF ABSENCES (for date range)
// ============================================

export async function getStaffAbsences(
  salonId: string = DEFAULT_SALON_ID,
  startDate: string,
  endDate: string
): Promise<StaffAbsence[]> {
  const supabase = createServerClient();

  const { data, error } = await supabase
    .from('staff_absences')
    .select(
      `
      staff_id,
      start_date,
      end_date,
      reason
    `
    )
    .eq('salon_id', salonId)
    .or(`start_date.lte.${endDate},end_date.gte.${startDate}`);

  if (error || !data) {
    console.error('Error fetching staff absences:', error);
    return [];
  }

  return data.map((row) => ({
    staffId: row.staff_id,
    startDate: row.start_date,
    endDate: row.end_date,
    reason: row.reason,
  }));
}

// ============================================
// GET STAFF SKILLS (services they can perform)
// ============================================

export const getStaffSkills = unstable_cache(
  async (salonId: string = DEFAULT_SALON_ID): Promise<Map<string, string[]>> => {
    const supabase = createServerClient();

    const { data, error } = await supabase
      .from('staff_service_skills')
      .select(
        `
        staff_id,
        service_id
      `
      )
      .eq('salon_id', salonId);

    if (error || !data) {
      console.error('Error fetching staff skills:', error);
      return new Map();
    }

    const skillsMap = new Map<string, string[]>();

    data.forEach((row) => {
      const existing = skillsMap.get(row.staff_id) || [];
      existing.push(row.service_id);
      skillsMap.set(row.staff_id, existing);
    });

    return skillsMap;
  },
  ['staff-skills'],
  { revalidate: 3600, tags: ['staff'] }
);
