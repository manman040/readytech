import { notFound } from 'next/navigation';
import { Card, PageHeader } from '@/components/ui';
import { createClient } from '@/lib/supabase/server';
import { CategoryForm, type Category } from '../category-form';

type Params = Promise<{ id: string }>;
const UUID = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;

export const metadata = { title: 'Edit category' };

export default async function CategoryPage({ params }: { params: Params }) {
  const { id } = await params;

  if (id === 'new') {
    return (
      <>
        <PageHeader crumbs={[{ href: '/catalogue', label: 'Service catalogue' }]} title="New category" />
        <Card>
          <CategoryForm />
        </Card>
      </>
    );
  }

  if (!UUID.test(id)) notFound();
  const supabase = await createClient();
  const { data } = await supabase.from('service_categories').select('*').eq('id', id).maybeSingle();
  if (!data) notFound();

  const { count } = await supabase
    .from('service_requests')
    .select('id', { count: 'exact', head: true })
    .eq('category_id', id);

  return (
    <>
      <PageHeader
        crumbs={[{ href: '/catalogue', label: 'Service catalogue' }]}
        title={data.name}
        description={`${count ?? 0} job(s) filed under this category`}
      />
      <Card>
        <CategoryForm category={data as Category} />
      </Card>
    </>
  );
}
