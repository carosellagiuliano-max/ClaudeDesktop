# Operations Guide - SCHNITTWERK

## Deployment

### Vercel (Empfohlen)

```bash
# Vercel CLI installieren
npm i -g vercel

# Deployment
vercel

# Production Deployment
vercel --prod
```

### Environment Variables

Erforderliche Variablen in Vercel Dashboard setzen:

```env
# Supabase
NEXT_PUBLIC_SUPABASE_URL=https://xxx.supabase.co
NEXT_PUBLIC_SUPABASE_ANON_KEY=xxx
SUPABASE_SERVICE_ROLE_KEY=xxx

# Stripe
NEXT_PUBLIC_STRIPE_PUBLISHABLE_KEY=pk_live_xxx
STRIPE_SECRET_KEY=sk_live_xxx
STRIPE_WEBHOOK_SECRET=whsec_xxx

# Sentry (optional)
NEXT_PUBLIC_SENTRY_DSN=https://xxx@sentry.io/xxx
SENTRY_ORG=schnittwerk
SENTRY_PROJECT=web
```

---

## Monitoring

### Health Check

```bash
# Endpoint
curl https://schnittwerk.ch/api/health

# Erwartete Response
{
  "status": "healthy",
  "timestamp": "2025-01-01T12:00:00Z",
  "checks": {
    "database": { "status": "up", "latency_ms": 12 },
    "supabase_auth": { "status": "up", "latency_ms": 45 }
  },
  "uptime_seconds": 86400
}
```

### Sentry Dashboard

- URL: https://sentry.io/organizations/schnittwerk/
- Alerts: Bei > 10 Errors/Stunde
- Performance: p95 < 500ms überwachen

### Logging

Logs sind strukturiert (JSON) und in Vercel Logs verfügbar:

```json
{
  "level": "info",
  "message": "Appointment created",
  "timestamp": "2025-01-01T12:00:00Z",
  "context": {
    "salonId": "xxx",
    "customerId": "yyy",
    "appointmentId": "zzz"
  }
}
```

---

## Incident Response

### Severity Levels

| Level | Beschreibung | Response Time |
|-------|--------------|---------------|
| P1 | System down, keine Buchungen möglich | < 15 min |
| P2 | Teilausfall, eingeschränkte Funktionalität | < 1 Stunde |
| P3 | Fehler mit Workaround | < 4 Stunden |
| P4 | Kosmetischer Bug | Nächster Sprint |

### P1 Incident Ablauf

1. **Erkennung** - Sentry Alert oder Kundenbeschwerde
2. **Triage** - Scope und Impact feststellen
3. **Kommunikation** - Statuspage aktualisieren
4. **Mitigation** - Rollback oder Hotfix
5. **Resolution** - Fix deployen
6. **Postmortem** - Root Cause analysieren

### Rollback

```bash
# Letzte funktionierende Version finden
vercel ls

# Rollback
vercel rollback [deployment-url]
```

---

## Database Operations

### Supabase Dashboard

- URL: https://app.supabase.com/project/xxx
- Backups: Automatisch täglich
- Point-in-Time Recovery: 7 Tage

### Migrations

```bash
# Neue Migration erstellen
npx supabase migration new feature_name

# Migration anwenden
npx supabase db push
```

### Backup wiederherstellen

1. Supabase Dashboard → Database → Backups
2. Point-in-Time Recovery auswählen
3. Neue Instanz erstellen oder bestehende überschreiben

---

## Performance Tuning

### Database Indexes

Wichtige Indexes prüfen:

```sql
-- Appointment lookups
CREATE INDEX IF NOT EXISTS idx_appointments_salon_date
ON appointments (salon_id, starts_at);

-- Customer search
CREATE INDEX IF NOT EXISTS idx_customers_salon_search
ON customers (salon_id, last_name, first_name);
```

### Caching

- Next.js: `revalidate` für statische Seiten
- Supabase: RLS-optimierte Queries
- Browser: Service Worker für Assets

### CDN

- Vercel Edge Network automatisch aktiv
- Bilder via `next/image` optimiert
- Statische Assets: 1 Jahr Cache

---

## Security

### Updates

```bash
# Security Audit
npm audit

# Kritische Updates
npm audit fix

# Dependencies aktualisieren
npm update
```

### Secrets Rotation

| Secret | Rotation | Prozess |
|--------|----------|---------|
| Supabase Keys | Bei Verdacht | Dashboard → Settings → API |
| Stripe Keys | Jährlich | Stripe Dashboard |
| Webhook Secrets | Bei Leak | Stripe → Webhooks |

### Access Control

- Supabase: RLS Policies aktiviert
- Admin: Nur über Auth
- API: Rate Limiting via Vercel

---

## Maintenance Windows

### Geplante Wartung

- Zeit: Sonntag 02:00-04:00 CET
- Ankündigung: 48h vorher
- Kanal: E-Mail an betroffene Kunden

### Prozess

1. Wartungsmodus aktivieren (Banner)
2. Backup erstellen
3. Migrations/Updates durchführen
4. Tests ausführen
5. Wartungsmodus deaktivieren
6. Monitoring prüfen

---

## Contacts

### Eskalation

| Rolle | Kontakt | Verfügbarkeit |
|-------|---------|---------------|
| On-Call Dev | +41 xxx | 24/7 |
| Tech Lead | email@xxx | Bürozeiten |
| Supabase Support | support.supabase.com | 24/7 |
| Vercel Support | vercel.com/support | 24/7 |

### External Services

| Service | Status Page |
|---------|-------------|
| Supabase | status.supabase.com |
| Vercel | vercel-status.com |
| Stripe | status.stripe.com |
