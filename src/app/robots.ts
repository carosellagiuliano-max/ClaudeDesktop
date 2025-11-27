import type { MetadataRoute } from 'next';

// ============================================
// ROBOTS.TXT CONFIGURATION
// ============================================

const BASE_URL = process.env.NEXT_PUBLIC_SITE_URL || 'https://schnittwerk.ch';

export default function robots(): MetadataRoute.Robots {
  return {
    rules: [
      {
        userAgent: '*',
        allow: '/',
        disallow: [
          '/api/',
          '/admin/',
          '/dashboard/',
          '/login',
          '/konto/',
          '/_next/',
          '/checkout/',
        ],
      },
    ],
    sitemap: `${BASE_URL}/sitemap.xml`,
  };
}
