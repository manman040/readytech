-- ReadyTech :: storage buckets and policies
--
-- Every bucket is private. Photographs of someone's office, a technician's
-- identity documents and the evidence behind a dispute are not things to serve
-- from a guessable public URL. Clients read through short-lived signed URLs
-- issued only to people these policies already allow.
--
-- Object keys follow "<request-or-owner-id>/<filename>", so the first path
-- segment is what the policies check.

insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values
  (
    'avatars',
    'avatars',
    false,
    2 * 1024 * 1024,
    array['image/jpeg', 'image/png', 'image/webp']
  ),
  (
    'service-evidence',
    'service-evidence',
    false,
    10 * 1024 * 1024,
    array['image/jpeg', 'image/png', 'image/webp', 'image/heic']
  ),
  (
    'technician-documents',
    'technician-documents',
    false,
    10 * 1024 * 1024,
    array['image/jpeg', 'image/png', 'application/pdf']
  ),
  (
    'message-attachments',
    'message-attachments',
    false,
    5 * 1024 * 1024,
    array['image/jpeg', 'image/png', 'image/webp']
  )
on conflict (id) do nothing;

-- ---------------------------------------------------------------------------
-- avatars
-- ---------------------------------------------------------------------------

create policy avatars_read_authenticated
  on storage.objects for select to authenticated
  using (bucket_id = 'avatars');

create policy avatars_write_own
  on storage.objects for insert to authenticated
  with check (
    bucket_id = 'avatars'
    and (storage.foldername(name))[1] = auth.uid()::text
  );

create policy avatars_update_own
  on storage.objects for update to authenticated
  using (
    bucket_id = 'avatars'
    and (storage.foldername(name))[1] = auth.uid()::text
  );

create policy avatars_delete_own
  on storage.objects for delete to authenticated
  using (
    bucket_id = 'avatars'
    and (storage.foldername(name))[1] = auth.uid()::text
  );

-- ---------------------------------------------------------------------------
-- service-evidence
-- ---------------------------------------------------------------------------

create policy service_evidence_read_participant
  on storage.objects for select to authenticated
  using (
    bucket_id = 'service-evidence'
    and (
      public.is_request_participant(
        ((storage.foldername(name))[1])::uuid
      )
      or public.is_admin()
    )
  );

create policy service_evidence_write_participant
  on storage.objects for insert to authenticated
  with check (
    bucket_id = 'service-evidence'
    and public.is_request_participant(((storage.foldername(name))[1])::uuid)
  );

-- No update or delete policy. Evidence is append-only in the database, and the
-- objects it points at have to be too, or the record means nothing.

-- ---------------------------------------------------------------------------
-- technician-documents
-- ---------------------------------------------------------------------------

create policy technician_documents_read_own
  on storage.objects for select to authenticated
  using (
    bucket_id = 'technician-documents'
    and (
      (storage.foldername(name))[1] = auth.uid()::text
      or public.is_admin()
    )
  );

create policy technician_documents_write_own
  on storage.objects for insert to authenticated
  with check (
    bucket_id = 'technician-documents'
    and (storage.foldername(name))[1] = auth.uid()::text
  );

-- A technician may replace a rejected document, but only their own.
create policy technician_documents_update_own
  on storage.objects for update to authenticated
  using (
    bucket_id = 'technician-documents'
    and (storage.foldername(name))[1] = auth.uid()::text
  );

-- ---------------------------------------------------------------------------
-- message-attachments
-- ---------------------------------------------------------------------------

create policy message_attachments_read_participant
  on storage.objects for select to authenticated
  using (
    bucket_id = 'message-attachments'
    and (
      public.is_request_participant(((storage.foldername(name))[1])::uuid)
      or public.is_admin()
    )
  );

create policy message_attachments_write_participant
  on storage.objects for insert to authenticated
  with check (
    bucket_id = 'message-attachments'
    and public.is_request_participant(((storage.foldername(name))[1])::uuid)
    and public.conversation_is_open(((storage.foldername(name))[1])::uuid)
  );
