/**
 * SCHNITTWERK - Twilio Status Webhook
 * Receives delivery status updates for SMS messages
 */

import { NextRequest, NextResponse } from 'next/server';
import { logger } from '@/lib/logging/logger';

// Twilio status webhook signature validation
const TWILIO_AUTH_TOKEN = process.env.TWILIO_AUTH_TOKEN;

interface TwilioStatusPayload {
  MessageSid: string;
  MessageStatus: string;
  To: string;
  ErrorCode?: string;
  ErrorMessage?: string;
}

/**
 * POST /api/webhooks/twilio/status
 * Receives SMS delivery status updates from Twilio
 */
export async function POST(request: NextRequest) {
  try {
    // Parse form data (Twilio sends as application/x-www-form-urlencoded)
    const formData = await request.formData();

    const payload: TwilioStatusPayload = {
      MessageSid: formData.get('MessageSid') as string,
      MessageStatus: formData.get('MessageStatus') as string,
      To: formData.get('To') as string,
      ErrorCode: formData.get('ErrorCode') as string | undefined,
      ErrorMessage: formData.get('ErrorMessage') as string | undefined,
    };

    // Log the status update
    logger.info('SMS delivery status received', {
      messageId: payload.MessageSid,
      status: payload.MessageStatus,
      to: payload.To?.slice(0, 6) + '***', // Masked for privacy
      errorCode: payload.ErrorCode,
    });

    // Handle different statuses
    switch (payload.MessageStatus) {
      case 'delivered':
        await handleDelivered(payload);
        break;

      case 'failed':
      case 'undelivered':
        await handleFailed(payload);
        break;

      case 'sent':
        // Message is on its way, no action needed
        break;

      default:
        logger.debug('SMS status update', { status: payload.MessageStatus });
    }

    // Twilio expects a 200 response
    return new NextResponse('OK', { status: 200 });
  } catch (error) {
    logger.error('Twilio webhook error', error as Error);

    // Still return 200 to prevent retries for malformed requests
    return new NextResponse('OK', { status: 200 });
  }
}

/**
 * Handle successful delivery
 */
async function handleDelivered(payload: TwilioStatusPayload) {
  logger.info('SMS delivered successfully', {
    messageId: payload.MessageSid,
  });

  // TODO: Update notification_logs table if tracking
  // await updateNotificationStatus(payload.MessageSid, 'delivered');
}

/**
 * Handle failed delivery
 */
async function handleFailed(payload: TwilioStatusPayload) {
  logger.warn('SMS delivery failed', {
    messageId: payload.MessageSid,
    errorCode: payload.ErrorCode,
    errorMessage: payload.ErrorMessage,
  });

  // TODO: Update notification_logs table
  // TODO: Consider retry logic for transient failures
  // TODO: Alert on persistent failures

  // Common error codes to handle:
  // 30003 - Unreachable destination
  // 30004 - Message blocked
  // 30005 - Unknown destination
  // 30006 - Landline or unreachable carrier
  // 30007 - Message filtered (spam)
}
