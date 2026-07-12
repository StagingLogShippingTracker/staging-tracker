-- Prophet21 order insight cache (cloned from Epicor OData, served to all site users)
create table if not exists public.p21_order_cache (
  so_key text primary key,
  so_raw text not null,
  found boolean not null default false,
  payload jsonb not null default '{}'::jsonb,
  matched_by text,
  source text not null default 'live',
  fetched_at timestamptz not null default timezone('utc', now()),
  expires_at timestamptz not null default (timezone('utc', now()) + interval '7 days')
);

create index if not exists p21_order_cache_expires_at_idx on public.p21_order_cache (expires_at desc);
create index if not exists p21_order_cache_fetched_at_idx on public.p21_order_cache (fetched_at desc);

alter table public.p21_order_cache enable row level security;

drop policy if exists "p21 cache read for app users" on public.p21_order_cache;
create policy "p21 cache read for app users"
  on public.p21_order_cache
  for select
  to anon, authenticated
  using (true);

comment on table public.p21_order_cache is 'Cached Prophet21 sales-order snapshots; synced from Swift network and served globally.';
