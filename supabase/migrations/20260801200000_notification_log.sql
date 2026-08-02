-- Immutable audit log of PM email notifications written by notify-pm.
create table if not exists public.notification_log (
  id uuid primary key default gen_random_uuid(),
  created_at timestamptz not null default now(),
  notification_type text not null default '',
  status text not null default 'sent',
  channel text not null default 'email',
  pm_name text,
  pm_email text,
  so text,
  po text,
  customer text,
  vendor text,
  carrier text,
  subject text,
  sent_by text,
  error_detail text,
  payload jsonb not null default '{}'::jsonb
);

comment on table public.notification_log is
  'Append-only log of notify-pm deliveries for Filters/Export on the Notifications page.';

create index if not exists notification_log_created_at_idx
  on public.notification_log (created_at desc);
create index if not exists notification_log_pm_name_idx
  on public.notification_log (pm_name);
create index if not exists notification_log_pm_email_idx
  on public.notification_log (lower(pm_email));
create index if not exists notification_log_type_idx
  on public.notification_log (notification_type);
create index if not exists notification_log_status_idx
  on public.notification_log (status);
create index if not exists notification_log_so_idx
  on public.notification_log (so);
create index if not exists notification_log_po_idx
  on public.notification_log (po);

alter table public.notification_log enable row level security;

drop policy if exists notification_log_select_authenticated on public.notification_log;
create policy notification_log_select_authenticated
  on public.notification_log for select
  to authenticated
  using (true);

-- Inserts come from notify-pm via service_role (bypasses RLS). No client writes.
drop policy if exists notification_log_insert_authenticated on public.notification_log;
revoke insert on public.notification_log from authenticated;
grant select on public.notification_log to authenticated;
grant all on public.notification_log to service_role;
