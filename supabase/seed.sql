-- ReadyTech :: development seed data
--
-- Enough of a marketplace to demonstrate every screen without anyone having to
-- register accounts by hand: customers, verified and unverified technicians,
-- devices, addresses, and service requests parked at the interesting points of
-- the lifecycle.
--
-- The service catalogue is deliberately NOT here - it is reference data the
-- product cannot run without, so it ships in
-- 20260101001700_service_catalogue.sql and reaches hosted projects too. The
-- category ids referenced below come from that migration.
--
-- Every account uses the password  ReadyTech123!  and an @readytech.test
-- address. Run with:  supabase db reset

-- ---------------------------------------------------------------------------
-- Safety
-- ---------------------------------------------------------------------------

-- Seed data in a real database would be indistinguishable from real customers
-- and real money. Refuse to run anywhere that already holds a genuine account.
do $$
begin
  if exists (
    select 1 from auth.users where email not like '%@readytech.test'
  ) then
    raise exception
      'Refusing to seed: this database contains non-seed accounts. '
      'The seed is for local development only.';
  end if;
end;
$$;

-- ---------------------------------------------------------------------------
-- Accounts
-- ---------------------------------------------------------------------------

-- profiles and a default customer role are created by the handle_new_user
-- trigger, exactly as they are for a real sign-up.
-- The four empty strings are not decoration. confirmation_token,
-- recovery_token, email_change_token_new and email_change are nullable with no
-- default, but GoTrue scans them into a non-nullable Go string. Leaving them
-- NULL makes every sign-in fail with "Database error querying schema", which
-- looks like a broken password rather than a broken seed.
insert into auth.users (
  instance_id, id, aud, role, email, encrypted_password,
  email_confirmed_at, created_at, updated_at,
  raw_app_meta_data, raw_user_meta_data,
  confirmation_token, recovery_token, email_change_token_new, email_change
)
select
  '00000000-0000-0000-0000-000000000000',
  person.id,
  'authenticated',
  'authenticated',
  person.email,
  extensions.crypt('ReadyTech123!', extensions.gen_salt('bf')),
  now(),
  now() - (person.age_days || ' days')::interval,
  now(),
  '{"provider":"email","providers":["email"]}'::jsonb,
  jsonb_build_object('full_name', person.full_name, 'phone', person.phone),
  '', '', '', ''
from (values
  -- Customers
  ('11111111-1111-4111-8111-000000000001'::uuid, 'adam@readytech.test',    'Adam Rahman',        '+60123456701', 120),
  ('11111111-1111-4111-8111-000000000002'::uuid, 'siti@readytech.test',    'Siti Nurhaliza',     '+60123456702', 96),
  ('11111111-1111-4111-8111-000000000003'::uuid, 'wei@readytech.test',     'Wei Ling Tan',       '+60123456703', 74),
  ('11111111-1111-4111-8111-000000000004'::uuid, 'kumar@readytech.test',   'Kumar Subramaniam',  '+60123456704', 51),
  ('11111111-1111-4111-8111-000000000005'::uuid, 'nurul@readytech.test',   'Nurul Aina',         '+60123456705', 33),
  ('11111111-1111-4111-8111-000000000006'::uuid, 'daniel@readytech.test',  'Daniel Lim',         '+60123456706', 21),

  -- Technicians
  ('22222222-2222-4222-8222-000000000001'::uuid, 'ahmad@readytech.test',   'Ahmad Zulkifli',     '+60123456801', 300),
  ('22222222-2222-4222-8222-000000000002'::uuid, 'faizal@readytech.test',  'Faizal Hassan',      '+60123456802', 280),
  ('22222222-2222-4222-8222-000000000003'::uuid, 'mei@readytech.test',     'Mei Chen Wong',      '+60123456803', 260),
  ('22222222-2222-4222-8222-000000000004'::uuid, 'raj@readytech.test',     'Rajesh Nair',        '+60123456804', 240),
  ('22222222-2222-4222-8222-000000000005'::uuid, 'hafiz@readytech.test',   'Hafiz Ibrahim',      '+60123456805', 200),
  ('22222222-2222-4222-8222-000000000006'::uuid, 'jason@readytech.test',   'Jason Teoh',         '+60123456806', 180),
  ('22222222-2222-4222-8222-000000000007'::uuid, 'aisyah@readytech.test',  'Aisyah Kamarudin',   '+60123456807', 150),
  ('22222222-2222-4222-8222-000000000008'::uuid, 'vincent@readytech.test', 'Vincent Ng',         '+60123456808', 120),
  ('22222222-2222-4222-8222-000000000009'::uuid, 'shafiq@readytech.test',  'Shafiq Osman',       '+60123456809',  90),
  ('22222222-2222-4222-8222-000000000010'::uuid, 'priya@readytech.test',   'Priya Devi',         '+60123456810',  45),

  -- Administrator
  ('33333333-3333-4333-8333-000000000001'::uuid, 'admin@readytech.test',   'ReadyTech Admin',    '+60123456900', 365)
) as person(id, email, full_name, phone, age_days);

