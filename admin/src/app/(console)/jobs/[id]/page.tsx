import Link from 'next/link';
import { notFound } from 'next/navigation';
import { ActionForm, Submit } from '@/components/action-form';
import { Card, Chip, Empty, EnumChip, PageHeader, Person, StatusChip } from '@/components/ui';
import {
  ASSIGNMENT_STATUS,
  DEVICE_TYPE,
  DISPUTE_REASON,
  DISPUTE_STATUS,
  EARNING_STATUS,
  EVIDENCE_TYPE,
  MATCHING_MODE,
  PAYMENT_STATUS,
  QUOTATION_ITEM_KIND,
  QUOTATION_KIND,
  QUOTATION_STATUS,
  SERVICE_ACTOR,
  URGENCY_LEVEL,
  WARRANTY_STATUS,
  describe,
} from '@/lib/domain/enums';
import { formatSen, formatSenRange } from '@/lib/domain/money';
import { ADMIN_LABEL, CUSTOMER_LABEL, isServiceStatus, type ServiceStatus } from '@/lib/domain/service-status';
import { formatDateTime, formatRelative } from '@/lib/format';
import { createClient } from '@/lib/supabase/server';
import { transitionJob } from './actions';

type Params = Promise<{ id: string }>;


export async function generateMetadata({ params }: { params: Params }) {
  const { id } = await params;
  const supabase = await createClient();
  const { data } = await supabase.from('service_requests').select('reference').eq('id', id).maybeSingle();
  return { title: data?.reference ?? 'Job' };
}

const UUID = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;

