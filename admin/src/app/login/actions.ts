'use server';

import { redirect } from 'next/navigation';
import type { ActionState } from '@/lib/action-state';
import { text } from '@/lib/actions';
import { createClient } from '@/lib/supabase/server';

export async function signIn(_: ActionState, form: FormData): Promise<ActionState> {
  const email = text(form, 'email');
  const password = form.get('password');
  if (!email || typeof password !== 'string' || !password) {
    return { error: 'Enter your email address and password.' };
  }

  const supabase = await createClient();
  const { error } = await supabase.auth.signInWithPassword({ email, password });
  if (error) {
    // The same sentence for a wrong password and an unknown address, so the
    // form cannot be used to find out who has an account.
    return { error: 'That email and password do not match an account.' };
  }

  // Signing in proves who someone is, not that they administer anything.
  const { data: isAdmin } = await supabase.rpc('is_admin');
  if (isAdmin !== true) {
    await supabase.auth.signOut();
    return {
      error:
        'This account is not an administrator. Customers and technicians use the ReadyTech app.',
    };
  }

  redirect('/');
}
