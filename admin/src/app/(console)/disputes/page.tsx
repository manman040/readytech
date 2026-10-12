import Link from 'next/link';
import type { Metadata } from 'next';
import { Card, Empty, EnumChip, firstParam, LoadError, PageHeader, Person, StatusChip, Tabs } from '@/components/ui';
import { DISPUTE_REASON, DISPUTE_STATUS } from '@/lib/domain/enums';
import { formatSen } from '@/lib/domain/money';
import { report } from '@/lib/errors';
import { formatDateTime, formatRelative } from '@/lib/format';
import { createClient } from '@/lib/supabase/server';

export const metadata: Metadata = { title: 'Disputes' };

type Row = {
  id: string;
  reason: string;
  status: string;
  description: string;
  created_at: string;
  resolved_at: string | null;
  refund_amount_sen: number;
  job: { id: string; reference: string; status: string } | null;
  raiser: { id: string; full_name: string; email: string } | null;
};

export default async function DisputesPage({
  searchParams,
}: {
  searchParams: Promise<Record<string, string | string[] | undefined>>;
}) {
  const tab = firstParam((await searchParams).tab) === 'closed' ? 'closed' : 'open';
  const supabase = await createClient();

  const { data, error } = await supabase
    .from('disputes')
    .select(
      `id, reason, status, description, created_at, resolved_at, refund_amount_sen,
       job:service_requests ( id, reference, status ),
       raiser:profiles!disputes_raised_by_fkey ( id, full_name, email )`,
    )
    .in('status', tab === 'open' ? ['open', 'under_review'] : ['resolved', 'rejected'])
    .order('created_at', { ascending: tab === 'open' })
    .limit(100);

  const rows = (data ?? []) as unknown as Row[];

  return (
    <>
      <PageHeader
        title="Disputes"
        description="Oldest first. A dispute reopens the job's conversation for as long as it is open."
      />
      <Tabs
        current={tab}
        items={[
          { key: 'open', label: 'Open', href: '/disputes' },
          { key: 'closed', label: 'Decided', href: '/disputes?tab=closed' },
        ]}
      />
      {error && <LoadError message={report('disputes', error)} />}
      <Card flush>
        {rows.length === 0 ? (
          <Empty title={tab === 'open' ? 'No open disputes' : 'No decided disputes yet'} />
        ) : (
          <div className="table-wrap">
            <table>
              <thead>
                <tr>
                  <th>Dispute</th>
                  <th>Status</th>
                  <th>Job</th>
                  <th>Raised by</th>
                  <th className="num">Refund</th>
                  <th>{tab === 'open' ? 'Raised' : 'Decided'}</th>
                </tr>
              </thead>
              <tbody>
                {rows.map((d) => (
                  <tr key={d.id}>
                    <td>
                      <Link href={`/disputes/${d.id}`} className="strong">
                        {DISPUTE_REASON[d.reason as keyof typeof DISPUTE_REASON]?.label ?? d.reason}
                      </Link>
                      <span className="sub clamp">{d.description}</span>
                    </td>
                    <td>
                      <EnumChip map={DISPUTE_STATUS} value={d.status} />
                    </td>
                    <td className="nowrap">
                      {d.job && (
                        <>
                          <Link href={`/jobs/${d.job.id}`} className="mono">
                            {d.job.reference}
                          </Link>
                          <span className="sub">
                            <StatusChip status={d.job.status} />
                          </span>
                        </>
                      )}
                    </td>
                    <td>
                      <Person id={d.raiser?.id} name={d.raiser?.full_name} email={d.raiser?.email} href={`/users/${d.raiser?.id}`} />
                    </td>
                    <td className="num">{d.refund_amount_sen ? formatSen(d.refund_amount_sen) : '—'}</td>
                    <td className="nowrap muted" title={formatDateTime(d.resolved_at ?? d.created_at)}>
                      {formatRelative(tab === 'open' ? d.created_at : d.resolved_at)}
                    </td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        )}
      </Card>
    </>
  );
}
