import type { Metadata } from 'next';
import { redirect } from 'next/navigation';
import { createServerClient } from '@/lib/supabase/server';
import { AdminSidebar } from '@/components/admin/admin-sidebar';
import { AdminHeader } from '@/components/admin/admin-header';
import { Toaster } from '@/components/ui/sonner';
import { isMockMode, getMockUser, getMockStaffMember } from '@/lib/mock/mock-auth';

// ============================================
// METADATA
// ============================================

export const metadata: Metadata = {
  title: {
    default: 'Admin | SCHNITTWERK',
    template: '%s | Admin | SCHNITTWERK',
  },
  robots: { index: false, follow: false },
};

// ============================================
// ADMIN LAYOUT
// ============================================

// Types
interface StaffMemberRow {
  id: string;
  role: string;
  display_name: string | null;
  salon_id: string;
}

export default async function AdminLayout({
  children,
}: {
  children: React.ReactNode;
}) {
  // ========== MOCK MODE ==========
  if (isMockMode()) {
    const mockUser = await getMockUser();

    if (!mockUser) {
      redirect('/admin/login');
    }

    const mockStaff = await getMockStaffMember(mockUser.id);

    if (!mockStaff) {
      redirect('/admin/login?error=unauthorized');
    }

    return (
      <div className="flex h-screen bg-background">
        {/* Mock Mode Banner */}
        <div className="fixed top-0 left-0 right-0 z-50 bg-amber-500 text-amber-950 text-center text-xs py-1 font-medium">
          DEMO-MODUS - Keine echte Datenbank verbunden
        </div>

        {/* Sidebar */}
        <AdminSidebar
          user={{
            name: mockStaff.display_name,
            email: mockUser.email,
            role: mockStaff.role,
          }}
        />

        {/* Main Content */}
        <div className="flex-1 flex flex-col overflow-hidden pt-6">
          {/* Header */}
          <AdminHeader
            user={{
              name: mockStaff.display_name,
              email: mockUser.email,
              role: mockStaff.role,
            }}
          />

          {/* Page Content */}
          <main className="flex-1 overflow-auto p-6">{children}</main>
        </div>

        {/* Toast Notifications */}
        <Toaster position="bottom-right" />
      </div>
    );
  }

  // ========== REAL MODE (Supabase) ==========
  // Check authentication
  const supabase = await createServerClient();
  const {
    data: { user },
  } = await supabase.auth.getUser();

  if (!user) {
    redirect('/admin/login');
  }

  // Check admin role
  const { data: staffMember } = await supabase
    .from('staff')
    .select('id, role, display_name, salon_id')
    .eq('user_id', user.id)
    .single() as { data: StaffMemberRow | null };

  if (!staffMember) {
    redirect('/admin/login?error=unauthorized');
  }

  const allowedRoles = ['admin', 'manager', 'staff', 'hq'];
  if (!allowedRoles.includes(staffMember.role)) {
    redirect('/admin/login?error=unauthorized');
  }

  return (
    <div className="flex h-screen bg-background">
      {/* Sidebar */}
      <AdminSidebar
        user={{
          name: staffMember.display_name || user.email || 'Admin',
          email: user.email || '',
          role: staffMember.role,
        }}
      />

      {/* Main Content */}
      <div className="flex-1 flex flex-col overflow-hidden">
        {/* Header */}
        <AdminHeader
          user={{
            name: staffMember.display_name || user.email || 'Admin',
            email: user.email || '',
            role: staffMember.role,
          }}
        />

        {/* Page Content */}
        <main className="flex-1 overflow-auto p-6">{children}</main>
      </div>

      {/* Toast Notifications */}
      <Toaster position="bottom-right" />
    </div>
  );
}
