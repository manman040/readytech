import Link from 'next/link';
import type { Metadata } from 'next';
import { Card, Chip, Empty, LoadError, PageHeader } from '@/components/ui';
import { DEVICE_TYPE, describe } from '@/lib/domain/enums';
import { formatSen, formatSenRange } from '@/lib/domain/money';
import { report } from '@/lib/errors';
import { createClient } from '@/lib/supabase/server';

export const metadata: Metadata = { title: 'Service catalogue' };

export default async function CataloguePage() {
  const supabase = await createClient();
  const { data, error } = await supabase
    .from('service_categories')
    .select('*')
    .order('sort_order')
    .order('name');

  return (
    <>
      <PageHeader
        title="Service catalogue"
        description="What customers can ask for and what it roughly costs. The app reads this live - no release needed."
        actions={
          <Link className="btn" href="/catalogue/new">
            New category
          </Link>
        }
      />
      {error && <LoadError message={report('catalogue', error)} />}
      <Card flush>
        {(data ?? []).length === 0 ? (
          <Empty title="No categories" />
        ) : (
          <div className="table-wrap">
            <table>
              <thead>
                <tr>
                  <th>Category</th>
                  <th>Devices</th>
                  <th className="num">Diagnosis</th>
                  <th className="num">Typical repair</th>
                  <th className="num">Warranty</th>
                  <th>State</th>
                </tr>
              </thead>
              <tbody>
                {(data ?? []).map((c) => (
                  <tr key={c.id}>
                    <td>
                      <Link href={`/catalogue/${c.id}`} className="strong">
                        {c.name}
                      </Link>
                      <span className="sub mono">{c.slug}</span>
                    </td>
                    <td className="small">
                      {(c.device_types as string[]).map((d) => describe(DEVICE_TYPE, d).label).join(', ') || (
                        <span className="faint">Any</span>
                      )}
                    </td>
                    <td className="num">{formatSen(c.diagnosis_fee_sen)}</td>
                    <td className="num">{formatSenRange(c.estimated_repair_min_sen, c.estimated_repair_max_sen)}</td>
                    <td className="num">{c.default_warranty_days} days</td>
                    <td>
                      <div className="actions">
                        {c.is_active ? <Chip tone="success" label="Offered" /> : <Chip tone="neutral" label="Hidden" />}
                        {c.requires_specialist && <Chip tone="info" label="Specialist" plain />}
                      </div>
                    </td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        )}
      </Card>
      <p className="muted small">
        Categories are hidden rather than deleted: past jobs refer to them, and a service history that loses its
        category is harder to read.
      </p>
    </>
  );
}
