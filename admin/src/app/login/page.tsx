import type { Metadata } from 'next';
import { ActionForm, Submit } from '@/components/action-form';
import { signIn } from './actions';

export const metadata: Metadata = { title: 'Sign in' };

export default async function LoginPage({
  searchParams,
}: {
  searchParams: Promise<Record<string, string | string[] | undefined>>;
}) {
  const { reason } = await searchParams;

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

        <h1 style={{ fontSize: 20 }}>Sign in</h1>
        <p className="muted" style={{ margin: '4px 0 18px' }}>
          For ReadyTech administrators. Use the same account you sign in to the app with.
        </p>

        {reason === 'not-admin' && (
          <div className="notice warn" style={{ marginBottom: 12 }}>
            That account no longer has administrator access, so it was signed out.
          </div>
        )}

        <ActionForm action={signIn}>
          <label className="field">
            Email
            <input type="email" name="email" autoComplete="username" required autoFocus />
          </label>
          <label className="field">
            Password
            <input type="password" name="password" autoComplete="current-password" required />
          </label>
          <Submit>Sign in</Submit>
        </ActionForm>
      </section>
    </main>
  );
}
