import Link from 'next/link';
import type { Metadata } from 'next';
import { DocumentReview } from '@/components/document-review';
import { Card, Empty, EnumChip, firstParam, LoadError, PageHeader, Tabs } from '@/components/ui';
import { humanise, VERIFICATION_STATUS } from '@/lib/domain/enums';
import { report } from '@/lib/errors';
import { formatDateTime, formatRelative } from '@/lib/format';
import { createClient } from '@/lib/supabase/server';

export const metadata: Metadata = { title: 'Verification queue' };

type Doc = {
  id: string;
  document_type: string;
  storage_path: string;
  status: string;
  created_at: string;
  reviewed_at: string | null;
  reviewer_notes: string | null;
  technician_id: string;
  technician: {
    verification_status: string;
    headline: string;
    years_experience: number;
    profile: { full_name: string; email: string; phone: string | null } | null;
  } | null;
  reviewer: { full_name: string } | null;
};

export default async function VerificationsPage({
  searchParams,
}: {
  searchParams: Promise<Record<string, string | string[] | undefined>>;
}) {
  const tab = firstParam((await searchParams).tab) === 'reviewed' ? 'reviewed' : 'pending';
  const supabase = await createClient();

  let query = supabase
    .from('technician_verifications')
    .select(
      `id, document_type, storage_path, status, created_at, reviewed_at, reviewer_notes, technician_id,
       technician:technician_profiles ( verification_status, headline, years_experience,
         profile:profiles!technician_profiles_id_fkey ( full_name, email, phone ) ),
       reviewer:profiles!technician_verifications_reviewed_by_fkey ( full_name )`,
    )
    .limit(50);

  query =
    tab === 'pending'
      ? query.eq('status', 'pending').order('created_at', { ascending: true })
      : query.neq('status', 'pending').order('reviewed_at', { ascending: false });

  const { data, error } = await query;
  const docs = (data ?? []) as unknown as Doc[];

  // Documents live in a private bucket. A short-lived link per document, issued
  // to this administrator's session, is the only way to see one.
  const signed = docs.length
    ? await supabase.storage.from('technician-documents').createSignedUrls(
        docs.map((d) => d.storage_path),
        600,
      )
    : { data: [] };

  return (
    <>
      <PageHeader
        title="Verification queue"
        description="Approving a document of an unverified technician verifies them, which is the moment they can be offered work."
      />
      <Tabs
        current={tab}
        items={[
          { key: 'pending', label: 'Waiting', href: '/verifications' },
          { key: 'reviewed', label: 'Recently reviewed', href: '/verifications?tab=reviewed' },
        ]}
      />
      {error && <LoadError message={report('verifications', error)} />}

      {docs.length === 0 ? (
        <Card>
          <Empty title={tab === 'pending' ? 'The queue is empty' : 'Nothing reviewed yet'}>
            {tab === 'pending' && 'Documents technicians upload from the app appear here, oldest first.'}
          </Empty>
        </Card>
      ) : (
        docs.map((doc, i) => {
          const url = signed.data?.[i]?.signedUrl ?? null;
          const isPdf = doc.storage_path.toLowerCase().endsWith('.pdf');
          return (
            <Card
              key={doc.id}
              title={
                <>
                  <Link href={`/technicians/${doc.technician_id}`}>
                    {doc.technician?.profile?.full_name || 'Unnamed technician'}
                  </Link>{' '}
                  <span className="muted">· {humanise(doc.document_type)}</span>
                </>
              }
              description={`Submitted ${formatRelative(doc.created_at)} · ${formatDateTime(doc.created_at)}`}
              actions={<EnumChip map={VERIFICATION_STATUS} value={doc.status} />}
            >
              <div className="grid two">
                <div>
                  {url ? (
                    isPdf ? (
                      <a className="btn secondary" href={url} target="_blank" rel="noreferrer">
                        Open PDF
                      </a>
                    ) : (
                      <a href={url} target="_blank" rel="noreferrer" className="thumbs" style={{ display: 'block' }}>
                        <img
                          src={url}
                          alt={humanise(doc.document_type)}
                          style={{ maxHeight: 280, width: '100%', objectFit: 'contain', borderRadius: 8, background: 'var(--surface-sunken)' }}
                        />
                      </a>
                    )
                  ) : (
                    <div className="notice warn">
                      The file is not in storage. Ask the technician to upload it again before approving.
                    </div>
                  )}
                  <dl className="kv" style={{ marginTop: 14 }}>
                    <dt>Technician status</dt>
                    <dd>
                      <EnumChip map={VERIFICATION_STATUS} value={doc.technician?.verification_status} />
                    </dd>
                    <dt>Headline</dt>
                    <dd>{doc.technician?.headline || '—'}</dd>
                    <dt>Experience</dt>
                    <dd>{doc.technician?.years_experience ?? 0} years</dd>
                    <dt>Contact</dt>
                    <dd>
                      {doc.technician?.profile?.email}
                      {doc.technician?.profile?.phone && ` · ${doc.technician.profile.phone}`}
                    </dd>
                  </dl>
                </div>
                <div>
                  {doc.status === 'pending' ? (
                    <DocumentReview verificationId={doc.id} />
                  ) : (
                    <dl className="kv">
                      <dt>Reviewed</dt>
                      <dd>
                        {formatDateTime(doc.reviewed_at)} by {doc.reviewer?.full_name ?? '—'}
                      </dd>
                      <dt>Notes</dt>
                      <dd>{doc.reviewer_notes ?? '—'}</dd>
                    </dl>
                  )}
                </div>
              </div>
            </Card>
          );
        })
      )}
    </>
  );
}
