import { formatSen, parseRinggit, senToInput } from './money';

/**
 * How each pricing_config key is edited.
 *
 * The kind comes from the key's suffix, the same convention the database uses
 * (admin_set_pricing() treats every `*_sen` key as whole sen). A key this
 * build does not recognise is still editable as a plain number - a pricing knob
 * added by a migration must not be invisible to the people who tune it.
 */
export type PricingKind = 'money' | 'percent' | 'km' | 'seconds' | 'days' | 'weights' | 'number';

export function pricingKind(key: string, value: unknown): PricingKind {
  if (value !== null && typeof value === 'object') return 'weights';
  if (key.endsWith('_sen')) return 'money';
  if (key.endsWith('_percent')) return 'percent';
  if (key.endsWith('_km')) return 'km';
  if (key.endsWith('_seconds')) return 'seconds';
  if (key.endsWith('_days')) return 'days';
  return 'number';
}

export const UNIT: Record<PricingKind, string> = {
  money: 'RM',
  percent: '%',
  km: 'km',
  seconds: 'seconds',
  days: 'days',
  weights: '',
  number: '',
};

/** How the current value reads in the table. */
export function displayPricing(key: string, value: unknown): string {
  const kind = pricingKind(key, value);
  if (kind === 'money') return formatSen(Number(value));
  if (kind === 'weights') {
    return Object.entries(value as Record<string, number>)
      .map(([k, v]) => `${k.replace(/_/g, ' ')} ${v}`)
      .join(' · ');
  }
  const unit = UNIT[kind];
  return unit ? `${value} ${unit}` : String(value);
}

/** What goes in the input box. */
export function inputPricing(key: string, value: unknown): string {
  return pricingKind(key, value) === 'money' ? senToInput(Number(value)) : String(value);
}

/**
 * Turns a submitted field back into the JSON value Postgres stores. Returns an
 * error sentence instead of guessing; admin_set_pricing() re-checks all of it.
 */
export function parsePricing(key: string, current: unknown, raw: string): { value: number } | { error: string } {
  const kind = pricingKind(key, current);
  if (kind === 'money') {
    const sen = parseRinggit(raw);
    return sen === null || sen < 0 ? { error: 'Enter an amount in ringgit, like 5 or 5.50.' } : { value: sen };
  }
  const n = Number(raw.trim());
  if (raw.trim() === '' || !Number.isFinite(n) || n < 0) return { error: 'Enter a number of zero or more.' };
  if ((kind === 'km' || kind === 'seconds' || kind === 'days') && !Number.isInteger(n)) {
    return { error: `Enter a whole number of ${UNIT[kind]}.` };
  }
  return { value: n };
}
