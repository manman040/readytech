import Link from 'next/link';
import type { Metadata } from 'next';
import { Card, Empty, EnumChip, firstParam, LoadError, PageHeader, pageParam, Pager, Tabs } from '@/components/ui';
import { USER_ROLE } from '@/lib/domain/enums';
import { report } from '@/lib/errors';
import { formatDate } from '@/lib/format';
import { searchTerm } from '@/lib/queries';
import { createClient } from '@/lib/supabase/server';

export const metadata: Metadata = { title: 'Accounts' };

const PAGE_SIZE = 40;

type Row = {
  id: string;
  full_name: string;
  email: string;
  phone: string | null;
  created_at: string;
  role: { role: string } | null;
};

export default async function UsersPage({
  searchParams,
}: {
  searchParams: Promise<Record<string, string | string[] | undefined>>;
}) {
  const params = await searchParams;
  const role = firstParam(params.role) ?? 'all';
  const q = firstParam(params.q);
  const page = pageParam(params.page);
  const supabase = await createClient();

  // `!inner` so filtering on the role filters the accounts, not just the embed.
  let query = supabase
    .from('profiles')
    .select('id, full_name, email, phone, created_at, role:user_roles!user_roles_user_id_fkey!inner ( role )', {
      count: 'exact',
    })
    .order('created_at', { ascending: false })
    .range((page - 1) * PAGE_SIZE, page * PAGE_SIZE - 1);

  if (role in USER_ROLE) query = query.eq('role.role', role);
  const term = searchTerm(q);
  if (term) query = query.or(`full_name.ilike.*${term}*,email.ilike.*${term}*,phone.ilike.*${term}*`);

  const { data, count, error } = await query;
  const rows = (data ?? []) as unknown as Row[];

  const href = (overrides: Record<string, string | undefined>) => {
    const sp = new URLSearchParams();
    const merged = { role: role === 'all' ? undefined : role, q, ...overrides };
    for (const [k, v] of Object.entries(merged)) if (v) sp.set(k, v);
    return sp.size ? `/users?${sp}` : '/users';
  };

  return (
    <>
      <PageHeader
        title="Accounts"
        description="Everyone with a ReadyTech account. Roles are changed here and nowhere else - never from the app."
      />
      <Tabs
        current={role}
        items={[
          { key: 'all', label: 'All', href: href({ role: undefined, page: undefined }) },
          ...Object.entries(USER_ROLE).map(([key, v]) => ({
            key,
            label: `${v.label}s`,
            href: href({ role: key, page: undefined }),
          })),
        ]}
      />
      <form className="toolbar" action="/users">
        {role !== 'all' && <input type="hidden" name="role" value={role} />}
        <input type="search" name="q" defaultValue={q} placeholder="Name, email or phone" />
        <button className="btn secondary" type="submit">
          Search
        </button>
      </form>
      {error && <LoadError message={report('users', error)} />}
      <Card flush>
        {rows.length === 0 ? (
          <Empty title="No accounts match" />
        ) : (
          <div className="table-wrap">
            <table>
              <thead>
                <tr>
                  <th>Name</th>
                  <th>Role</th>
                  <th>Phone</th>
                  <th>Joined</th>
                </tr>
              </thead>
              <tbody>
                {rows.map((u) => (
                  <tr key={u.id}>
                    <td>
                      <Link href={`/users/${u.id}`} className="strong">
                        {u.full_name || '(no name)'}
                      </Link>
                      <span className="sub">{u.email}</span>
                    </td>
                    <td>
                      <EnumChip map={USER_ROLE} value={u.role?.role} plain />
                    </td>
                    <td className="nowrap">{u.phone ?? <span className="faint">—</span>}</td>
                    <td className="nowrap muted">{formatDate(u.created_at)}</td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        )}
        <Pager page={page} pageSize={PAGE_SIZE} total={count ?? 0} hrefFor={(p) => href({ page: String(p) })} />
      </Card>
    </>
  );
}
