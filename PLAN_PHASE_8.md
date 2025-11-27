# Phase 8: Enhanced Features & Marketing

## Ziel
Erweiterte Funktionen zur Kundenbindung und Geschäftsoptimierung - SMS-Benachrichtigungen, verbessertes Loyalty-Programm, Marketing-Automatisierung und fortgeschrittene Buchungsfunktionen.

---

## Deliverables Übersicht

| # | Deliverable | Priorität | Geschätzte Komplexität |
|---|-------------|-----------|------------------------|
| 8.1 | SMS-Benachrichtigungen (Twilio) | Hoch | Mittel |
| 8.2 | Termin-Erinnerungen (Automated) | Hoch | Mittel |
| 8.3 | Erweitertes Loyalty-Programm | Hoch | Hoch |
| 8.4 | Push-Benachrichtigungen (Web Push) | Mittel | Mittel |
| 8.5 | Marketing-Automatisierung | Mittel | Hoch |
| 8.6 | Warteliste für ausgebuchte Slots | Mittel | Mittel |
| 8.7 | Anzahlungen/Deposits | Niedrig | Mittel |
| 8.8 | Kunden-Feedback-System | Niedrig | Niedrig |

---

## 8.1 SMS-Benachrichtigungen (Twilio) ✅ ABGESCHLOSSEN

### Implementierungsschritte
- [x] Twilio SDK installieren und konfigurieren
- [x] `lib/notifications/sms.ts` erstellen
- [x] SMS-Templates für verschiedene Events
- [x] Opt-in/Opt-out Verwaltung (DSGVO) - notification_preferences Tabelle
- [x] SMS-Versand mit Retry-Logik
- [x] Twilio Webhook für Delivery Status

### SMS-Events
| Event | Template | Timing |
|-------|----------|--------|
| Buchungsbestätigung | Termin bestätigt | Sofort |
| Termin-Erinnerung | 24h Erinnerung | 24h vorher |
| Termin-Erinnerung | 1h Erinnerung | 1h vorher |
| Stornierung | Termin abgesagt | Sofort |
| Keine Show | Verpasster Termin | Nach No-Show |

### Dateien
```
src/
├── lib/
│   └── notifications/
│       ├── sms.ts           # Twilio-Integration
│       ├── templates.ts     # SMS-Vorlagen
│       └── queue.ts         # Versand-Queue
└── app/
    └── api/
        └── webhooks/
            └── twilio/
                └── route.ts # Delivery Status
```

---

## 8.2 Termin-Erinnerungen (Automated) ✅ ABGESCHLOSSEN

### Implementierungsschritte
- [x] Cron-Job für Erinnerungen (Vercel Cron)
- [x] Reminder-Service (reminders.ts)
- [x] Multi-Channel Support (SMS + Email ready)
- [x] Kundenspezifische Präferenzen (notification_preferences)
- [x] Timezone-Handling (Europe/Zurich)

### Cron-Jobs
```typescript
// Täglich um 08:00: 24h Erinnerungen
// Stündlich: 1h Erinnerungen
```

---

## 8.3 Erweitertes Loyalty-Programm ✅ ABGESCHLOSSEN

### Tier-System
| Tier | Punkte | Vorteile |
|------|--------|----------|
| Bronze | 0-499 | 1 Punkt pro CHF |
| Silver | 500-999 | 1.25 Punkte/CHF, 5% Rabatt |
| Gold | 1000-1999 | 1.5 Punkte/CHF, 10% Rabatt |
| Platinum | 2000+ | 2 Punkte/CHF, 15% Rabatt, Priority Booking |

### Implementierungsschritte
- [x] Tier-Logik in `loyalty-service.ts`
- [x] Punkte-Einlösung (redeemPoints)
- [x] Tier-Upgrade Check (checkTierUpgrade)
- [x] Punkte-History (getTransactionHistory)
- [x] Leaderboard und Stats für Admin
- [x] Verfalls-Regelung (expires_at auf Transaktionen)

