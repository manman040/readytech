import Link from 'next/link';
import { notFound } from 'next/navigation';
import { ActionForm, Submit } from '@/components/action-form';
import { Card, Empty, EnumChip, PageHeader, StatusChip } from '@/components/ui';
import { requireAdmin } from '@/lib/auth';
import { DEVICE_TYPE, USER_ROLE, describe } from '@/lib/domain/enums';
import { formatDate, formatDateTime, formatRelative } from '@/lib/format';
import { createClient } from '@/lib/supabase/server';
import { setRole } from '../actions';

type Params = Promise<{ id: string }>;
const UUID = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;

export const metadata = { title: 'Account' };

export default async function UserPage({ params }: { params: Params }) {
  const { id } = await params;
  if (!UUID.test(id)) notFound();
  const admin = await requireAdmin();
  const supabase = await createClient();

  const { data: user } = await supabase
    .from('profiles')
    .select(
      `id, full_name, email, phone, created_at, updated_at,
       role:user_roles!user_roles_user_id_fkey ( role, updated_at,
         assigner:profiles!user_roles_assigned_by_fkey ( full_name ) )`,
    )
    .eq('id', id)
    .maybeSingle();
  if (!user) notFound();

  const [jobs, devices, technician] = await Promise.all([
    supabase
      .from('service_requests')
      .select('id, reference, status, requested_at')
      .eq('customer_id', id)
      .order('requested_at', { ascending: false })
      .limit(20),
    supabase
      .from('devices')
      .select('id, nickname, device_type, brand, model, archived_at')
      .eq('owner_id', id)
      .order('created_at', { ascending: false }),
    supabase.from('technician_profiles').select('id, verification_status').eq('id', id).maybeSingle(),
  ]);

  const roleRow = (Array.isArray(user.role) ? user.role[0] : user.role) as unknown as
    | { role: string; updated_at: string; assigner: { full_name: string } | null }
    | null;
  const currentRole = roleRow?.role ?? 'customer';
  const isSelf = admin.id === id;

  return (
    <>
      <PageHeader
        crumbs={[{ href: '/users', label: 'Accounts' }]}
        title={user.full_name || '(no name)'}
        description={user.email}
        actions={<EnumChip map={USER_ROLE} value={currentRole} />}
      />

      <div className="grid split">
        <div className="stack">
          <Card flush title="Jobs as a customer">
            {(jobs.data ?? []).length === 0 ? (
              <Empty title="No jobs requested" />
            ) : (
              <div className="table-wrap">
                <table>
                  <tbody>
                    {(jobs.data ?? []).map((j) => (
                      <tr key={j.id}>
                        <td>
                          <Link href={`/jobs/${j.id}`} className="mono strong">
                            {j.reference}
                          </Link>
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

          <Card title="Devices">
            {(devices.data ?? []).length === 0 ? (
              <p className="muted">No devices saved.</p>
            ) : (
              <div className="stack" style={{ gap: 8 }}>
                {(devices.data ?? []).map((d) => (
                  <div key={d.id} className="small">
                    <span className="strong">{d.nickname}</span>{' '}
                    <span className="muted">
                      {describe(DEVICE_TYPE, d.device_type).label}
                      {d.brand && ` · ${d.brand} ${d.model ?? ''}`}
                      {d.archived_at && ' · archived'}
                    </span>
                  </div>
                ))}
              </div>
            )}
          </Card>
        </div>

        <div className="stack">
          <Card title="Account">
            <dl className="kv">
              <dt>Email</dt>
              <dd>{user.email}</dd>
              <dt>Phone</dt>
              <dd>{user.phone ?? '—'}</dd>
              <dt>Joined</dt>
              <dd>{formatDate(user.created_at)}</dd>
              <dt>Role since</dt>
              <dd>
                {formatDateTime(roleRow?.updated_at)}
                {roleRow?.assigner?.full_name && <span className="sub muted">set by {roleRow.assigner.full_name}</span>}
              </dd>
              {technician.data && (
                <>
                  <dt>Technician</dt>
                  <dd>
                    <Link href={`/technicians/${id}`}>Technician profile</Link>
                  </dd>
                </>
              )}
            </dl>
          </Card>

          <Card title="Role">
            {isSelf ? (
              <p className="muted small">
                You cannot change your own role. Another administrator has to - that way nobody can lock the console
                out, or quietly step down to cover a trail.
              </p>
            ) : (
              <ActionForm
                action={setRole}
                confirm="Changing a role changes what this person can see and do immediately. Continue?"
                resetOnSuccess
              >
                <input type="hidden" name="user_id" value={id} />
                <label className="field">
                  New role
                  <select name="new_role" required defaultValue="">
                    <option value="" disabled>
                      Choose…
                    </option>
                    {Object.entries(USER_ROLE)
                      .filter(([key]) => key !== currentRole)
                      .map(([key, v]) => (
                        <option key={key} value={key}>
                          {v.label}
                        </option>
                      ))}
                  </select>
                </label>
                <label className="field">
                  Reason
                  <span className="hint">Kept in the audit log.</span>
                  <textarea name="reason" required minLength={5} maxLength={500} />
                </label>
                <p className="muted small">
                  An administrator can see every customer&apos;s jobs, messages and payments. Appoint one deliberately.
                </p>
                <Submit variant="secondary">Change role</Submit>
              </ActionForm>
            )}
          </Card>
        </div>
      </div>
    </>
  );
}