-- ---------------------------------------------------------------------------
-- Roles
-- ---------------------------------------------------------------------------

update public.user_roles
   set role = 'technician'
 where user_id::text like '22222222-%';

update public.user_roles
   set role = 'admin'
 where user_id::text like '33333333-%';

-- ---------------------------------------------------------------------------
-- Technician profiles
-- ---------------------------------------------------------------------------

-- Spread across Kuala Lumpur, Petaling Jaya and Shah Alam, so distance-based
-- matching produces a meaningful ordering rather than a tie.
insert into public.technician_profiles (
  id, headline, bio, years_experience,
  base_latitude, base_longitude, service_radius_km,
  is_available, accepts_emergency, verification_status, verified_at,
  rating_average, rating_count, completed_jobs, cancelled_jobs,
  offers_received, offers_accepted
) values
  ('22222222-2222-4222-8222-000000000001',
   'Laptop hardware specialist',
   'Twelve years repairing laptops. Screen, board and charging port work, with '
   'parts sourced the same day where possible.',
   12, 3.139000, 101.686900, 20, true, true, 'approved', now() - interval '200 days',
   4.85, 132, 214, 6, 268, 231),

  ('22222222-2222-4222-8222-000000000002',
   'Networks and small office IT',
   'Sets up and fixes office networks, routers and shared printers.',
   9, 3.107600, 101.606100, 25, true, true, 'approved', now() - interval '180 days',
   4.72, 88, 141, 5, 190, 158),

  ('22222222-2222-4222-8222-000000000003',
   'Windows, macOS and data recovery',
   'Operating system migrations and recovery from failing drives.',
   11, 3.157400, 101.712300, 18, true, false, 'approved', now() - interval '170 days',
   4.91, 156, 233, 3, 281, 254),

  ('22222222-2222-4222-8222-000000000004',
   'Desktop and gaming PC builds',
   'Diagnoses and repairs desktops, including cooling and power supply faults.',
   8, 3.073800, 101.518300, 22, true, false, 'approved', now() - interval '150 days',
   4.64, 71, 118, 7, 168, 133),

  ('22222222-2222-4222-8222-000000000005',
   'Printers and office equipment',
   'Printer, scanner and copier faults for homes and small offices.',
   7, 3.201200, 101.615900, 20, true, false, 'approved', now() - interval '140 days',
   4.55, 64, 97, 6, 145, 108),

  ('22222222-2222-4222-8222-000000000006',
   'Virus removal and system clean-up',
   'Removes infections and restores a machine to a usable state without a wipe '
   'where that is possible.',
   6, 3.118900, 101.677200, 15, true, true, 'approved', now() - interval '120 days',
   4.78, 93, 149, 4, 178, 161),

  -- Radius 25 rather than 16 on purpose: the open offer further down is for a
  -- job 22 km away in Setia Alam, and rank_technicians() filters on this
  -- column. A narrower radius would make the seed contradict the matching
  -- function it is meant to demonstrate.
  ('22222222-2222-4222-8222-000000000007',
   'Mobile and tablet repairs',
   'Screen and battery replacement for phones and tablets.',
   5, 3.166500, 101.652800, 25, true, false, 'approved', now() - interval '100 days',
   4.69, 58, 88, 3, 112, 94),

  ('22222222-2222-4222-8222-000000000008',
   'Servers, NAS and backups',
   'Small business servers, network storage and backup that actually restores.',
   14, 3.048600, 101.583200, 30, false, true, 'approved', now() - interval '90 days',
   4.88, 42, 76, 1, 95, 82),

  -- Verification still in the queue, so the admin console has something to
  -- review and the app has an unverified state to render.
  ('22222222-2222-4222-8222-000000000009',
   'General IT support',
   'Laptop and desktop repairs, software setup and troubleshooting.',
   4, 3.128700, 101.694400, 12, false, false, 'pending', null,
   0, 0, 0, 0, 0, 0),

  ('22222222-2222-4222-8222-000000000010',
   'Laptop and software support',
   'Newly joined. Laptop repairs and Windows support.',
   3, 3.145200, 101.709800, 14, true, false, 'approved', now() - interval '20 days',
   4.40, 5, 8, 0, 12, 9);

