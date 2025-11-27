'use client';

import { useState } from 'react';
import { useRouter } from 'next/navigation';
import { Eye, EyeOff, Loader2 } from 'lucide-react';
import { Button } from '@/components/ui/button';
import { Input } from '@/components/ui/input';
import { Label } from '@/components/ui/label';
import { createBrowserClient } from '@/lib/supabase/client';
import { MOCK_ADMIN_USER, MOCK_STAFF_USER } from '@/lib/mock/mock-data';

// ============================================
// MOCK MODE CHECK
// ============================================

const isMockMode = process.env.NEXT_PUBLIC_MOCK_MODE === 'true';

// ============================================
// ADMIN LOGIN FORM
// ============================================

export function AdminLoginForm() {
  const router = useRouter();
  const [email, setEmail] = useState('');
  const [password, setPassword] = useState('');
  const [showPassword, setShowPassword] = useState(false);
  const [isLoading, setIsLoading] = useState(false);
  const [error, setError] = useState<string | null>(null);

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    setError(null);
    setIsLoading(true);

    // ========== MOCK MODE ==========
    if (isMockMode) {
      // Check mock credentials
      const isAdmin = email === MOCK_ADMIN_USER.email && password === MOCK_ADMIN_USER.password;
      const isStaff = email === MOCK_STAFF_USER.email && password === MOCK_STAFF_USER.password;

      if (isAdmin || isStaff) {
        // Store mock session in localStorage AND cookies (for server components)
        const mockUser = isAdmin ? MOCK_ADMIN_USER : MOCK_STAFF_USER;
        localStorage.setItem('mock_user', JSON.stringify(mockUser));
        localStorage.setItem('mock_session', 'true');

        // Set cookies for server-side auth check
        document.cookie = `mock_session=true; path=/; max-age=86400`;
        document.cookie = `mock_user=${encodeURIComponent(JSON.stringify(mockUser))}; path=/; max-age=86400`;

        // Small delay to simulate network
        await new Promise(resolve => setTimeout(resolve, 500));

        router.push('/admin');
        router.refresh();
        return;
      } else {
        setError('E-Mail oder Passwort ist ungültig.');
        setIsLoading(false);
        return;
      }
    }

    // ========== REAL MODE (Supabase) ==========
    try {
      const supabase = createBrowserClient();

      const { data, error: signInError } = await supabase.auth.signInWithPassword({
        email,
        password,
      });

      if (signInError) {
        setError('E-Mail oder Passwort ist ungültig.');
        setIsLoading(false);
        return;
      }

      if (data.user) {
        // Check if user is staff
        const { data: staffMember } = await supabase
          .from('staff')
          .select('role')
          .eq('user_id', data.user.id)
          .single();

        if (!staffMember) {
          await supabase.auth.signOut();
          setError('Sie haben keine Berechtigung für den Admin-Bereich.');
          setIsLoading(false);
          return;
        }

        // Redirect to admin dashboard
        router.push('/admin');
        router.refresh();
      }
    } catch {
      setError('Ein Fehler ist aufgetreten. Bitte versuchen Sie es erneut.');
      setIsLoading(false);
    }
  };

  return (
    <form onSubmit={handleSubmit} className="space-y-4">
      {error && (
        <div className="p-3 rounded-md bg-destructive/10 text-destructive text-sm">
          {error}
        </div>
      )}

      <div className="space-y-2">
        <Label htmlFor="email">E-Mail</Label>
        <Input
          id="email"
          type="email"
          placeholder="name@salon.ch"
          value={email}
          onChange={(e) => setEmail(e.target.value)}
          required
          autoComplete="email"
          disabled={isLoading}
        />
      </div>

      <div className="space-y-2">
        <Label htmlFor="password">Passwort</Label>
        <div className="relative">
          <Input
            id="password"
            type={showPassword ? 'text' : 'password'}
            placeholder="Ihr Passwort"
            value={password}
            onChange={(e) => setPassword(e.target.value)}
            required
            autoComplete="current-password"
            disabled={isLoading}
            className="pr-10"
          />
          <button
            type="button"
            onClick={() => setShowPassword(!showPassword)}
            className="absolute right-3 top-1/2 -translate-y-1/2 text-muted-foreground hover:text-foreground"
            tabIndex={-1}
          >
            {showPassword ? (
              <EyeOff className="h-4 w-4" />
            ) : (
              <Eye className="h-4 w-4" />
            )}
          </button>
        </div>
      </div>

      <Button type="submit" className="w-full" disabled={isLoading}>
        {isLoading ? (
          <>
            <Loader2 className="h-4 w-4 mr-2 animate-spin" />
            Anmelden...
          </>
        ) : (
          'Anmelden'
        )}
      </Button>

      {/* Mock Mode Hint */}
      {isMockMode && (
        <div className="mt-4 p-3 rounded-md bg-amber-500/10 border border-amber-500/20 text-amber-700 dark:text-amber-400 text-xs">
          <p className="font-medium mb-1">Demo-Modus aktiv</p>
          <p>Admin: admin@schnittwerk.ch / admin123</p>
          <p>Staff: vanessa@schnittwerk.ch / staff123</p>
        </div>
      )}
    </form>
  );
}
