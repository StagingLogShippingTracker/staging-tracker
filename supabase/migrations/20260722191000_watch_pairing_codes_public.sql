-- Expose watch pairing codes via public API for service_role only.
-- PostgREST does not expose the private schema by default (caused: Invalid schema: private).

create table if not exists public.watch_pairing_codes (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users (id) on delete cascade,
  code_hash text not null unique,
  expires_at timestamptz not null,
  consumed_at timestamptz,
  created_at timestamptz not null default now()
);

create index if not exists watch_pairing_codes_public_user_idx
  on public.watch_pairing_codes (user_id);

alter table public.watch_pairing_codes enable row level security;

-- No policies for anon/authenticated => clients cannot read/write.
revoke all on table public.watch_pairing_codes from public, anon, authenticated;
grant all on table public.watch_pairing_codes to service_role;

-- Copy any rows from private (if present), then drop private table.
do $$
begin
  if exists (
    select 1 from information_schema.tables
    where table_schema = 'private' and table_name = 'watch_pairing_codes'
  ) then
    insert into public.watch_pairing_codes (id, user_id, code_hash, expires_at, consumed_at, created_at)
    select id, user_id, code_hash, expires_at, consumed_at, created_at
    from private.watch_pairing_codes
    on conflict (id) do nothing;
    drop table private.watch_pairing_codes;
  end if;
end $$;
