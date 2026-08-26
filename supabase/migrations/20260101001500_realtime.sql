-- ReadyTech :: realtime publication
--
-- Only the tables the app genuinely subscribes to are published. Adding a table
-- here has a cost: every write is decoded from the WAL and fanned out, whether
-- or not anyone is listening. Service history, pricing and reputation are read
-- on demand instead.
--
-- Publication carries no authorisation of its own. Realtime applies the same
-- row level security policies as any other read, so a subscriber receives only
-- rows they could have selected.

do $$
begin
  if not exists (
    select 1 from pg_publication where pubname = 'supabase_realtime'
  ) then
    create publication supabase_realtime;
  end if;
end;
$$;

-- Job status, so both sides see the lifecycle advance without polling.
alter publication supabase_realtime add table public.service_requests;

-- Live tracking. Written at a deliberately low frequency by the technician app
-- - see docs/ARCHITECTURE.md on the location update interval.
alter publication supabase_realtime add table public.technician_locations;

-- Chat.
alter publication supabase_realtime add table public.messages;

-- The notification centre.
alter publication supabase_realtime add table public.notifications;

-- Quotations, so a customer sees one arrive while looking at the job.
alter publication supabase_realtime add table public.quotations;

-- Job offers, so a technician's dashboard reacts without a refresh.
alter publication supabase_realtime add table public.technician_assignments;

-- REPLICA IDENTITY FULL makes the old row available on update and delete
-- events. Without it a subscriber gets only the primary key and cannot tell
-- which status a job moved *from*, which is exactly what the timeline needs.
alter table public.service_requests replica identity full;
alter table public.quotations replica identity full;
alter table public.technician_assignments replica identity full;
