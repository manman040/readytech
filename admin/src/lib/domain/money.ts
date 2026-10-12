/**
 * Ringgit, held as a whole number of sen.
 *
 * The TypeScript twin of `Money` in app/lib/core/utils/money.dart. Same rule:
 * no floating point anywhere near a price. Amounts arrive from Postgres as
 * `bigint` sen and are formatted from integers; amounts typed by an
 * administrator are parsed into integers before they leave the browser.
 */

/** `RM125.50`, `-RM3.00`, `RM1,250.00` - the format the app prints. */
export function formatSen(sen: number | string | null | undefined): string {
  if (sen === null || sen === undefined || sen === '') return '—';
  const value = typeof sen === 'string' ? Number(sen) : sen;
  if (!Number.isSafeInteger(value)) return '—';

  const negative = value < 0;
  const magnitude = Math.abs(value);
  const ringgit = Math.floor(magnitude / 100);
  const cents = magnitude % 100;
  const grouped = ringgit.toString().replace(/\B(?=(\d{3})+(?!\d))/g, ',');
  return `${negative ? '-' : ''}RM${grouped}.${cents.toString().padStart(2, '0')}`;
}

/** `RM125.50 - RM180.00`, for pre-diagnosis estimates. */
export function formatSenRange(low: number | null, high: number | null): string {
  if (low === null || high === null) return '—';
  return `${formatSen(low)} - ${formatSen(high)}`;
}

/**
 * Parses `125`, `125.5`, `125.50`, `RM 1,250.00` into sen. Returns null for
 * anything else, including three decimal places - silently rounding a typed
 * price is how an admin sets a fee they did not mean. Mirrors
 * `Money.tryParse`.
 */
export function parseRinggit(input: string | null | undefined): number | null {
  if (input === null || input === undefined) return null;
  const cleaned = input.trim().replace(/^RM/i, '').replace(/[\s,]/g, '');
  if (!/^-?\d+(\.\d{0,2})?$/.test(cleaned)) return null;

  const negative = cleaned.startsWith('-');
  const [whole = '0', fraction = ''] = cleaned.replace('-', '').split('.');
  const sen = Number(whole) * 100 + Number(fraction.padEnd(2, '0') || '0');
  if (!Number.isSafeInteger(sen)) return null;
  return negative ? -sen : sen;
}

/** Sen to the plain decimal shown in an input box: `2000` → `20.00`. */
export function senToInput(sen: number | null | undefined): string {
  if (sen === null || sen === undefined) return '';
  return formatSen(sen).replace('RM', '').replace(/,/g, '');
}
