create schema if not exists private;
revoke all on schema private from public, anon, authenticated;
grant usage on schema private to service_role;

create table if not exists private.app_secrets (
  key text primary key,
  value text not null,
  updated_at timestamptz not null default now()
);

revoke all on table private.app_secrets from public, anon, authenticated;
grant select on table private.app_secrets to service_role;

-- Value is set/rotated via SQL or dashboard; never exposed to anon/authenticated.
insert into private.app_secrets(key, value)
values ('MAKE_EMAIL_WEBHOOK_URL', 'REPLACE_ME')
on conflict (key) do nothing;
