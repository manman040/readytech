'use server';

import type { ActionState } from '@/lib/action-state';
import { callAdminRpc, text } from '@/lib/actions';
import { USER_ROLE } from '@/lib/domain/enums';

export async function setRole(_: ActionState, form: FormData): Promise<ActionState> {
  const role = text(form, 'new_role');
  if (!(role in USER_ROLE)) return { error: 'Choose a role.' };

  return callAdminRpc(
    'admin_set_user_role',
    { user_id: text(form, 'user_id'), new_role: role, reason: text(form, 'reason') },
    role === 'technician'
      ? 'Now a technician. They start unverified - approve them on their technician page before they get work.'
      : `Role changed to ${USER_ROLE[role as keyof typeof USER_ROLE].label.toLowerCase()}.`,
  );
}
