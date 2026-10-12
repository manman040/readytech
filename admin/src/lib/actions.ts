import 'server-only';
import { revalidatePath } from 'next/cache';
import type { ActionState } from '@/lib/action-state';
import { requireAdmin } from '@/lib/auth';
import { report } from '@/lib/errors';
import { createClient } from '@/lib/supabase/server';

export type { ActionState };

/**
 * The shape of every admin write: confirm the caller is an administrator,
 * call one admin_* function, refresh what changed.
 *
 * The requireAdmin() here is courtesy, not security - each function checks
 * is_admin() itself and would refuse a non-admin whatever this file did.
 */
export async function callAdminRpc(
  fn: string,
  args: Record<string, unknown>,
  message: string,
): Promise<ActionState> {
  await requireAdmin();
  const supabase = await createClient();
  const { error } = await supabase.rpc(fn, args);
  if (error) return { error: report(fn, error) };
  // Queue counts in the sidebar change with almost every action, so the whole
  // console is refreshed rather than guessing which pages show the row.
  revalidatePath('/', 'layout');
  return { ok: true, message };
}

export function text(form: FormData, name: string): string {
  const value = form.get(name);
  return typeof value === 'string' ? value.trim() : '';
}

export function optionalText(form: FormData, name: string): string | null {
  return text(form, name) || null;
}
