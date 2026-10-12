/**
 * Build-time configuration.
 *
 * Read once, and checked: a missing value renders a "not configured" page
 * naming it (see app/layout.tsx), the same choice the mobile app makes. A blank
 * console that fails on its first query would be worse.
 */

export type SupabaseConfig = { url: string; key: string };

export function supabaseConfig(): SupabaseConfig | { missing: string[] } {
  const url = process.env.NEXT_PUBLIC_SUPABASE_URL ?? '';
  const key = process.env.NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY ?? '';
  const missing = [
    !url && 'NEXT_PUBLIC_SUPABASE_URL',
    !key && 'NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY',
  ].filter((name): name is string => Boolean(name));
  return missing.length ? { missing } : { url, key };
}

export function requireSupabaseConfig(): SupabaseConfig {
  const config = supabaseConfig();
  if ('missing' in config) {
    throw new Error(`Admin console is not configured: ${config.missing.join(', ')}`);
  }
  return config;
}
