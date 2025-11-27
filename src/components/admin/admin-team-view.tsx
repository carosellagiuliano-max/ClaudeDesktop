'use client';

import { useState } from 'react';
import { useRouter } from 'next/navigation';
import {
  Plus,
  MoreHorizontal,
  Mail,
  Phone,
  Calendar,
  Edit,
  Trash2,
  Clock,
  Shield,
  Briefcase,
  Award,
  CalendarOff,
  Check,
  X,
} from 'lucide-react';
import { Button } from '@/components/ui/button';
import { Card, CardContent, CardHeader, CardTitle } from '@/components/ui/card';
import { Badge } from '@/components/ui/badge';
import { Avatar, AvatarFallback } from '@/components/ui/avatar';
import {
  DropdownMenu,
  DropdownMenuContent,
  DropdownMenuItem,
  DropdownMenuSeparator,
  DropdownMenuTrigger,
} from '@/components/ui/dropdown-menu';
import {
  Dialog,
  DialogContent,
  DialogHeader,
  DialogTitle,
  DialogDescription,
  DialogFooter,
} from '@/components/ui/dialog';
import {
  Select,
  SelectContent,
  SelectItem,
  SelectTrigger,
  SelectValue,
} from '@/components/ui/select';
import { Input } from '@/components/ui/input';
import { Label } from '@/components/ui/label';
import { Checkbox } from '@/components/ui/checkbox';
import { Tabs, TabsContent, TabsList, TabsTrigger } from '@/components/ui/tabs';
import {
  Table,
  TableBody,
  TableCell,
  TableHead,
  TableHeader,
  TableRow,
} from '@/components/ui/table';
import { createBrowserClient } from '@/lib/supabase/client';
import { toast } from 'sonner';

// ============================================
// TYPES
// ============================================

interface StaffMember {
  id: string;
  user_id: string | null;
  display_name: string;
  email: string | null;
  phone: string | null;
  role: string;
  color: string | null;
  is_active: boolean;
  created_at: string;
  working_hours: Record<string, unknown> | null;
  employment_type: string | null;
  hire_date: string | null;
  bio: string | null;
  specializations: string[] | null;
}

interface Service {
  id: string;
  name: string;
  duration_minutes: number;
}

interface Absence {
  id: string;
  staff_id: string;
  start_date: string;
  end_date: string;
  absence_type: string;
  status: string;
  notes: string | null;
}

interface StaffSkill {
  staff_id: string;
  service_id: string;
  proficiency_level: string;
}

interface WorkingHour {
  id: string;
  staff_id: string;
  day_of_week: number;
  start_time: string;
  end_time: string;
  is_active: boolean;
}

interface AdminTeamViewProps {
  staff: StaffMember[];
  services: Service[];
  absences: Absence[];
  skills: StaffSkill[];
  workingHours: WorkingHour[];
}

// ============================================
// CONSTANTS
// ============================================

const roleConfig: Record<string, { label: string; variant: 'default' | 'secondary' | 'outline' }> =
  {
    admin: { label: 'Administrator', variant: 'default' },
    manager: { label: 'Manager', variant: 'default' },
    staff: { label: 'Mitarbeiter', variant: 'secondary' },
    hq: { label: 'Hauptverwaltung', variant: 'outline' },
  };

const dayNames = ['Sonntag', 'Montag', 'Dienstag', 'Mittwoch', 'Donnerstag', 'Freitag', 'Samstag'];
const shortDayNames = ['So', 'Mo', 'Di', 'Mi', 'Do', 'Fr', 'Sa'];

const absenceTypes: Record<string, { label: string; color: string }> = {
  vacation: { label: 'Urlaub', color: 'bg-blue-500' },
  sick: { label: 'Krankheit', color: 'bg-red-500' },
  personal: { label: 'Persönlich', color: 'bg-yellow-500' },
  training: { label: 'Weiterbildung', color: 'bg-purple-500' },
  other: { label: 'Sonstiges', color: 'bg-gray-500' },
};