-- Skills. Proficiency 5 marks a genuine specialist and carries the most weight
-- in matching.
insert into public.technician_skills (technician_id, category_id, proficiency, is_primary)
values
  ('22222222-2222-4222-8222-000000000001', '44444444-0000-4000-8000-000000000001', 5, true),
  ('22222222-2222-4222-8222-000000000001', '44444444-0000-4000-8000-000000000003', 4, false),
  ('22222222-2222-4222-8222-000000000001', '44444444-0000-4000-8000-000000000011', 3, false),

  ('22222222-2222-4222-8222-000000000002', '44444444-0000-4000-8000-000000000005', 5, true),
  ('22222222-2222-4222-8222-000000000002', '44444444-0000-4000-8000-000000000012', 5, false),
  ('22222222-2222-4222-8222-000000000002', '44444444-0000-4000-8000-000000000010', 3, false),

  ('22222222-2222-4222-8222-000000000003', '44444444-0000-4000-8000-000000000007', 5, true),
  ('22222222-2222-4222-8222-000000000003', '44444444-0000-4000-8000-000000000008', 5, false),
  ('22222222-2222-4222-8222-000000000003', '44444444-0000-4000-8000-000000000002', 4, false),

  ('22222222-2222-4222-8222-000000000004', '44444444-0000-4000-8000-000000000003', 5, true),
  ('22222222-2222-4222-8222-000000000004', '44444444-0000-4000-8000-000000000001', 3, false),

  ('22222222-2222-4222-8222-000000000005', '44444444-0000-4000-8000-000000000004', 5, true),
  ('22222222-2222-4222-8222-000000000005', '44444444-0000-4000-8000-000000000011', 4, false),

  ('22222222-2222-4222-8222-000000000006', '44444444-0000-4000-8000-000000000006', 5, true),
  ('22222222-2222-4222-8222-000000000006', '44444444-0000-4000-8000-000000000002', 4, false),

  ('22222222-2222-4222-8222-000000000007', '44444444-0000-4000-8000-000000000009', 5, true),

  ('22222222-2222-4222-8222-000000000008', '44444444-0000-4000-8000-000000000010', 5, true),
  ('22222222-2222-4222-8222-000000000008', '44444444-0000-4000-8000-000000000005', 4, false),

  ('22222222-2222-4222-8222-000000000009', '44444444-0000-4000-8000-000000000001', 3, true),
  ('22222222-2222-4222-8222-000000000009', '44444444-0000-4000-8000-000000000002', 3, false),

  ('22222222-2222-4222-8222-000000000010', '44444444-0000-4000-8000-000000000001', 3, true),
  ('22222222-2222-4222-8222-000000000010', '44444444-0000-4000-8000-000000000002', 4, false);

-- Live positions for the technicians who are online.
insert into public.technician_locations (technician_id, latitude, longitude, updated_at)
values
  ('22222222-2222-4222-8222-000000000001', 3.141200, 101.688300, now() - interval '40 seconds'),
  ('22222222-2222-4222-8222-000000000002', 3.109100, 101.608800, now() - interval '2 minutes'),
  ('22222222-2222-4222-8222-000000000003', 3.155900, 101.710400, now() - interval '1 minute'),
  ('22222222-2222-4222-8222-000000000004', 3.076200, 101.521500, now() - interval '5 minutes'),
  ('22222222-2222-4222-8222-000000000006', 3.120300, 101.679900, now() - interval '30 seconds'),
  ('22222222-2222-4222-8222-000000000010', 3.146800, 101.707200, now() - interval '3 minutes');

-- A verification document waiting in the admin queue.
insert into public.technician_verifications
  (technician_id, document_type, storage_path, status)
values
  ('22222222-2222-4222-8222-000000000009', 'national_id',
   '22222222-2222-4222-8222-000000000009/national-id.jpg', 'pending');

-- ---------------------------------------------------------------------------
-- Customer devices and addresses
-- ---------------------------------------------------------------------------

insert into public.devices
  (id, owner_id, device_type, nickname, brand, model, serial_number, purchase_date, notes)
values
  ('55555555-0000-4000-8000-000000000001', '11111111-1111-4111-8111-000000000001',
   'laptop', 'Work laptop', 'ASUS', 'TUF Gaming F15', 'S4N2029A11', '2024-03-15',
   'Used for work. Screen flickered once before.'),
  ('55555555-0000-4000-8000-000000000002', '11111111-1111-4111-8111-000000000001',
   'printer', 'Home printer', 'Epson', 'L3210', null, '2023-11-02', null),
  ('55555555-0000-4000-8000-000000000003', '11111111-1111-4111-8111-000000000002',
   'laptop', 'MacBook', 'Apple', 'MacBook Air M2', 'C02XQ1AB', '2023-08-20', null),
  ('55555555-0000-4000-8000-000000000004', '11111111-1111-4111-8111-000000000003',
   'desktop', 'Gaming PC', 'Custom', 'Ryzen 5600 / RTX 3060', null, '2022-12-01',
   'Built it myself. Two SSDs.'),
  ('55555555-0000-4000-8000-000000000005', '11111111-1111-4111-8111-000000000004',
   'network_device', 'Office router', 'TP-Link', 'Archer AX55', null, null,
   'Serves about twelve staff.'),
  ('55555555-0000-4000-8000-000000000006', '11111111-1111-4111-8111-000000000005',
   'mobile', 'Personal phone', 'Samsung', 'Galaxy S23', null, '2024-06-10', null);

