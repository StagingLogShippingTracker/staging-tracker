-- Cross-app shared carrier-name directory, mirroring shared_contacts exactly.
-- Same store behind "Carrier" here (Windows/Android + Wear) and Swift
-- Document Generator's "Carrier" field.
create table if not exists public.shared_carriers (
  name_key text primary key,
  name text not null,
  last_used_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  created_at timestamptz not null default now()
);

create table if not exists public.shared_carrier_tombstones (
  name_key text primary key,
  deleted_at timestamptz not null default now()
);

create trigger shared_carriers_touch_updated
  before update on public.shared_carriers
  for each row execute function public.touch_updated_at();

alter table public.shared_carriers enable row level security;
alter table public.shared_carrier_tombstones enable row level security;

create policy anon_all_shared_carriers
  on public.shared_carriers
  for all
  to anon
  using (true)
  with check (true);

create policy anon_all_shared_carrier_tombstones
  on public.shared_carrier_tombstones
  for all
  to anon
  using (true)
  with check (true);
