import type { Metadata } from 'next';
import { ActionForm, Submit } from '@/components/action-form';
import { Card, LoadError, PageHeader } from '@/components/ui';
import { displayPricing, inputPricing, pricingKind, UNIT } from '@/lib/domain/pricing';
import { humanise } from '@/lib/domain/enums';
import { report } from '@/lib/errors';
import { formatDateTime } from '@/lib/format';
import { createClient } from '@/lib/supabase/server';
import { savePricing } from './actions';

export const metadata: Metadata = { title: 'Pricing' };

type Row = {
  key: string;
  value: unknown;
  description: string;
  updated_at: string;
  editor: { full_name: string } | null;
};

const GROUPS: { title: string; description: string; keys: (key: string) => boolean }[] = [
  {
    title: 'Customer fees',
    description: 'What goes on a customer’s estimate and quotation.',
    keys: (k) => /fee|surcharge|warranty/.test(k) && !k.startsWith('cancellation'),
  },
  {
    title: 'Commission',
    description: 'Applied when a job settles. Each earning keeps the rate in force when it was paid.',
    keys: (k) => k.startsWith('commission'),
  },
  {
    title: 'Cancellation',
    description: 'Applied by the cancellation policy.',
    keys: (k) => k.startsWith('cancellation'),
  },
  {
    title: 'Matching',
    description: 'How far matching looks and how it ranks. Never shown to customers or technicians.',
    keys: (k) => k.startsWith('matching') || k.startsWith('offer'),
  },
];

export default async function PricingPage() {
  const supabase = await createClient();
  const { data, error } = await supabase
    .from('pricing_config')
    .select('key, value, description, updated_at, editor:profiles ( full_name )')
    .order('key');
  const rows = (data ?? []) as unknown as Row[];

  const placed = new Set<string>();
  const grouped = GROUPS.map((g) => {
    const items = rows.filter((r) => !placed.has(r.key) && g.keys(r.key));
    items.forEach((r) => placed.add(r.key));
    return { ...g, items };
  });
  const other = rows.filter((r) => !placed.has(r.key));
  if (other.length) grouped.push({ title: 'Other', description: '', keys: () => false, items: other });

  return (
    <>
      <PageHeader
        title="Pricing"
        description="Every fee the marketplace charges lives here, not in the app. Each change is checked by the database and written to the audit log."
      />
      {error && <LoadError message={report('pricing', error)} />}

      {grouped
        .filter((g) => g.items.length)
        .map((group) => (
          <Card key={group.title} title={group.title} description={group.description}>
            <div className="stack">
              {group.items.map((row) => (
                <PricingRow key={row.key} row={row} />
              ))}
            </div>
          </Card>
        ))}
    </>
  );
}

function PricingRow({ row }: { row: Row }) {
  const kind = pricingKind(row.key, row.value);
  return (
    <div className="grid two" style={{ alignItems: 'start', paddingBottom: 14, borderBottom: '1px solid var(--hairline)' }}>
      <div>
        <div className="strong">{humanise(row.key.replace(/_sen$/, ''))}</div>
        <p className="muted small">{row.description}</p>
        <p className="faint small" style={{ marginTop: 4 }}>
          <code>{row.key}</code> · now <strong>{displayPricing(row.key, row.value)}</strong> · updated{' '}
          {formatDateTime(row.updated_at)}
          {row.editor?.full_name && ` by ${row.editor.full_name}`}
        </p>
      </div>
      <ActionForm action={savePricing} className="form">
        <input type="hidden" name="key" value={row.key} />
        {kind === 'weights' ? (
          <div className="form-row">
            {Object.entries(row.value as Record<string, number>).map(([name, weight]) => (
              <label key={name} className="field">
                {humanise(name)}
                <input type="number" name={`w.${name}`} min={0} step="any" defaultValue={weight} required />
              </label>
            ))}
          </div>
        ) : (
          <label className="field">
            {UNIT[kind] ? `Value (${UNIT[kind]})` : 'Value'}
            <input
              type="text"
              inputMode="decimal"
              name="value"
              required
              defaultValue={inputPricing(row.key, row.value)}
            />
          </label>
        )}
        <div>
          <Submit variant="secondary" small>
            Save
          </Submit>
        </div>
      </ActionForm>
    </div>
  );
}
