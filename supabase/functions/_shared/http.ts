/**
 * Shared HTTP plumbing for ReadyTech Edge Functions.
 *
 * Every function returns errors in the same envelope:
 *
 *     { "error": { "code": "conflict", "message": "..." } }
 *
 * The Flutter client's ErrorMapper reads `error.message` and shows it to the
 * user, so anything written there must be a sentence a customer can act on.
 * Diagnostic detail goes to the log, never into the body.
 */

/** Statuses the client maps onto its own failure types. */
export const Status = {
  ok: 200,
  badRequest: 400,
  unauthorised: 401,
  forbidden: 403,
  notFound: 404,
  conflict: 409,
  tooManyRequests: 429,
  serverError: 500,
} as const;

/**
 * The mobile app does not need CORS, but the admin dashboard does, and so does
 * a browser-based payment return.
 *
 * Allowed origins are read from ALLOWED_ORIGINS rather than hardcoded to `*`:
 * these functions act with the service role, and a wildcard would let any page
 * on the internet drive them with a user's token.
 */
const allowedOrigins = (Deno.env.get('ALLOWED_ORIGINS') ?? '')
  .split(',')
  .map((origin) => origin.trim())
  .filter(Boolean);

export function corsHeaders(request: Request): Record<string, string> {
  const origin = request.headers.get('Origin') ?? '';
  const permitted = allowedOrigins.includes(origin);

  return {
    'Access-Control-Allow-Origin': permitted ? origin : 'null',
    'Access-Control-Allow-Headers':
      'authorization, x-client-info, apikey, content-type',
    'Access-Control-Allow-Methods': 'POST, OPTIONS',
    'Access-Control-Max-Age': '86400',
    Vary: 'Origin',
  };
}

export function jsonResponse(
  request: Request,
  body: unknown,
  status: number = Status.ok,
): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders(request), 'Content-Type': 'application/json' },
  });
}

/**
 * An error the user is meant to see.
 *
 * Throw this for anything with a message worth showing. Everything else should
 * be an ordinary exception, which `handle` turns into a generic 500 - a stack
 * trace or a driver message must never reach a phone.
 */
export class PublicError extends Error {
  constructor(
    readonly status: number,
    message: string,
    readonly code: string = 'error',
  ) {
    super(message);
    this.name = 'PublicError';
  }

  static badRequest(message: string) {
    return new PublicError(Status.badRequest, message, 'validation');
  }

  static forbidden(message = 'You do not have permission to do that.') {
    return new PublicError(Status.forbidden, message, 'permission');
  }

  static notFound(message = 'We could not find what you were looking for.') {
    return new PublicError(Status.notFound, message, 'not_found');
  }

  static conflict(message: string) {
    return new PublicError(Status.conflict, message, 'conflict');
  }
}

/**
 * Wraps a handler with CORS, method checking and error translation.
 *
 * Use this for every function, so one place decides what an error looks like
 * on the wire and no handler can accidentally leak an internal message.
 */
export function handle(
  name: string,
  handler: (request: Request) => Promise<Response>,
): (request: Request) => Promise<Response> {
  return async (request: Request) => {
    if (request.method === 'OPTIONS') {
      return new Response(null, { status: 204, headers: corsHeaders(request) });
    }

    if (request.method !== 'POST') {
      return jsonResponse(
        request,
        { error: { code: 'method', message: 'Method not allowed.' } },
        405,
      );
    }

    try {
      return await handler(request);
    } catch (error) {
      if (error instanceof PublicError) {
        return jsonResponse(
          request,
          { error: { code: error.code, message: error.message } },
          error.status,
        );
      }

      // Unexpected. Log the detail, return nothing useful to an attacker.
      console.error(`[${name}] unhandled error`, error);
      return jsonResponse(
        request,
        {
          error: {
            code: 'server',
            message: 'Something went wrong on our side. Please try again.',
          },
        },
        Status.serverError,
      );
    }
  };
}

/** Parses and validates a JSON body, with a clear message when it is wrong. */
export async function readJson<T>(request: Request): Promise<T> {
  try {
    return (await request.json()) as T;
  } catch {
    throw PublicError.badRequest('That request could not be read.');
  }
}
