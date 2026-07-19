create or replace function public.get_app_secret(p_key text)
returns text
language sql
security definer
set search_path = private, public
as $$
  select value from private.app_secrets where key = p_key limit 1;
$$;

revoke all on function public.get_app_secret(text) from public, anon, authenticated;
grant execute on function public.get_app_secret(text) to service_role;
