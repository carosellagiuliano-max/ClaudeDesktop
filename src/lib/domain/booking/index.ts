// ============================================
// BOOKING DOMAIN EXPORTS
// ============================================

// Types
export type {
  TimeInterval,
  SlotEngineInput,
  ServiceSlotInfo,
  AvailableSlot,
  SlotsByDate,
  DayOpeningHours,
  StaffWorkingHours,
  StaffAbsence,
  BlockedTime,
  ExistingAppointment,
  BookingRules,
  BookableService,
  BookableStaff,
  SlotReservation,
  BookingRequest,
  BookingConfirmation,
  SlotEngineErrorCode,
} from './types';

export { SlotEngineError } from './types';

// Slot Engine
export { computeAvailableSlots, groupSlotsByDate } from './slot-engine';

// Reservation System
export {
  generateSlotKey,
  createReservation,
  isReservationValid,
  hasConflictingReservation,
  validateReservation,
  getRemainingReservationTime,
  formatRemainingTime,
} from './reservation';
