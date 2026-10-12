'use server';

import type { ActionState } from '@/lib/action-state';
import { callAdminRpc, optionalText, text } from '@/lib/actions';

export async function reviewDocument(_: ActionState, form: FormData): Promise<ActionState> {
  const decision = text(form, 'decision');
  if (decision !== 'approved' && decision !== 'rejected') {
    return { error: 'Choose whether to approve or reject the document.' };
  }
  return callAdminRpc(
    'admin_review_verification',
    { verification_id: text(form, 'verification_id'), decision, notes: optionalText(form, 'notes') },
    decision === 'approved'
      ? 'Document approved. The technician has been notified.'
      : 'Document rejected. The technician has been told why.',
  );
}

export async function setTechnicianStatus(_: ActionState, form: FormData): Promise<ActionState> {
  const status = text(form, 'new_status');
  if (!['approved', 'rejected', 'suspended'].includes(status)) {
    return { error: 'Choose a decision.' };
  }
  const messages: Record<string, string> = {
    approved: 'Technician approved. They can receive jobs once they switch on availability.',
    rejected: 'Technician rejected and notified.',
    suspended: 'Technician suspended. They will not be offered new jobs.',
  };
  return callAdminRpc(
    'admin_set_technician_status',
    { technician_id: text(form, 'technician_id'), new_status: status, reason: optionalText(form, 'reason') },
    messages[status] ?? 'Saved.',
  );
}
