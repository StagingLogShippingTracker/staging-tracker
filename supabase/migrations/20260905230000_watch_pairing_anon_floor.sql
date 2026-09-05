-- Floor Wear pairing without user sign-in (user_id nullable + floor replace RPC).
alter table public.watch_pairing_codes
  alter column user_id drop not null;

create or replace function public.replace_watch_pairing_code(
  p_user_id uuid,
  p_code_hash text,
  p_expires_at timestamptz
)
returns public.watch_pairing_codes
language plpgsql
security definer
set search_path = public
as $$
declare
  v_row public.watch_pairing_codes;
begin
  delete from public.watch_pairing_codes
  where user_id = p_user_id and consumed_at is null;

  insert into public.watch_pairing_codes (user_id, code_hash, expires_at)
  values (p_user_id, p_code_hash, p_expires_at)
  returning * into v_row;

  return v_row;
end;
$$;

create or replace function public.replace_floor_watch_pairing_code(
  p_code_hash text,
  p_expires_at timestamptz
)
returns public.watch_pairing_codes
language plpgsql
security definer
set search_path = public
as $$
declare
  v_row public.watch_pairing_codes;
begin
  delete from public.watch_pairing_codes
  where user_id is null and consumed_at is null;

  insert into public.watch_pairing_codes (user_id, code_hash, expires_at)
  values (null, p_code_hash, p_expires_at)
  returning * into v_row;

  return v_row;
end;
$$;

revoke all on function public.replace_floor_watch_pairing_code(text, timestamptz)
  from public, anon, authenticated;
grant execute on function public.replace_floor_watch_pairing_code(text, timestamptz)
  to service_role;
