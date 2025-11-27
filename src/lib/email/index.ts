// ============================================
// EMAIL SERVICE
// ============================================

// Booking emails
export {
  sendBookingConfirmationEmail,
  sendCancellationEmail,
  sendReminderEmail,
} from './booking-emails';
export type {
  BookingConfirmationData,
  CancellationEmailData,
  ReminderEmailData,
} from './booking-emails';

// Order emails
export {
  sendOrderConfirmationEmail,
  sendOrderShippedEmail,
  sendOrderCancelledEmail,
  sendVoucherToRecipient,
  sendPaymentFailedEmail,
  sendRefundConfirmationEmail,
} from './order-emails';

// Base email
export { sendEmail, type EmailOptions } from './send';