### Datenbank-Schema
```sql
-- Neue Spalten für customers
ALTER TABLE customers ADD COLUMN loyalty_tier VARCHAR(20) DEFAULT 'bronze';
ALTER TABLE customers ADD COLUMN points_expires_at TIMESTAMPTZ;

-- Punkte-Transaktionen
CREATE TABLE loyalty_transactions (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  customer_id UUID REFERENCES customers(id),
  type VARCHAR(20), -- 'earn', 'redeem', 'expire', 'bonus'
  points INTEGER,
  description TEXT,
  reference_id UUID, -- appointment_id or order_id
  created_at TIMESTAMPTZ DEFAULT NOW()
);
```

---

## 8.4 Push-Benachrichtigungen (Web Push) ✅ ABGESCHLOSSEN

### Implementierungsschritte
- [x] Service Worker für Push (public/sw.js)
- [x] VAPID Keys Konfiguration
- [x] `lib/notifications/push.ts`
- [x] Subscription-Verwaltung (push_subscriptions Tabelle)
- [x] Push-Events: Termin, Warteliste, Loyalty
- [x] Offline Support im Service Worker

### Dateien
```
public/
├── sw.js              # Service Worker
src/
├── lib/
│   └── notifications/
│       └── push.ts    # Web Push API
└── components/
    └── PushSubscription.tsx
```

---

## 8.5 Marketing-Automatisierung ✅ ABGESCHLOSSEN

### Implementierungsschritte
- [x] Geburtstags-Kampagnen mit Bonus-Punkten
- [x] "Wir vermissen dich" (60 Tage ohne Termin)
- [x] Welcome-Kampagnen für neue Kunden
- [x] Post-Visit Feedback-Anfragen
- [x] Kampagnen-Logging (marketing_logs)
- [x] Analytics-Views für Performance

### Automatische Trigger
| Trigger | Aktion | Timing |
|---------|--------|--------|
| Geburtstag | 10% Gutschein | Am Geburtstag |
| 60 Tage inaktiv | Erinnerung + 5% | Tag 60 |
| Nach erstem Termin | Willkommens-Mail | 1 Tag später |
| Nach Kauf | Pflegetipps | 3 Tage später |

---

## 8.6 Warteliste für ausgebuchte Slots ✅ ABGESCHLOSSEN

### Implementierungsschritte
- [x] `waitlist` Tabelle mit allen Features
- [x] WaitlistService mit joinWaitlist, leaveWaitlist
- [x] Automatische Benachrichtigung (notifyWaitlistForSlot)
- [x] Max. 5 Einträge pro Kunde (Abuse-Schutz)
- [x] Zeitlimit für Buchung (30 Min, expires_at)
- [x] Cron-Job für Expiration

### Datenbank-Schema
```sql
CREATE TABLE waitlist (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  salon_id UUID REFERENCES salons(id),
  customer_id UUID REFERENCES customers(id),
  service_id UUID REFERENCES services(id),
  staff_id UUID REFERENCES staff(id),
  requested_date DATE,
  requested_time TIME,
  status VARCHAR(20) DEFAULT 'waiting', -- 'waiting', 'notified', 'booked', 'expired'
  notified_at TIMESTAMPTZ,
  expires_at TIMESTAMPTZ,
  created_at TIMESTAMPTZ DEFAULT NOW()
);
```

---

## 8.7 Anzahlungen/Deposits ✅ ABGESCHLOSSEN

### Implementierungsschritte
- [x] Deposit-Konfiguration pro Service (deposit_required, deposit_type, deposit_amount)
- [x] DepositService mit Stripe Payment Intent Integration
- [x] Deposit-Verrechnung (applyDepositToPayment)
- [x] Stornierungsregeln (is_deposit_refundable, process_deposit_refund)
- [x] Admin-Übersicht (v_pending_deposits, v_deposit_stats)