export default async function JobPage({ params }: { params: Params }) {
  const { id } = await params;
  if (!UUID.test(id)) notFound();
  const supabase = await createClient();

  const { data: job } = await supabase
    .from('service_requests')
    .select(
      `*,
       customer:profiles!service_requests_customer_id_fkey ( id, full_name, email, phone ),
       technician:technician_profiles!service_requests_assigned_technician_id_fkey (
         id, headline, rating_average, rating_count,
         profile:profiles!technician_profiles_id_fkey ( full_name, email, phone )
       ),
       category:service_categories!service_requests_category_id_fkey ( id, name ),
       device:devices ( id, nickname, device_type, brand, model, serial_number )`,
    )
    .eq('id', id)
    .maybeSingle();

  if (!job) notFound();
  const status = job.status as ServiceStatus;
  const matching = status === 'REQUESTED' || status === 'MATCHING';

  const [
    history,
    transitions,
    answers,
    diagnoses,
    quotations,
    payments,
    earnings,
    evidence,
    messages,
    disputes,
    cancellation,
    warranty,
    review,
    offers,
    ranked,
  ] = await Promise.all([
    supabase
      .from('service_status_history')
      .select('id, from_status, to_status, actor_role, reason, created_at, actor:profiles ( full_name )')
      .eq('request_id', id)
      .order('created_at', { ascending: true }),
    supabase.from('service_status_transitions').select('to_status, allowed_actors').eq('from_status', status),
    supabase.from('service_request_items').select('question_text, answer_text').eq('request_id', id).order('sort_order'),
    supabase.from('diagnoses').select('*').eq('request_id', id).order('created_at', { ascending: false }),
    supabase
      .from('quotations')
      .select('*, items:quotation_items ( * ), approval:quotation_approvals ( decision, note, approved_at, quotation_version )')
      .eq('request_id', id)
      .order('version', { ascending: false }),
    supabase
      .from('payments')
      .select('*, items:payment_items ( * )')
      .eq('request_id', id)
      .order('created_at', { ascending: false }),
    supabase.from('technician_earnings').select('*').eq('request_id', id),
    supabase
      .from('service_evidence')
      .select('id, type, storage_path, caption, captured_at, uploader:profiles ( full_name )')
      .eq('request_id', id)
      .order('captured_at'),
    supabase
      .from('messages')
      .select('id, kind, body, attachment_path, created_at, read_at, reported_at, reported_reason, report_reviewed_at, sender_id, sender:profiles!messages_sender_id_fkey ( full_name )')
      .eq('request_id', id)
      .order('created_at', { ascending: true })
      .limit(200),
    supabase
      .from('disputes')
      .select('id, reason, status, description, created_at, refund_amount_sen')
      .eq('request_id', id)
      .order('created_at'),
    supabase.from('cancellation_records').select('*, by:profiles ( full_name )').eq('request_id', id).maybeSingle(),
    supabase.from('warranties').select('*').eq('request_id', id).maybeSingle(),
    supabase.from('reviews').select('*').eq('request_id', id).maybeSingle(),
    supabase
      .from('technician_assignments')
      .select('id, status, rank, score, distance_km, eta_minutes, offered_at, responded_at, decline_reason, technician:technician_profiles ( id, profile:profiles!technician_profiles_id_fkey ( full_name ) )')
      .eq('request_id', id)
      .order('rank'),
    matching
      ? supabase.rpc('rank_technicians', { request_id: id, max_results: 5 })
      : Promise.resolve({ data: null, error: null }),
  ]);

  const adminMoves = ((transitions.data ?? []) as { to_status: string; allowed_actors: string[] }[])
    .filter((t) => t.allowed_actors.includes('admin') && isServiceStatus(t.to_status))
    .map((t) => t.to_status as ServiceStatus);

  const evidenceRows = (evidence.data ?? []) as any[];
  const signed = evidenceRows.length
    ? await supabase.storage.from('service-evidence').createSignedUrls(
        evidenceRows.map((e) => e.storage_path),
        600,
      )
    : { data: [] as { signedUrl: string | null }[] };

  const customer = job.customer as any;
  const technician = job.technician as any;
  const device = job.device as any;

  return (
    <>
      <PageHeader
        crumbs={[{ href: '/jobs', label: 'Jobs' }]}
        title={
          <span className="mono" style={{ fontSize: 22 }}>
            {job.reference}
          </span>
        }
        description={
          <>
            {job.category?.name ?? 'Unclassified'} · requested {formatDateTime(job.requested_at)}
          </>
        }
        actions={
          <>
            <StatusChip status={status} />
            {job.urgency !== 'normal' && <EnumChip map={URGENCY_LEVEL} value={job.urgency} />}
          </>
        }
      />

      <div className="grid split">
        <div className="stack">
          <Card title="Problem" description="The customer's own words, kept verbatim.">
            <p style={{ whiteSpace: 'pre-wrap' }}>{job.problem_description}</p>
            {(job.problem_summary || answers.data?.length) && (
              <dl className="kv" style={{ marginTop: 16 }}>
                {job.problem_summary && (
                  <>
                    <dt>Classified as</dt>
                    <dd>
                      {job.problem_summary}
                      <span className="sub muted small">
                        by {job.classified_by ?? 'unknown'}
                        {job.classification_confidence !== null &&
                          ` · ${Math.round(Number(job.classification_confidence) * 100)}% confidence`}
                      </span>
                    </dd>
                  </>
                )}
                {(answers.data ?? []).map((a: any) => (
                  <Pair key={a.question_text} label={a.question_text} value={a.answer_text} />
                ))}
              </dl>
            )}
          </Card>

          <Card title="Timeline" description="Written by the database on every status change. Cannot be edited.">
            {history.data && history.data.length > 0 ? (
              <ol className="timeline">
                {(history.data as any[]).map((h) => (
                  <li key={h.id}>
                    <StatusChip status={h.to_status} />{' '}
                    <span className="muted small">
                      by {h.actor?.full_name ?? describe(SERVICE_ACTOR, h.actor_role).label}
                      {h.actor?.full_name && ` (${describe(SERVICE_ACTOR, h.actor_role).label.toLowerCase()})`}
                    </span>
                    {h.reason && <p className="small" style={{ marginTop: 4 }}>“{h.reason}”</p>}
                    <div className="when">{formatDateTime(h.created_at)}</div>
                  </li>
                ))}
              </ol>
            ) : (
              <p className="muted">No history recorded.</p>
            )}
          </Card>

          {(diagnoses.data?.length ?? 0) > 0 && (
            <Card title="Diagnosis">
              {(diagnoses.data as any[]).map((d) => (
                <dl className="kv" key={d.id}>
                  <dt>Found</dt>
                  <dd>{d.problem_found}</dd>
                  <dt>Recommended</dt>
                  <dd>{d.recommended_action}</dd>
                  {d.notes && <Pair label="Notes" value={d.notes} />}
                  <dt>Recorded</dt>
                  <dd>{formatDateTime(d.created_at)}</dd>
                </dl>
              ))}
            </Card>
          )}

          <Card
            flush
            title="Quotations"
            description="An approved quotation is immutable; extra work is a new version with its own approval."
          >
            {quotations.data && quotations.data.length > 0 ? (
              (quotations.data as any[]).map((q) => {
                const approval = Array.isArray(q.approval) ? q.approval[0] : q.approval;
                return (
                  <div key={q.id} style={{ borderTop: '1px solid var(--hairline)' }}>
                    <div className="card-head" style={{ padding: '12px 20px' }}>
                      <div className="actions">
                        <strong>Version {q.version}</strong>
                        <EnumChip map={QUOTATION_KIND} value={q.kind} plain />
                        <EnumChip map={QUOTATION_STATUS} value={q.status} />
                      </div>
                      <span className="muted small">
                        {q.submitted_at ? `Submitted ${formatDateTime(q.submitted_at)}` : 'Not submitted'}
                        {approval && ` · ${approval.decision} ${formatDateTime(approval.approved_at)}`}
                      </span>
                    </div>
                    <div className="table-wrap">
                      <table>
                        <tbody>
                          {(q.items as any[])
                            .sort((a, b) => a.sort_order - b.sort_order)
                            .map((item) => (
                              <tr key={item.id}>
                                <td>
                                  {item.description}
                                  <span className="sub">{describe(QUOTATION_ITEM_KIND, item.kind).label}</span>
                                </td>
                                <td className="num muted">
                                  {item.quantity} × {formatSen(item.unit_price_sen)}
                                </td>
                                <td className="num">{formatSen(item.amount_sen)}</td>
                              </tr>
                            ))}
                          <tr>
                            <td className="muted">Platform fee</td>
                            <td />
                            <td className="num">{formatSen(q.platform_fee_sen)}</td>
                          </tr>
                          <tr>
                            <td className="strong">Total</td>
                            <td />
                            <td className="num strong">{formatSen(q.total_sen)}</td>
                          </tr>
                        </tbody>
                      </table>
                    </div>
                  </div>
                );
              })
            ) : (
              <Empty title="No quotation yet" />
            )}
          </Card>

          <Card flush title="Payments" description="Read-only. Only the payment Edge Functions settle or refund.">
            {payments.data && payments.data.length > 0 ? (
              <div className="table-wrap">
                <table>
                  <thead>
                    <tr>
                      <th>Status</th>
                      <th>Provider</th>
                      <th className="num">Amount</th>
                      <th>Paid</th>
                      <th>Verified with provider</th>
                    </tr>
                  </thead>
                  <tbody>
                    {(payments.data as any[]).map((p) => (
                      <tr key={p.id}>
                        <td>
                          <EnumChip map={PAYMENT_STATUS} value={p.status} />
                          {p.failure_reason && <span className="sub danger-text">{p.failure_reason}</span>}
                        </td>
                        <td>
                          {p.provider}
                          {p.provider_bill_code && <span className="sub mono">{p.provider_bill_code}</span>}
                        </td>
                        <td className="num">{formatSen(p.amount_sen)}</td>
                        <td className="nowrap">{formatDateTime(p.paid_at)}</td>
                        <td className="nowrap">{formatDateTime(p.verified_at)}</td>
                      </tr>
                    ))}
                    {(earnings.data as any[] | null)?.map((e) => (
                      <tr key={e.id}>
                        <td>
                          <EnumChip map={EARNING_STATUS} value={e.status} />
                        </td>
                        <td className="muted">Technician earning</td>
                        <td className="num">{formatSen(e.net_sen)}</td>
                        <td colSpan={2} className="muted small">
                          {formatSen(e.gross_sen)} gross − {formatSen(e.commission_sen)} commission (
                          {Number(e.commission_percent)}%)
                        </td>
                      </tr>
                    ))}
                  </tbody>
                </table>
              </div>
            ) : (
              <Empty title="No payment yet" />
            )}
          </Card>

          {evidenceRows.length > 0 && (
            <Card title="Evidence" description="Append-only. Links expire after ten minutes.">
              <div className="thumbs">
                {evidenceRows.map((e, i) => {
                  const url = signed.data?.[i]?.signedUrl;
                  return (
                    <a key={e.id} href={url ?? '#'} target="_blank" rel="noreferrer">
                      {url ? <img src={url} alt={e.caption ?? describe(EVIDENCE_TYPE, e.type).label} /> : null}
                      <span>
                        {describe(EVIDENCE_TYPE, e.type).label}
                        {e.caption ? ` · ${e.caption}` : ''}
                        <br />
                        {e.uploader?.full_name} · {formatDateTime(e.captured_at)}
                      </span>
                    </a>
                  );
                })}
              </div>
            </Card>
          )}

          <Card title="Conversation" description="Visible to support so a dispute about what was said can be settled.">
            {messages.data && messages.data.length > 0 ? (
              <div className="stack" style={{ gap: 8 }}>
                {(messages.data as any[]).map((m) => (
                  <div key={m.id} className={`message${m.reported_at && !m.report_reviewed_at ? ' flagged' : ''}`}>
                    <div className="meta">
                      {m.kind === 'system' ? 'System' : m.sender?.full_name ?? 'Unknown'} ·{' '}
                      {formatDateTime(m.created_at)}
                      {m.reported_at && (
                        <>
                          {' '}
                          · <span className="danger-text">Reported: {m.reported_reason ?? 'no reason given'}</span>
                          {!m.report_reviewed_at && (
                            <>
                              {' '}
                              · <Link href="/moderation">review</Link>
                            </>
                          )}
                        </>
                      )}
                    </div>
                    {m.kind === 'image' ? <em className="muted">Image attachment</em> : m.body}
                  </div>
                ))}
              </div>
            ) : (
              <p className="muted">No messages.</p>
            )}
          </Card>
        </div>

        <div className="stack">
          <Card title="Act on this job">
            <p className="muted small" style={{ marginBottom: 12 }}>
              The customer currently sees <strong>“{CUSTOMER_LABEL[status]}”</strong>.
            </p>
            {adminMoves.length > 0 ? (
              <ActionForm
                action={transitionJob}
                confirm="This changes a live job and may notify the customer and technician. Continue?"
                resetOnSuccess
              >
                <input type="hidden" name="request_id" value={job.id} />
                <label className="field">
                  Move to
                  <select name="to_status" required defaultValue="">
                    <option value="" disabled>
                      Choose…
                    </option>
                    {adminMoves.map((s) => (
                      <option key={s} value={s}>
                        {ADMIN_LABEL[s]}
                        {s === 'MATCHING' ? ' (release technician)' : ''}
                      </option>
                    ))}
                  </select>
                </label>
                <label className="field">
                  Reason
                  <span className="hint">Shown on the job timeline and in any notification.</span>
                  <textarea name="reason" required minLength={5} maxLength={500} />
                </label>
                <Submit variant="secondary">Apply</Submit>
              </ActionForm>
            ) : (
              <p className="muted small">
                No administrator moves are possible from “{ADMIN_LABEL[status]}”. The transition table decides
                this, not the console.
              </p>
            )}
          </Card>

          <Card title="People">
            <dl className="kv">
              <dt>Customer</dt>
              <dd>
                <Person id={customer?.id} name={customer?.full_name} email={customer?.email} href={`/users/${customer?.id}`} />
              </dd>
              <dt>Contact</dt>
              <dd>{job.contact_phone ?? customer?.phone ?? '—'}</dd>
              <dt>Technician</dt>
              <dd>
                {technician ? (
                  <>
                    <Person
                      id={technician.id}
                      name={technician.profile?.full_name}
                      email={technician.profile?.email}
                      href={`/technicians/${technician.id}`}
                    />
                    <span className="sub muted small">
                      ★ {Number(technician.rating_average).toFixed(2)} ({technician.rating_count})
                    </span>
                  </>
                ) : (
                  <span className="faint">Not assigned</span>
                )}
              </dd>
              <dt>Matching</dt>
              <dd>{describe(MATCHING_MODE, job.matching_mode).label}</dd>
            </dl>
          </Card>

          <Card title="Location">
            <dl className="kv">
              <dt>Address</dt>
              <dd>{job.service_address}</dd>
              {job.address_directions && <Pair label="Directions" value={job.address_directions} />}
              <dt>Coordinates</dt>
              <dd>
                <a
                  href={`https://www.google.com/maps?q=${job.service_latitude},${job.service_longitude}`}
                  target="_blank"
                  rel="noreferrer"
                  className="mono"
                >
                  {Number(job.service_latitude).toFixed(5)}, {Number(job.service_longitude).toFixed(5)}
                </a>
              </dd>
              <dt>Arrival code</dt>
              <dd>
                {job.arrival_code_verified_at ? (
                  <Chip tone="success" label={`Verified ${formatRelative(job.arrival_code_verified_at)}`} />
                ) : (
                  <span className="muted">Not yet verified</span>
                )}
              </dd>
            </dl>
          </Card>

          <Card title="Estimate and device">
            <dl className="kv">
              <dt>Estimate</dt>
              <dd>{formatSenRange(job.estimated_total_min_sen, job.estimated_total_max_sen)}</dd>
              {job.estimated_distance_km !== null && (
                <Pair label="Distance" value={`${Number(job.estimated_distance_km).toFixed(1)} km`} />
              )}
              <dt>Device</dt>
              <dd>
                {device ? (
                  <>
                    {device.nickname}
                    <span className="sub muted small">
                      {describe(DEVICE_TYPE, device.device_type).label}
                      {device.brand && ` · ${device.brand} ${device.model ?? ''}`}
                      {device.serial_number && ` · S/N ${device.serial_number}`}
                    </span>
                  </>
                ) : (
                  '—'
                )}
              </dd>
            </dl>
          </Card>

          {(disputes.data?.length ?? 0) > 0 && (
            <Card title="Disputes">
              <div className="stack" style={{ gap: 10 }}>
                {(disputes.data as any[]).map((d) => (
                  <Link key={d.id} href={`/disputes/${d.id}`} style={{ color: 'inherit' }}>
                    <div className="actions">
                      <EnumChip map={DISPUTE_STATUS} value={d.status} />
                      <span className="strong">{describe(DISPUTE_REASON, d.reason).label}</span>
                    </div>
                    <p className="muted small clamp">{d.description}</p>
                  </Link>
                ))}
              </div>
            </Card>
          )}

          {cancellation.data && (
            <Card title="Cancellation">
              <dl className="kv">
                <dt>By</dt>
                <dd>
                  {(cancellation.data as any).by?.full_name ?? '—'} (
                  {describe(SERVICE_ACTOR, cancellation.data.cancelled_by_role).label.toLowerCase()})
                </dd>
                <dt>At stage</dt>
                <dd>{ADMIN_LABEL[cancellation.data.status_at_cancellation as ServiceStatus]}</dd>
                <dt>Reason</dt>
                <dd>{cancellation.data.reason}</dd>
                <dt>Fee</dt>
                <dd>
                  {formatSen(cancellation.data.fee_sen)}
                  {cancellation.data.fee_waived && ' (waived)'}
                </dd>
              </dl>
            </Card>
          )}

          {warranty.data && (
            <Card title="Warranty">
              <dl className="kv">
                <dt>Status</dt>
                <dd>
                  <EnumChip map={WARRANTY_STATUS} value={warranty.data.status} />
                </dd>
                <dt>Covers</dt>
                <dd>{warranty.data.covered_work}</dd>
                <dt>Expires</dt>
                <dd>
                  {formatDateTime(warranty.data.expires_at)} ({warranty.data.days} days)
                </dd>
              </dl>
            </Card>
          )}

          {review.data && (
            <Card title="Review" actions={<Link href="/moderation?tab=reviews">Moderate</Link>}>
              <p className="strong">{'★'.repeat(review.data.rating_overall)}{'☆'.repeat(5 - review.data.rating_overall)}</p>
              {review.data.comment && <p style={{ marginTop: 6 }}>{review.data.comment}</p>}
            </Card>
          )}

          {(offers.data?.length ?? 0) > 0 && (
            <Card title="Offer ledger" description="Scores are internal and never shown to customers or technicians.">
              <div className="stack" style={{ gap: 8 }}>
                {(offers.data as any[]).map((o) => (
                  <div key={o.id} className="small">
                    <div className="actions">
                      <span className="strong">#{o.rank}</span>
                      <Link href={`/technicians/${o.technician?.id}`}>{o.technician?.profile?.full_name}</Link>
                      <EnumChip map={ASSIGNMENT_STATUS} value={o.status} />
                    </div>
                    <span className="muted">
                      score {o.score ?? '—'} · {o.distance_km ?? '—'} km · offered {formatRelative(o.offered_at)}
                      {o.decline_reason && ` · ${o.decline_reason}`}
                    </span>
                  </div>
                ))}
              </div>
            </Card>
          )}

          {matching && (
            <Card title="Who matches now" description="Live ranking from rank_technicians(), the same function matching uses.">
              {ranked.error ? (
                <p className="muted small">The ranking could not be computed for this job.</p>
              ) : ranked.data && (ranked.data as any[]).length > 0 ? (
                <div className="stack" style={{ gap: 8 }}>
                  {(ranked.data as any[]).map((r, i) => (
                    <div key={r.technician_id} className="small">
                      <span className="strong">{i + 1}. </span>
                      <Link href={`/technicians/${r.technician_id}`}>{r.full_name}</Link>
                      <span className="sub muted">
                        score {Number(r.score).toFixed(1)} · {Number(r.distance_km).toFixed(1)} km · ★{' '}
                        {Number(r.rating_average).toFixed(2)}
                      </span>
                    </div>
                  ))}
                </div>
              ) : (
                <p className="muted small">
                  No available, verified technician covers this location for this category.
                </p>
              )}
            </Card>
          )}
        </div>
      </div>
    </>
  );
}

function Pair({ label, value }: { label: string; value: string }) {
  return (
    <>
      <dt>{label}</dt>
      <dd>{value}</dd>
    </>
  );
}
