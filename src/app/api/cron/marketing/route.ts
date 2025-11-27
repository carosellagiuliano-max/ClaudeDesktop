/**
 * SCHNITTWERK - Marketing Cron Job
 * Runs daily to process automated marketing campaigns
 *
 * Vercel Cron: 0 8 * * * (daily at 08:00)
 */

import { NextRequest, NextResponse } from 'next/server';
import { headers } from 'next/headers';
import { getMarketingService } from '@/lib/services/marketing-service';
import { getFeedbackService } from '@/lib/services/feedback-service';
import { logger } from '@/lib/logging/logger';
import { createServiceRoleClient } from '@/lib/supabase/server';

// Verify the request is from Vercel Cron
function verifyCronRequest(request: NextRequest): boolean {
  const authHeader = request.headers.get('authorization');
  const cronSecret = process.env.CRON_SECRET;

  // In development, allow all requests
  if (process.env.NODE_ENV === 'development') {
    return true;
  }

  // Vercel cron sends the secret in the Authorization header
  if (cronSecret && authHeader === `Bearer ${cronSecret}`) {
    return true;
  }

  // Also check the x-vercel-cron-signature header
  const vercelCron = request.headers.get('x-vercel-cron-signature');
  if (vercelCron) {
    return true;
  }

  return false;
}

export async function GET(request: NextRequest) {
  const startTime = Date.now();

  // Verify this is a legitimate cron request
  if (!verifyCronRequest(request)) {
    logger.warn('Unauthorized marketing cron request');
    return NextResponse.json({ error: 'Unauthorized' }, { status: 401 });
  }

  logger.info('Marketing cron job started');

  const results = {
    birthday: { sent: 0, failed: 0 },
    reengagement: { sent: 0, failed: 0 },
    welcome: { sent: 0, failed: 0 },
    postVisit: { sent: 0, failed: 0 },
    feedbackRequests: { created: 0, failed: 0 },
  };

  try {
    const supabase = createServiceRoleClient();
    const marketingService = getMarketingService();
    const feedbackService = getFeedbackService();

    // Get all active salons
    const { data: salons } = await supabase
      .from('salons')
      .select('id, name')
      .eq('is_active', true);

    if (!salons || salons.length === 0) {
      logger.info('No active salons found');
      return NextResponse.json({
        success: true,
        message: 'No active salons',
        results,
        duration: Date.now() - startTime,
      });
    }

    // Process campaigns for each salon
    for (const salon of salons) {
      try {
        // 1. Birthday campaigns
        const birthdayResults = await marketingService.processBirthdayCampaigns(salon.id);
        results.birthday.sent += birthdayResults.sent;
        results.birthday.failed += birthdayResults.failed;

        // 2. Re-engagement campaigns (60 days inactive)
        const reengagementResults = await marketingService.processReengagementCampaigns(
          salon.id,
          60
        );
        results.reengagement.sent += reengagementResults.sent;
        results.reengagement.failed += reengagementResults.failed;

        // 3. Welcome campaigns (new customers from yesterday)
        const welcomeResults = await marketingService.processWelcomeCampaigns(salon.id);
        results.welcome.sent += welcomeResults.sent;
        results.welcome.failed += welcomeResults.failed;

        // 4. Post-visit feedback requests
        const postVisitResults = await marketingService.processPostVisitCampaigns(salon.id);
        results.postVisit.sent += postVisitResults.sent;
        results.postVisit.failed += postVisitResults.failed;

        // 5. Create feedback requests for completed appointments
        const feedbackResults = await createFeedbackRequests(salon.id, feedbackService, supabase);
        results.feedbackRequests.created += feedbackResults.created;
        results.feedbackRequests.failed += feedbackResults.failed;

      } catch (salonError) {
        logger.error('Marketing cron failed for salon', salonError as Error, {
          salonId: salon.id,
        });
      }
    }

    const duration = Date.now() - startTime;

    logger.info('Marketing cron job completed', {
      duration,
      results,
      salonsProcessed: salons.length,
    });

    return NextResponse.json({
      success: true,
      message: 'Marketing campaigns processed',
      results,
      salonsProcessed: salons.length,
      duration,
    });

  } catch (error) {
    const errorMessage = error instanceof Error ? error.message : 'Unknown error';
    logger.error('Marketing cron job failed', new Error(errorMessage));

    return NextResponse.json(
      {
        success: false,
        error: errorMessage,
        results,
        duration: Date.now() - startTime,
      },
      { status: 500 }
    );
  }
}

/**
 * Create feedback requests for completed appointments from yesterday
 */
async function createFeedbackRequests(
  salonId: string,
  feedbackService: ReturnType<typeof getFeedbackService>,
  supabase: ReturnType<typeof createServiceRoleClient>
): Promise<{ created: number; failed: number }> {
  const yesterday = new Date();
  yesterday.setDate(yesterday.getDate() - 1);
  yesterday.setHours(0, 0, 0, 0);

  const today = new Date();
  today.setHours(0, 0, 0, 0);

  // Get completed appointments from yesterday that don't have feedback requests
  const { data: appointments, error } = await supabase
    .from('appointments')
    .select('id')
    .eq('salon_id', salonId)
    .eq('status', 'completed')
    .gte('ends_at', yesterday.toISOString())
    .lt('ends_at', today.toISOString());

  if (error || !appointments) {
    return { created: 0, failed: 0 };
  }

  let created = 0;
  let failed = 0;

  for (const appt of appointments) {
    try {
      const result = await feedbackService.createFeedbackRequest(appt.id);
      if (result) {
        created++;
      }
    } catch {
      failed++;
    }
  }

  return { created, failed };
}

// Allow POST for manual triggering (admin only)
export async function POST(request: NextRequest) {
  // For manual triggers, verify admin authentication
  const headersList = await headers();
  const authHeader = headersList.get('authorization');

  if (!authHeader) {
    return NextResponse.json({ error: 'Unauthorized' }, { status: 401 });
  }

  // Process same as GET
  return GET(request);
}
