-- Mid-state marker between "staged" and "shipped": staff can flag a staging
-- entry as physically prepped/ready to load without changing its urgency
-- status or moving it out of the staging table. Purely informational — Ship
-- and Quick Ship both bypass it entirely and work exactly as before.
alter table public.staging
  add column if not exists prepared_for_shipping boolean not null default false;
