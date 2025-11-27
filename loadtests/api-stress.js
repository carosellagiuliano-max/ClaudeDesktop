/**
 * SCHNITTWERK Load Test - API Stress Test
 * Run with: k6 run loadtests/api-stress.js
 */

import http from 'k6/http';
import { check, sleep } from 'k6';
import { Rate } from 'k6/metrics';

// ============================================
// CONFIGURATION
// ============================================

const BASE_URL = __ENV.BASE_URL || 'http://localhost:3000';

export const options = {
  scenarios: {
    // Constant load scenario
    constant_load: {
      executor: 'constant-arrival-rate',
      rate: 100,             // 100 requests per second
      timeUnit: '1s',
      duration: '2m',
      preAllocatedVUs: 50,
      maxVUs: 100,
    },

    // Spike scenario
    spike: {
      executor: 'ramping-arrival-rate',
      startRate: 10,
      timeUnit: '1s',
      preAllocatedVUs: 50,
      maxVUs: 200,
      stages: [
        { duration: '30s', target: 10 },   // Normal load
        { duration: '10s', target: 200 },  // Spike!
        { duration: '30s', target: 200 },  // Stay at spike
        { duration: '10s', target: 10 },   // Scale down
        { duration: '30s', target: 10 },   // Normal load
      ],
      startTime: '2m30s', // Start after constant_load
    },
  },

  thresholds: {
    http_req_duration: ['p(99)<1000'], // 99% under 1s
    http_req_failed: ['rate<0.05'],    // Less than 5% failure
  },
};

// ============================================
// CUSTOM METRICS
// ============================================

const apiErrors = new Rate('api_errors');

// ============================================
// API ENDPOINTS TO TEST
// ============================================

const endpoints = [
  { path: '/api/health', method: 'GET', weight: 10 },
  { path: '/api/public/services', method: 'GET', weight: 30 },
  { path: '/api/public/staff', method: 'GET', weight: 20 },
  { path: '/api/public/products', method: 'GET', weight: 20 },
  { path: '/api/public/salon', method: 'GET', weight: 20 },
];

// ============================================
// WEIGHTED RANDOM SELECTION
// ============================================

function selectEndpoint() {
  const totalWeight = endpoints.reduce((sum, e) => sum + e.weight, 0);
  let random = Math.random() * totalWeight;

  for (const endpoint of endpoints) {
    random -= endpoint.weight;
    if (random <= 0) {
      return endpoint;
    }
  }

  return endpoints[0];
}

// ============================================
// MAIN TEST
// ============================================

export default function () {
  const endpoint = selectEndpoint();
  const url = `${BASE_URL}${endpoint.path}`;

  const res = http.get(url);

  const success = check(res, {
    'status is 200': (r) => r.status === 200,
    'response time OK': (r) => r.timings.duration < 500,
  });

  apiErrors.add(!success);

  // Small delay between requests
  sleep(0.1);
}

// ============================================
// SETUP
// ============================================

export function setup() {
  console.log('Starting API stress test...');

  // Warm up
  for (let i = 0; i < 5; i++) {
    http.get(`${BASE_URL}/api/health`);
    sleep(0.5);
  }

  return {};
}
