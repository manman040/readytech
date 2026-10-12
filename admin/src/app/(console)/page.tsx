import Link from 'next/link';
import { Card, Empty, LoadError, PageHeader, Person, Stat, StatusChip } from '@/components/ui';
import { formatRelative } from '@/lib/format';
import { formatSen } from '@/lib/domain/money';
import { ADMIN_LABEL, SERVICE_STATUSES, STATUS_TONE } from '@/lib/domain/service-status';
import { JOB_LIST_SELECT, type JobListRow } from '@/lib/queries';
import { getDashboardStats } from '@/lib/stats';
import { createClient } from '@/lib/supabase/server';

const TONE_COLOUR: Record<string, string> = {
  info: 'var(--blue-50)',
  live: 'var(--teal-50)',
  warning: 'var(--amber-50)',
  success: 'var(--green-50)',
  danger: 'var(--red-50)',
  neutral: 'var(--slate-40)',
};

export default async function OverviewPage() {
  const stats = await getDashboardStats();
  const supabase = await createClient();

  const [{ data: recent }, { data: queue }] = await Promise.all([
    supabase
      .from('service_requests')
      .select(JOB_LIST_SELECT)
      .order('created_at', { ascending: false })
      .limit(8),
    supabase
      .from('technician_verifications')
      .select('id, document_type, created_at, technician_id, technician:technician_profiles ( profile:profiles!technician_profiles_id_fkey ( full_name ) )')
      .eq('status', 'pending')
      .order('created_at', { ascending: true })
      .limit(5),
  ]);

  if (!stats) {
    return (
      <>
        <PageHeader title="Overview" />
        <LoadError message="The marketplace figures could not be loaded. Check that the database is reachable and migrations are applied." />
      </>
    );
  }

  const byStatus = SERVICE_STATUSES.map((status) => ({
    status,
    count: stats.jobs_by_status[status] ?? 0,
  })).filter((row) => row.count > 0);
  const maxCount = Math.max(1, ...byStatus.map((row) => row.count));

  return (
    <>
      <PageHeader title="Overview" description="The marketplace right now, and what is waiting for an administrator." />

      <div className="stats">
        <Stat
          label="Documents to review"
          value={stats.documents_pending}
          hint={`${stats.technicians_awaiting_review} technician(s) waiting`}
          href="/verifications"
          attention={stats.documents_pending > 0}
        />
        <Stat
          label="Open disputes"
          value={stats.disputes_open}
          href="/disputes"
          attention={stats.disputes_open > 0}
        />
        <Stat
          label="Reported messages"
          value={stats.messages_reported}
          href="/moderation"
          attention={stats.messages_reported > 0}
        />
        <Stat
          label="Jobs still matching"
          value={stats.jobs_matching}
          hint="Requested, no technician yet"
          href="/jobs?group=matching"
        />
      </div>

      <div className="stats">
        <Stat label="Active jobs" value={stats.jobs_active} href="/jobs?group=active" />
        <Stat
          label="Completed, last 30 days"
          value={stats.jobs_completed_30d}
          hint={`${stats.jobs_cancelled_30d} cancelled`}
        />
        <Stat label="Paid, last 30 days" value={formatSen(stats.gross_paid_sen_30d)} href="/finance" />
        <Stat
          label="Technicians available"
          value={stats.technicians_available}
          hint={`of ${stats.technicians_approved} verified`}
          href="/technicians"
        />
        <Stat label="Customers" value={stats.customers} href="/users?role=customer" />
        <Stat
          label="Average rating"
          value={Number(stats.average_rating).toFixed(2)}
          hint="Across all reviews"
        />
      </div>

      <div className="grid split">
        <Card flush title="Latest jobs" actions={<Link href="/jobs">All jobs</Link>}>
          {recent && recent.length > 0 ? (
            <div className="table-wrap">
              <table>
                <thead>
                  <tr>
                    <th>Job</th>
                    <th>Status</th>
                    <th>Customer</th>
                    <th>Technician</th>
                    <th>Requested</th>
                  </tr>
                </thead>
                <tbody>
                  {(recent as unknown as JobListRow[]).map((job) => (
                    <tr key={job.id}>
                      <td>
                        <Link href={`/jobs/${job.id}`} className="mono strong">
                          {job.reference}
                        </Link>
                        <span className="sub">{job.category?.name ?? 'Unclassified'}</span>
                      </td>
                      <td>
                        <StatusChip status={job.status} />
                      </td>
                      <td>
                        <Person id={job.customer?.id} name={job.customer?.full_name} href={`/users/${job.customer?.id}`} />
                      </td>
                      <td>
                        <Person
                          id={job.technician?.id}
                          name={job.technician?.profile?.full_name}
                          href={`/technicians/${job.technician?.id}`}
                        />
                      </td>
                      <td className="nowrap muted">{formatRelative(job.created_at)}</td>
                    </tr>
                  ))}
                </tbody>
              </table>
            </div>
          ) : (
            <Empty title="No jobs yet">Requests from the app appear here.</Empty>
          )}
        </Card>

        <div className="stack">
          <Card title="Jobs by status" description={`${stats.jobs_total} jobs in total`}>
            {byStatus.length === 0 ? (
              <p className="muted">No jobs yet.</p>
            ) : (
              <div className="stack" style={{ gap: 8 }}>
                {byStatus.map(({ status, count }) => (
                  <Link key={status} href={`/jobs?status=${status}`} className="bar-row" style={{ color: 'inherit' }}>
                    <span>{ADMIN_LABEL[status]}</span>
                    <span className="bar">
                      <span
                        style={{
                          width: `${(count / maxCount) * 100}%`,
                          background: TONE_COLOUR[STATUS_TONE[status]],
                        }}
                      />
                    </span>
                    <span className="num">{count}</span>
                  </Link>
                ))}
              </div>
            )}
          </Card>

          <Card title="Oldest documents waiting" actions={<Link href="/verifications">Queue</Link>}>
            {queue && queue.length > 0 ? (
              <ul className="timeline">
                {queue.map((doc) => {
                  const row = doc as unknown as {
                    id: string;
                    document_type: string;
                    created_at: string;
                    technician_id: string;
                    technician: { profile: { full_name: string } | null } | null;
                  };
                  return (
                    <li key={row.id}>
                      <Link href={`/technicians/${row.technician_id}`}>
                        {row.technician?.profile?.full_name || 'Technician'}
                      </Link>{' '}
                      <span className="muted">· {row.document_type.replace(/_/g, ' ')}</span>
                      <div className="when">Submitted {formatRelative(row.created_at)}</div>
                    </li>
                  );
                })}
              </ul>
            ) : (
              <p className="muted">Nothing waiting. Every submitted document has been reviewed.</p>
            )}
          </Card>

          <Card title="Money" description="Read-only. Settlement and payouts run in the payment Edge Functions.">
            <dl className="kv">
              <dt>Paid, all time</dt>
              <dd className="strong">{formatSen(stats.gross_paid_sen_total)}</dd>
              <dt>Commission earned</dt>
              <dd>{formatSen(stats.commission_sen_total)}</dd>
              <dt>Owed to technicians</dt>
              <dd>{formatSen(stats.earnings_pending_sen)}</dd>
              <dt>Awaiting payment</dt>
              <dd>{stats.jobs_payment_pending} job(s)</dd>
            </dl>
          </Card>
        </div>
      </div>
    </>
  );
}
