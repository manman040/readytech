'use server';

import type { ActionState } from '@/lib/action-state';
import { callAdminRpc, text } from '@/lib/actions';
import { ADMIN_LABEL, isServiceStatus } from '@/lib/domain/service-status';

export async function transitionJob(_: ActionState, form: FormData): Promise<ActionState> {
  const toStatus = text(form, 'to_status');
  if (!isServiceStatus(toStatus)) return { error: 'Choose what should happen to the job.' };

  return callAdminRpc(
    'admin_transition_service_request',
    { request_id: text(form, 'request_id'), to_status: toStatus, reason: text(form, 'reason') },
    toStatus === 'CANCELLED' || toStatus === 'MATCHING'
      ? `Job moved to "${ADMIN_LABEL[toStatus]}". The people on the job have been notified.`
      : `Job moved to "${ADMIN_LABEL[toStatus]}".`,
  );
}
