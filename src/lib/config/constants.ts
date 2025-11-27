// Application Constants for SCHNITTWERK

export const APP_CONFIG = {
  name: 'SCHNITTWERK',
  fullName: 'SCHNITTWERK by Vanessa Carosella',
  description: 'Ihr Friseursalon in St. Gallen',

  // Location
  address: {
    street: 'Rorschacherstrasse 152',
    zip: '9000',
    city: 'St. Gallen',
    country: 'Schweiz',
  },

  // Contact
  phone: '+41 71 XXX XX XX',
  email: 'info@schnittwerk.ch',

  // Social
  instagram: 'https://instagram.com/schnittwerk',

  // Business
  currency: 'CHF',
  timezone: 'Europe/Zurich',
  locale: 'de-CH',

  // VAT
  defaultVatRate: 8.1,
} as const;

export const BOOKING_DEFAULTS = {
  slotGranularityMinutes: 15,
  minLeadTimeMinutes: 60,
  maxBookingHorizonDays: 90,
  cancellationCutoffHours: 24,
  reservationTimeoutMinutes: 15,
  maxActiveReservationsPerCustomer: 2,
} as const;

export const LOYALTY_CONFIG = {
  pointsPerChf: 1,
  pointsRedemptionRate: 0.01, // 1 point = 0.01 CHF
} as const;
