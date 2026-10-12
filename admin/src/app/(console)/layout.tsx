import type { ReactNode } from 'react';
import { Nav, type NavGroup } from '@/components/nav';
import { requireAdmin } from '@/lib/auth';
import { getDashboardStats } from '@/lib/stats';
import { signOut } from './actions';

// Every page reads live marketplace state as the signed-in administrator.
export const dynamic = 'force-dynamic';

export default async function ConsoleLayout({ children }: { children: ReactNode }) {
  const admin = await requireAdmin();
  const stats = await getDashboardStats();

  const groups: NavGroup[] = [
    {
      title: 'Operations',
      items: [
        { href: '/', label: 'Overview' },
        { href: '/jobs', label: 'Jobs' },
        { href: '/disputes', label: 'Disputes', count: stats?.disputes_open },
      ],
    },
    {
      title: 'People',
      items: [
        { href: '/verifications', label: 'Verification queue', count: stats?.documents_pending },
        { href: '/technicians', label: 'Technicians' },
        { href: '/users', label: 'Accounts' },
      ],
    },
    {
      title: 'Marketplace',
      items: [
        { href: '/catalogue', label: 'Service catalogue' },
        { href: '/pricing', label: 'Pricing' },
        { href: '/finance', label: 'Payments & earnings' },
      ],
    },
    {
      title: 'Trust',
      items: [
        { href: '/moderation', label: 'Moderation', count: stats?.messages_reported },
        { href: '/audit', label: 'Audit log' },
      ],
    },
  ];

  return (
    <div className="shell">
      <aside className="sidebar">
        <div className="brand">
          <span className="brand-mark">R</span>
          <span>
            ReadyTech
            <small>Admin console</small>
          </span>
        </div>
        <Nav groups={groups} />
        <div className="sidebar-foot">
          <div className="who">
            {admin.fullName}
            <small>{admin.email}</small>
          </div>
          <form action={signOut}>
            <button type="submit" className="btn secondary small">
              Sign out
            </button>
          </form>
        </div>
      </aside>
      <main className="main">
        <div className="page">{children}</div>
      </main>
    </div>
  );
}
