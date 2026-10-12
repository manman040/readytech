import Link from 'next/link';
import { notFound } from 'next/navigation';
import { ActionForm, Submit } from '@/components/action-form';
import { DocumentReview } from '@/components/document-review';
import { Card, Chip, Empty, EnumChip, PageHeader, StatusChip } from '@/components/ui';
import { humanise, VERIFICATION_STATUS } from '@/lib/domain/enums';
import { formatSen } from '@/lib/domain/money';
import { isActive, type ServiceStatus } from '@/lib/domain/service-status';
import { formatDate, formatDateTime, formatRelative } from '@/lib/format';
import { createClient } from '@/lib/supabase/server';
import { setTechnicianStatus } from '../actions';

type Params = Promise<{ id: string }>;
const UUID = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;

export async function generateMetadata({ params }: { params: Params }) {
  const { id } = await params;
  if (!UUID.test(id)) return { title: 'Technician' };
  const supabase = await createClient();
  const { data } = await supabase.from('profiles').select('full_name').eq('id', id).maybeSingle();
  return { title: data?.full_name || 'Technician' };
}

export default async function TechnicianPage({ params }: { params: Params }) {
  const { id } = await params;
  if (!UUID.test(id)) notFound();
  const supabase = await createClient();

  const { data: tech } = await supabase
    .from('technician_profiles')
    .select('*, profile:profiles!technician_profiles_id_fkey ( full_name, email, phone, created_at )')
    .eq('id', id)
    .maybeSingle();
  if (!tech) notFound();

  const [skills, docs, jobs, reviews, earnings, location, role] = await Promise.all([
    supabase
      .from('technician_skills')
      .select('id, proficiency, is_primary, category:service_categories ( name )')
      .eq('technician_id', id)
      .order('proficiency', { ascending: false }),
    supabase
      .from('technician_verifications')
      .select('id, document_type, storage_path, status, created_at, reviewed_at, reviewer_notes')
      .eq('technician_id', id)
      .order('created_at', { ascending: false }),
    supabase
      .from('service_requests')
      .select('id, reference, status, requested_at, category:service_categories!service_requests_category_id_fkey ( name )')
      .eq('assigned_technician_id', id)
      .order('requested_at', { ascending: false })
      .limit(15),
    supabase
      .from('reviews')
      .select('id, rating_overall, comment, created_at, request_id')
      .eq('technician_id', id)
      .order('created_at', { ascending: false })
      .limit(5),
    supabase.from('technician_earnings').select('net_sen, status').eq('technician_id', id),
    supabase.from('technician_locations').select('latitude, longitude, updated_at').eq('technician_id', id).maybeSingle(),
    supabase.from('user_roles').select('role').eq('user_id', id).maybeSingle(),
  ]);

  const docRows = (docs.data ?? []) as {
    id: string;
    document_type: string;
    storage_path: string;
    status: string;
    created_at: string;
    reviewed_at: string | null;
    reviewer_notes: string | null;
  }[];
  const signed = docRows.length
    ? await supabase.storage.from('technician-documents').createSignedUrls(
        docRows.map((d) => d.storage_path),
        600,
      )
    : { data: [] };

  const profile = tech.profile as { full_name: string; email: string; phone: string | null; created_at: string } | null;
  const status = tech.verification_status as string;
  const jobRows = (jobs.data ?? []) as unknown as {
    id: string;
    reference: string;
    status: ServiceStatus;
    requested_at: string;
    category: { name: string } | null;
  }[];
  const liveJob = jobRows.find((j) => isActive(j.status));
  const earned = (earnings.data ?? []) as { net_sen: number; status: string }[];
  const sum = (s: string) => earned.filter((e) => e.status === s).reduce((t, e) => t + Number(e.net_sen), 0);
  const isTechnicianRole = role.data?.role === 'technician';

  return (
    <>
      <PageHeader
        crumbs={[{ href: '/technicians', label: 'Technicians' }]}
        title={profile?.full_name || 'Unnamed technician'}
        description={tech.headline || profile?.email}
        actions={
          <>
            <EnumChip map={VERIFICATION_STATUS} value={status} />
            {status === 'approved' &&
              (tech.is_available ? <Chip tone="live" label="Available" /> : <Chip tone="neutral" label="Offline" plain />)}
          </>
        }
      />

      {!isTechnicianRole && (
        <div className="notice warn">
          This account is no longer a technician (role: {role.data?.role ?? 'unknown'}). The profile is kept because
          past jobs, reviews and earnings refer to it.
        </div>
      )}

      <div className="grid split">
        <div className="stack">
          <Card title="Verification documents" description="Private files. Links expire after ten minutes.">
            {docRows.length === 0 ? (
              <Empty title="No documents submitted">
                {status === 'unsubmitted'
                  ? 'This technician registered but has not uploaded anything. You can still decide on them below.'
                  : null}
              </Empty>
            ) : (
              <div className="stack">
                {docRows.map((doc, i) => {
                  const url = signed.data?.[i]?.signedUrl;
                  return (
                    <div key={doc.id} className="grid two" style={{ borderTop: i ? '1px solid var(--hairline)' : 0, paddingTop: i ? 16 : 0 }}>
                      <div>
                        <div className="actions" style={{ marginBottom: 8 }}>
                          <strong>{humanise(doc.document_type)}</strong>
                          <EnumChip map={VERIFICATION_STATUS} value={doc.status} />
                        </div>
                        {url ? (
                          <a href={url} target="_blank" rel="noreferrer">
                            Open file
                          </a>
                        ) : (
                          <span className="muted small">File missing from storage</span>
                        )}
                        <p className="muted small" style={{ marginTop: 6 }}>
                          Submitted {formatDateTime(doc.created_at)}
                          {doc.reviewed_at && ` · reviewed ${formatDateTime(doc.reviewed_at)}`}
                        </p>
                        {doc.reviewer_notes && <p className="small">“{doc.reviewer_notes}”</p>}
                      </div>
                      <div>{doc.status === 'pending' && <DocumentReview verificationId={doc.id} />}</div>
                    </div>
                  );
                })}
              </div>
            )}
          </Card>

          <Card flush title="Recent jobs">
            {jobRows.length === 0 ? (
              <Empty title="No jobs yet" />
            ) : (
              <div className="table-wrap">
                <table>
                  <tbody>
                    {jobRows.map((j) => (
                      <tr key={j.id}>
                        <td>
                          <Link href={`/jobs/${j.id}`} className="mono strong">
                            {j.reference}
                          </Link>
                          <span className="sub">{j.category?.name}</span>
                        </td>
                        <td>
                          <StatusChip status={j.status} />
                        </td>
                        <td className="muted nowrap">{formatRelative(j.requested_at)}</td>
                      </tr>
                    ))}
                  </tbody>
                </table>
              </div>
            )}
          </Card>

          <Card title="Latest reviews">
            {(reviews.data ?? []).length === 0 ? (
              <p className="muted">No reviews yet.</p>
            ) : (
              <div className="stack" style={{ gap: 12 }}>
                {(reviews.data ?? []).map((r) => (
                  <div key={r.id}>
                    <span className="strong">{'★'.repeat(r.rating_overall)}</span>
                    <span className="faint">{'★'.repeat(5 - r.rating_overall)}</span>{' '}
                    <span className="muted small">{formatDate(r.created_at)}</span>
                    {r.comment && <p className="small">{r.comment}</p>}
                  </div>
                ))}
              </div>
            )}
          </Card>
        </div>

        <div className="stack">
          <Card title="Decision">
            {liveJob && (
              <div className="notice warn" style={{ marginBottom: 12 }}>
                Holds live job <Link href={`/jobs/${liveJob.id}`}>{liveJob.reference}</Link>. Suspending stops new
                offers; it does not take them off this job.
              </div>
            )}
            {status === 'suspended' && tech.suspended_reason && (
              <p className="small" style={{ marginBottom: 12 }}>
                Suspended: “{tech.suspended_reason}”
              </p>
            )}
            <ActionForm
              action={setTechnicianStatus}
              confirm="The technician will be notified of this decision. Continue?"
              resetOnSuccess
            >
              <input type="hidden" name="technician_id" value={id} />
              <label className="field">
                Reason
                <span className="hint">Required to reject or suspend. The technician sees it.</span>
                <textarea name="reason" maxLength={500} />
              </label>
              <div className="actions">
                {status !== 'approved' && (
                  <Submit name="new_status" value="approved">
                    {status === 'suspended' ? 'Reinstate' : 'Approve'}
                  </Submit>
                )}
                {(status === 'unsubmitted' || status === 'pending') && (
                  <Submit name="new_status" value="rejected" variant="secondary">
                    Reject
                  </Submit>
                )}
                {status !== 'suspended' && (
                  <Submit name="new_status" value="suspended" variant="danger">
                    Suspend
                  </Submit>
                )}
              </div>
            </ActionForm>
          </Card>

          <Card title="Profile">
            <dl className="kv">
              <dt>Email</dt>
              <dd>{profile?.email}</dd>
              <dt>Phone</dt>
              <dd>{profile?.phone ?? '—'}</dd>
              <dt>Experience</dt>
              <dd>{tech.years_experience} years</dd>
              <dt>Service radius</dt>
              <dd>{tech.service_radius_km} km</dd>
              <dt>Emergencies</dt>
              <dd>{tech.accepts_emergency ? 'Accepts' : 'Does not accept'}</dd>
              <dt>Base</dt>
              <dd>
                {tech.base_latitude !== null ? (
                  <a
                    className="mono"
                    target="_blank"
                    rel="noreferrer"
                    href={`https://www.google.com/maps?q=${tech.base_latitude},${tech.base_longitude}`}
                  >
                    {Number(tech.base_latitude).toFixed(4)}, {Number(tech.base_longitude).toFixed(4)}
                  </a>
                ) : (
                  'Not set'
                )}
              </dd>
              <dt>Last position</dt>
              <dd>{location.data ? formatRelative(location.data.updated_at) : '—'}</dd>
              <dt>Verified</dt>
              <dd>{formatDate(tech.verified_at)}</dd>
              <dt>Joined</dt>
              <dd>{formatDate(profile?.created_at)}</dd>
            </dl>
            {tech.bio && (
              <p className="small muted" style={{ marginTop: 12 }}>
                {tech.bio}
              </p>
            )}
          </Card>

          <Card title="Reputation" description="Maintained by triggers. Never edited by hand.">
            <dl className="kv">
              <dt>Rating</dt>
              <dd>
                ★ {Number(tech.rating_average).toFixed(2)} from {tech.rating_count}
              </dd>
              <dt>Completed</dt>
              <dd>{tech.completed_jobs}</dd>
              <dt>Cancelled</dt>
              <dd>{tech.cancelled_jobs}</dd>
              <dt>Offers accepted</dt>
              <dd>
                {tech.offers_accepted} of {tech.offers_received}
              </dd>
              <dt>Earnings released</dt>
              <dd>{formatSen(sum('released'))}</dd>
              <dt>Pending release</dt>
              <dd>{formatSen(sum('pending'))}</dd>
            </dl>
          </Card>

          <Card title="Specialisms">
            {(skills.data ?? []).length === 0 ? (
              <p className="muted small">None listed yet.</p>
            ) : (
              <div className="stack" style={{ gap: 6 }}>
                {(skills.data as unknown as { id: string; proficiency: number; is_primary: boolean; category: { name: string } | null }[]).map(
                  (s) => (
                    <div key={s.id} className="actions small">
                      <span>{s.category?.name}</span>
                      <span className="faint">{'●'.repeat(s.proficiency)}{'○'.repeat(5 - s.proficiency)}</span>
                      {s.is_primary && <Chip tone="info" label="Primary" plain />}
                    </div>
                  ),
                )}
              </div>
            )}
          </Card>
        </div>
      </div>
    </>
  );
}