insert into public.saved_addresses
  (user_id, label, name, address_line, city, state, postcode, latitude, longitude, directions, is_default)
values
  ('11111111-1111-4111-8111-000000000001', 'home', 'Home',
   'Blok C-12-3, Residensi Suasana, Jalan Ampang', 'Kuala Lumpur', 'Wilayah Persekutuan', '50450',
   3.158900, 101.716400, 'Guardhouse will call up. Lift lobby B.', true),
  ('11111111-1111-4111-8111-000000000002', 'home', 'Apartment',
   'A-7-2, Pangsapuri Sri Kenanga, Jalan Kuchai Lama', 'Kuala Lumpur', 'Wilayah Persekutuan', '58200',
   3.089700, 101.687300, null, true),
  ('11111111-1111-4111-8111-000000000003', 'home', 'House',
   '22, Jalan SS2/24', 'Petaling Jaya', 'Selangor', '47300',
   3.117200, 101.621800, 'Blue gate, corner lot.', true),
  ('11111111-1111-4111-8111-000000000004', 'office', 'Office',
   'Unit 5-3, Menara Bangsar, Jalan Maarof', 'Kuala Lumpur', 'Wilayah Persekutuan', '59100',
   3.130400, 101.670900, 'Ask reception for the IT room.', true),
  ('11111111-1111-4111-8111-000000000005', 'home', 'Home',
   '18, Jalan Setia Prima, Setia Alam', 'Shah Alam', 'Selangor', '40170',
   3.104600, 101.452200, null, true);

-- ---------------------------------------------------------------------------
-- Service requests
-- ---------------------------------------------------------------------------

-- Each request sits at a different point in the lifecycle, so every screen has
-- something real to render. Statuses are inserted directly here rather than
-- driven through the state machine, which is what the seed is for; the guard
-- trigger still governs every transition made by the running application.