const proficiencyLevels: Record<string, { label: string; color: string }> = {
  beginner: { label: 'Anfänger', color: 'bg-yellow-500' },
  standard: { label: 'Standard', color: 'bg-blue-500' },
  expert: { label: 'Experte', color: 'bg-green-500' },
};

// ============================================
// HELPERS
// ============================================

function getInitials(name: string): string {
  return name
    .split(' ')
    .map((n) => n[0])
    .join('')
    .toUpperCase()
    .slice(0, 2);
}

function formatDate(dateString: string): string {
  return new Date(dateString).toLocaleDateString('de-CH', {
    day: '2-digit',
    month: '2-digit',
    year: 'numeric',
  });
}

// ============================================
// ADMIN TEAM VIEW
// ============================================

export function AdminTeamView({
  staff,
  services,
  absences,
  skills,
  workingHours,
}: AdminTeamViewProps) {
  const router = useRouter();
  const [deleteDialogOpen, setDeleteDialogOpen] = useState(false);
  const [selectedMember, setSelectedMember] = useState<StaffMember | null>(null);

  // Working Hours Dialog
  const [hoursDialogOpen, setHoursDialogOpen] = useState(false);
  const [editingHours, setEditingHours] = useState<
    Record<number, { start: string; end: string; active: boolean }>
  >({});

  // Skills Dialog
  const [skillsDialogOpen, setSkillsDialogOpen] = useState(false);
  const [editingSkills, setEditingSkills] = useState<Record<string, string>>({});

  // Absence Dialog
  const [absenceDialogOpen, setAbsenceDialogOpen] = useState(false);
  const [newAbsence, setNewAbsence] = useState({
    startDate: '',
    endDate: '',
    type: 'vacation',
    notes: '',
  });

  const [isSaving, setIsSaving] = useState(false);

  const activeStaff = staff.filter((s) => s.is_active);
  const inactiveStaff = staff.filter((s) => !s.is_active);

  // Get skills for a staff member
  const getStaffSkills = (staffId: string) => {
    return skills.filter((s) => s.staff_id === staffId);
  };

  // Get working hours for a staff member
  const getStaffWorkingHours = (staffId: string) => {
    return workingHours.filter((h) => h.staff_id === staffId);
  };

  // Get absences for a staff member
  const getStaffAbsences = (staffId: string) => {
    return absences.filter((a) => a.staff_id === staffId);
  };

  // Open hours dialog
  const openHoursDialog = (member: StaffMember) => {
    setSelectedMember(member);
    const staffHours = getStaffWorkingHours(member.id);
    const hoursMap: Record<number, { start: string; end: string; active: boolean }> = {};

    // Initialize all days
    for (let i = 0; i < 7; i++) {
      const dayHour = staffHours.find((h) => h.day_of_week === i);
      hoursMap[i] = dayHour
        ? {
            start: dayHour.start_time.slice(0, 5),
            end: dayHour.end_time.slice(0, 5),
            active: dayHour.is_active,
          }
        : { start: '09:00', end: '18:00', active: false };
    }

    setEditingHours(hoursMap);
    setHoursDialogOpen(true);
  };

  // Save working hours
  const handleSaveHours = async () => {
    if (!selectedMember) return;
    setIsSaving(true);
    const supabase = createBrowserClient();

    // Delete existing hours
    await supabase.from('staff_working_hours').delete().eq('staff_id', selectedMember.id);

    // Insert new hours
    const hoursToInsert = Object.entries(editingHours)
      .filter(([_, hours]) => hours.active)
      .map(([day, hours]) => ({
        staff_id: selectedMember.id,
        day_of_week: parseInt(day),
        start_time: hours.start,
        end_time: hours.end,
        is_active: true,
      }));

    if (hoursToInsert.length > 0) {
      const { error } = await supabase.from('staff_working_hours').insert(hoursToInsert);
      if (error) {
        toast.error('Fehler beim Speichern der Arbeitszeiten');
        setIsSaving(false);
        return;
      }
    }

    toast.success('Arbeitszeiten gespeichert');
    setHoursDialogOpen(false);
    router.refresh();
    setIsSaving(false);
  };

  // Open skills dialog
  const openSkillsDialog = (member: StaffMember) => {
    setSelectedMember(member);
    const staffSkills = getStaffSkills(member.id);
    const skillsMap: Record<string, string> = {};

    services.forEach((service) => {
      const skill = staffSkills.find((s) => s.service_id === service.id);
      skillsMap[service.id] = skill?.proficiency_level || '';
    });

    setEditingSkills(skillsMap);
    setSkillsDialogOpen(true);
  };

  // Save skills
  const handleSaveSkills = async () => {
    if (!selectedMember) return;
    setIsSaving(true);
    const supabase = createBrowserClient();

    // Delete existing skills
    await supabase.from('staff_skills').delete().eq('staff_id', selectedMember.id);

    // Insert new skills
    const skillsToInsert = Object.entries(editingSkills)
      .filter(([_, level]) => level !== '')
      .map(([serviceId, level]) => ({
        staff_id: selectedMember.id,
        service_id: serviceId,
        proficiency_level: level,
      }));

    if (skillsToInsert.length > 0) {
      const { error } = await supabase.from('staff_skills').insert(skillsToInsert);
      if (error) {
        toast.error('Fehler beim Speichern der Skills');
        setIsSaving(false);
        return;
      }
    }

    toast.success('Skills gespeichert');
    setSkillsDialogOpen(false);
    router.refresh();
    setIsSaving(false);
  };

  // Open absence dialog
  const openAbsenceDialog = (member: StaffMember) => {
    setSelectedMember(member);
    setNewAbsence({
      startDate: '',
      endDate: '',
      type: 'vacation',
      notes: '',
    });
    setAbsenceDialogOpen(true);
  };

  // Save absence
  const handleSaveAbsence = async () => {
    if (!selectedMember || !newAbsence.startDate || !newAbsence.endDate) {
      toast.error('Bitte Start- und Enddatum angeben');
      return;
    }

    setIsSaving(true);
    const supabase = createBrowserClient();

    const { error } = await supabase.from('staff_absences').insert({
      staff_id: selectedMember.id,
      start_date: newAbsence.startDate,
      end_date: newAbsence.endDate,
      absence_type: newAbsence.type,
      notes: newAbsence.notes || null,
      status: 'approved',
    });

    if (error) {
      toast.error('Fehler beim Speichern der Abwesenheit');
    } else {
      toast.success('Abwesenheit gespeichert');
      setAbsenceDialogOpen(false);
      router.refresh();
    }

    setIsSaving(false);
  };

  const handleDeleteClick = (member: StaffMember) => {
    setSelectedMember(member);
    setDeleteDialogOpen(true);
  };

  const handleDeleteConfirm = async () => {
    if (!selectedMember) return;
    const supabase = createBrowserClient();

    const { error } = await supabase
      .from('staff')
      .update({ is_active: false, updated_at: new Date().toISOString() })
      .eq('id', selectedMember.id);

    if (error) {
      toast.error('Fehler beim Deaktivieren');
    } else {
      toast.success('Mitarbeiter deaktiviert');
      router.refresh();
    }

    setDeleteDialogOpen(false);
    setSelectedMember(null);
  };

  const handleActivate = async (member: StaffMember) => {
    const supabase = createBrowserClient();

    const { error } = await supabase
      .from('staff')
      .update({ is_active: true, updated_at: new Date().toISOString() })
      .eq('id', member.id);

    if (error) {
      toast.error('Fehler beim Aktivieren');
    } else {
      toast.success('Mitarbeiter aktiviert');
      router.refresh();
    }
  };

  return (
    <div className="space-y-6">
      {/* Header */}
      <div className="flex items-center justify-between">
        <div>
          <p className="text-muted-foreground text-sm">{activeStaff.length} aktive Mitarbeiter</p>
        </div>
        <Button>
          <Plus className="mr-2 h-4 w-4" />
          Mitarbeiter hinzufügen
        </Button>
      </div>

      <Tabs defaultValue="overview" className="space-y-4">
        <TabsList>
          <TabsTrigger value="overview">Übersicht</TabsTrigger>
          <TabsTrigger value="absences">Abwesenheiten ({absences.length})</TabsTrigger>
          <TabsTrigger value="skills">Skills</TabsTrigger>
        </TabsList>

        {/* Overview Tab */}
        <TabsContent value="overview">
          {/* Active Staff */}
          <div className="grid gap-4 md:grid-cols-2 lg:grid-cols-3">
            {activeStaff.map((member) => {
              const role = roleConfig[member.role] || {
                label: member.role,
                variant: 'secondary' as const,
              };
              const memberSkills = getStaffSkills(member.id);
              const memberHours = getStaffWorkingHours(member.id);

              return (
                <Card key={member.id}>
                  <CardContent className="p-4">
                    <div className="flex items-start justify-between">
                      <div className="flex items-center gap-3">
                        <Avatar
                          className="h-12 w-12"
                          style={{
                            backgroundColor: member.color || 'hsl(var(--primary))',
                          }}
                        >
                          <AvatarFallback
                            className="text-white"
                            style={{
                              backgroundColor: member.color || 'hsl(var(--primary))',
                            }}
                          >
                            {getInitials(member.display_name)}
                          </AvatarFallback>
                        </Avatar>
                        <div>
                          <h3 className="font-medium">{member.display_name}</h3>
                          <Badge variant={role.variant} className="mt-1">
                            <Shield className="mr-1 h-3 w-3" />
                            {role.label}
                          </Badge>
                        </div>
                      </div>
                      <DropdownMenu>
                        <DropdownMenuTrigger asChild>
                          <Button variant="ghost" size="icon">
                            <MoreHorizontal className="h-4 w-4" />
                          </Button>
                        </DropdownMenuTrigger>
                        <DropdownMenuContent align="end">
                          <DropdownMenuItem>
                            <Edit className="mr-2 h-4 w-4" />
                            Bearbeiten
                          </DropdownMenuItem>
                          <DropdownMenuItem onClick={() => openHoursDialog(member)}>
                            <Clock className="mr-2 h-4 w-4" />
                            Arbeitszeiten
                          </DropdownMenuItem>
                          <DropdownMenuItem onClick={() => openSkillsDialog(member)}>
                            <Award className="mr-2 h-4 w-4" />
                            Skills
                          </DropdownMenuItem>
                          <DropdownMenuItem onClick={() => openAbsenceDialog(member)}>
                            <Calendar className="mr-2 h-4 w-4" />
                            Abwesenheit
                          </DropdownMenuItem>
                          <DropdownMenuSeparator />
                          <DropdownMenuItem
                            onClick={() => handleDeleteClick(member)}
                            className="text-destructive"
                          >
                            <Trash2 className="mr-2 h-4 w-4" />
                            Deaktivieren
                          </DropdownMenuItem>
                        </DropdownMenuContent>
                      </DropdownMenu>
                    </div>

                    <div className="mt-4 space-y-2 text-sm">
                      {member.email && (
                        <a
                          href={`mailto:${member.email}`}
                          className="text-muted-foreground hover:text-foreground flex items-center gap-2"
                        >
                          <Mail className="h-4 w-4" />
                          {member.email}
                        </a>
                      )}
                      {member.phone && (
                        <a
                          href={`tel:${member.phone}`}
                          className="text-muted-foreground hover:text-foreground flex items-center gap-2"
                        >
                          <Phone className="h-4 w-4" />
                          {member.phone}
                        </a>
                      )}
                    </div>

                    {/* Quick info */}
                    <div className="text-muted-foreground mt-4 flex gap-4 border-t pt-4 text-xs">
                      <span className="flex items-center gap-1">
                        <Clock className="h-3 w-3" />
                        {memberHours.filter((h) => h.is_active).length} Tage
                      </span>
                      <span className="flex items-center gap-1">
                        <Award className="h-3 w-3" />
                        {memberSkills.length} Skills
                      </span>
                    </div>
                  </CardContent>
                </Card>
              );
            })}
          </div>

          {/* Inactive Staff */}
          {inactiveStaff.length > 0 && (
            <div className="mt-8 space-y-4">
              <h3 className="text-muted-foreground text-lg font-medium">
                Inaktive Mitarbeiter ({inactiveStaff.length})
              </h3>
              <div className="grid gap-4 md:grid-cols-2 lg:grid-cols-3">
                {inactiveStaff.map((member) => (
                  <Card key={member.id} className="opacity-60">
                    <CardContent className="p-4">
                      <div className="flex items-center justify-between">
                        <div className="flex items-center gap-3">
                          <Avatar className="bg-muted h-10 w-10">
                            <AvatarFallback className="bg-muted text-muted-foreground">
                              {getInitials(member.display_name)}
                            </AvatarFallback>
                          </Avatar>
                          <div>
                            <h3 className="text-muted-foreground font-medium">
                              {member.display_name}
                            </h3>
                            <Badge variant="outline" className="mt-1">
                              Inaktiv
                            </Badge>
                          </div>
                        </div>
                        <Button variant="outline" size="sm" onClick={() => handleActivate(member)}>
                          Aktivieren
                        </Button>
                      </div>
                    </CardContent>
                  </Card>
                ))}
              </div>
            </div>
          )}
        </TabsContent>

        {/* Absences Tab */}
        <TabsContent value="absences">
          <Card>
            <CardHeader>
              <CardTitle>Abwesenheiten</CardTitle>
            </CardHeader>
            <CardContent>
              {absences.length === 0 ? (
                <p className="text-muted-foreground py-8 text-center">
                  Keine geplanten Abwesenheiten
                </p>
              ) : (
                <Table>
                  <TableHeader>
                    <TableRow>
                      <TableHead>Mitarbeiter</TableHead>
                      <TableHead>Typ</TableHead>
                      <TableHead>Von</TableHead>
                      <TableHead>Bis</TableHead>
                      <TableHead>Status</TableHead>
                      <TableHead>Notizen</TableHead>
                    </TableRow>
                  </TableHeader>
                  <TableBody>
                    {absences.map((absence) => {
                      const staffMember = staff.find((s) => s.id === absence.staff_id);
                      const type = absenceTypes[absence.absence_type] || {
                        label: absence.absence_type,
                        color: 'bg-gray-500',
                      };
                      return (
                        <TableRow key={absence.id}>
                          <TableCell className="font-medium">
                            {staffMember?.display_name || 'Unbekannt'}
                          </TableCell>
                          <TableCell>
                            <Badge className={`${type.color} text-white`}>{type.label}</Badge>
                          </TableCell>
                          <TableCell>{formatDate(absence.start_date)}</TableCell>
                          <TableCell>{formatDate(absence.end_date)}</TableCell>
                          <TableCell>
                            <Badge
                              variant={absence.status === 'approved' ? 'default' : 'secondary'}
                            >
                              {absence.status === 'approved' ? 'Genehmigt' : 'Ausstehend'}
                            </Badge>
                          </TableCell>
                          <TableCell className="text-muted-foreground">
                            {absence.notes || '-'}
                          </TableCell>
                        </TableRow>
                      );
                    })}
                  </TableBody>
                </Table>
              )}
            </CardContent>
          </Card>
        </TabsContent>

        {/* Skills Tab */}
        <TabsContent value="skills">
          <Card>
            <CardHeader>
              <CardTitle>Skills Matrix</CardTitle>
            </CardHeader>
            <CardContent>
              <div className="overflow-x-auto">
                <Table>
                  <TableHeader>
                    <TableRow>
                      <TableHead className="bg-background sticky left-0">Mitarbeiter</TableHead>
                      {services.map((service) => (
                        <TableHead key={service.id} className="min-w-[100px] text-center">
                          {service.name}
                        </TableHead>
                      ))}
                    </TableRow>
                  </TableHeader>
                  <TableBody>
                    {activeStaff.map((member) => {
                      const memberSkills = getStaffSkills(member.id);
                      return (
                        <TableRow key={member.id}>
                          <TableCell className="bg-background sticky left-0 font-medium">
                            {member.display_name}
                          </TableCell>
                          {services.map((service) => {
                            const skill = memberSkills.find((s) => s.service_id === service.id);
                            const level = skill ? proficiencyLevels[skill.proficiency_level] : null;
                            return (
                              <TableCell key={service.id} className="text-center">
                                {level ? (
                                  <Badge className={`${level.color} text-xs text-white`}>
                                    {level.label}
                                  </Badge>
                                ) : (
                                  <span className="text-muted-foreground">-</span>
                                )}
                              </TableCell>
                            );
                          })}
                        </TableRow>
                      );
                    })}
                  </TableBody>
                </Table>
              </div>
            </CardContent>
          </Card>
        </TabsContent>
      </Tabs>

      {/* Delete Confirmation Dialog */}
      <Dialog open={deleteDialogOpen} onOpenChange={setDeleteDialogOpen}>
        <DialogContent>
          <DialogHeader>
            <DialogTitle>Mitarbeiter deaktivieren</DialogTitle>
            <DialogDescription>
              Sind Sie sicher, dass Sie {selectedMember?.display_name} deaktivieren möchten? Der
              Mitarbeiter hat keinen Zugriff mehr auf das System.
            </DialogDescription>
          </DialogHeader>
          <DialogFooter>
            <Button variant="outline" onClick={() => setDeleteDialogOpen(false)}>
              Abbrechen
            </Button>
            <Button variant="destructive" onClick={handleDeleteConfirm}>
              Deaktivieren
            </Button>
          </DialogFooter>
        </DialogContent>
      </Dialog>

      {/* Working Hours Dialog */}
      <Dialog open={hoursDialogOpen} onOpenChange={setHoursDialogOpen}>
        <DialogContent className="sm:max-w-lg">
          <DialogHeader>
            <DialogTitle>Arbeitszeiten - {selectedMember?.display_name}</DialogTitle>
            <DialogDescription>Definieren Sie die regelmässigen Arbeitszeiten</DialogDescription>
          </DialogHeader>
          <div className="space-y-4 py-4">
            {[1, 2, 3, 4, 5, 6, 0].map((day) => (
              <div key={day} className="flex items-center gap-4">
                <div className="w-24">
                  <Checkbox
                    id={`day-${day}`}
                    checked={editingHours[day]?.active || false}
                    onCheckedChange={(checked) =>
                      setEditingHours({
                        ...editingHours,
                        [day]: { ...editingHours[day], active: checked === true },
                      })
                    }
                  />
                  <Label htmlFor={`day-${day}`} className="ml-2">
                    {dayNames[day]}
                  </Label>
                </div>
                {editingHours[day]?.active && (
                  <>
                    <Input
                      type="time"
                      value={editingHours[day]?.start || '09:00'}
                      onChange={(e) =>
                        setEditingHours({
                          ...editingHours,
                          [day]: { ...editingHours[day], start: e.target.value },
                        })
                      }
                      className="w-32"
                    />
                    <span>bis</span>
                    <Input
                      type="time"
                      value={editingHours[day]?.end || '18:00'}
                      onChange={(e) =>
                        setEditingHours({
                          ...editingHours,
                          [day]: { ...editingHours[day], end: e.target.value },
                        })
                      }
                      className="w-32"
                    />
                  </>
                )}
              </div>
            ))}
          </div>
          <DialogFooter>
            <Button variant="outline" onClick={() => setHoursDialogOpen(false)}>
              Abbrechen
            </Button>
            <Button onClick={handleSaveHours} disabled={isSaving}>
              {isSaving ? 'Speichern...' : 'Speichern'}
            </Button>
          </DialogFooter>
        </DialogContent>
      </Dialog>

      {/* Skills Dialog */}
      <Dialog open={skillsDialogOpen} onOpenChange={setSkillsDialogOpen}>
        <DialogContent className="sm:max-w-lg">
          <DialogHeader>
            <DialogTitle>Skills - {selectedMember?.display_name}</DialogTitle>
            <DialogDescription>
              Wählen Sie die Dienstleistungen und Kompetenz-Level
            </DialogDescription>
          </DialogHeader>
          <div className="max-h-96 space-y-4 overflow-y-auto py-4">
            {services.map((service) => (
              <div key={service.id} className="flex items-center justify-between gap-4">
                <span className="font-medium">{service.name}</span>
                <Select
                  value={editingSkills[service.id] || ''}
                  onValueChange={(value) =>
                    setEditingSkills({ ...editingSkills, [service.id]: value })
                  }
                >
                  <SelectTrigger className="w-36">
                    <SelectValue placeholder="Nicht zugewiesen" />
                  </SelectTrigger>
                  <SelectContent>
                    <SelectItem value="">Nicht zugewiesen</SelectItem>
                    <SelectItem value="beginner">Anfänger</SelectItem>
                    <SelectItem value="standard">Standard</SelectItem>
                    <SelectItem value="expert">Experte</SelectItem>
                  </SelectContent>
                </Select>
              </div>
            ))}
          </div>
          <DialogFooter>
            <Button variant="outline" onClick={() => setSkillsDialogOpen(false)}>
              Abbrechen
            </Button>
            <Button onClick={handleSaveSkills} disabled={isSaving}>
              {isSaving ? 'Speichern...' : 'Speichern'}
            </Button>
          </DialogFooter>
        </DialogContent>
      </Dialog>

      {/* Absence Dialog */}
      <Dialog open={absenceDialogOpen} onOpenChange={setAbsenceDialogOpen}>
        <DialogContent className="sm:max-w-md">
          <DialogHeader>
            <DialogTitle>Abwesenheit - {selectedMember?.display_name}</DialogTitle>
            <DialogDescription>Erfassen Sie eine neue Abwesenheit</DialogDescription>
          </DialogHeader>
          <div className="space-y-4 py-4">
            <div className="space-y-2">
              <Label htmlFor="absenceType">Art der Abwesenheit</Label>
              <Select
                value={newAbsence.type}
                onValueChange={(value) => setNewAbsence({ ...newAbsence, type: value })}
              >
                <SelectTrigger id="absenceType">
                  <SelectValue />
                </SelectTrigger>
                <SelectContent>
                  <SelectItem value="vacation">Urlaub</SelectItem>
                  <SelectItem value="sick">Krankheit</SelectItem>
                  <SelectItem value="personal">Persönlich</SelectItem>
                  <SelectItem value="training">Weiterbildung</SelectItem>
                  <SelectItem value="other">Sonstiges</SelectItem>
                </SelectContent>
              </Select>
            </div>
            <div className="grid grid-cols-2 gap-4">
              <div className="space-y-2">
                <Label htmlFor="startDate">Von</Label>
                <Input
                  id="startDate"
                  type="date"
                  value={newAbsence.startDate}
                  onChange={(e) => setNewAbsence({ ...newAbsence, startDate: e.target.value })}
                />
              </div>
              <div className="space-y-2">
                <Label htmlFor="endDate">Bis</Label>
                <Input
                  id="endDate"
                  type="date"
                  value={newAbsence.endDate}
                  onChange={(e) => setNewAbsence({ ...newAbsence, endDate: e.target.value })}
                />
              </div>
            </div>
            <div className="space-y-2">
              <Label htmlFor="notes">Notizen (optional)</Label>
              <Input
                id="notes"
                value={newAbsence.notes}
                onChange={(e) => setNewAbsence({ ...newAbsence, notes: e.target.value })}
                placeholder="z.B. Grund, Vertretung..."
              />
            </div>
          </div>
          <DialogFooter>
            <Button variant="outline" onClick={() => setAbsenceDialogOpen(false)}>
              Abbrechen
            </Button>
            <Button onClick={handleSaveAbsence} disabled={isSaving}>
              {isSaving ? 'Speichern...' : 'Speichern'}
            </Button>
          </DialogFooter>
        </DialogContent>
      </Dialog>
    </div>
  );
}
