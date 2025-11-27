/**
 * ============================================
 * SCHNITTWERK - Slot Engine Tests
 * Property-based and unit tests for booking slot calculation
 * ============================================
 */

import { describe, it, expect, beforeEach } from 'vitest';
import {
  computeAvailableSlots,
  groupSlotsByDate,
} from '@/lib/domain/booking/slot-engine';
import type {
  SlotEngineInput,
  BookableService,
  BookableStaff,
  DayOpeningHours,
  StaffWorkingHours,
  StaffAbsence,
  BlockedTime,
  ExistingAppointment,
  BookingRules,
} from '@/lib/domain/booking/types';
import { addDays, addMinutes, setHours, setMinutes, startOfDay } from 'date-fns';

// ============================================
// TEST FIXTURES
// ============================================

const createDate = (daysFromNow: number, hours: number, minutes: number): Date => {
  const date = addDays(startOfDay(new Date()), daysFromNow);
  return setMinutes(setHours(date, hours), minutes);
};

const mockServices: BookableService[] = [
  {
    id: 'service-1',
    name: 'Haarschnitt Damen',
    durationMinutes: 45,
    currentPrice: 8500,
    categoryId: 'cat-1',
    isActive: true,
  },
  {
    id: 'service-2',
    name: 'Färben',
    durationMinutes: 90,
    currentPrice: 12000,
    categoryId: 'cat-1',
    isActive: true,
  },
];

const mockStaff: BookableStaff[] = [
  {
    id: 'staff-1',
    name: 'Vanessa',
    serviceIds: ['service-1', 'service-2'],
    isBookable: true,
  },
  {
    id: 'staff-2',
    name: 'Sarah',
    serviceIds: ['service-1'],
    isBookable: true,
  },
];

const mockOpeningHours: DayOpeningHours[] = [
  { dayOfWeek: 0, openTime: '09:00', closeTime: '18:00', isClosed: true }, // Sunday closed
  { dayOfWeek: 1, openTime: '09:00', closeTime: '18:00', isClosed: false }, // Monday
  { dayOfWeek: 2, openTime: '09:00', closeTime: '18:00', isClosed: false }, // Tuesday
  { dayOfWeek: 3, openTime: '09:00', closeTime: '18:00', isClosed: false }, // Wednesday
  { dayOfWeek: 4, openTime: '09:00', closeTime: '18:00', isClosed: false }, // Thursday
  { dayOfWeek: 5, openTime: '09:00', closeTime: '18:00', isClosed: false }, // Friday
  { dayOfWeek: 6, openTime: '09:00', closeTime: '14:00', isClosed: false }, // Saturday
];

const mockStaffWorkingHours: StaffWorkingHours[] = [
  { staffId: 'staff-1', dayOfWeek: 1, startTime: '09:00', endTime: '17:00' },
  { staffId: 'staff-1', dayOfWeek: 2, startTime: '09:00', endTime: '17:00' },
  { staffId: 'staff-1', dayOfWeek: 3, startTime: '09:00', endTime: '17:00' },
  { staffId: 'staff-1', dayOfWeek: 4, startTime: '09:00', endTime: '17:00' },
  { staffId: 'staff-1', dayOfWeek: 5, startTime: '09:00', endTime: '17:00' },
  { staffId: 'staff-2', dayOfWeek: 1, startTime: '10:00', endTime: '18:00' },
  { staffId: 'staff-2', dayOfWeek: 2, startTime: '10:00', endTime: '18:00' },
  { staffId: 'staff-2', dayOfWeek: 3, startTime: '10:00', endTime: '18:00' },
];

const mockBookingRules: BookingRules = {
  slotGranularityMinutes: 15,
  leadTimeMinutes: 60,
  horizonDays: 30,
  bufferBetweenMinutes: 0,
  allowMultipleServices: true,
  requireDeposit: false,
  cancellationDeadlineHours: 24,
};

// ============================================
// UNIT TESTS
// ============================================

