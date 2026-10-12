'use server';

import type { ActionState } from '@/lib/action-state';
import { callAdminRpc, optionalText, text } from '@/lib/actions';
import { parseRinggit } from '@/lib/domain/money';
import { isServiceStatus } from '@/lib/domain/service-status';

export async function markUnderReview(_: ActionState, form: FormData): Promise<ActionState> {
  return callAdminRpc(
    'admin_update_dispute',
    { dispute_id: text(form, 'dispute_id'), new_status: 'under_review' },
    'Marked as under review. The person who raised it has been notified.',
  );
}

export async function decideDispute(_: ActionState, form: FormData): Promise<ActionState> {
  const decision = text(form, 'decision');
  if (decision !== 'resolved' && decision !== 'rejected') {
    return { error: 'Choose whether the dispute is upheld.' };
  }

  // Ringgit typed by a person, sent as whole sen. Anything that is not a clean
  // amount is refused here rather than rounded into something nobody typed.
  const refundText = text(form, 'refund');
  const refund = refundText ? parseRinggit(refundText) : 0;
  if (refund === null || refund < 0) {
    return { error: 'Enter the refund in ringgit, like 45 or 45.50.' };
  }

  const outcome = optionalText(form, 'request_outcome');
  if (outcome !== null && !isServiceStatus(outcome)) {
    return { error: 'Choose what happens to the job.' };
  }

  return callAdminRpc(
    'admin_update_dispute',
    {
      dispute_id: text(form, 'dispute_id'),
      new_status: decision,
      resolution: text(form, 'resolution'),
      refund_amount_sen: refund,
      request_outcome: outcome,
    },
    decision === 'resolved' ? 'Dispute resolved and the customer notified.' : 'Dispute closed as not upheld.',
  );
}
