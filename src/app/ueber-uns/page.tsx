import type { Metadata } from 'next';
import Link from 'next/link';
import { Calendar, Award, Heart, Sparkles } from 'lucide-react';
import { Button } from '@/components/ui/button';
import { Card, CardContent } from '@/components/ui/card';

// ============================================
// METADATA
// ============================================

export const metadata: Metadata = {
  title: 'Über uns',
  description:
    'Lernen Sie SCHNITTWERK kennen – Ihr Premium-Friseursalon in St. Gallen. Erfahren Sie mehr über unsere Geschichte, Philosophie und was uns antreibt.',
};

// ============================================
// PAGE DATA - TODO: Fetch from CMS/database
// ============================================

const values = [
  {
    icon: Award,
    title: 'Qualität',
    description:
      'Wir verwenden ausschliesslich hochwertige Produkte und setzen auf kontinuierliche Weiterbildung.',
  },
  {
    icon: Heart,
    title: 'Leidenschaft',
    description:
      'Haare sind unsere Leidenschaft. Jeder Schnitt, jede Coloration ist für uns Kunst.',
  },
  {
    icon: Sparkles,
    title: 'Individualität',
    description: 'Ihr Look ist so einzigartig wie Sie. Wir kreieren massgeschneiderte Styles.',
  },
];

const milestones = [
  { year: '2018', title: 'Gründung', description: 'SCHNITTWERK öffnet seine Türen in St. Gallen' },
  { year: '2019', title: 'Wachstum', description: 'Erweiterung des Teams und Serviceangebots' },
  { year: '2021', title: 'Auszeichnung', description: 'Nominierung zum besten Salon der Region' },
  { year: '2023', title: 'Innovation', description: 'Launch unseres Online-Buchungssystems' },
];

// ============================================
// PAGE COMPONENT
// ============================================

export default function UeberUnsPage() {
  return (
    <div className="py-12">
      {/* Hero Section */}
      <section className="container-wide mb-16">
        <div className="grid items-center gap-12 lg:grid-cols-2">
          <div>
            <p className="text-primary mb-2 text-sm font-medium tracking-wider uppercase">
              Unsere Geschichte
            </p>
            <h1 className="mb-6 text-4xl font-bold md:text-5xl">Über SCHNITTWERK</h1>
            <p className="text-muted-foreground mb-6 text-lg leading-relaxed">
              Was 2018 als Vision begann, ist heute einer der führenden Friseursalons in St. Gallen.
              SCHNITTWERK steht für höchste Qualität, kreatives Handwerk und ein unvergleichliches
              Kundenerlebnis.
            </p>
            <p className="text-muted-foreground mb-8 leading-relaxed">
              Unser Name ist Programm: Bei uns verschmilzt präzise Handwerkskunst mit modernem
              Design. Wir glauben daran, dass ein guter Haarschnitt mehr ist als nur Technik – es
              ist Ausdruck Ihrer Persönlichkeit.
            </p>
            <Button asChild>
              <Link href="/team">Unser Team kennenlernen</Link>
            </Button>
          </div>

          {/* Image Placeholder */}
          <div className="from-muted to-muted/50 relative aspect-[4/3] overflow-hidden rounded-2xl bg-gradient-to-br">
            <div className="absolute inset-0 flex items-center justify-center">
              <span className="text-muted-foreground/30 text-sm">Salon-Bild</span>
            </div>
          </div>
        </div>
      </section>

      {/* Values Section */}
      <section className="bg-muted/30 py-16">
        <div className="container-wide">
          <div className="mb-12 text-center">
            <p className="text-primary mb-2 text-sm font-medium tracking-wider uppercase">
              Wofür wir stehen
            </p>
            <h2 className="text-3xl font-bold">Unsere Werte</h2>
          </div>

          <div className="grid gap-6 md:grid-cols-3">
            {values.map((value) => (
              <Card key={value.title} className="border-border/50">
                <CardContent className="p-6 text-center">
                  <div className="bg-primary/10 mb-4 inline-flex h-14 w-14 items-center justify-center rounded-full">
                    <value.icon className="text-primary h-7 w-7" />
                  </div>
                  <h3 className="mb-2 text-xl font-semibold">{value.title}</h3>
                  <p className="text-muted-foreground">{value.description}</p>
                </CardContent>
              </Card>
            ))}
          </div>
        </div>
      </section>

      {/* Timeline Section */}
      <section className="container-wide py-16">
        <div className="mb-12 text-center">
          <p className="text-primary mb-2 text-sm font-medium tracking-wider uppercase">
            Unsere Reise
          </p>
          <h2 className="text-3xl font-bold">Meilensteine</h2>
        </div>

        <div className="mx-auto max-w-2xl">
          <div className="relative">
            {/* Timeline Line */}
            <div className="bg-border absolute top-0 bottom-0 left-8 w-px" />

            {/* Milestones */}
            <div className="space-y-8">
              {milestones.map((milestone, index) => (
                <div key={milestone.year} className="relative flex gap-6">
                  {/* Year Badge */}
                  <div className="bg-primary text-primary-foreground relative z-10 flex h-16 w-16 shrink-0 items-center justify-center rounded-full text-sm font-bold">
                    {milestone.year}
                  </div>

                  {/* Content */}
                  <div className="pt-3">
                    <h3 className="text-lg font-semibold">{milestone.title}</h3>
                    <p className="text-muted-foreground">{milestone.description}</p>
                  </div>
                </div>
              ))}
            </div>
          </div>
        </div>
      </section>

      {/* CTA Section */}
      <section className="container-wide">
        <Card className="bg-charcoal border-0 text-white">
          <CardContent className="p-8 text-center md:p-12">
            <h2 className="mb-4 text-2xl font-bold md:text-3xl">Überzeugen Sie sich selbst</h2>
            <p className="mx-auto mb-8 max-w-xl text-white/70">
              Erleben Sie die SCHNITTWERK-Qualität bei Ihrem nächsten Besuch. Wir freuen uns darauf,
              Sie kennenzulernen.
            </p>
            <Button size="lg" className="btn-glow" asChild>
              <Link href="/termin-buchen">
                <Calendar className="mr-2 h-5 w-5" />
                Termin buchen
              </Link>
            </Button>
          </CardContent>
        </Card>
      </section>
    </div>
  );
}