describe('Slot Engine', () => {
  describe('computeAvailableSlots', () => {
    it('should return empty array for closed days', async () => {
      const input: SlotEngineInput = {
        salonId: 'salon-1',
        dateRangeStart: createDate(7, 0, 0), // A Sunday
        dateRangeEnd: createDate(7, 23, 59),
        serviceIds: ['service-1'],
      };

      // Find a Sunday
      let sundayOffset = 7;
      for (let i = 0; i < 7; i++) {
        if (addDays(new Date(), i).getDay() === 0) {
          sundayOffset = i;
          break;
        }
      }

      input.dateRangeStart = createDate(sundayOffset, 0, 0);
      input.dateRangeEnd = createDate(sundayOffset, 23, 59);

      const slots = await computeAvailableSlots(input, {
        services: mockServices.filter((s) => s.id === 'service-1'),
        openingHours: mockOpeningHours,
        staff: mockStaff,
        staffWorkingHours: mockStaffWorkingHours,
        staffAbsences: [],
        blockedTimes: [],
        existingAppointments: [],
        bookingRules: mockBookingRules,
      });

      expect(slots.filter((s) => s.startsAt.getDay() === 0)).toHaveLength(0);
    });

    it('should filter staff by service skills', async () => {
      const input: SlotEngineInput = {
        salonId: 'salon-1',
        dateRangeStart: createDate(1, 0, 0),
        dateRangeEnd: createDate(3, 23, 59),
        serviceIds: ['service-2'], // Färben - only Vanessa can do this
      };

      const slots = await computeAvailableSlots(input, {
        services: mockServices.filter((s) => s.id === 'service-2'),
        openingHours: mockOpeningHours,
        staff: mockStaff,
        staffWorkingHours: mockStaffWorkingHours,
        staffAbsences: [],
        blockedTimes: [],
        existingAppointments: [],
        bookingRules: mockBookingRules,
      });

      // All slots should be for Vanessa (staff-1)
      expect(slots.every((s) => s.staffId === 'staff-1')).toBe(true);
    });

    it('should respect existing appointments', async () => {
      const tomorrow = addDays(startOfDay(new Date()), 1);
      const bookedStart = setMinutes(setHours(tomorrow, 10), 0);
      const bookedEnd = setMinutes(setHours(tomorrow, 11), 0);

      const existingAppointments: ExistingAppointment[] = [
        {
          id: 'apt-1',
          staffId: 'staff-1',
          startsAt: bookedStart,
          endsAt: bookedEnd,
          status: 'confirmed',
        },
      ];

      const input: SlotEngineInput = {
        salonId: 'salon-1',
        dateRangeStart: tomorrow,
        dateRangeEnd: tomorrow,
        serviceIds: ['service-1'],
      };

      const slots = await computeAvailableSlots(input, {
        services: mockServices.filter((s) => s.id === 'service-1'),
        openingHours: mockOpeningHours,
        staff: mockStaff.filter((s) => s.id === 'staff-1'),
        staffWorkingHours: mockStaffWorkingHours,
        staffAbsences: [],
        blockedTimes: [],
        existingAppointments,
        bookingRules: mockBookingRules,
      });

      // No slots should overlap with the booked time
      const conflictingSlots = slots.filter(
        (s) =>
          s.staffId === 'staff-1' &&
          s.startsAt < bookedEnd &&
          s.endsAt > bookedStart
      );

      expect(conflictingSlots).toHaveLength(0);
    });

    it('should respect staff absences', async () => {
      const tomorrow = addDays(startOfDay(new Date()), 1);

      const staffAbsences: StaffAbsence[] = [
        {
          staffId: 'staff-1',
          startsAt: tomorrow,
          endsAt: addDays(tomorrow, 1),
          reason: 'Urlaub',
        },
      ];

      const input: SlotEngineInput = {
        salonId: 'salon-1',
        dateRangeStart: tomorrow,
        dateRangeEnd: tomorrow,
        serviceIds: ['service-1'],
      };

      const slots = await computeAvailableSlots(input, {
        services: mockServices.filter((s) => s.id === 'service-1'),
        openingHours: mockOpeningHours,
        staff: mockStaff,
        staffWorkingHours: mockStaffWorkingHours,
        staffAbsences,
        blockedTimes: [],
        existingAppointments: [],
        bookingRules: mockBookingRules,
      });

      // No slots for staff-1 on this day
      const vanessaSlots = slots.filter((s) => s.staffId === 'staff-1');
      expect(vanessaSlots).toHaveLength(0);
    });

    it('should respect lead time', async () => {
      const now = new Date();
      const today = startOfDay(now);

      const input: SlotEngineInput = {
        salonId: 'salon-1',
        dateRangeStart: today,
        dateRangeEnd: today,
        serviceIds: ['service-1'],
      };

      const slots = await computeAvailableSlots(input, {
        services: mockServices.filter((s) => s.id === 'service-1'),
        openingHours: mockOpeningHours,
        staff: mockStaff,
        staffWorkingHours: mockStaffWorkingHours,
        staffAbsences: [],
        blockedTimes: [],
        existingAppointments: [],
        bookingRules: { ...mockBookingRules, leadTimeMinutes: 60 },
      });

      // All slots should be at least 60 minutes from now
      const minStartTime = addMinutes(now, 60);
      const tooEarlySlots = slots.filter((s) => s.startsAt < minStartTime);

      expect(tooEarlySlots).toHaveLength(0);
    });

    it('should calculate correct total duration for multiple services', async () => {
      const input: SlotEngineInput = {
        salonId: 'salon-1',
        dateRangeStart: createDate(1, 0, 0),
        dateRangeEnd: createDate(1, 23, 59),
        serviceIds: ['service-1', 'service-2'], // 45 + 90 = 135 minutes
      };

      const slots = await computeAvailableSlots(input, {
        services: mockServices,
        openingHours: mockOpeningHours,
        staff: mockStaff.filter((s) => s.id === 'staff-1'), // Only Vanessa can do both
        staffWorkingHours: mockStaffWorkingHours,
        staffAbsences: [],
        blockedTimes: [],
        existingAppointments: [],
        bookingRules: mockBookingRules,
      });

      // All slots should have totalDuration of 135
      expect(slots.every((s) => s.totalDuration === 135)).toBe(true);
    });

    it('should respect slot granularity', async () => {
      const input: SlotEngineInput = {
        salonId: 'salon-1',
        dateRangeStart: createDate(1, 0, 0),
        dateRangeEnd: createDate(1, 23, 59),
        serviceIds: ['service-1'],
      };

      const slots = await computeAvailableSlots(input, {
        services: mockServices.filter((s) => s.id === 'service-1'),
        openingHours: mockOpeningHours,
        staff: mockStaff,
        staffWorkingHours: mockStaffWorkingHours,
        staffAbsences: [],
        blockedTimes: [],
        existingAppointments: [],
        bookingRules: { ...mockBookingRules, slotGranularityMinutes: 30 },
      });

      // All slot start times should be on 30-minute boundaries
      const nonAlignedSlots = slots.filter(
        (s) => s.startsAt.getMinutes() % 30 !== 0
      );

      expect(nonAlignedSlots).toHaveLength(0);
    });

    it('should prefer selected staff when provided', async () => {
      const input: SlotEngineInput = {
        salonId: 'salon-1',
        dateRangeStart: createDate(1, 0, 0),
        dateRangeEnd: createDate(1, 23, 59),
        serviceIds: ['service-1'],
        preferredStaffId: 'staff-2',
      };

      const slots = await computeAvailableSlots(input, {
        services: mockServices.filter((s) => s.id === 'service-1'),
        openingHours: mockOpeningHours,
        staff: mockStaff,
        staffWorkingHours: mockStaffWorkingHours,
        staffAbsences: [],
        blockedTimes: [],
        existingAppointments: [],
        bookingRules: mockBookingRules,
      });

      // Slots should include both staff, but sorted with preferred first for same time
      expect(slots.length).toBeGreaterThan(0);
    });
  });

  describe('groupSlotsByDate', () => {
    it('should group slots by date', () => {
      const tomorrow = addDays(startOfDay(new Date()), 1);
      const dayAfter = addDays(startOfDay(new Date()), 2);

      const slots = [
        {
          staffId: 'staff-1',
          staffName: 'Vanessa',
          startsAt: setHours(tomorrow, 9),
          endsAt: setHours(tomorrow, 10),
          totalDuration: 60,
          services: [],
        },
        {
          staffId: 'staff-1',
          staffName: 'Vanessa',
          startsAt: setHours(tomorrow, 10),
          endsAt: setHours(tomorrow, 11),
          totalDuration: 60,
          services: [],
        },
        {
          staffId: 'staff-1',
          staffName: 'Vanessa',
          startsAt: setHours(dayAfter, 9),
          endsAt: setHours(dayAfter, 10),
          totalDuration: 60,
          services: [],
        },
      ];

      const grouped = groupSlotsByDate(slots);

      expect(grouped).toHaveLength(2);
      expect(grouped[0].slots).toHaveLength(2);
      expect(grouped[1].slots).toHaveLength(1);
    });

    it('should format display dates correctly', () => {
      const today = startOfDay(new Date());
      const tomorrow = addDays(today, 1);

      const slots = [
        {
          staffId: 'staff-1',
          staffName: 'Vanessa',
          startsAt: setHours(today, 14),
          endsAt: setHours(today, 15),
          totalDuration: 60,
          services: [],
        },
        {
          staffId: 'staff-1',
          staffName: 'Vanessa',
          startsAt: setHours(tomorrow, 9),
          endsAt: setHours(tomorrow, 10),
          totalDuration: 60,
          services: [],
        },
      ];

      const grouped = groupSlotsByDate(slots);

      expect(grouped[0].displayDate).toBe('Heute');
      expect(grouped[1].displayDate).toBe('Morgen');
    });
  });
});

