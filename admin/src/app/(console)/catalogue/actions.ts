'use server';

import { revalidatePath } from 'next/cache';
import { redirect } from 'next/navigation';
import type { ActionState } from '@/lib/action-state';
import { optionalText, text } from '@/lib/actions';
import { requireAdmin } from '@/lib/auth';
import { DEVICE_TYPE } from '@/lib/domain/enums';
import { parseRinggit } from '@/lib/domain/money';
import { report } from '@/lib/errors';
import { createClient } from '@/lib/supabase/server';

/**
 * Creates or updates a service category.
 *
 * This is the one console write that goes straight to a table: the category's
 * own constraints already state everything that must be true of it, and the
 * service_categories_audit trigger records the change. The checks below exist
 * to give a readable message before Postgres gives a generic one.
 */
export async function saveCategory(_: ActionState, form: FormData): Promise<ActionState> {
  await requireAdmin();
  const id = optionalText(form, 'id');

  const name = text(form, 'name');
  const slug = text(form, 'slug').toLowerCase();
  if (name.length < 2) return { error: 'Give the category a name.' };
  if (!/^[a-z0-9]+(-[a-z0-9]+)*$/.test(slug)) {
    return { error: 'The slug is lowercase letters, numbers and dashes, like "laptop-screen".' };
  }

  const diagnosis = parseRinggit(text(form, 'diagnosis_fee'));
  const min = parseRinggit(text(form, 'estimate_min'));
  const max = parseRinggit(text(form, 'estimate_max'));
  if (diagnosis === null || min === null || max === null || diagnosis < 0 || min < 0 || max < 0) {
    return { error: 'Enter fees in ringgit, like 20 or 20.50.' };
  }
  if (max < min) return { error: 'The top of the estimate cannot be below the bottom.' };

  const warranty = Number(text(form, 'default_warranty_days'));
  if (!Number.isInteger(warranty) || warranty < 0 || warranty > 365) {
    return { error: 'Warranty is a whole number of days between 0 and 365.' };
  }
  const sortOrder = Number(text(form, 'sort_order') || '0');
  if (!Number.isInteger(sortOrder)) return { error: 'Sort order is a whole number.' };

  const deviceTypes = form.getAll('device_types').filter((v): v is string => typeof v === 'string' && v in DEVICE_TYPE);

  const row = {
    name,
    slug,
    description: text(form, 'description'),
    icon: optionalText(form, 'icon'),
    device_types: deviceTypes,
    diagnosis_fee_sen: diagnosis,
    estimated_repair_min_sen: min,
    estimated_repair_max_sen: max,
    default_warranty_days: warranty,
    requires_specialist: form.get('requires_specialist') === 'on',
    is_active: form.get('is_active') === 'on',
    sort_order: sortOrder,
  };

  const supabase = await createClient();
  const { data, error } = id
    ? await supabase.from('service_categories').update(row).eq('id', id).select('id').single()
    : await supabase.from('service_categories').insert(row).select('id').single();

  if (error) {
    if (error.code === '23505') return { error: 'Another category already uses that slug.' };
    return { error: report('saveCategory', error) };
  }

  revalidatePath('/catalogue');
  if (!id) redirect(`/catalogue/${data.id}`);
  return { ok: true, message: 'Saved. New requests use these values from now on; existing jobs keep theirs.' };
}
