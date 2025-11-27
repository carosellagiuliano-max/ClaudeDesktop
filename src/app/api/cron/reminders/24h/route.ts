/**
 * SCHNITTWERK - 24h Reminder Cron Job
 * Vercel Cron: Run daily at 08:00 CET
 *
 * vercel.json config:
 * {
 *   "crons": [{
 *     "path": "/api/cron/reminders/24h",
 *     "schedule": "0 7 * * *"  // 07:00 UTC = 08:00 CET
 *   }]
 * }
 */

import { NextRequest, NextResponse } from 'next/server';
import { process24HourReminders } from '@/lib/notifications/reminders';
import { logger } from '@/lib/logging/logger';

// Verify cron secret to prevent unauthorized access
const CRON_SECRET = process.env.CRON_SECRET;

export async function GET(request: NextRequest) {
  // Verify authorization
  const authHeader = request.headers.get('authorization');
  if (CRON_SECRET && authHeader !== `Bearer ${CRON_SECRET}`) {
    logger.warn('Unauthorized cron access attempt', { path: '/api/cron/reminders/24h' });
    return NextResponse.json({ error: 'Unauthorized' }, { status: 401 });
  }

  logger.info('Starting 24h reminder cron job');

  try {
    const result = await process24HourReminders();

    logger.info('24h reminder cron completed', result);

    return NextResponse.json({
      success: true,
      ...result,
      timestamp: new Date().toISOString(),
    });
  } catch (error) {
    logger.error('24h reminder cron failed', error as Error);

    return NextResponse.json(
      {
        success: false,
        error: error instanceof Error ? error.message : 'Unknown error',
        timestamp: new Date().toISOString(),
      },
      { status: 500 }
    );
  }
}
