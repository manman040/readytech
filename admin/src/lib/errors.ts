/**
 * Turns a Supabase error into something an administrator may read.
 *
 * The same contract as app/lib/core/errors/error_mapper.dart: our own Postgres
 * functions raise SQLSTATEs in the RT class with messages written for people,
 * so those are shown verbatim. Every other database error is replaced with a
 * generic sentence, because a Postgres error string leaks the schema - and the
 * console is a browser tab, which is a place screenshots get taken.
 */

export const RT_CODES = {
  validation: 'RT400',
  forbidden: 'RT403',
  notFound: 'RT404',
  conflict: 'RT409',
} as const;

type ErrorLike = { code?: string | null; message?: string | null } | null | undefined;

export function userMessage(error: ErrorLike): string {
  if (!error) return 'Something went wrong. Please try again.';
  const code = error.code ?? '';

  if (code.startsWith('RT') && error.message) return error.message;

  switch (code) {
    case '23505':
      return 'That record already exists.';
    case '23503':
      return 'That reference is no longer valid. Please refresh.';
    case '23502':
    case '23514':
    case '22P02':
      return 'Some of the details are missing or invalid.';
    case '42501':
      return 'You do not have permission to do that.';
    case 'PGRST116':
      return 'That record could not be found. It may have been changed by someone else.';
    default:
      return 'We could not complete that request. Please try again.';
  }
}

/** Logs the full error on the server and returns the safe message. */
export function report(context: string, error: ErrorLike): string {
  if (error) console.error(`[admin] ${context}`, error);
  return userMessage(error);
}
