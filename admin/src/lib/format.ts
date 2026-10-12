/**
 * Dates as an administrator in Malaysia reads them.
 *
 * Fixed to Asia/Kuala_Lumpur rather than the server's zone: the console may be
 * hosted anywhere, and "the technician arrived at 3:04 am" because a server
 * sits in UTC is the sort of thing that starts an argument in a dispute.
 */

const TIME_ZONE = 'Asia/Kuala_Lumpur';

const dateTime = new Intl.DateTimeFormat('en-MY', {
  timeZone: TIME_ZONE,
  day: 'numeric',
  month: 'short',
  year: 'numeric',
  hour: 'numeric',
  minute: '2-digit',
});

const dateOnly = new Intl.DateTimeFormat('en-MY', {
  timeZone: TIME_ZONE,
  day: 'numeric',
  month: 'short',
  year: 'numeric',
});

export function formatDateTime(value: string | null | undefined): string {
  if (!value) return '—';
  const date = new Date(value);
  return Number.isNaN(date.getTime()) ? '—' : dateTime.format(date);
}

export function formatDate(value: string | null | undefined): string {
  if (!value) return '—';
  const date = new Date(value);
  return Number.isNaN(date.getTime()) ? '—' : dateOnly.format(date);
}

/** "3 min ago", "2 days ago". `now` is injectable for tests. */
export function formatRelative(value: string | null | undefined, now: Date = new Date()): string {
  if (!value) return '—';
  const then = new Date(value).getTime();
  if (Number.isNaN(then)) return '—';
  const seconds = Math.round((now.getTime() - then) / 1000);
  const future = seconds < 0;
  const s = Math.abs(seconds);

  const [amount, unit] =
    s < 60 ? [s, 'sec']
    : s < 3600 ? [Math.floor(s / 60), 'min']
    : s < 86400 ? [Math.floor(s / 3600), 'hr']
    : [Math.floor(s / 86400), Math.floor(s / 86400) === 1 ? 'day' : 'days'];

  if (s < 45) return 'just now';
  return future ? `in ${amount} ${unit}` : `${amount} ${unit} ago`;
}

export function shortId(id: string): string {
  return id.slice(0, 8);
}
