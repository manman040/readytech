'use client';

import { useActionState, useEffect, useRef, type ReactNode } from 'react';
import { useFormStatus } from 'react-dom';
import type { ActionState } from '@/lib/action-state';

/**
 * A form bound to a server action, with the three things every admin action
 * needs: a pending state so nobody double-submits a suspension, the server's
 * message shown in place, and an optional confirmation for actions that
 * notify a real person.
 */
export function ActionForm({
  action,
  children,
  confirm,
  resetOnSuccess,
  className = 'form',
}: {
  action: (state: ActionState, form: FormData) => Promise<ActionState>;
  children: ReactNode;
  confirm?: string;
  resetOnSuccess?: boolean;
  className?: string;
}) {
  const [state, formAction] = useActionState(action, {});
  const formRef = useRef<HTMLFormElement>(null);

  useEffect(() => {
    if (state.ok && resetOnSuccess) formRef.current?.reset();
  }, [state, resetOnSuccess]);

  return (
    <form
      ref={formRef}
      action={formAction}
      className={className}
      onSubmit={(event) => {
        if (confirm && !window.confirm(confirm)) event.preventDefault();
      }}
    >
      {children}
      {state.error && (
        <div className="notice error" role="alert">
          {state.error}
        </div>
      )}
      {state.ok && state.message && (
        <div className="notice ok" role="status">
          {state.message}
        </div>
      )}
    </form>
  );
}

export function Submit({
  children,
  variant,
  small,
  name,
  value,
}: {
  children: ReactNode;
  variant?: 'secondary' | 'danger' | 'ghost';
  small?: boolean;
  name?: string;
  value?: string;
}) {
  const { pending } = useFormStatus();
  return (
    <button
      type="submit"
      className={['btn', variant, small && 'small'].filter(Boolean).join(' ')}
      disabled={pending}
      name={name}
      value={value}
    >
      {pending ? 'Working…' : children}
    </button>
  );
}
