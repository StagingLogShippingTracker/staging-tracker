-- Watch pairing codes (service-role / Edge Function only) + cloud SVR progress.

create schema if not exists private;

create table if not exists private.watch_pairing_codes (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users (id) on delete cascade,
  code_hash text not null unique,
  expires_at timestamptz not null,
  consumed_at timestamptz,
  created_at timestamptz not null default now()
);

create index if not exists watch_pairing_codes_user_idx
  on private.watch_pairing_codes (user_id);

revoke all on table private.watch_pairing_codes from public, anon, authenticated;
grant all on table private.watch_pairing_codes to service_role;

create table if not exists public.verification_audit_state (
  user_id uuid primary key references auth.users (id) on delete cascade,
  mode text not null default 'all',
  queue jsonb not null default '[]'::jsonb,
  index int not null default 0,
  results jsonb not null default '[]'::jsonb,
  discrepancy_ids jsonb not null default '[]'::jsonb,
  updated_at timestamptz not null default now()
);

alter table public.verification_audit_state enable row level security;

drop policy if exists "verification_audit_state_select_own" on public.verification_audit_state;
create policy "verification_audit_state_select_own"
  on public.verification_audit_state for select
  to authenticated
  using (auth.uid() = user_id);

drop policy if exists "verification_audit_state_insert_own" on public.verification_audit_state;
create policy "verification_audit_state_insert_own"
  on public.verification_audit_state for insert
  to authenticated
  with check (auth.uid() = user_id);

drop policy if exists "verification_audit_state_update_own" on public.verification_audit_state;
create policy "verification_audit_state_update_own"
  on public.verification_audit_state for update
  to authenticated
  using (auth.uid() = user_id)
  with check (auth.uid() = user_id);

drop policy if exists "verification_audit_state_delete_own" on public.verification_audit_state;
create policy "verification_audit_state_delete_own"
  on public.verification_audit_state for delete
  to authenticated
  using (auth.uid() = user_id);

grant select, insert, update, delete on public.verification_audit_state to authenticated;
