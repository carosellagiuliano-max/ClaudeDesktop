import type { Metadata } from 'next';
import Link from 'next/link';

// ============================================
// METADATA
// ============================================

export const metadata: Metadata = {
  title: 'Datenschutzerklärung',
  description:
    'Datenschutzerklärung von SCHNITTWERK St. Gallen. Informationen zur Verarbeitung Ihrer personenbezogenen Daten.',
};

// ============================================
// COMPANY DATA
// ============================================

const companyInfo = {
  name: 'SCHNITTWERK',
  legalName: 'SCHNITTWERK GmbH',
  address: 'Musterstrasse 123, 9000 St. Gallen, Schweiz',
  email: 'datenschutz@schnittwerk.ch',
  lastUpdated: '1. Januar 2024',
};

// ============================================
// PAGE COMPONENT
// ============================================

export default function DatenschutzPage() {
  return (
    <div className="py-12">
      <div className="container-wide max-w-3xl">
        <h1 className="mb-4 text-3xl font-bold">Datenschutzerklärung</h1>
        <p className="text-muted-foreground mb-8">
          Letzte Aktualisierung: {companyInfo.lastUpdated}
        </p>

        <div className="prose prose-gray dark:prose-invert max-w-none space-y-8">
          {/* Introduction */}
          <section>
            <h2 className="mb-4 text-xl font-semibold">1. Einleitung</h2>
            <p className="text-muted-foreground">
              Mit dieser Datenschutzerklärung informieren wir Sie darüber, welche Personendaten wir
              im Zusammenhang mit unseren Tätigkeiten und Aktivitäten einschliesslich unserer
              Website <strong>schnittwerk.ch</strong> bearbeiten. Wir informieren insbesondere
              darüber, wofür, wie und wo wir welche Personendaten bearbeiten. Wir informieren
              ausserdem über die Rechte von Personen, deren Daten wir bearbeiten.
            </p>
          </section>

          {/* Responsible Party */}
          <section>
            <h2 className="mb-4 text-xl font-semibold">2. Verantwortliche Stelle</h2>
            <p className="text-muted-foreground">Verantwortlich für die Datenbearbeitung ist:</p>
            <address className="text-muted-foreground mt-2 not-italic">
              {companyInfo.legalName}
              <br />
              {companyInfo.address}
              <br />
              E-Mail: {companyInfo.email}
            </address>
          </section>

          {/* Data Collection */}
          <section>
            <h2 className="mb-4 text-xl font-semibold">
              3. Erhebung und Bearbeitung von Personendaten
            </h2>
            <p className="text-muted-foreground mb-4">
              Wir bearbeiten Personendaten, die wir im Rahmen unserer Geschäftstätigkeit erhalten
              haben. Wir bearbeiten insbesondere Daten, die Sie uns selbst übermitteln, zum
              Beispiel:
            </p>
            <ul className="text-muted-foreground list-inside list-disc space-y-2">
              <li>bei der Terminbuchung (Name, E-Mail, Telefon, gewünschte Leistung)</li>
              <li>bei der Erstellung eines Kundenkontos (Name, E-Mail, Passwort)</li>
              <li>bei Bestellungen im Online-Shop (Name, Adresse, Zahlungsdaten)</li>
              <li>bei der Kontaktaufnahme über das Kontaktformular</li>
              <li>bei der Anmeldung zum Newsletter</li>
            </ul>
          </section>

          {/* Purpose */}
          <section>
            <h2 className="mb-4 text-xl font-semibold">4. Zweck der Datenbearbeitung</h2>
            <p className="text-muted-foreground mb-4">
              Wir bearbeiten Personendaten für folgende Zwecke:
            </p>
            <ul className="text-muted-foreground list-inside list-disc space-y-2">
              <li>Erbringung unserer Dienstleistungen und Vertragsabwicklung</li>
              <li>Terminverwaltung und Kundenkommunikation</li>
              <li>Abwicklung von Bestellungen und Zahlungen</li>
              <li>Versand von Terminerinnerungen und Bestätigungen</li>
              <li>Beantwortung von Anfragen</li>
              <li>Marketing und Werbung (nur mit Ihrer Einwilligung)</li>
              <li>Verbesserung unserer Website und Dienstleistungen</li>
            </ul>
          </section>

          {/* Cookies */}
          <section>
            <h2 className="mb-4 text-xl font-semibold">5. Cookies</h2>
            <p className="text-muted-foreground mb-4">
              Unsere Website verwendet Cookies. Cookies sind kleine Textdateien, die beim Besuch
              unserer Website auf Ihrem Gerät gespeichert werden. Wir verwenden:
            </p>
            <ul className="text-muted-foreground list-inside list-disc space-y-2">
              <li>
                <strong>Notwendige Cookies:</strong> Für die Grundfunktionen der Website (z.B.
                Warenkorb, Login)
              </li>
              <li>
                <strong>Analyse-Cookies:</strong> Zur Verbesserung unserer Website (nur mit Ihrer
                Einwilligung)
              </li>
              <li>
                <strong>Marketing-Cookies:</strong> Für personalisierte Werbung (nur mit Ihrer
                Einwilligung)
              </li>
            </ul>
            <p className="text-muted-foreground mt-4">
              Sie können Cookies in Ihren Browsereinstellungen jederzeit löschen oder blockieren.
            </p>
          </section>

          {/* Third Parties */}
          <section>
            <h2 className="mb-4 text-xl font-semibold">6. Weitergabe an Dritte</h2>
            <p className="text-muted-foreground mb-4">
              Wir geben Personendaten nur dann an Dritte weiter, wenn dies für die Erbringung
              unserer Dienstleistungen erforderlich ist oder Sie eingewilligt haben. Empfänger
              können sein:
            </p>
            <ul className="text-muted-foreground list-inside list-disc space-y-2">
              <li>Zahlungsdienstleister (z.B. Stripe)</li>
              <li>E-Mail-Dienstleister für Terminerinnerungen</li>
              <li>Hosting-Provider (Vercel)</li>
              <li>Datenbank-Anbieter (Supabase)</li>
            </ul>
          </section>

          {/* Data Security */}
          <section>
            <h2 className="mb-4 text-xl font-semibold">7. Datensicherheit</h2>
            <p className="text-muted-foreground">
              Wir treffen geeignete technische und organisatorische Sicherheitsmassnahmen zum Schutz
              Ihrer Personendaten gegen unberechtigten Zugriff, Verlust oder Missbrauch. Die
              Datenübertragung auf unserer Website erfolgt verschlüsselt über HTTPS.
            </p>
          </section>

          {/* Rights */}
          <section>
            <h2 className="mb-4 text-xl font-semibold">8. Ihre Rechte</h2>
            <p className="text-muted-foreground mb-4">
              Sie haben folgende Rechte bezüglich Ihrer Personendaten:
            </p>
            <ul className="text-muted-foreground list-inside list-disc space-y-2">
              <li>
                <strong>Auskunftsrecht:</strong> Sie können Auskunft über Ihre gespeicherten Daten
                verlangen
              </li>
              <li>
                <strong>Berichtigungsrecht:</strong> Sie können die Berichtigung unrichtiger Daten
                verlangen
              </li>
              <li>
                <strong>Löschungsrecht:</strong> Sie können die Löschung Ihrer Daten verlangen
              </li>
              <li>
                <strong>Widerspruchsrecht:</strong> Sie können der Datenbearbeitung widersprechen
              </li>
              <li>
                <strong>Datenportabilität:</strong> Sie können die Herausgabe Ihrer Daten verlangen
              </li>
            </ul>
            <p className="text-muted-foreground mt-4">
              Zur Ausübung Ihrer Rechte wenden Sie sich bitte an:{' '}
              <a href={`mailto:${companyInfo.email}`} className="text-primary hover:underline">
                {companyInfo.email}
              </a>
            </p>
          </section>

          {/* Retention */}
          <section>
            <h2 className="mb-4 text-xl font-semibold">9. Aufbewahrungsdauer</h2>
            <p className="text-muted-foreground">
              Wir speichern Personendaten nur so lange, wie dies für die Zwecke, für die sie erhoben
              wurden, erforderlich ist oder gesetzliche Aufbewahrungspflichten bestehen.
              Buchhaltungsrelevante Daten werden 10 Jahre aufbewahrt.
            </p>
          </section>

          {/* Changes */}
          <section>
            <h2 className="mb-4 text-xl font-semibold">10. Änderungen</h2>
            <p className="text-muted-foreground">
              Wir können diese Datenschutzerklärung jederzeit ändern. Die aktuelle Version ist auf
              unserer Website veröffentlicht.
            </p>
          </section>

          {/* Contact */}
          <section>
            <h2 className="mb-4 text-xl font-semibold">11. Kontakt</h2>
            <p className="text-muted-foreground">
              Bei Fragen zum Datenschutz erreichen Sie uns unter:{' '}
              <a href={`mailto:${companyInfo.email}`} className="text-primary hover:underline">
                {companyInfo.email}
              </a>
            </p>
          </section>
        </div>
      </div>
    </div>
  );
}
