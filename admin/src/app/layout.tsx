import type { Metadata } from 'next';
import type { ReactNode } from 'react';
import { supabaseConfig } from '@/lib/config';
import './globals.css';

export const metadata: Metadata = {
  title: { default: 'ReadyTech Admin', template: '%s · ReadyTech Admin' },
  description: 'Administrator console for the ReadyTech service marketplace.',
  robots: { index: false, follow: false },
};

export default function RootLayout({ children }: { children: ReactNode }) {
  const config = supabaseConfig();

  return (
    <html lang="en">
      <body>
        {'missing' in config ? <NotConfigured missing={config.missing} /> : children}
      </body>
    </html>
  );
}

/** The console's equivalent of the app's "not configured" screen. */
function NotConfigured({ missing }: { missing: string[] }) {
  return (
    <main className="login">
      <section className="card">
        <div className="brand">
          <span className="brand-mark">R</span>
          <span>
            ReadyTech
            <small>Admin console</small>
          </span>
        </div>
        <h1>Not configured</h1>
        <p className="muted" style={{ marginTop: 8 }}>
          Copy <code>admin/.env.example</code> to <code>admin/.env.local</code> and set:
        </p>
        <ul>
          {missing.map((name) => (
            <li key={name}>
              <code>{name}</code>
            </li>
          ))}
        </ul>
        <p className="muted small">
          Both values are printed by <code>supabase status</code>. Restart <code>npm run dev</code>{' '}
          afterwards.
        </p>
      </section>
    </main>
  );
}
