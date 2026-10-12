import Link from 'next/link';
import type { Metadata } from 'next';
import { Card, Empty, LoadError, PageHeader, pageParam, Pager } from '@/components/ui';
import { humanise } from '@/lib/domain/enums';
import { report } from '@/lib/errors';
import { formatDateTime } from '@/lib/format';
import { createClient } from '@/lib/supabase/server';

export const metadata: Metadata = { title: 'Audit log' };

const PAGE_SIZE = 50;

type Entry = {
  id: string;
  action: string;
  target_table: string;
  target_id: string;
  detail: Record<string, unknown>;
  created_at: string;
  admin: { full_name: string; email: string } | null;
};

/** Where a target lives in the console, when it has a page. */
function targetHref(entry: Entry): string | null {
  const id = entry.target_id;
  switch (entry.target_table) {
    case 'service_requests':
      return `/jobs/${id}`;
    case 'technician_profiles':
      return `/technicians/${id}`;
    case 'technician_verifications':
      return typeof entry.detail.technician_id === 'string' ? `/technicians/${entry.detail.technician_id}` : null;
    case 'disputes':
      return `/disputes/${id}`;
    case 'user_roles':
      return `/users/${id}`;
    case 'service_categories':
      return `/catalogue/${id}`;
    case 'pricing_config':
      return '/pricing';
    case 'messages':
    case 'reviews':
      return typeof entry.detail.request_id === 'string' ? `/jobs/${entry.detail.request_id}` : null;
    default:
      return null;
  }
}

/** The one-line summary of an entry; the full detail is one click away. */
function summary(entry: Entry): string {
  const d = entry.detail;
  const parts: string[] = [];
  if (d.reference) parts.push(String(d.reference));
  if (d.from !== undefined && d.to !== undefined && typeof d.from !== 'object') parts.push(`${d.from} → ${d.to}`);
  if (d.reason) parts.push(`“${d.reason}”`);
  if (d.notes) parts.push(`“${d.notes}”`);
  if (d.resolution) parts.push(`“${d.resolution}”`);
  return parts.join(' · ');
}

export default async function AuditPage({
  searchParams,
}: {
  searchParams: Promise<Record<string, string | string[] | undefined>>;
}) {
  const page = pageParam((await searchParams).page);
  const supabase = await createClient();
  const { data, count, error } = await supabase
    .from('admin_audit_log')
    .select('id, action, target_table, target_id, detail, created_at, admin:profiles ( full_name, email )', {
      count: 'exact',
    })
    .order('created_at', { ascending: false })
    .range((page - 1) * PAGE_SIZE, page * PAGE_SIZE - 1);
  const rows = (data ?? []) as unknown as Entry[];

  return (
    <>
      <PageHeader
        title="Audit log"
        description="Every administrative action, written by the database as it happens. Nobody can edit or delete an entry - administrators included."
      />
      {error && <LoadError message={report('audit', error)} />}
      <Card flush>
        {rows.length === 0 ? (
          <Empty title="Nothing recorded yet">Actions taken in this console appear here.</Empty>
        ) : (
          <div className="table-wrap">
            <table>
              <thead>
                <tr>
                  <th>When</th>
                  <th>Who</th>
                  <th>Action</th>
                  <th>Detail</th>
                </tr>
              </thead>
              <tbody>
                {rows.map((e) => {
                  const href = targetHref(e);
                  return (
                    <tr key={e.id}>
                      <td className="nowrap">{formatDateTime(e.created_at)}</td>
                      <td>
                        {e.admin?.full_name ?? 'Deleted account'}
                        <span className="sub">{e.admin?.email}</span>
                      </td>
                      <td className="nowrap">
                        <span className="strong">{humanise(e.action.replace('.', ' '))}</span>
                        <span className="sub">
                          {href ? <Link href={href}>{e.target_table}</Link> : e.target_table}
                        </span>
                      </td>
                      <td>
                        <span className="clamp">{summary(e)}</span>
                        <details className="disclose small">
                          <summary className="muted">Full record</summary>
                          <pre className="mono" style={{ whiteSpace: 'pre-wrap', margin: 0 }}>
                            {JSON.stringify(e.detail, null, 2)}
                          </pre>
                        </details>
                      </td>
                    </tr>
                  );
                })}
              </tbody>
            </table>
          </div>
        )}
        <Pager page={page} pageSize={PAGE_SIZE} total={count ?? 0} hrefFor={(p) => `/audit?page=${p}`} />
      </Card>
    </>
  );
}