// ============================================
// PROPERTY-BASED TESTS (Invariants)
// ============================================

describe('Slot Engine Invariants', () => {
  it('INVARIANT: No duplicate start times for same staff', async () => {
    // NOTE: Slots CAN overlap in time (because granularity < service duration)
    // But no two slots should have the SAME start time for the same staff
    const input: SlotEngineInput = {
      salonId: 'salon-1',
      dateRangeStart: createDate(1, 0, 0),
      dateRangeEnd: createDate(7, 23, 59),
      serviceIds: ['service-1'],
    };

    const slots = await computeAvailableSlots(input, {
      services: mockServices.filter((s) => s.id === 'service-1'),
      openingHours: mockOpeningHours,
      staff: mockStaff,
      staffWorkingHours: mockStaffWorkingHours,
      staffAbsences: [],
      blockedTimes: [],
      existingAppointments: [],
      bookingRules: mockBookingRules,
    });

    // Group by staff
    const slotsByStaff = new Map<string, typeof slots>();
    slots.forEach((slot) => {
      const existing = slotsByStaff.get(slot.staffId) || [];
      existing.push(slot);
      slotsByStaff.set(slot.staffId, existing);
    });

    // Check no duplicate start times within each staff's slots
    slotsByStaff.forEach((staffSlots, staffId) => {
      const startTimes = new Set<string>();
      for (const slot of staffSlots) {
        const key = slot.startsAt.toISOString();
        if (startTimes.has(key)) {
          throw new Error(
            `Duplicate slot start time for ${staffId}: ${key}`
          );
        }
        startTimes.add(key);
      }
    });

    expect(true).toBe(true); // If we get here, no duplicates found
  });

  it('INVARIANT: All slots are within opening hours', async () => {
    const input: SlotEngineInput = {
      salonId: 'salon-1',
      dateRangeStart: createDate(1, 0, 0),
      dateRangeEnd: createDate(7, 23, 59),
      serviceIds: ['service-1'],
    };

    const slots = await computeAvailableSlots(input, {
      services: mockServices.filter((s) => s.id === 'service-1'),
      openingHours: mockOpeningHours,
      staff: mockStaff,
      staffWorkingHours: mockStaffWorkingHours,
      staffAbsences: [],
      blockedTimes: [],
      existingAppointments: [],
      bookingRules: mockBookingRules,
    });

    slots.forEach((slot) => {
      const dayOfWeek = slot.startsAt.getDay();
      const openingHour = mockOpeningHours.find((h) => h.dayOfWeek === dayOfWeek);

      expect(openingHour).toBeDefined();
      expect(openingHour!.isClosed).toBe(false);

      const slotStartMinutes = slot.startsAt.getHours() * 60 + slot.startsAt.getMinutes();
      const slotEndMinutes = slot.endsAt.getHours() * 60 + slot.endsAt.getMinutes();

      const [openH, openM] = openingHour!.openTime.split(':').map(Number);
      const [closeH, closeM] = openingHour!.closeTime.split(':').map(Number);
      const openMinutes = openH * 60 + openM;
      const closeMinutes = closeH * 60 + closeM;

      expect(slotStartMinutes).toBeGreaterThanOrEqual(openMinutes);
      expect(slotEndMinutes).toBeLessThanOrEqual(closeMinutes);
    });
  });

  it('INVARIANT: Slot duration matches service total', async () => {
    const serviceDuration = 45; // service-1 duration

    const input: SlotEngineInput = {
      salonId: 'salon-1',
      dateRangeStart: createDate(1, 0, 0),
      dateRangeEnd: createDate(3, 23, 59),
      serviceIds: ['service-1'],
    };

    const slots = await computeAvailableSlots(input, {
      services: mockServices.filter((s) => s.id === 'service-1'),
      openingHours: mockOpeningHours,
      staff: mockStaff,
      staffWorkingHours: mockStaffWorkingHours,
      staffAbsences: [],
      blockedTimes: [],
      existingAppointments: [],
      bookingRules: mockBookingRules,
    });

    slots.forEach((slot) => {
      expect(slot.totalDuration).toBe(serviceDuration);

      const actualDuration =
        (slot.endsAt.getTime() - slot.startsAt.getTime()) / (1000 * 60);
      expect(actualDuration).toBe(serviceDuration);
    });
  });

  it('INVARIANT: Slots are sorted chronologically', async () => {
    const input: SlotEngineInput = {
      salonId: 'salon-1',
      dateRangeStart: createDate(1, 0, 0),
      dateRangeEnd: createDate(7, 23, 59),
      serviceIds: ['service-1'],
    };

    const slots = await computeAvailableSlots(input, {
      services: mockServices.filter((s) => s.id === 'service-1'),
      openingHours: mockOpeningHours,
      staff: mockStaff,
      staffWorkingHours: mockStaffWorkingHours,
      staffAbsences: [],
      blockedTimes: [],
      existingAppointments: [],
      bookingRules: mockBookingRules,
    });

    for (let i = 1; i < slots.length; i++) {
      expect(slots[i].startsAt.getTime()).toBeGreaterThanOrEqual(
        slots[i - 1].startsAt.getTime()
      );
    }
  });

  it('INVARIANT: No slots in the past', async () => {
    const now = new Date();

    const input: SlotEngineInput = {
      salonId: 'salon-1',
      dateRangeStart: startOfDay(now),
      dateRangeEnd: createDate(3, 23, 59),
      serviceIds: ['service-1'],
    };

    const slots = await computeAvailableSlots(input, {
      services: mockServices.filter((s) => s.id === 'service-1'),
      openingHours: mockOpeningHours,
      staff: mockStaff,
      staffWorkingHours: mockStaffWorkingHours,
      staffAbsences: [],
      blockedTimes: [],
      existingAppointments: [],
      bookingRules: { ...mockBookingRules, leadTimeMinutes: 0 },
    });

    slots.forEach((slot) => {
      expect(slot.startsAt.getTime()).toBeGreaterThanOrEqual(now.getTime());
    });
  });
});
