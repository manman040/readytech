import Link from 'next/link';
import { notFound } from 'next/navigation';
import { ActionForm, Submit } from '@/components/action-form';
import { Card, EnumChip, PageHeader, Person, StatusChip } from '@/components/ui';
import { DISPUTE_REASON, DISPUTE_STATUS, EVIDENCE_TYPE, PAYMENT_STATUS, describe } from '@/lib/domain/enums';
import { formatSen } from '@/lib/domain/money';
import { ADMIN_LABEL, isServiceStatus, type ServiceStatus } from '@/lib/domain/service-status';
import { formatDateTime } from '@/lib/format';
import { createClient } from '@/lib/supabase/server';
import { decideDispute, markUnderReview } from '../actions';

type Params = Promise<{ id: string }>;
const UUID = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;

export const metadata = { title: 'Dispute' };

export default async function DisputePage({ params }: { params: Params }) {
  const { id } = await params;
  if (!UUID.test(id)) notFound();
  const supabase = await createClient();

  const { data: dispute } = await supabase
    .from('disputes')
    .select(
      `*,
       raiser:profiles!disputes_raised_by_fkey ( id, full_name, email, phone ),
       resolver:profiles!disputes_resolved_by_fkey ( full_name ),
       job:service_requests (
         id, reference, status, customer_id, assigned_technician_id,
         customer:profiles!service_requests_customer_id_fkey ( id, full_name, email ),
         technician:technician_profiles!service_requests_assigned_technician_id_fkey (
           id, profile:profiles!technician_profiles_id_fkey ( full_name, email ) )
       )`,
    )
    .eq('id', id)
    .maybeSingle();
  if (!dispute) notFound();

  const job = dispute.job as {
    id: string;
    reference: string;
    status: ServiceStatus;
    customer_id: string;
    assigned_technician_id: string | null;
    customer: { id: string; full_name: string; email: string } | null;
    technician: { id: string; profile: { full_name: string; email: string } | null } | null;
  };
  const raiser = dispute.raiser as { id: string; full_name: string; email: string; phone: string | null } | null;
  const open = dispute.status === 'open' || dispute.status === 'under_review';

  const [payments, evidence, outcomes] = await Promise.all([
    supabase.from('payments').select('id, status, amount_sen, paid_at').eq('request_id', job.id),
    supabase
      .from('service_evidence')
      .select('id, type, storage_path, caption, captured_at, uploader:profiles ( full_name )')
      .eq('request_id', job.id)
      .order('captured_at'),
    supabase.from('service_status_transitions').select('to_status, allowed_actors').eq('from_status', 'DISPUTED'),
  ]);

  const paidSen = (payments.data ?? [])
    .filter((p) => p.status === 'paid')
    .reduce((total, p) => total + Number(p.amount_sen), 0);

  const outcomeOptions = ((outcomes.data ?? []) as { to_status: string; allowed_actors: string[] }[])
    .filter((t) => t.allowed_actors.includes('admin') && isServiceStatus(t.to_status))
    .map((t) => t.to_status as ServiceStatus);

  const evidenceRows = (evidence.data ?? []) as unknown as {
    id: string;
    type: string;
    storage_path: string;
    caption: string | null;
    captured_at: string;
    uploader: { full_name: string } | null;
  }[];
  const signed = evidenceRows.length
    ? await supabase.storage.from('service-evidence').createSignedUrls(
        evidenceRows.map((e) => e.storage_path),
        600,
      )
    : { data: [] };

  return (
    <>
      <PageHeader
        crumbs={[
          { href: '/disputes', label: 'Disputes' },
          { href: `/jobs/${job.id}`, label: job.reference },
        ]}
        title={describe(DISPUTE_REASON, dispute.reason).label}
        description={`Raised ${formatDateTime(dispute.created_at)}`}
        actions={<EnumChip map={DISPUTE_STATUS} value={dispute.status} />}
      />

      <div className="grid split">
        <div className="stack">
          <Card title="What they said">
            <p style={{ whiteSpace: 'pre-wrap' }}>{dispute.description}</p>
          </Card>

          <Card title="Evidence" description="Everything uploaded on this job, before and after the dispute. Append-only.">
            {evidenceRows.length === 0 ? (
              <p className="muted">No photos were uploaded on this job.</p>
            ) : (
              <div className="thumbs">
                {evidenceRows.map((e, i) => {
                  const url = signed.data?.[i]?.signedUrl;
                  return (
                    <a key={e.id} href={url ?? '#'} target="_blank" rel="noreferrer">
                      {url ? <img src={url} alt={e.caption ?? describe(EVIDENCE_TYPE, e.type).label} /> : null}
                      <span>
                        {describe(EVIDENCE_TYPE, e.type).label} · {e.uploader?.full_name}
                        <br />
                        {formatDateTime(e.captured_at)}
                      </span>
                    </a>
                  );
                })}
              </div>
            )}
            <p className="muted small" style={{ marginTop: 12 }}>
              The full conversation and timeline are on the <Link href={`/jobs/${job.id}`}>job page</Link>.
            </p>
          </Card>

          {!open && (
            <Card title="Decision">
              <dl className="kv">
                <dt>Outcome</dt>
                <dd>
                  <EnumChip map={DISPUTE_STATUS} value={dispute.status} />
                </dd>
                <dt>Resolution</dt>
                <dd>{dispute.resolution}</dd>
                <dt>Refund owed</dt>
                <dd>{formatSen(dispute.refund_amount_sen)}</dd>
                <dt>Decided</dt>
                <dd>
                  {formatDateTime(dispute.resolved_at)} by {(dispute.resolver as { full_name: string } | null)?.full_name ?? '—'}
                </dd>
              </dl>
            </Card>
          )}
        </div>

        <div className="stack">
          {open && (
            <Card title="Decide">
              {dispute.status === 'open' && (
                <ActionForm action={markUnderReview} className="actions">
                  <input type="hidden" name="dispute_id" value={id} />
                  <Submit variant="secondary" small>
                    Mark under review
                  </Submit>
                  <span className="muted small">Tells them someone is looking at it.</span>
                </ActionForm>
              )}

              <hr style={{ border: 0, borderTop: '1px solid var(--hairline)', margin: '16px 0' }} />

              <ActionForm action={decideDispute} confirm="This decision is final and is sent to the person who raised the dispute. Continue?">
                <input type="hidden" name="dispute_id" value={id} />
                <label className="field">
                  Resolution
                  <span className="hint">Sent to them as written. At least 10 characters.</span>
                  <textarea name="resolution" required minLength={10} maxLength={2000} />
                </label>
                <label className="field">
                  Refund owed (RM)
                  <span className="hint">
                    Up to {formatSen(paidSen)} paid. Recorded here; the refund itself is issued by the payment
                    service.
                  </span>
                  <input type="text" name="refund" inputMode="decimal" placeholder="0.00" />
                </label>
                {job.status === 'DISPUTED' && (
                  <label className="field">
                    Then move the job to
                    <span className="hint">Required unless another dispute on this job is still open.</span>
                    <select name="request_outcome" defaultValue="">
                      <option value="">Leave it disputed</option>
                      {outcomeOptions.map((s) => (
                        <option key={s} value={s}>
                          {ADMIN_LABEL[s]}
                        </option>
                      ))}
                    </select>
                  </label>
                )}
                <div className="actions">
                  <Submit name="decision" value="resolved">
                    Uphold
                  </Submit>
                  <Submit name="decision" value="rejected" variant="secondary">
                    Not upheld
                  </Submit>
                </div>
              </ActionForm>
            </Card>
          )}

          <Card title="Job">
            <dl className="kv">
              <dt>Reference</dt>
              <dd>
                <Link href={`/jobs/${job.id}`} className="mono">
                  {job.reference}
                </Link>
              </dd>
              <dt>Status</dt>
              <dd>
                <StatusChip status={job.status} />
              </dd>
              <dt>Raised by</dt>
              <dd>
                <Person id={raiser?.id} name={raiser?.full_name} email={raiser?.email} href={`/users/${raiser?.id}`} />
              </dd>
              <dt>Customer</dt>
              <dd>
                <Person id={job.customer?.id} name={job.customer?.full_name} href={`/users/${job.customer?.id}`} />
              </dd>
              <dt>Technician</dt>
              <dd>
                <Person
                  id={job.technician?.id}
                  name={job.technician?.profile?.full_name}
                  href={`/technicians/${job.technician?.id}`}
                />
              </dd>
            </dl>
          </Card>

          <Card title="Payments">
            {(payments.data ?? []).length === 0 ? (
              <p className="muted small">Nothing has been paid on this job.</p>
            ) : (
              <dl className="kv">
                {(payments.data ?? []).map((p) => (
                  <div key={p.id} style={{ display: 'contents' }}>
                    <dt>
                      <EnumChip map={PAYMENT_STATUS} value={p.status} />
                    </dt>
                    <dd>
                      {formatSen(p.amount_sen)} <span className="muted small">{formatDateTime(p.paid_at)}</span>
                    </dd>
                  </div>
                ))}
              </dl>
            )}
          </Card>
        </div>
      </div>
    </>
  );
}
