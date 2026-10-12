import Link from 'next/link';
import type { Metadata } from 'next';
import { Card, Chip, Empty, EnumChip, firstParam, LoadError, PageHeader, pageParam, Pager, Tabs } from '@/components/ui';
import { VERIFICATION_STATUS } from '@/lib/domain/enums';
import { report } from '@/lib/errors';
import { formatRelative } from '@/lib/format';
import { createClient } from '@/lib/supabase/server';

export const metadata: Metadata = { title: 'Technicians' };

const PAGE_SIZE = 30;

type Row = {
  id: string;
  headline: string;
  verification_status: string;
  is_available: boolean;
  accepts_emergency: boolean;
  rating_average: number;
  rating_count: number;
  completed_jobs: number;
  cancelled_jobs: number;
  offers_received: number;
  offers_accepted: number;
  service_radius_km: number;
  created_at: string;
  profile: { full_name: string; email: string; phone: string | null } | null;
  skills: { proficiency: number; is_primary: boolean; category: { name: string } | null }[];
};

export default async function TechniciansPage({
  searchParams,
}: {
  searchParams: Promise<Record<string, string | string[] | undefined>>;
}) {
  const params = await searchParams;
  const status = firstParam(params.status) ?? 'all';
  const page = pageParam(params.page);
  const supabase = await createClient();

  let query = supabase
    .from('technician_profiles')
    .select(
      `id, headline, verification_status, is_available, accepts_emergency, rating_average, rating_count,
       completed_jobs, cancelled_jobs, offers_received, offers_accepted, service_radius_km, created_at,
       profile:profiles!technician_profiles_id_fkey ( full_name, email, phone ),
       skills:technician_skills ( proficiency, is_primary, category:service_categories ( name ) )`,
      { count: 'exact' },
    )
    .order('created_at', { ascending: false })
    .range((page - 1) * PAGE_SIZE, page * PAGE_SIZE - 1);

  if (status in VERIFICATION_STATUS) query = query.eq('verification_status', status);

  const { data, count, error } = await query;
  const rows = (data ?? []) as unknown as Row[];

  return (
    <>
      <PageHeader
        title="Technicians"
        description="Availability is the technician's own switch; only a verified technician who has it on is ever offered work."
      />
      <Tabs
        current={status}
        items={[
          { key: 'all', label: 'All', href: '/technicians' },
          ...Object.entries(VERIFICATION_STATUS).map(([key, v]) => ({
            key,
            label: v.label,
            href: `/technicians?status=${key}`,
          })),
        ]}
      />
      {error && <LoadError message={report('technicians', error)} />}

      <Card flush>
        {rows.length === 0 ? (
          <Empty title="No technicians here" />
        ) : (
          <div className="table-wrap">
            <table>
              <thead>
                <tr>
                  <th>Technician</th>
                  <th>Verification</th>
                  <th>Specialisms</th>
                  <th className="num">Rating</th>
                  <th className="num">Jobs done</th>
                  <th className="num">Acceptance</th>
                  <th>Joined</th>
                </tr>
              </thead>
              <tbody>
                {rows.map((t) => {
                  const primary = [...t.skills].sort(
                    (a, b) => Number(b.is_primary) - Number(a.is_primary) || b.proficiency - a.proficiency,
                  );
                  const acceptance = t.offers_received
                    ? `${Math.round((t.offers_accepted / t.offers_received) * 100)}%`
                    : '—';
                  return (
                    <tr key={t.id}>
                      <td>
                        <Link href={`/technicians/${t.id}`} className="strong">
                          {t.profile?.full_name || 'Unnamed technician'}
                        </Link>
                        <span className="sub">{t.headline || t.profile?.email}</span>
                      </td>
                      <td>
                        <div className="actions">
                          <EnumChip map={VERIFICATION_STATUS} value={t.verification_status} />
                          {t.verification_status === 'approved' &&
                            (t.is_available ? <Chip tone="live" label="Available" /> : <Chip tone="neutral" label="Offline" plain />)}
                        </div>
                      </td>
                      <td className="small">
                        {primary.length
                          ? primary
                              .slice(0, 3)
                              .map((s) => s.category?.name)
                              .join(', ')
                          : <span className="faint">None listed</span>}
                      </td>
                      <td className="num">
                        {t.rating_count ? `★ ${Number(t.rating_average).toFixed(2)}` : '—'}
                        <span className="sub">{t.rating_count} reviews</span>
                      </td>
                      <td className="num">
                        {t.completed_jobs}
                        {t.cancelled_jobs > 0 && <span className="sub">{t.cancelled_jobs} cancelled</span>}
                      </td>
                      <td className="num">{acceptance}</td>
                      <td className="nowrap muted">{formatRelative(t.created_at)}</td>
                    </tr>
                  );
                })}
              </tbody>
            </table>
          </div>
        )}
        <Pager
          page={page}
          pageSize={PAGE_SIZE}
          total={count ?? 0}
          hrefFor={(p) => `/technicians?${status !== 'all' ? `status=${status}&` : ''}page=${p}`}
        />
      </Card>
    </>
  );
}
