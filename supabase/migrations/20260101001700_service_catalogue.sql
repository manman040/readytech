-- ReadyTech :: service catalogue
--
-- The categories the marketplace runs on. These are reference data, not demo
-- data: without them a customer cannot file a request at all, and
-- estimate_service_cost() and rank_technicians() both key off a category. They
-- belong here beside pricing_config rather than in seed.sql, which never runs
-- against a hosted project.
--
-- A separate migration rather than an edit to 20260101000300 because that one
-- has already been applied. Migrations are forward-only; see docs/DEPLOYMENT.md.
--
-- Idempotent on slug, so re-running is harmless and an operator can add a
-- category by hand without this fighting them.
insert into public.service_categories (
  id, slug, name, description, icon, device_types,
  diagnosis_fee_sen, estimated_repair_min_sen, estimated_repair_max_sen,
  default_warranty_days, requires_specialist, sort_order
) values
  ('44444444-0000-4000-8000-000000000001', 'laptop-hardware', 'Laptop Hardware',
   'Screen, keyboard, battery, charging port, fan and internal component faults.',
   'laptop', '{laptop}', 2000, 3000, 30000, 14, false, 1),
  ('44444444-0000-4000-8000-000000000002', 'laptop-software', 'Laptop Software',
   'Slow performance, crashes, driver problems and application faults.',
   'apps', '{laptop,desktop}', 2000, 2000, 12000, 7, false, 2),
  ('44444444-0000-4000-8000-000000000003', 'desktop-hardware', 'Desktop PC Hardware',
   'Power supply, motherboard, graphics card, storage and cooling faults.',
   'desktop_windows', '{desktop}', 2000, 4000, 40000, 14, false, 3),
  ('44444444-0000-4000-8000-000000000004', 'printer', 'Printer & Scanner',
   'Paper jams, print quality, connectivity and driver problems.',
   'print', '{printer}', 1500, 2000, 15000, 7, false, 4),
  ('44444444-0000-4000-8000-000000000005', 'network-wifi', 'Network & WiFi',
   'Slow or dropping connections, router setup, coverage and cabling.',
   'wifi', '{network_device}', 2500, 3000, 25000, 14, false, 5),
  ('44444444-0000-4000-8000-000000000006', 'virus-malware', 'Virus & Malware Removal',
   'Infections, ransomware, browser hijacking and unwanted software.',
   'security', '{laptop,desktop,mobile,tablet}', 2000, 4000, 15000, 7, false, 6),
  ('44444444-0000-4000-8000-000000000007', 'os-installation', 'Operating System & Setup',
   'Windows or macOS installation, migration and first-time configuration.',
   'settings_applications', '{laptop,desktop}', 1500, 5000, 18000, 7, false, 7),
  ('44444444-0000-4000-8000-000000000008', 'data-recovery', 'Data Recovery',
   'Recovering files from failing drives, deleted partitions and dead devices.',
   'restore_page', '{laptop,desktop,server,peripheral}', 3000, 15000, 120000, 0, true, 8),
  ('44444444-0000-4000-8000-000000000009', 'mobile-device', 'Mobile & Tablet',
   'Screens, batteries, charging ports and software faults on phones and tablets.',
   'smartphone', '{mobile,tablet}', 1500, 5000, 45000, 14, false, 9),
  ('44444444-0000-4000-8000-000000000010', 'server-nas', 'Server & NAS',
   'Small business servers, network storage, backups and RAID faults.',
   'dns', '{server}', 5000, 10000, 90000, 30, true, 10),
  ('44444444-0000-4000-8000-000000000011', 'peripherals', 'Peripherals & Accessories',
   'Monitors, docking stations, keyboards, mice and webcams.',
   'devices_other', '{peripheral}', 1500, 1500, 12000, 7, false, 11),
  ('44444444-0000-4000-8000-000000000012', 'office-setup', 'Office IT Setup',
   'Setting up workstations, shared printers and networks for a small office.',
   'business', '{laptop,desktop,network_device,printer}', 3000, 15000, 80000, 14, false, 12)
on conflict (slug) do nothing;