### Konfiguration
```typescript
interface DepositConfig {
  enabled: boolean;
  type: 'fixed' | 'percentage';
  amount: number; // CHF oder %
  refundableUntil: number; // Stunden vor Termin
}
```

---

## 8.8 Kunden-Feedback-System ✅ ABGESCHLOSSEN

### Implementierungsschritte
- [x] Feedback-Anfrage mit sicheren Tokens
- [x] Sterne-Bewertung (1-5) + Kategorien
- [x] Optionaler Kommentar
- [x] Google Review Tracking
- [x] Admin-Dashboard (v_feedback_summary, v_recent_feedback)
- [x] Trend-Analyse (getRatingTrend)

---

## Priorisierte Reihenfolge

1. **8.1 SMS-Benachrichtigungen** - Kritisch für Termin-Erinnerungen
2. **8.2 Termin-Erinnerungen** - Reduziert No-Shows signifikant
3. **8.3 Loyalty-Programm** - Kundenbindung
4. **8.6 Warteliste** - Bessere Auslastung
5. **8.5 Marketing** - Wachstum
6. **8.4 Push** - Zusätzlicher Kanal
7. **8.8 Feedback** - Qualitätssicherung
8. **8.7 Deposits** - Nice-to-have

---

## Erfolgskriterien

- [x] SMS-Erinnerungen funktionieren zuverlässig
- [ ] No-Show Rate reduziert um 30% (zu messen nach Go-Live)
- [ ] Loyalty-Einlösung > 20% der Stammkunden (zu messen nach Go-Live)
- [ ] Marketing-E-Mails: Open Rate > 30% (zu messen nach Go-Live)
- [ ] Warteliste konvertiert > 50% der Freiwerdungen (zu messen nach Go-Live)
- [ ] Durchschnittliche Bewertung > 4.5 Sterne (zu messen nach Go-Live)

---

## PHASE 8 STATUS: ✅ VOLLSTÄNDIG IMPLEMENTIERT

### Erstellte Dateien

**Services:**
- `src/lib/services/loyalty-service.ts`
- `src/lib/services/waitlist-service.ts`
- `src/lib/services/marketing-service.ts`
- `src/lib/services/feedback-service.ts`
- `src/lib/services/deposit-service.ts`
- `src/lib/services/index.ts`

**Notifications:**
- `src/lib/notifications/sms.ts`
- `src/lib/notifications/templates.ts`
- `src/lib/notifications/reminders.ts`
- `src/lib/notifications/push.ts`
- `src/lib/notifications/types.ts`

**API Routes:**
- `src/app/api/cron/reminders/24h/route.ts`
- `src/app/api/cron/reminders/1h/route.ts`
- `src/app/api/cron/waitlist/expire/route.ts`
- `src/app/api/cron/marketing/route.ts`
- `src/app/api/webhooks/twilio/status/route.ts`

**Service Worker:**
- `public/sw.js`

**Migrationen:**
- `00021_sms_reminders.sql`
- `00022_waitlist.sql`
- `00023_marketing_feedback.sql`
- `00024_push_subscriptions.sql`
- `00025_deposits.sql`

### Vercel Cron Jobs
```json
{
  "crons": [
    { "path": "/api/cron/reminders/24h", "schedule": "0 7 * * *" },
    { "path": "/api/cron/reminders/1h", "schedule": "0 * * * *" },
    { "path": "/api/cron/waitlist/expire", "schedule": "*/5 * * * *" },
    { "path": "/api/cron/marketing", "schedule": "0 8 * * *" }
  ]
}
```

---

## Umgebungsvariablen (Neu)

```env
# Twilio
TWILIO_ACCOUNT_SID=xxx
TWILIO_AUTH_TOKEN=xxx
TWILIO_PHONE_NUMBER=+41xxx

# Web Push (VAPID)
NEXT_PUBLIC_VAPID_PUBLIC_KEY=xxx
VAPID_PRIVATE_KEY=xxx
VAPID_SUBJECT=mailto:admin@schnittwerk.ch
```
