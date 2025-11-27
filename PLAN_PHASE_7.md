# Phase 7: Hardening, Testing & Operations

## Ziel
Production-Readiness - Das System soll robust, getestet, überwacht und dokumentiert sein.

---

## Deliverables Übersicht

| # | Deliverable | Priorität | Geschätzte Komplexität |
|---|-------------|-----------|------------------------|
| 7.1 | Umfassende Test-Suite | Hoch | Hoch |
| 7.2 | Error Tracking (Sentry) | Hoch | Mittel |
| 7.3 | Logging-System | Hoch | Mittel |
| 7.4 | Health-Checks | Mittel | Niedrig |
| 7.5 | Analytics-Dashboards vervollständigen | Mittel | Mittel |
| 7.6 | Performance-Optimierung | Mittel | Mittel |
| 7.7 | Security-Audit (RLS Review) | Hoch | Mittel |
| 7.8 | Load-Tests | Niedrig | Mittel |
| 7.9 | Dokumentation | Mittel | Niedrig |
| 7.10 | UX-Verbesserungen (Empty States, Errors, Loading) | Mittel | Niedrig |

---

## 7.1 Umfassende Test-Suite

### Struktur
```
tests/
├── unit/
│   ├── domain/
│   │   ├── slot-engine.test.ts      # Property-based Tests
│   │   ├── booking-service.test.ts
│   │   ├── payment-service.test.ts
│   │   └── loyalty-service.test.ts
│   ├── validators/
│   │   ├── booking.test.ts
│   │   └── order.test.ts
│   └── utils/
│       ├── date.test.ts
│       └── currency.test.ts
│
├── integration/
│   ├── booking-flow.test.ts
│   ├── checkout-flow.test.ts
│   ├── stripe-webhook.test.ts
│   ├── notification.test.ts
│   └── rls-policies.test.ts
│
├── e2e/
│   ├── public-site.spec.ts
│   ├── booking.spec.ts
│   ├── checkout.spec.ts
│   ├── customer-portal.spec.ts
│   └── admin-portal.spec.ts
│
└── fixtures/
    ├── salon.ts
    ├── customer.ts
    ├── staff.ts
    ├── services.ts
    └── products.ts
```

### Implementierungsschritte

#### 7.1.1 Test-Setup & Konfiguration
- [ ] Jest/Vitest für Unit-Tests konfigurieren
- [ ] Playwright für E2E-Tests konfigurieren
- [ ] Test-Fixtures erstellen (Testdaten)
- [ ] CI/CD Pipeline für Tests einrichten

#### 7.1.2 Unit-Tests für Domain-Logik
- [ ] `slot-engine.test.ts` - Slot-Berechnung, Verfügbarkeit, Überlappungen
- [ ] `booking-service.test.ts` - Buchungsregeln, Validierung, Stornierung
- [ ] `payment-service.test.ts` - Preisberechnung, Rabatte, MwSt
- [ ] `loyalty-service.test.ts` - Punkteberechnung, Tier-Upgrades
- [ ] `voucher-service.test.ts` - Einlösung, Gültigkeit, Teileinlösung

#### 7.1.3 Integration-Tests
- [ ] `booking-flow.test.ts` - Kompletter Buchungsprozess
- [ ] `checkout-flow.test.ts` - Warenkorb → Zahlung → Bestätigung
- [ ] `stripe-webhook.test.ts` - Webhook-Verarbeitung
- [ ] `notification.test.ts` - E-Mail/SMS-Versand
- [ ] `rls-policies.test.ts` - Datenzugriff pro Rolle

#### 7.1.4 E2E-Tests mit Playwright
- [ ] `public-site.spec.ts` - Öffentliche Seiten, SEO
- [ ] `booking.spec.ts` - Terminbuchung von A-Z
- [ ] `checkout.spec.ts` - Shop-Checkout-Flow
- [ ] `customer-portal.spec.ts` - Kundenportal-Funktionen
- [ ] `admin-portal.spec.ts` - Admin-Funktionen

---

## 7.2 Error Tracking (Sentry)

### Implementierungsschritte
- [ ] `@sentry/nextjs` installieren und konfigurieren
- [ ] `sentry.client.config.ts` erstellen
- [ ] `sentry.server.config.ts` erstellen
- [ ] `sentry.edge.config.ts` erstellen
- [ ] Error Boundary Component erweitern
- [ ] Custom Error Pages mit Sentry-Integration
- [ ] Source Maps für Production konfigurieren
- [ ] Release Tracking einrichten

### Dateien
```
src/
├── lib/
│   └── sentry.ts              # Sentry-Konfiguration & Helpers
├── instrumentation.ts          # Next.js Instrumentation
└── sentry.client.config.ts
└── sentry.server.config.ts
```

---

## 7.3 Logging-System

### Implementierungsschritte
- [ ] Structured Logger erstellen (`lib/logging/logger.ts`)
- [ ] Log-Levels definieren (info, warn, error, debug)
- [ ] Context-Enrichment (salonId, userId, correlationId)
- [ ] Request-ID Middleware für Tracing
- [ ] Sensitive Data Masking

### Logger-Interface
```typescript
interface LogContext {
  salonId?: string;
  userId?: string;
  correlationId?: string;
  [key: string]: unknown;
}

logger.info('Appointment created', { appointmentId, customerId });
logger.error('Payment failed', error, { orderId, amount });
```

---

## 7.4 Health-Checks

### Implementierungsschritte
- [ ] `/api/health` Endpoint erstellen
- [ ] Database connectivity check
- [ ] Stripe connectivity check
- [ ] Redis/Cache check (falls vorhanden)
- [ ] Memory/CPU metrics
- [ ] Uptime tracking