insert into public.service_requests (
  id, reference, customer_id, device_id, category_id, assigned_technician_id,
  problem_description, problem_summary, classified_device_type,
  classification_confidence, classified_by,
  urgency, status, matching_mode,
  service_latitude, service_longitude, service_address, address_directions,
  contact_phone, arrival_code, arrival_code_verified_at,
  estimated_total_min_sen, estimated_total_max_sen,
  estimated_distance_km, estimated_eta_minutes,
  requested_at, matched_at, assigned_at, arrived_at, diagnosis_at,
  approved_at, completed_at, paid_at
) values
  -- 1. Finished, paid and under warranty. The full record: diagnosis,
  --    quotation, evidence, payment, warranty and a review.
  ('66666666-0000-4000-8000-000000000001', 'RT-26-000001',
   '11111111-1111-4111-8111-000000000001', '55555555-0000-4000-8000-000000000001',
   '44444444-0000-4000-8000-000000000001', '22222222-2222-4222-8222-000000000001',
   'My laptop turns on but the screen stays black. I can hear the fan running.',
   'Laptop powers on with no display', 'laptop', 0.910, 'rule_based',
   'normal', 'WARRANTY_ACTIVE', 'user_selected',
   3.158900, 101.716400, 'Blok C-12-3, Residensi Suasana, Jalan Ampang, 50450 Kuala Lumpur',
   'Guardhouse will call up. Lift lobby B.',
   '+60123456701', '4821', now() - interval '9 days' + interval '38 minutes',
   6000, 11000, 3.20, 14,
   now() - interval '9 days', now() - interval '9 days' + interval '2 minutes',
   now() - interval '9 days' + interval '6 minutes',
   now() - interval '9 days' + interval '35 minutes',
   now() - interval '9 days' + interval '45 minutes',
   now() - interval '9 days' + interval '70 minutes',
   now() - interval '9 days' + interval '150 minutes',
   now() - interval '9 days' + interval '155 minutes'),

  -- 2. Waiting on the customer to approve a quotation.
  ('66666666-0000-4000-8000-000000000002', 'RT-26-000002',
   '11111111-1111-4111-8111-000000000003', '55555555-0000-4000-8000-000000000004',
   '44444444-0000-4000-8000-000000000003', '22222222-2222-4222-8222-000000000004',
   'Desktop shuts down by itself after about ten minutes of gaming. Fans get very loud first.',
   'Desktop shutting down under load', 'desktop', 0.870, 'rule_based',
   'normal', 'AWAITING_CUSTOMER_APPROVAL', 'auto',
   3.117200, 101.621800, '22, Jalan SS2/24, 47300 Petaling Jaya, Selangor',
   'Blue gate, corner lot.',
   '+60123456703', '7134', now() - interval '95 minutes',
   7000, 15000, 5.80, 22,
   now() - interval '3 hours', now() - interval '3 hours' + interval '1 minute',
   now() - interval '3 hours' + interval '4 minutes',
   now() - interval '100 minutes', now() - interval '90 minutes',
   null, null, null),

  -- 3. Live job: the technician is on the way. This is the one to open when
  --    demonstrating tracking.
  ('66666666-0000-4000-8000-000000000003', 'RT-26-000003',
   '11111111-1111-4111-8111-000000000004', '55555555-0000-4000-8000-000000000005',
   '44444444-0000-4000-8000-000000000005', '22222222-2222-4222-8222-000000000002',
   'The whole office has lost internet. The router lights are on but nobody can connect.',
   'Office network down', 'network_device', 0.940, 'rule_based',
   'emergency', 'TECHNICIAN_ON_THE_WAY', 'auto',
   3.130400, 101.670900, 'Unit 5-3, Menara Bangsar, Jalan Maarof, 59100 Kuala Lumpur',
   'Ask reception for the IT room.',
   '+60123456704', '2946', null,
   9000, 31000, 7.10, 26,
   now() - interval '18 minutes', now() - interval '17 minutes',
   now() - interval '15 minutes', null, null, null, null, null),

  -- 4. Still matching, so the "finding a technician" state has an example.
  ('66666666-0000-4000-8000-000000000004', 'RT-26-000004',
   '11111111-1111-4111-8111-000000000005', '55555555-0000-4000-8000-000000000006',
   '44444444-0000-4000-8000-000000000009', null,
   'Phone screen cracked after I dropped it. Touch still works but there are lines across the display.',
   'Cracked phone screen', 'mobile', 0.960, 'rule_based',
   'normal', 'MATCHING', 'auto',
   3.104600, 101.452200, '18, Jalan Setia Prima, Setia Alam, 40170 Shah Alam, Selangor',
   null,
   '+60123456705', '5507', null,
   8000, 48000, null, null,
   now() - interval '3 minutes', now() - interval '2 minutes',
   null, null, null, null, null, null),

  -- 5. Cancelled. Kept on the record, which is the point.
  ('66666666-0000-4000-8000-000000000005', 'RT-26-000005',
   '11111111-1111-4111-8111-000000000002', '55555555-0000-4000-8000-000000000003',
   '44444444-0000-4000-8000-000000000002', '22222222-2222-4222-8222-000000000003',
   'MacBook is extremely slow since the last update and the fan runs constantly.',
   'Laptop running slowly after update', 'laptop', 0.820, 'rule_based',
   'normal', 'CANCELLED', 'user_selected',
   3.089700, 101.687300, 'A-7-2, Pangsapuri Sri Kenanga, Jalan Kuchai Lama, 58200 Kuala Lumpur',
   null,
   '+60123456702', '3390', null,
   5500, 15500, 4.40, 18,
   now() - interval '5 days', now() - interval '5 days' + interval '1 minute',
   now() - interval '5 days' + interval '3 minutes',
   null, null, null, null, null);

update public.service_requests
   set cancelled_at = now() - interval '5 days' + interval '25 minutes'
 where id = '66666666-0000-4000-8000-000000000005';

-- Follow-up answers for the completed job.
insert into public.service_request_items
  (request_id, question_key, question_text, answer_text, sort_order)
values
  ('66666666-0000-4000-8000-000000000001', 'powers_on',
   'Does the laptop power on?', 'Yes', 1),
  ('66666666-0000-4000-8000-000000000001', 'fan_audible',
   'Can you hear the fan?', 'Yes', 2),
  ('66666666-0000-4000-8000-000000000001', 'external_monitor',
   'Does an external monitor work?', 'Yes', 3),
  ('66666666-0000-4000-8000-000000000002', 'shutdown_timing',
   'When does it shut down?', 'Only under load, after about ten minutes', 1),
  ('66666666-0000-4000-8000-000000000002', 'cleaned_recently',
   'Has the inside been cleaned in the last year?', 'Not sure', 2);

-- Offers, including one that was declined and one that was withdrawn when
-- somebody else accepted first.
insert into public.technician_assignments
  (request_id, technician_id, status, rank, score, distance_km, eta_minutes,
   offered_at, expires_at, responded_at, decline_reason)
