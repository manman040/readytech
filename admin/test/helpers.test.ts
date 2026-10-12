import { describe, expect, it } from 'vitest';
import { userMessage } from '@/lib/errors';
import { formatRelative } from '@/lib/format';
import { formatSen, formatSenRange, parseRinggit, senToInput } from '@/lib/domain/money';
import { displayPricing, parsePricing, pricingKind } from '@/lib/domain/pricing';
import { searchTerm } from '@/lib/queries';

describe('money', () => {
  it('formats sen the way the app does', () => {
    expect(formatSen(12550)).toBe('RM125.50');
    expect(formatSen(0)).toBe('RM0.00');
    expect(formatSen(5)).toBe('RM0.05');
    expect(formatSen(-300)).toBe('-RM3.00');
    expect(formatSen(123456789)).toBe('RM1,234,567.89');
    expect(formatSen('2000')).toBe('RM20.00');
    expect(formatSen(null)).toBe('—');
    expect(formatSenRange(6000, 11000)).toBe('RM60.00 - RM110.00');
  });

  it('parses typed ringgit into whole sen without rounding', () => {
    expect(parseRinggit('125')).toBe(12500);
    expect(parseRinggit('125.5')).toBe(12550);
    expect(parseRinggit('125.50')).toBe(12550);
    expect(parseRinggit('RM 1,250.00')).toBe(125000);
    expect(parseRinggit('0.1')).toBe(10);
    expect(parseRinggit('-3')).toBe(-300);
  });

  it('refuses anything that is not a clean amount', () => {
    for (const bad of ['', 'abc', '1.234', '1.2.3', '12a', '.', 'RM']) {
      expect(parseRinggit(bad), bad).toBeNull();
    }
  });

  it('round-trips through an input box', () => {
    expect(senToInput(2000)).toBe('20.00');
    expect(parseRinggit(senToInput(123456))).toBe(123456);
  });
});

describe('errors', () => {
  it('shows our own RT messages verbatim', () => {
    expect(userMessage({ code: 'RT409', message: 'That document has already been reviewed.' })).toBe(
      'That document has already been reviewed.',
    );
  });

  it('never shows a raw Postgres message', () => {
    const message = userMessage({ code: '23514', message: 'new row violates check constraint "x" on table "payments"' });
    expect(message).not.toContain('payments');
    expect(userMessage({ code: 'XX000', message: 'internal detail' })).not.toContain('internal');
  });
});

describe('pricing', () => {
  it('infers how to edit a key from its name', () => {
    expect(pricingKind('platform_fee_sen', 500)).toBe('money');
    expect(pricingKind('commission_percent', 10)).toBe('percent');
    expect(pricingKind('matching_radius_km', 15)).toBe('km');
    expect(pricingKind('matching_weights', { distance: 20 })).toBe('weights');
    expect(displayPricing('platform_fee_sen', 500)).toBe('RM5.00');
  });

  it('parses money as sen and refuses fractional distances', () => {
    expect(parsePricing('platform_fee_sen', 500, '7.50')).toEqual({ value: 750 });
    expect(parsePricing('commission_percent', 10, '12.5')).toEqual({ value: 12.5 });
    expect(parsePricing('matching_radius_km', 15, '2.5')).toHaveProperty('error');
    expect(parsePricing('platform_fee_sen', 500, '-1')).toHaveProperty('error');
  });
});

describe('search', () => {
  it('strips PostgREST filter syntax from user input', () => {
    expect(searchTerm('RT-26,status.eq.PAID')).toBe('RT-26 status.eq.PAID');
    expect(searchTerm('a)')).toBeNull();
    expect(searchTerm('adam*%')).toBe('adam');
  });
});

describe('dates', () => {
  it('reads relative time', () => {
    const now = new Date('2026-10-05T12:00:00Z');
    expect(formatRelative('2026-10-05T11:59:50Z', now)).toBe('just now');
    expect(formatRelative('2026-10-05T11:55:00Z', now)).toBe('5 min ago');
    expect(formatRelative('2026-10-03T12:00:00Z', now)).toBe('2 days ago');
  });
});