### Response-Format
```json
{
  "status": "healthy",
  "timestamp": "2025-01-01T12:00:00Z",
  "checks": {
    "database": { "status": "up", "latency_ms": 12 },
    "stripe": { "status": "up", "latency_ms": 45 },
    "cache": { "status": "up", "latency_ms": 2 }
  },
  "uptime_seconds": 86400
}
```

---

## 7.5 Analytics-Dashboards vervollständigen

### Aktueller Stand prüfen
- [ ] Vorhandene Analytics-Seite analysieren
- [ ] TypeScript-Fehler in `analytics/page.tsx` beheben

### Metriken implementieren
- [ ] Umsatz-Dashboard (täglich, wöchentlich, monatlich)
- [ ] Buchungs-Statistiken (Auslastung, No-Shows, Stornierungen)
- [ ] Kunden-Metriken (Neukunden, Wiederkehrende, CLV)
- [ ] Produkt-Performance (Top-Seller, Bestand-Warnungen)
- [ ] Mitarbeiter-Statistiken (Auslastung, Umsatz pro Mitarbeiter)

### Accounting Export View
- [ ] SQL View `accounting_export` erstellen
- [ ] CSV Export für Buchhaltung
- [ ] Filterbare Finanzübersicht

---

## 7.6 Performance-Optimierung

### Implementierungsschritte
- [ ] React Server Components optimieren
- [ ] Daten-Caching Strategie (revalidate)
- [ ] Image Optimization (next/image)
- [ ] Bundle Size Analyse & Optimierung
- [ ] Database Query Optimierung
- [ ] Index-Analyse für häufige Queries
- [ ] Lazy Loading für große Komponenten
- [ ] Prefetching für kritische Routen

---

## 7.7 Security-Audit (RLS Review)

### Implementierungsschritte
- [ ] Alle RLS-Policies dokumentieren
- [ ] Test-Cases für jede Policy schreiben
- [ ] Cross-Tenant Datenzugriff testen
- [ ] Admin-Rechte Eskalation prüfen
- [ ] API-Route Authentifizierung prüfen
- [ ] Input Validation überall prüfen
- [ ] CSRF-Schutz verifizieren
- [ ] Rate-Limiting implementieren

### Checkliste
```
□ Customers können nur eigene Daten sehen
□ Staff kann nur Salon-Daten sehen
□ Admin kann keine anderen Salons sehen
□ HQ kann alle Salons sehen
□ Anonyme User haben nur Lesezugriff auf öffentliche Daten
□ Keine SQL-Injection möglich
□ Keine XSS-Schwachstellen
□ Sichere Session-Verwaltung
```

---

## 7.8 Load-Tests

### Tool
Verwende `k6` oder `artillery` für Load-Tests

### Test-Szenarien
- [ ] Booking Flow unter Last (50 concurrent users)
- [ ] Checkout Flow unter Last (20 concurrent users)
- [ ] API-Endpunkte Stress-Test
- [ ] Database Connection Pool Test
- [ ] Cache-Performance unter Last

### Metriken erfassen
- Response Time (p50, p95, p99)
- Throughput (requests/sec)
- Error Rate
- Database Connection Usage

---

## 7.9 Dokumentation

### Zu erstellende Dokumente
- [ ] `docs/testing.md` - Test-Strategie, wie Tests laufen, Coverage-Ziele
- [ ] `docs/operations.md` - Deployment, Monitoring, Incident Response
- [ ] `docs/deletion-and-retention.md` - Datenlöschung, Aufbewahrungsfristen (DSGVO)
- [ ] API-Dokumentation aktualisieren
- [ ] README.md vervollständigen

---

## 7.10 UX-Verbesserungen

### Empty States
- [ ] Keine Termine → Hilfreiche Nachricht + CTA
- [ ] Keine Kunden → Onboarding-Hinweis
- [ ] Keine Bestellungen → Shop-Link
- [ ] Leerer Warenkorb → Produktvorschläge

### Error Messages
- [ ] Benutzerfreundliche Fehlermeldungen (deutsch)
- [ ] Kontextbezogene Hilfe bei Fehlern
- [ ] Retry-Optionen wo sinnvoll
- [ ] Support-Kontakt bei kritischen Fehlern

### Loading States
- [ ] Skeleton-Loader für alle Listen
- [ ] Optimistic UI für häufige Aktionen
- [ ] Loading-Indikatoren für Buttons
- [ ] Progress-Anzeige für längere Operationen

---

## Priorisierte Reihenfolge

1. **7.2 Sentry Integration** - Sofortige Sichtbarkeit von Fehlern
2. **7.3 Logging-System** - Debugging-Grundlage
3. **7.4 Health-Checks** - Monitoring-Basis
4. **7.7 Security-Audit** - Kritisch vor Go-Live
5. **7.1 Test-Suite** - Unit → Integration → E2E
6. **7.5 Analytics** - TypeScript-Fixes + Metriken
7. **7.10 UX-Verbesserungen** - Polish
8. **7.6 Performance** - Optimierung
9. **7.8 Load-Tests** - Validierung
10. **7.9 Dokumentation** - Abschluss

---

## Erfolgskriterien

- [ ] Test Coverage > 70% für Domain-Logik
- [ ] Alle E2E-Tests grün
- [ ] Sentry meldet < 1 Error pro 100 Requests
- [ ] Health-Check Uptime > 99.5%
- [ ] p95 Response Time < 500ms
- [ ] Security-Audit bestanden
- [ ] Load-Test: 50 concurrent users ohne Degradation
- [ ] Dokumentation vollständig und aktuell
