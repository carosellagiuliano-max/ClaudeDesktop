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
  const [staff, salon] = await Promise.all([
    getStaffMembers(),
    getSalon(),
  ]);

  return (
    <div className="py-12">
      {/* Page Header */}
      <section className="container-wide mb-16">
        <div className="text-center max-w-3xl mx-auto">
          <p className="text-primary text-sm font-medium uppercase tracking-wider mb-2">
            Die Menschen hinter {salon?.name || 'SCHNITTWERK'}
          </p>
          <h1 className="text-4xl md:text-5xl font-bold mb-6">Unser Team</h1>
          <p className="text-lg text-muted-foreground">
            Lernen Sie die talentierten Stylisten kennen, die Ihren Besuch bei
            uns zu einem besonderen Erlebnis machen.
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
                <div className="relative aspect-[3/4] bg-gradient-to-br from-muted to-muted/50">
                  {member.avatarUrl ? (
                    <Image
                      src={member.avatarUrl}
                      alt={member.displayName}
                      fill
                      className="object-cover"
                    />
                  ) : (
                    <div className="absolute inset-0 flex items-center justify-center">
                      <Scissors className="h-12 w-12 text-muted-foreground/20" />
                    </div>
                  )}
                </div>

                {/* Content */}
                <CardContent className="p-5">
                  <h3 className="font-semibold text-lg">{member.displayName}</h3>
                  {member.jobTitle && (
                    <p className="text-sm text-primary mb-3">{member.jobTitle}</p>
                  )}
                  {member.bio && (
                    <p className="text-sm text-muted-foreground mb-4 line-clamp-3">
                      {member.bio}
                    </p>
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
          <div className="text-center py-12">
            <Scissors className="h-12 w-12 text-muted-foreground/20 mx-auto mb-4" />
            <p className="text-muted-foreground">
              Unser Team wird bald vorgestellt.
            </p>
          </div>
        )}
      </section>

      {/* Join Us Section */}
      <section className="container-wide mb-16">
        <Card className="bg-muted/30 border-border/50">
          <CardContent className="p-8 md:p-12">
            <div className="grid gap-8 md:grid-cols-2 items-center">
              <div>
                <div className="inline-flex h-12 w-12 items-center justify-center rounded-full bg-primary/10 mb-4">
                  <Award className="h-6 w-6 text-primary" />
                </div>
                <h2 className="text-2xl font-bold mb-4">
                  Werde Teil unseres Teams
                </h2>
                <p className="text-muted-foreground mb-4">
                  Du bist leidenschaftlicher Friseur und suchst eine neue
                  Herausforderung? Wir sind immer auf der Suche nach Talenten,
                  die unser Team bereichern.
                </p>
                <ul className="space-y-2 text-sm text-muted-foreground mb-6">
                  <li>• Attraktive Arbeitszeiten</li>
                  <li>• Weiterbildungsmöglichkeiten</li>
                  <li>• Modernes Arbeitsumfeld</li>
                  <li>• Familiäres Team</li>
                </ul>
                <Button variant="outline" asChild>
                  <Link href="/kontakt">Jetzt bewerben</Link>
                </Button>
              </div>
              <div className="relative aspect-video bg-gradient-to-br from-primary/10 to-primary/5 rounded-xl flex items-center justify-center">
                <span className="text-muted-foreground/30 text-sm">
                  Team-Bild
                </span>
              </div>
            </div>
          </CardContent>
        </Card>
      </section>

      {/* CTA Section */}
      <section className="container-wide text-center">
        <h2 className="text-2xl font-bold mb-4">
          Bereit für Ihren neuen Look?
        </h2>
        <p className="text-muted-foreground mb-8 max-w-xl mx-auto">
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
