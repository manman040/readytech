import { ActionForm, Submit } from '@/components/action-form';
import { reviewDocument } from '@/app/(console)/technicians/actions';

/** Approve or reject one submitted verification document. */
export function DocumentReview({ verificationId }: { verificationId: string }) {
  return (
    <ActionForm action={reviewDocument}>
      <input type="hidden" name="verification_id" value={verificationId} />
      <label className="field">
        Notes
        <span className="hint">Required to reject. Sent to the technician, so write it for them.</span>
        <textarea name="notes" maxLength={500} placeholder="e.g. The photo is blurred - please upload a clearer copy." />
      </label>
      <div className="actions">
        <Submit name="decision" value="approved">
          Approve
        </Submit>
        <Submit name="decision" value="rejected" variant="danger">
          Reject
        </Submit>
      </div>
    </ActionForm>
  );
}
