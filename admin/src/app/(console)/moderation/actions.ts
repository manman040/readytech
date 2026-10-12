'use server';

import type { ActionState } from '@/lib/action-state';
import { callAdminRpc, optionalText, text } from '@/lib/actions';

export async function reviewReport(_: ActionState, form: FormData): Promise<ActionState> {
  const redact = text(form, 'outcome') === 'redact';
  return callAdminRpc(
    'admin_review_message_report',
    { message_id: text(form, 'message_id'), redact, reason: optionalText(form, 'reason') },
    redact
      ? 'Message removed. The original is kept in the audit log.'
      : 'Report dismissed. The message stays as it was.',
  );
}

export async function removeReview(_: ActionState, form: FormData): Promise<ActionState> {
  return callAdminRpc(
    'admin_remove_review',
    { review_id: text(form, 'review_id'), reason: text(form, 'reason') },
    'Review removed. The technician’s rating has been recalculated.',
  );
}
