-- ReadyTech :: messaging and notifications

create table public.messages (
  id uuid primary key default extensions.gen_random_uuid(),
  request_id uuid not null
    references public.service_requests (id) on delete cascade,
  sender_id uuid references public.profiles (id) on delete set null,

  kind public.message_kind not null default 'text',
  body text,
  -- Object key in the private message-attachments bucket.
  attachment_path text,

  read_at timestamptz,
  -- Set when a participant reports the message. Moderation reviews these
  -- rather than the whole conversation.
  reported_at timestamptz,
  reported_reason text,

  created_at timestamptz not null default now(),

  constraint messages_has_content check (
    (kind = 'text' and body is not null and char_length(body) between 1 and 4000)
    or (kind = 'image' and attachment_path is not null)
    or (kind = 'system' and body is not null)
  )
);

comment on table public.messages is
  'Scoped to one service request. There is no general inbox: customers and '
  'technicians can reach each other about a job, not in general.';

create index messages_request_idx
  on public.messages (request_id, created_at desc);

create index messages_unread_idx
  on public.messages (request_id, sender_id)
  where read_at is null;

create index messages_reported_idx
  on public.messages (reported_at)
  where reported_at is not null;

-- Conversations close with the job. Leaving them open indefinitely turns a
-- marketplace introduction into an unmoderated private channel, and takes the
-- work off-platform where none of the protections apply.
create or replace function public.conversation_is_open(request uuid)
returns boolean
language sql
stable
security definer
set search_path = public, pg_temp
as $$
  select exists (
    select 1
    from public.service_requests r
    where r.id = request
      and (
        r.status not in ('COMPLETED', 'PAID', 'WARRANTY_ACTIVE', 'CANCELLED')
        -- A grace window after completion, so a last question about the repair
        -- is not cut off mid-sentence.
        or r.completed_at > now() - interval '48 hours'
        -- A dispute reopens the channel for as long as it is being reviewed.
        or exists (
          select 1 from public.disputes d
          where d.request_id = r.id and d.status in ('open', 'under_review')
        )
      )
  );
$$;

-- ---------------------------------------------------------------------------
-- notifications
-- ---------------------------------------------------------------------------

-- Stored server side so the notification centre is consistent across a
-- reinstall or a second device, rather than living only in whatever the push
-- service happened to deliver.
create table public.notifications (
  id uuid primary key default extensions.gen_random_uuid(),
  user_id uuid not null references public.profiles (id) on delete cascade,
  type public.notification_type not null,

  title text not null,
  body text not null,
  -- Deep link payload: which request, which quotation. Kept small.
  data jsonb not null default '{}'::jsonb,

  read_at timestamptz,
  created_at timestamptz not null default now(),

  constraint notifications_title_length check (char_length(title) between 1 and 120),
  constraint notifications_body_length check (char_length(body) between 1 and 500)
);

create index notifications_user_idx
  on public.notifications (user_id, created_at desc);

create index notifications_unread_idx
  on public.notifications (user_id)
  where read_at is null;
