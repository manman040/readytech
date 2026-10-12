'use server';

import type { ActionState } from '@/lib/action-state';
import { callAdminRpc, text } from '@/lib/actions';
import { requireAdmin } from '@/lib/auth';
import { parsePricing } from '@/lib/domain/pricing';
import { report } from '@/lib/errors';
import { createClient } from '@/lib/supabase/server';

export async function savePricing(_: ActionState, form: FormData): Promise<ActionState> {
  await requireAdmin();
  const key = text(form, 'key');
  const supabase = await createClient();

  // The stored value decides the shape of the new one, read fresh rather than
  // trusted from the form.
  const { data: current, error } = await supabase.from('pricing_config').select('value').eq('key', key).maybeSingle();
  if (error || !current) return { error: error ? report('pricing read', error) : 'That setting no longer exists.' };

  let value: unknown;
  if (current.value !== null && typeof current.value === 'object') {
    const weights: Record<string, number> = {};
    for (const name of Object.keys(current.value as Record<string, unknown>)) {
      const parsed = parsePricing('weight', 0, text(form, `w.${name}`));
      if ('error' in parsed) return { error: `${name.replace(/_/g, ' ')}: ${parsed.error}` };
      weights[name] = parsed.value;
    }
    value = weights;
  } else {
    const parsed = parsePricing(key, current.value, text(form, 'value'));
    if ('error' in parsed) return { error: parsed.error };
    value = parsed.value;
  }

  return callAdminRpc('admin_set_pricing', { config_key: key, new_value: value }, 'Saved. New estimates and quotations use it now.');
}
