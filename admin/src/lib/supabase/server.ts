import { createServerClient } from '@supabase/ssr';
import { cookies } from 'next/headers';
import { requireSupabaseConfig } from '@/lib/config';

/**
 * A Supabase client acting as the signed-in administrator.
 *
 * Created per request and never shared. It carries the admin's own JWT, so
 * every query is filtered by the same Row Level Security as the mobile app;
 * the console's extra reach comes from the is_admin() policies and the
 * admin_* functions, not from a privileged key.
 */
export async function createClient() {
  const { url, key } = requireSupabaseConfig();
  const cookieStore = await cookies();

  return createServerClient(url, key, {
    cookies: {
      getAll() {
        return cookieStore.getAll();
      },
      setAll(cookiesToSet) {
        try {
          for (const { name, value, options } of cookiesToSet) {
            cookieStore.set(name, value, options);
          }
        } catch {
          // Server Components cannot write cookies. proxy.ts refreshes the
          // session on every request, so nothing is lost here.
        }
      },
    },
  });
}
