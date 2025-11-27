import type { Metadata } from 'next';
import Link from 'next/link';
import Image from 'next/image';
import { Calendar, Scissors, Award, Instagram } from 'lucide-react';
import { Button } from '@/components/ui/button';
import { Card, CardContent } from '@/components/ui/card';
import { Badge } from '@/components/ui/badge';
import { getStaffMembers, getSalon } from '@/lib/actions';

// ============================================
// METADATA
// ============================================

export const metadata: Metadata = {
  title: 'Unser Team',
  description:
    'Lernen Sie das SCHNITTWERK-Team kennen. Unsere erfahrenen Stylisten freuen sich darauf, Ihren perfekten Look zu kreieren.',
};

// ============================================
// PAGE COMPONENT
// ============================================

export default async function TeamPage() {
  const [staff, salon] = await Promise.all([getStaffMembers(), getSalon()]);

  return (
    <div className="py-12">
      {/* Page Header */}
      <section className="container-wide mb-16">
        <div className="mx-auto max-w-3xl text-center">
          <p className="text-primary mb-2 text-sm font-medium tracking-wider uppercase">
            Die Menschen hinter {salon?.name || 'SCHNITTWERK'}
          </p>
          <h1 className="mb-6 text-4xl font-bold md:text-5xl">Unser Team</h1>
          <p className="text-muted-foreground text-lg">
            Lernen Sie die talentierten Stylisten kennen, die Ihren Besuch bei uns zu einem
            besonderen Erlebnis machen.
          </p>
        </div>
      </section>

      {/* Team Grid */}
      <section className="container-wide mb-16">
        {staff.length > 0 ? (
          <div className="grid gap-8 md:grid-cols-2 lg:grid-cols-4">
            {staff.map((member) => (
              <Card key={member.id} className="group border-border/50 overflow-hidden">
                {/* Image */}
                <div className="from-muted to-muted/50 relative aspect-[3/4] bg-gradient-to-br">
                  {member.avatarUrl ? (
                    <Image
                      src={member.avatarUrl}
                      alt={member.displayName}
                      fill
                      className="object-cover"
                    />
                  ) : (
                    <div className="absolute inset-0 flex items-center justify-center">
                      <Scissors className="text-muted-foreground/20 h-12 w-12" />
                    </div>
                  )}
                </div>

                {/* Content */}
                <CardContent className="p-5">
                  <h3 className="text-lg font-semibold">{member.displayName}</h3>
                  {member.jobTitle && (
                    <p className="text-primary mb-3 text-sm">{member.jobTitle}</p>
                  )}
                  {member.bio && (
                    <p className="text-muted-foreground mb-4 line-clamp-3 text-sm">{member.bio}</p>
                  )}

                  {/* Specialties */}
                  {member.specialties.length > 0 && (
                    <div className="flex flex-wrap gap-1.5">
                      {member.specialties.map((specialty) => (
                        <Badge key={specialty} variant="secondary" className="text-xs">
                          {specialty}
                        </Badge>
                      ))}
                    </div>
                  )}
                </CardContent>
              </Card>
            ))}
          </div>
        ) : (
          <div className="py-12 text-center">
            <Scissors className="text-muted-foreground/20 mx-auto mb-4 h-12 w-12" />
            <p className="text-muted-foreground">Unser Team wird bald vorgestellt.</p>
          </div>
        )}
      </section>

      {/* Join Us Section */}
      <section className="container-wide mb-16">
        <Card className="bg-muted/30 border-border/50">
          <CardContent className="p-8 md:p-12">
            <div className="grid items-center gap-8 md:grid-cols-2">
              <div>
                <div className="bg-primary/10 mb-4 inline-flex h-12 w-12 items-center justify-center rounded-full">
                  <Award className="text-primary h-6 w-6" />
                </div>
                <h2 className="mb-4 text-2xl font-bold">Werde Teil unseres Teams</h2>
                <p className="text-muted-foreground mb-4">
                  Du bist leidenschaftlicher Friseur und suchst eine neue Herausforderung? Wir sind
                  immer auf der Suche nach Talenten, die unser Team bereichern.
                </p>
                <ul className="text-muted-foreground mb-6 space-y-2 text-sm">
                  <li>• Attraktive Arbeitszeiten</li>
                  <li>• Weiterbildungsmöglichkeiten</li>
                  <li>• Modernes Arbeitsumfeld</li>
                  <li>• Familiäres Team</li>
                </ul>
                <Button variant="outline" asChild>
                  <Link href="/kontakt">Jetzt bewerben</Link>
                </Button>
              </div>
              <div className="from-primary/10 to-primary/5 relative flex aspect-video items-center justify-center rounded-xl bg-gradient-to-br">
                <span className="text-muted-foreground/30 text-sm">Team-Bild</span>
              </div>
            </div>
          </CardContent>
        </Card>
      </section>

      {/* CTA Section */}
      <section className="container-wide text-center">
        <h2 className="mb-4 text-2xl font-bold">Bereit für Ihren neuen Look?</h2>
        <p className="text-muted-foreground mx-auto mb-8 max-w-xl">
          Buchen Sie jetzt Ihren Termin bei einem unserer erfahrenen Stylisten.
        </p>
        <Button size="lg" className="btn-glow" asChild>
          <Link href="/termin-buchen">
            <Calendar className="mr-2 h-5 w-5" />
            Termin buchen
          </Link>
        </Button>
      </section>
    </div>
  );
}
