/**
 * Supabase clients for Edge Functions.
 *
 * Two clients, used for different jobs, and the distinction is the whole point:
 *
 *   callerClient  acts as the signed-in user. Row Level Security applies. Use
 *                 it to answer "is this person allowed to do this", because it
 *                 asks the database rather than trusting the request body.
 *
 *   serviceClient bypasses every policy. Use it only after the caller's
 *                 authority has been established, and only for the write that
 *                 a client is deliberately not permitted to make itself -
 *                 settling a payment, assigning a technician, issuing a
 *                 warranty.
 *
 * Reaching for serviceClient first is the mistake that makes row level security
 * decorative.
 */
import { createClient, type SupabaseClient } from 'jsr:@supabase/supabase-js@2';

function requireEnv(name: string): string {
  const value = Deno.env.get(name);
  if (!value) {
    // Fail at startup rather than producing an unauthenticated client that
    // quietly returns empty results.
    throw new Error(`Missing required environment variable: ${name}`);
  }
  return value;
}

const supabaseUrl = requireEnv('SUPABASE_URL');

/** Runs as the signed-in caller, with all policies enforced. */
export function callerClient(request: Request): SupabaseClient {
  const authorization = request.headers.get('Authorization');
  if (!authorization) {
    throw new Error('Missing Authorization header');
  }

  return createClient(supabaseUrl, requireEnv('SUPABASE_ANON_KEY'), {
    global: { headers: { Authorization: authorization } },
    auth: { persistSession: false, autoRefreshToken: false },
  });
}

/** Runs with full privileges. Never construct one from unvalidated input. */
export function serviceClient(): SupabaseClient {
  return createClient(supabaseUrl, requireEnv('SUPABASE_SERVICE_ROLE_KEY'), {
    auth: { persistSession: false, autoRefreshToken: false },
  });
}

/**
 * Resolves the caller's user id from their token, or throws.
 *
 * Reads it from the verified JWT rather than from the request body - a user id
 * a client can name is a user id a client can change.
 */
export async function requireUser(request: Request): Promise<string> {
  const client = callerClient(request);
  const { data, error } = await client.auth.getUser();

  if (error || !data.user) {
    throw new Error('Invalid or expired session');
  }
  return data.user.id;
}

/** Resolves the caller's role from user_roles, not from a client claim. */
export async function requireRole(
  request: Request,
): Promise<{ userId: string; role: 'customer' | 'technician' | 'admin' }> {
  const client = callerClient(request);
  const { data: userData, error: userError } = await client.auth.getUser();

  if (userError || !userData.user) {
    throw new Error('Invalid or expired session');
  }

  const { data, error } = await client
    .from('user_roles')
    .select('role')
    .eq('user_id', userData.user.id)
    .single();

  if (error || !data) {
    throw new Error('No role assigned to this account');
  }

  return { userId: userData.user.id, role: data.role };
}
