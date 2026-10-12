import Link from 'next/link';
import type { Metadata } from 'next';
import {
  Card,
  Empty,
  EnumChip,
  firstParam,
  LoadError,
  PageHeader,
  pageParam,
  Pager,
  Person,
  StatusChip,
  Tabs,
} from '@/components/ui';
import { URGENCY_LEVEL } from '@/lib/domain/enums';
import { formatSenRange } from '@/lib/domain/money';
import { ADMIN_LABEL, isServiceStatus, STATUS_GROUPS } from '@/lib/domain/service-status';
import { report } from '@/lib/errors';
import { formatDateTime, formatRelative } from '@/lib/format';
import { JOB_LIST_SELECT, searchTerm, type JobListRow } from '@/lib/queries';
import { createClient } from '@/lib/supabase/server';

export const metadata: Metadata = { title: 'Jobs' };

const PAGE_SIZE = 25;

type Search = Promise<Record<string, string | string[] | undefined>>;

export default async function JobsPage({ searchParams }: { searchParams: Search }) {
  const params = await searchParams;
  const group = firstParam(params.group) ?? 'all';
  const status = firstParam(params.status);
  const q = firstParam(params.q);
  const page = pageParam(params.page);

  const supabase = await createClient();
  let query = supabase
    .from('service_requests')
    .select(JOB_LIST_SELECT, { count: 'exact' })
    .order('created_at', { ascending: false })
    .range((page - 1) * PAGE_SIZE, page * PAGE_SIZE - 1);

  if (status && isServiceStatus(status)) {
    query = query.eq('status', status);
  } else if (STATUS_GROUPS[group]) {
    query = query.in('status', STATUS_GROUPS[group].statuses);
  }

  const term = searchTerm(q);
  if (term) {
    query = query.or(
      `reference.ilike.*${term}*,problem_description.ilike.*${term}*,service_address.ilike.*${term}*`,
    );
  }

  const { data, count, error } = await query;
  const jobs = (data ?? []) as unknown as JobListRow[];

  const hrefFor = (overrides: Record<string, string | undefined>) => {
    const next = new URLSearchParams();
    const merged = { group: group === 'all' ? undefined : group, status, q, ...overrides };
    for (const [key, value] of Object.entries(merged)) if (value) next.set(key, value);
    const qs = next.toString();
    return qs ? `/jobs?${qs}` : '/jobs';
  };

  const currentTab = status ? '' : group;

  return (
    <>
      <PageHeader
        title="Jobs"
        description="Every service request. Nothing here is ever deleted - a cancelled job stays on the record."
      />

      <Tabs
        current={currentTab}
        items={[
          { key: 'all', label: 'All', href: hrefFor({ group: undefined, status: undefined, page: undefined }) },
          ...Object.entries(STATUS_GROUPS).map(([key, value]) => ({
            key,
            label: value.label,
            href: hrefFor({ group: key, status: undefined, page: undefined }),
          })),
        ]}
      />

      <form className="toolbar" action="/jobs">
        {group !== 'all' && <input type="hidden" name="group" value={group} />}
        <input type="search" name="q" defaultValue={q} placeholder="Reference, problem or address" />
        <button className="btn secondary" type="submit">
          Search
        </button>
        {status && (
          <span className="muted">
            Showing <strong>{ADMIN_LABEL[status as keyof typeof ADMIN_LABEL] ?? status}</strong> ·{' '}
            <Link href={hrefFor({ status: undefined })}>clear</Link>
          </span>
        )}
      </form>

      {error && <LoadError message={report('jobs list', error)} />}

      <Card flush>
        {jobs.length === 0 ? (
          <Empty title="No jobs match">Try another filter or search.</Empty>
        ) : (
          <div className="table-wrap">
            <table>
              <thead>
                <tr>
                  <th>Job</th>
                  <th>Status</th>
                  <th>Problem</th>
                  <th>Customer</th>
                  <th>Technician</th>
                  <th className="num">Estimate</th>
                  <th>Requested</th>
                </tr>
              </thead>
              <tbody>
                {jobs.map((job) => (
                  <tr key={job.id}>
                    <td className="nowrap">
                      <Link href={`/jobs/${job.id}`} className="mono strong">
                        {job.reference}
                      </Link>
                      <span className="sub">
                        {job.urgency !== 'normal' ? (
                          <EnumChip map={URGENCY_LEVEL} value={job.urgency} plain />
                        ) : (
                          job.category?.name ?? 'Unclassified'
                        )}
                      </span>
                    </td>
                    <td>
                      <StatusChip status={job.status} />
                    </td>
                    <td>
                      <span className="clamp">{job.problem_summary || job.problem_description}</span>
                    </td>
                    <td>
                      <Person
                        id={job.customer?.id}
                        name={job.customer?.full_name}
                        email={job.customer?.email}
                        href={`/users/${job.customer?.id}`}
                      />
                    </td>
                    <td>
                      <Person
                        id={job.technician?.id}
                        name={job.technician?.profile?.full_name}
                        href={`/technicians/${job.technician?.id}`}
                      />
                    </td>
                    <td className="num">
                      {formatSenRange(job.estimated_total_min_sen, job.estimated_total_max_sen)}
                    </td>
                    <td className="nowrap" title={formatDateTime(job.requested_at)}>
                      {formatRelative(job.requested_at)}
                    </td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        )}
        <Pager
          page={page}
          pageSize={PAGE_SIZE}
          total={count ?? 0}
          hrefFor={(p) => hrefFor({ page: String(p) })}
        />
      </Card>
    </>
  );
}