values
  ('66666666-0000-4000-8000-000000000003', '22222222-2222-4222-8222-000000000002',
   'accepted', 1, 87.40, 7.10, 26,
   now() - interval '17 minutes', now() - interval '16 minutes',
   now() - interval '15 minutes', null),
  ('66666666-0000-4000-8000-000000000003', '22222222-2222-4222-8222-000000000008',
   'withdrawn', 2, 74.10, 11.80, 33,
   now() - interval '17 minutes', now() - interval '16 minutes',
   now() - interval '15 minutes', null),
  -- A live offer for the technician dashboard to render. A real offer window is
  -- pricing_config.offer_timeout_seconds (45 seconds); this one is deliberately
  -- long, because an offer that expires before anyone has finished running
  -- `db reset` is not demo data.
  ('66666666-0000-4000-8000-000000000004', '22222222-2222-4222-8222-000000000007',
   'offered', 1, 79.60, 22.40, 59,
   now() - interval '2 minutes', now() + interval '4 hours', null, null),
  ('66666666-0000-4000-8000-000000000002', '22222222-2222-4222-8222-000000000004',
   'accepted', 1, 82.30, 5.80, 22,
   now() - interval '3 hours', now() - interval '3 hours' + interval '45 seconds',
   now() - interval '3 hours' + interval '4 minutes', null),
  ('66666666-0000-4000-8000-000000000002', '22222222-2222-4222-8222-000000000001',
   'declined', 2, 71.90, 9.30, 27,
   now() - interval '3 hours', now() - interval '3 hours' + interval '45 seconds',
   now() - interval '3 hours' + interval '30 seconds', 'Already on another job');

-- ---------------------------------------------------------------------------
-- Diagnoses and quotations
-- ---------------------------------------------------------------------------

insert into public.diagnoses
  (id, request_id, technician_id, problem_found, notes, recommended_action, created_at)
values
  ('77777777-0000-4000-8000-000000000001', '66666666-0000-4000-8000-000000000001',
   '22222222-2222-4222-8222-000000000001',
   'Damaged display cable',
   'External monitor works normally, so the graphics chip and board are fine. '
   'The internal panel is not detected at all. The cable shows wear where it '
   'passes through the left hinge.',
   'Replace the display cable and re-seat the panel connector.',
   now() - interval '9 days' + interval '55 minutes'),

  ('77777777-0000-4000-8000-000000000002', '66666666-0000-4000-8000-000000000002',
   '22222222-2222-4222-8222-000000000004',
   'CPU cooler thermal paste has dried out',
   'Package temperature reaches 96 degrees within eight minutes under load and '
   'the board shuts down to protect itself. Heatsink is also heavily dust '
   'blocked.',
   'Clean the heatsink and fans, reapply thermal paste, and retest under load.',
   now() - interval '80 minutes');

-- Approved quotation for the completed job. Items are inserted first so the
-- totals trigger computes the amounts, then the status moves to approved -
-- an approved quotation is immutable, so the order matters.
insert into public.quotations
  (id, request_id, technician_id, diagnosis_id, kind, version, status,
   notes, submitted_at, created_at)
values
  ('88888888-0000-4000-8000-000000000001', '66666666-0000-4000-8000-000000000001',
   '22222222-2222-4222-8222-000000000001', '77777777-0000-4000-8000-000000000001',
   'initial', 1, 'submitted',
   'Replacement cable is a compatible part with a 14 day warranty.',
   now() - interval '9 days' + interval '62 minutes',
   now() - interval '9 days' + interval '60 minutes');

insert into public.quotation_items
  (quotation_id, kind, description, quantity, unit_price_sen, amount_sen, sort_order)
values
  ('88888888-0000-4000-8000-000000000001', 'diagnosis', 'On-site diagnosis', 1, 2000, 2000, 1),
  ('88888888-0000-4000-8000-000000000001', 'labour', 'Display cable replacement', 1, 3000, 3000, 2),
  ('88888888-0000-4000-8000-000000000001', 'part', 'LCD display cable (compatible)', 1, 3500, 3500, 3),
  ('88888888-0000-4000-8000-000000000001', 'travel', 'Travel to Jalan Ampang', 1, 1000, 1000, 4);

update public.quotations
   set status = 'approved'
 where id = '88888888-0000-4000-8000-000000000001';

insert into public.quotation_approvals
  (quotation_id, quotation_version, approved_by, decision, approved_at)
values
  ('88888888-0000-4000-8000-000000000001', 1,
   '11111111-1111-4111-8111-000000000001', 'approved',
   now() - interval '9 days' + interval '70 minutes');

-- Quotation still awaiting a decision, for the approval screen.
insert into public.quotations
  (id, request_id, technician_id, diagnosis_id, kind, version, status,
   notes, valid_until, submitted_at, created_at)
