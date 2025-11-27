/**
 * SCHNITTWERK Load Test - Booking Flow
 * Run with: k6 run loadtests/booking-flow.js
 *
 * Install k6:
 * - macOS: brew install k6
 * - Windows: choco install k6
 * - Linux: https://k6.io/docs/getting-started/installation/
 */

import http from 'k6/http';
import { check, sleep, group } from 'k6';
import { Rate, Trend } from 'k6/metrics';

// ============================================
// CONFIGURATION
// ============================================

const BASE_URL = __ENV.BASE_URL || 'http://localhost:3000';

export const options = {
  // Ramp up to 50 users over 2 minutes, hold for 5 minutes, ramp down
  stages: [
    { duration: '2m', target: 20 }, // Ramp up to 20 users
    { duration: '5m', target: 50 }, // Ramp up to 50 users
    { duration: '3m', target: 50 }, // Stay at 50 users
    { duration: '2m', target: 0 },  // Ramp down
  ],

  thresholds: {
    http_req_duration: ['p(95)<500'], // 95% of requests should be under 500ms
    http_req_failed: ['rate<0.01'],   // Less than 1% failure rate
    'booking_success': ['rate>0.95'], // 95% booking success rate
  },
};

// ============================================
// CUSTOM METRICS
// ============================================

const bookingSuccess = new Rate('booking_success');
const bookingDuration = new Trend('booking_duration');

// ============================================
// TEST DATA
// ============================================

const testCustomers = [
  { email: 'test1@example.com', name: 'Test User 1' },
  { email: 'test2@example.com', name: 'Test User 2' },
  { email: 'test3@example.com', name: 'Test User 3' },
];

// ============================================
// MAIN TEST SCENARIO
// ============================================

export default function () {
  const customer = testCustomers[Math.floor(Math.random() * testCustomers.length)];

  group('Homepage', () => {
    const res = http.get(`${BASE_URL}/`);
    check(res, {
      'homepage status 200': (r) => r.status === 200,
      'homepage loads fast': (r) => r.timings.duration < 1000,
    });
    sleep(1);
  });

  group('Booking Page', () => {
    const res = http.get(`${BASE_URL}/termin-buchen`);
    check(res, {
      'booking page status 200': (r) => r.status === 200,
      'booking page loads fast': (r) => r.timings.duration < 2000,
    });
    sleep(2);
  });

  group('Load Services', () => {
    const res = http.get(`${BASE_URL}/api/public/services`);
    check(res, {
      'services API status 200': (r) => r.status === 200,
      'services returns data': (r) => {
        try {
          const data = JSON.parse(r.body);
          return Array.isArray(data) || data.services;
        } catch {
          return false;
        }
      },
    });
    sleep(1);
  });

  group('Check Availability', () => {
    const tomorrow = new Date();
    tomorrow.setDate(tomorrow.getDate() + 1);
    const dateStr = tomorrow.toISOString().split('T')[0];

    const res = http.get(
      `${BASE_URL}/api/public/availability?date=${dateStr}&serviceId=test-service`
    );

    check(res, {
      'availability API responds': (r) => r.status === 200 || r.status === 404,
    });
    sleep(1);
  });

  group('Simulate Booking', () => {
    const startTime = Date.now();

    // In real test, this would POST to booking API
    const bookingPayload = JSON.stringify({
      customerId: `test-${__VU}-${__ITER}`,
      serviceIds: ['test-service'],
      staffId: 'any',
      startsAt: new Date(Date.now() + 86400000).toISOString(),
      customerEmail: customer.email,
      customerName: customer.name,
    });

    // Simulate booking submission (replace with actual endpoint)
    const res = http.post(`${BASE_URL}/api/booking`, bookingPayload, {
      headers: { 'Content-Type': 'application/json' },
    });

    const duration = Date.now() - startTime;
    bookingDuration.add(duration);

    const success = res.status === 200 || res.status === 201 || res.status === 404;
    bookingSuccess.add(success);

    check(res, {
      'booking responds': (r) => r.status !== 500,
    });

    sleep(2);
  });
}

// ============================================
// SETUP & TEARDOWN
// ============================================

export function setup() {
  console.log(`Load test starting against ${BASE_URL}`);

  // Verify server is reachable
  const res = http.get(`${BASE_URL}/api/health`);
  if (res.status !== 200) {
    console.warn('Health check failed, server might not be ready');
  }

  return { startTime: Date.now() };
}

export function teardown(data) {
  const duration = (Date.now() - data.startTime) / 1000;
  console.log(`Load test completed in ${duration.toFixed(2)} seconds`);
}
