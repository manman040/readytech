import { redirect } from 'next/navigation';
import { cache } from 'react';
import { createClient } from '@/lib/supabase/server';

export type Admin = {
  id: string;
  email: string;
  fullName: string;
};

/**
 * The signed-in administrator, or a redirect.
 *
 * Asks Postgres, through is_admin(), rather than reading a role out of the
 * token or the profile: user_roles is the source of truth, and a role revoked
 * a minute ago must stop working now, not when the JWT expires.
 *
 * Cached per request, so the layout and the page share one lookup.
 */
export const requireAdmin = cache(async (): Promise<Admin> => {
  const supabase = await createClient();
  const {
    data: { user },
  } = await supabase.auth.getUser();
  if (!user) redirect('/login');

  const { data: isAdmin, error } = await supabase.rpc('is_admin');
  if (error || isAdmin !== true) {
    await supabase.auth.signOut();
    redirect('/login?reason=not-admin');
  }

  const { data: profile } = await supabase
    .from('profiles')
    .select('full_name, email')
    .eq('id', user.id)
    .maybeSingle();

  return {
    id: user.id,
    email: profile?.email ?? user.email ?? '',
    fullName: profile?.full_name || 'Administrator',
  };
});