values
  ('88888888-0000-4000-8000-000000000002', '66666666-0000-4000-8000-000000000002',
   '22222222-2222-4222-8222-000000000004', '77777777-0000-4000-8000-000000000002',
   'initial', 1, 'submitted',
   'Includes a full clean. If the shutdown continues after this I will not '
   'charge for a second visit.',
   now() + interval '2 days', now() - interval '70 minutes',
   now() - interval '75 minutes');

insert into public.quotation_items
  (quotation_id, kind, description, quantity, unit_price_sen, amount_sen, sort_order)
values
  ('88888888-0000-4000-8000-000000000002', 'diagnosis', 'On-site diagnosis', 1, 2000, 2000, 1),
  ('88888888-0000-4000-8000-000000000002', 'labour', 'Heatsink clean and thermal paste', 1, 4500, 4500, 2),
  ('88888888-0000-4000-8000-000000000002', 'part', 'Thermal compound', 1, 1500, 1500, 3),
  ('88888888-0000-4000-8000-000000000002', 'travel', 'Travel to Petaling Jaya', 1, 1000, 1000, 4);

-- ---------------------------------------------------------------------------
-- Evidence, checklist, payment, earnings, warranty, review
-- ---------------------------------------------------------------------------

insert into public.service_evidence
  (request_id, type, storage_path, caption, uploaded_by, created_at)
values
  ('66666666-0000-4000-8000-000000000001', 'before_service',
   '66666666-0000-4000-8000-000000000001/before-lid-closed.jpg',
   'Laptop as received, lid closed', '22222222-2222-4222-8222-000000000001',
   now() - interval '9 days' + interval '40 minutes'),
  ('66666666-0000-4000-8000-000000000001', 'before_service',
   '66666666-0000-4000-8000-000000000001/before-screen-black.jpg',
   'Powered on, display remains black', '22222222-2222-4222-8222-000000000001',
   now() - interval '9 days' + interval '41 minutes'),
  ('66666666-0000-4000-8000-000000000001', 'diagnosis',
   '66666666-0000-4000-8000-000000000001/diagnosis-cable-wear.jpg',
   'Wear on the display cable at the left hinge',
   '22222222-2222-4222-8222-000000000001',
   now() - interval '9 days' + interval '56 minutes'),
  ('66666666-0000-4000-8000-000000000001', 'after_service',
   '66666666-0000-4000-8000-000000000001/after-display-working.jpg',
   'Display working after cable replacement',
   '22222222-2222-4222-8222-000000000001',
   now() - interval '9 days' + interval '145 minutes');

insert into public.service_checklists
  (request_id, label, is_passed, sort_order, checked_at)
values
  ('66666666-0000-4000-8000-000000000001', 'Powers on', true, 1, now() - interval '9 days' + interval '146 minutes'),
  ('66666666-0000-4000-8000-000000000001', 'Display', true, 2, now() - interval '9 days' + interval '146 minutes'),
  ('66666666-0000-4000-8000-000000000001', 'Keyboard', true, 3, now() - interval '9 days' + interval '147 minutes'),
  ('66666666-0000-4000-8000-000000000001', 'WiFi', true, 4, now() - interval '9 days' + interval '147 minutes'),
  ('66666666-0000-4000-8000-000000000001', 'Audio', true, 5, now() - interval '9 days' + interval '148 minutes'),
  ('66666666-0000-4000-8000-000000000001', 'USB ports', true, 6, now() - interval '9 days' + interval '148 minutes');

insert into public.payments
  (id, request_id, quotation_id, provider, provider_bill_code, provider_reference,
   status, amount_sen, paid_at, verified_at, created_at)
values
  ('99999999-0000-4000-8000-000000000001', '66666666-0000-4000-8000-000000000001',
   '88888888-0000-4000-8000-000000000001', 'toyyibpay', 'sandbox-bill-000001',
   'TP-SBX-8841207', 'paid', 10000,
   now() - interval '9 days' + interval '154 minutes',
   now() - interval '9 days' + interval '155 minutes',
   now() - interval '9 days' + interval '151 minutes');

insert into public.payment_items (payment_id, kind, label, amount_sen, sort_order)
values
  ('99999999-0000-4000-8000-000000000001', 'diagnosis', 'On-site diagnosis', 2000, 1),
  ('99999999-0000-4000-8000-000000000001', 'labour', 'Display cable replacement', 3000, 2),
  ('99999999-0000-4000-8000-000000000001', 'part', 'LCD display cable (compatible)', 3500, 3),
  ('99999999-0000-4000-8000-000000000001', 'travel', 'Travel to Jalan Ampang', 1000, 4),
  ('99999999-0000-4000-8000-000000000001', 'other', 'Platform fee', 500, 5);

