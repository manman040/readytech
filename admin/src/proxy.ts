import { createServerClient } from '@supabase/ssr';
import { NextResponse, type NextRequest } from 'next/server';
import { supabaseConfig } from '@/lib/config';

/**
 * Refreshes the Supabase session on every request and sends anyone without one
 * to the sign-in page.
 *
 * This is the convenience layer, like the app's router redirect. It answers
 * "signed in?" only; "administrator?" is answered by requireAdmin() in the
 * console layout, and what an administrator may actually do is answered by
 * Postgres.
 */
export async function proxy(request: NextRequest) {
  const config = supabaseConfig();
  if ('missing' in config) return NextResponse.next();

  let response = NextResponse.next({ request });

  const supabase = createServerClient(config.url, config.key, {
    cookies: {
      getAll() {
        return request.cookies.getAll();
      },
      setAll(cookiesToSet, headers) {
        for (const { name, value } of cookiesToSet) request.cookies.set(name, value);
        response = NextResponse.next({ request });
        for (const { name, value, options } of cookiesToSet) {
          response.cookies.set(name, value, options);
        }
        for (const [name, value] of Object.entries(headers ?? {})) {
          response.headers.set(name, value);
        }
      },
    },
  });

  // getUser() validates the token with Supabase Auth rather than trusting
  // whatever the cookie claims.
  const {
    data: { user },
  } = await supabase.auth.getUser();

  const isLogin = request.nextUrl.pathname.startsWith('/login');
  if (!user && !isLogin) {
    const url = request.nextUrl.clone();
    url.pathname = '/login';
    url.search = '';
    return NextResponse.redirect(url);
  }

  return response;
}

export const config = {
  matcher: ['/((?!_next/static|_next/image|favicon.ico|icon.svg).*)'],
};
