import Link from 'next/link';
import type { Metadata } from 'next';
import { Card, Empty, EnumChip, firstParam, LoadError, PageHeader, pageParam, Pager, Stat, Tabs } from '@/components/ui';
import { EARNING_STATUS, PAYMENT_PROVIDER, PAYMENT_STATUS } from '@/lib/domain/enums';
import { formatSen } from '@/lib/domain/money';
import { report } from '@/lib/errors';
import { formatDateTime } from '@/lib/format';
import { getDashboardStats } from '@/lib/stats';
import { createClient } from '@/lib/supabase/server';

export const metadata: Metadata = { title: 'Payments & earnings' };

const PAGE_SIZE = 30;

export default async function FinancePage({
  searchParams,
}: {
  searchParams: Promise<Record<string, string | string[] | undefined>>;
}) {
  const params = await searchParams;
  const tab = firstParam(params.tab) === 'earnings' ? 'earnings' : 'payments';
  const page = pageParam(params.page);
  const range: [number, number] = [(page - 1) * PAGE_SIZE, page * PAGE_SIZE - 1];
  const supabase = await createClient();
  const stats = await getDashboardStats();

  const result =
    tab === 'payments'
      ? await supabase
          .from('payments')
          .select(
            'id, status, provider, provider_bill_code, amount_sen, paid_at, verified_at, failure_reason, created_at, job:service_requests ( id, reference )',
            { count: 'exact' },
          )
          .order('created_at', { ascending: false })
          .range(...range)
      : await supabase
          .from('technician_earnings')
          .select(
            `id, status, gross_sen, commission_percent, commission_sen, net_sen, released_at, withheld_reason, created_at,
             job:service_requests ( id, reference ),
             technician:technician_profiles ( id, profile:profiles!technician_profiles_id_fkey ( full_name ) )`,
            { count: 'exact' },
          )
          .order('created_at', { ascending: false })
          .range(...range);

  const rows = (result.data ?? []) as any[];

  return (
    <>
      <PageHeader
        title="Payments & earnings"
        description="Read-only, deliberately. A payment is settled only by the server after it has confirmed with ToyyibPay, and earnings are released by the payment service - not from a browser."
      />

      {stats && (
        <div className="stats">
          <Stat label="Paid, all time" value={formatSen(stats.gross_paid_sen_total)} />
          <Stat label="Paid, last 30 days" value={formatSen(stats.gross_paid_sen_30d)} />
          <Stat label="Commission earned" value={formatSen(stats.commission_sen_total)} />
          <Stat label="Owed to technicians" value={formatSen(stats.earnings_pending_sen)} hint="Pending release" />
        </div>
      )}

      <Tabs
        current={tab}
        items={[
          { key: 'payments', label: 'Customer payments', href: '/finance' },
          { key: 'earnings', label: 'Technician earnings', href: '/finance?tab=earnings' },
        ]}
      />
      {result.error && <LoadError message={report('finance', result.error)} />}

      <Card flush>
        {rows.length === 0 ? (
          <Empty title={tab === 'payments' ? 'No payments yet' : 'No earnings yet'} />
        ) : tab === 'payments' ? (
          <div className="table-wrap">
            <table>
              <thead>
                <tr>
                  <th>Job</th>
                  <th>Status</th>
                  <th>Provider</th>
                  <th className="num">Amount</th>
                  <th>Paid</th>
                  <th>Verified</th>
                </tr>
              </thead>
              <tbody>
                {rows.map((p) => (
                  <tr key={p.id}>
                    <td>
                      <Link className="mono strong" href={`/jobs/${p.job?.id}`}>
                        {p.job?.reference}
                      </Link>
                    </td>
                    <td>
                      <EnumChip map={PAYMENT_STATUS} value={p.status} />
                      {p.failure_reason && <span className="sub danger-text">{p.failure_reason}</span>}
                    </td>
                    <td>
                      <EnumChip map={PAYMENT_PROVIDER} value={p.provider} plain />
                      {p.provider_bill_code && <span className="sub mono">{p.provider_bill_code}</span>}
                    </td>
                    <td className="num strong">{formatSen(p.amount_sen)}</td>
                    <td className="nowrap">{formatDateTime(p.paid_at)}</td>
                    <td className="nowrap">{formatDateTime(p.verified_at)}</td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        ) : (
          <div className="table-wrap">
            <table>
              <thead>
                <tr>
                  <th>Technician</th>
                  <th>Job</th>
                  <th>Status</th>
                  <th className="num">Gross</th>
                  <th className="num">Commission</th>
                  <th className="num">Net</th>
                  <th>Released</th>
                </tr>
              </thead>
              <tbody>
                {rows.map((e) => (
                  <tr key={e.id}>
                    <td>
                      <Link href={`/technicians/${e.technician?.id}`}>{e.technician?.profile?.full_name}</Link>
                    </td>
                    <td>
                      <Link className="mono" href={`/jobs/${e.job?.id}`}>
                        {e.job?.reference}
                      </Link>
                    </td>
                    <td>
                      <EnumChip map={EARNING_STATUS} value={e.status} />
                      {e.withheld_reason && <span className="sub">{e.withheld_reason}</span>}
                    </td>
                    <td className="num">{formatSen(e.gross_sen)}</td>
                    <td className="num muted">
                      {formatSen(e.commission_sen)}
                      <span className="sub">{Number(e.commission_percent)}%</span>
                    </td>
                    <td className="num strong">{formatSen(e.net_sen)}</td>
                    <td className="nowrap">{formatDateTime(e.released_at)}</td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        )}
        <Pager
          page={page}
          pageSize={PAGE_SIZE}
          total={result.count ?? 0}
          hrefFor={(p) => `/finance?${tab === 'earnings' ? 'tab=earnings&' : ''}page=${p}`}
        />
      </Card>
    </>
  );
}
