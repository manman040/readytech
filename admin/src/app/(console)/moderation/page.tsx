import Link from 'next/link';
import type { Metadata } from 'next';
import { ActionForm, Submit } from '@/components/action-form';
import { Card, Empty, firstParam, LoadError, PageHeader, Tabs } from '@/components/ui';
import { report } from '@/lib/errors';
import { formatDateTime, formatRelative } from '@/lib/format';
import { createClient } from '@/lib/supabase/server';
import { removeReview, reviewReport } from './actions';

export const metadata: Metadata = { title: 'Moderation' };

type Reported = {
  id: string;
  kind: string;
  body: string | null;
  created_at: string;
  reported_at: string;
  reported_reason: string | null;
  sender: { full_name: string } | null;
  job: { id: string; reference: string } | null;
};

type Review = {
  id: string;
  rating_overall: number;
  comment: string | null;
  created_at: string;
  customer: { full_name: string } | null;
  technician: { id: string; profile: { full_name: string } | null } | null;
  job: { id: string; reference: string } | null;
};

export default async function ModerationPage({
  searchParams,
}: {
  searchParams: Promise<Record<string, string | string[] | undefined>>;
}) {
  const tab = firstParam((await searchParams).tab) === 'reviews' ? 'reviews' : 'messages';
  const supabase = await createClient();

  return (
    <>
      <PageHeader
        title="Moderation"
        description="Reported messages and published reviews. Nothing is erased silently: the original is always kept in the audit log."
      />
      <Tabs
        current={tab}
        items={[
          { key: 'messages', label: 'Reported messages', href: '/moderation' },
          { key: 'reviews', label: 'Reviews', href: '/moderation?tab=reviews' },
        ]}
      />
      {tab === 'messages' ? <ReportedMessages supabase={supabase} /> : <Reviews supabase={supabase} />}
    </>
  );
}

async function ReportedMessages({ supabase }: { supabase: Awaited<ReturnType<typeof createClient>> }) {
  const { data, error } = await supabase
    .from('messages')
    .select(
      `id, kind, body, created_at, reported_at, reported_reason,
       sender:profiles!messages_sender_id_fkey ( full_name ),
       job:service_requests ( id, reference )`,
    )
    .not('reported_at', 'is', null)
    .is('report_reviewed_at', null)
    .order('reported_at', { ascending: true })
    .limit(50);
  const rows = (data ?? []) as unknown as Reported[];

  if (error) return <LoadError message={report('reported messages', error)} />;
  if (rows.length === 0) {
    return (
      <Card>
        <Empty title="No reports waiting">Messages a customer or technician reports from the app appear here.</Empty>
      </Card>
    );
  }

  return (
    <>
      {rows.map((m) => (
        <Card
          key={m.id}
          title={
            <>
              {m.sender?.full_name ?? 'Unknown sender'} on{' '}
              <Link href={`/jobs/${m.job?.id}`} className="mono">
                {m.job?.reference}
              </Link>
            </>
          }
          description={`Reported ${formatRelative(m.reported_at)}: ${m.reported_reason ?? 'no reason given'}`}
        >
          <div className="grid two">
            <div>
              <div className="message flagged">
                <div className="meta">Sent {formatDateTime(m.created_at)}</div>
                {m.kind === 'image' ? <em className="muted">Image attachment</em> : m.body}
              </div>
              <p className="muted small" style={{ marginTop: 8 }}>
                Read it in context on the <Link href={`/jobs/${m.job?.id}`}>job page</Link> before deciding.
              </p>
            </div>
            <ActionForm action={reviewReport}>
              <input type="hidden" name="message_id" value={m.id} />
              <label className="field">
                Reason
                <span className="hint">Required to remove. Kept in the audit log.</span>
                <textarea name="reason" maxLength={500} />
              </label>
              <div className="actions">
                <Submit name="outcome" value="dismiss" variant="secondary">
                  Dismiss report
                </Submit>
                <Submit name="outcome" value="redact" variant="danger">
                  Remove message
                </Submit>
              </div>
            </ActionForm>
          </div>
        </Card>
      ))}
    </>
  );
}

async function Reviews({ supabase }: { supabase: Awaited<ReturnType<typeof createClient>> }) {
  const { data, error } = await supabase
    .from('reviews')
    .select(
      `id, rating_overall, comment, created_at,
       customer:profiles ( full_name ),
       technician:technician_profiles ( id, profile:profiles!technician_profiles_id_fkey ( full_name ) ),
       job:service_requests ( id, reference )`,
    )
    .order('created_at', { ascending: false })
    .limit(50);
  const rows = (data ?? []) as unknown as Review[];

  if (error) return <LoadError message={report('reviews', error)} />;

  return (
    <Card flush title="Published reviews" description="Removing a review recalculates the technician's rating, which feeds matching. Use it for abuse or personal information, not for a low score.">
      {rows.length === 0 ? (
        <Empty title="No reviews yet" />
      ) : (
        <div className="table-wrap">
          <table>
            <thead>
              <tr>
                <th>Rating</th>
                <th>Comment</th>
                <th>For</th>
                <th>Job</th>
                <th>Remove</th>
              </tr>
            </thead>
            <tbody>
              {rows.map((r) => (
                <tr key={r.id}>
                  <td className="nowrap">
                    <span className="strong">{'★'.repeat(r.rating_overall)}</span>
                    <span className="faint">{'★'.repeat(5 - r.rating_overall)}</span>
                    <span className="sub">{formatRelative(r.created_at)}</span>
                  </td>
                  <td>
                    <span className="clamp">{r.comment ?? <span className="faint">No comment</span>}</span>
                    <span className="sub">by {r.customer?.full_name}</span>
                  </td>
                  <td>
                    <Link href={`/technicians/${r.technician?.id}`}>{r.technician?.profile?.full_name}</Link>
                  </td>
                  <td>
                    <Link href={`/jobs/${r.job?.id}`} className="mono">
                      {r.job?.reference}
                    </Link>
                  </td>
                  <td style={{ minWidth: 240 }}>
                    <ActionForm action={removeReview} confirm="Remove this review? The technician's rating will change.">
                      <input type="hidden" name="review_id" value={r.id} />
                      <input type="text" name="reason" placeholder="Reason" required minLength={5} />
                      <Submit variant="danger" small>
                        Remove
                      </Submit>
                    </ActionForm>
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      )}
    </Card>
  );
}