-- Commission is 10% of the 9,500 sen of service value, leaving the platform
-- fee out of the technician's gross.
insert into public.technician_earnings
  (request_id, technician_id, payment_id, gross_sen, commission_percent,
   commission_sen, net_sen, status, released_at, created_at)
values
  ('66666666-0000-4000-8000-000000000001', '22222222-2222-4222-8222-000000000001',
   '99999999-0000-4000-8000-000000000001', 9500, 10.00, 950, 8550,
   'released', now() - interval '9 days' + interval '160 minutes',
   now() - interval '9 days' + interval '156 minutes');

insert into public.warranties
  (request_id, quotation_id, covered_work, days, starts_at, expires_at, terms, status)
values
  ('66666666-0000-4000-8000-000000000001', '88888888-0000-4000-8000-000000000001',
   'Display cable replacement', 14,
   now() - interval '9 days' + interval '155 minutes',
   now() + interval '5 days',
   'Covers the replaced cable and the workmanship. Accidental damage and '
   'unrelated faults are not covered.',
   'active');

insert into public.reviews
  (request_id, customer_id, technician_id, rating_overall, rating_quality,
   rating_professionalism, rating_punctuality, rating_pricing, comment, created_at)
values
  ('66666666-0000-4000-8000-000000000001', '11111111-1111-4111-8111-000000000001',
   '22222222-2222-4222-8222-000000000001', 5, 5, 5, 5, 4,
   'Arrived earlier than the estimate, explained what was wrong before doing '
   'anything, and the price was exactly what the quotation said.',
   now() - interval '8 days');

-- ---------------------------------------------------------------------------
-- Conversation and notifications
-- ---------------------------------------------------------------------------

insert into public.messages (request_id, sender_id, kind, body, read_at, created_at)
values
  ('66666666-0000-4000-8000-000000000003', '22222222-2222-4222-8222-000000000002',
   'text', 'On my way, about twenty five minutes. Is there parking on site?',
   now() - interval '13 minutes', now() - interval '14 minutes'),
  ('66666666-0000-4000-8000-000000000003', '11111111-1111-4111-8111-000000000004',
   'text', 'Yes, visitor bays at level B1. Tell the guard you are here for unit 5-3.',
   null, now() - interval '12 minutes'),
  ('66666666-0000-4000-8000-000000000003', '22222222-2222-4222-8222-000000000002',
   'text', 'Understood, thank you.', null, now() - interval '11 minutes');

insert into public.notifications (user_id, type, title, body, data, read_at, created_at)
values
  ('11111111-1111-4111-8111-000000000004', 'technician_accepted',
   'Faizal is on the way',
   'Faizal Hassan accepted your emergency request. Estimated arrival 26 minutes.',
   '{"request_id":"66666666-0000-4000-8000-000000000003"}'::jsonb,
   null, now() - interval '15 minutes'),
  ('11111111-1111-4111-8111-000000000003', 'quotation_submitted',
   'Your quotation is ready',
   'Rajesh Nair has sent a quotation for RM90.00. Review it to continue.',
   '{"request_id":"66666666-0000-4000-8000-000000000002"}'::jsonb,
   null, now() - interval '70 minutes'),
  ('11111111-1111-4111-8111-000000000001', 'warranty_reminder',
   'Warranty ending soon',
   'The 14 day warranty on your display cable replacement ends in 5 days.',
   '{"request_id":"66666666-0000-4000-8000-000000000001"}'::jsonb,
   null, now() - interval '2 hours'),
  ('22222222-2222-4222-8222-000000000007', 'job_offer',
   'New job nearby',
   'Cracked phone screen in Setia Alam. 22.4 km, estimated RM80 to RM480.',
   '{"request_id":"66666666-0000-4000-8000-000000000004"}'::jsonb,
   null, now() - interval '2 minutes');

insert into public.cancellation_records
  (request_id, cancelled_by, cancelled_by_role, reason, status_at_cancellation,
   fee_sen, fee_waived, created_at)
values
  ('66666666-0000-4000-8000-000000000005', '11111111-1111-4111-8111-000000000002',
   'customer', 'Sorted it myself with a clean reinstall before the visit.',
   'ASSIGNED', 0, true, now() - interval '5 days' + interval '25 minutes');

-- ---------------------------------------------------------------------------
-- Sequence alignment
-- ---------------------------------------------------------------------------

-- The references above are written out so they read well in this file, which
-- means the sequence behind generate_service_reference() has not moved. Without
-- this, the first five requests created through the app would each try to claim
-- a reference the seed already used, and fail on the unique index with a
-- duplicate-key error that says nothing about the real cause.
select setval(
  'public.service_reference_seq',
  (select count(*) from public.service_requests)
);
