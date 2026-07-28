-- Transactional inventory mutations + notification status + watch-pair claim.
-- SECURITY INVOKER so RLS still applies to the calling authenticated user.

-- ---------------------------------------------------------------------------
-- Notification outcome columns (pmd_email remains display/recipient hint)
-- ---------------------------------------------------------------------------
alter table public.shipped
  add column if not exists notification_status text not null default 'none',
  add column if not exists notification_error text,
  add column if not exists notified_at timestamptz;

alter table public.shipped
  drop constraint if exists shipped_notification_status_check;

alter table public.shipped
  add constraint shipped_notification_status_check
  check (notification_status = any (array['none', 'pending', 'sent', 'failed']));

-- ---------------------------------------------------------------------------
-- Server-side consolidation undo tokens (2-minute window)
-- ---------------------------------------------------------------------------
create table if not exists public.consolidation_undo (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users (id) on delete cascade,
  merged_id uuid not null,
  sources jsonb not null,
  created_at timestamptz not null default now(),
  expires_at timestamptz not null,
  consumed_at timestamptz
);

create index if not exists consolidation_undo_user_idx
  on public.consolidation_undo (user_id);

alter table public.consolidation_undo enable row level security;

drop policy if exists consolidation_undo_select_own on public.consolidation_undo;
create policy consolidation_undo_select_own
  on public.consolidation_undo for select
  to authenticated
  using (auth.uid() = user_id);

drop policy if exists consolidation_undo_insert_own on public.consolidation_undo;
create policy consolidation_undo_insert_own
  on public.consolidation_undo for insert
  to authenticated
  with check (auth.uid() = user_id);

drop policy if exists consolidation_undo_update_own on public.consolidation_undo;
create policy consolidation_undo_update_own
  on public.consolidation_undo for update
  to authenticated
  using (auth.uid() = user_id)
  with check (auth.uid() = user_id);

drop policy if exists consolidation_undo_delete_own on public.consolidation_undo;
create policy consolidation_undo_delete_own
  on public.consolidation_undo for delete
  to authenticated
  using (auth.uid() = user_id);

grant select, insert, update, delete on public.consolidation_undo to authenticated;

-- ---------------------------------------------------------------------------
-- Helpers
-- ---------------------------------------------------------------------------
create or replace function public._changelog_user()
returns text
language sql
stable
set search_path = public
as $$
  select coalesce(
    nullif(split_part(coalesce(auth.jwt() ->> 'email', ''), '@', 1), ''),
    'Guest'
  );
$$;

create or replace function public._write_changelog(p_table text, p_action text)
returns void
language plpgsql
security invoker
set search_path = public
as $$
begin
  insert into public.changelog (table_name, action, user_email)
  values (p_table, p_action, public._changelog_user());
end;
$$;

-- ---------------------------------------------------------------------------
-- ship_staging_entry: lock → insert shipped → delete staging → changelog
-- ---------------------------------------------------------------------------
create or replace function public.ship_staging_entry(
  p_staging_id uuid,
  p_carrier text,
  p_shipped_by text,
  p_type text default null,
  p_qty integer default null,
  p_weight text default null,
  p_photo_urls text[] default null,
  p_pmd_email text default null,
  p_notification_status text default 'none'
)
returns jsonb
language plpgsql
security invoker
set search_path = public
as $$
declare
  v_src public.staging%rowtype;
  v_shipped public.shipped%rowtype;
  v_type text;
  v_qty integer;
  v_weight text;
  v_photos text[];
  v_notif text;
begin
  if auth.uid() is null then
    raise exception 'Authentication required' using errcode = '42501';
  end if;
  if nullif(trim(p_carrier), '') is null then
    raise exception 'Carrier is required' using errcode = '22023';
  end if;
  if nullif(trim(p_shipped_by), '') is null then
    raise exception 'Shipped by is required' using errcode = '22023';
  end if;

  v_notif := coalesce(nullif(trim(p_notification_status), ''), 'none');
  if v_notif not in ('none', 'pending', 'sent', 'failed') then
    v_notif := 'none';
  end if;

  select * into v_src
  from public.staging
  where id = p_staging_id
  for update;

  if not found then
    raise exception 'Staging entry not found or already shipped' using errcode = 'P0002';
  end if;

  v_type := coalesce(nullif(trim(p_type), ''), v_src.type);
  v_qty := coalesce(p_qty, v_src.qty);
  v_weight := coalesce(p_weight, v_src.weight);
  v_photos := coalesce(p_photo_urls, v_src.photo_urls, array[]::text[]);

  insert into public.shipped (
    so, customer, type, qty, carrier, location, weight, comments,
    shipped_by, pmd_email, photo_urls, notification_status
  ) values (
    v_src.so, v_src.customer, v_type, v_qty, trim(p_carrier), v_src.location,
    v_weight, v_src.comments, trim(p_shipped_by), p_pmd_email, v_photos, v_notif
  )
  returning * into v_shipped;

  delete from public.staging where id = v_src.id;

  perform public._write_changelog('staging', 'Ship Confirmed SO: ' || v_src.so);
  perform public._write_changelog('shipped', 'Added via Ship Confirm: SO: ' || v_src.so);
  perform public._write_changelog(
    'staging',
    'Bin Movement: To Shipped Log — SO ' || v_src.so || ': ' || v_type ||
    ' moved from Staging Log to Shipped Log (' || coalesce(v_src.location, '') || ')'
  );

  return to_jsonb(v_shipped);
end;
$$;

revoke all on function public.ship_staging_entry(
  uuid, text, text, text, integer, text, text[], text, text
) from public;
grant execute on function public.ship_staging_entry(
  uuid, text, text, text, integer, text, text[], text, text
) to authenticated;

-- ---------------------------------------------------------------------------
-- return_staging_to_stock
-- ---------------------------------------------------------------------------
create or replace function public.return_staging_to_stock(
  p_staging_id uuid,
  p_picked_by text,
  p_returned_by text,
  p_reason text,
  p_photo_urls text[] default null,
  p_pmd_email text default null,
  p_notification_status text default 'none'
)
returns jsonb
language plpgsql
security invoker
set search_path = public
as $$
declare
  v_src public.staging%rowtype;
  v_shipped public.shipped%rowtype;
  v_photos text[];
  v_notif text;
  v_pmd text;
begin
  if auth.uid() is null then
    raise exception 'Authentication required' using errcode = '42501';
  end if;
  if nullif(trim(p_picked_by), '') is null
     or nullif(trim(p_returned_by), '') is null
     or nullif(trim(p_reason), '') is null then
    raise exception 'Picked by, returned by, and reason are required' using errcode = '22023';
  end if;

  v_notif := coalesce(nullif(trim(p_notification_status), ''), 'none');
  if v_notif not in ('none', 'pending', 'sent', 'failed') then
    v_notif := 'none';
  end if;

  select * into v_src from public.staging where id = p_staging_id for update;
  if not found then
    raise exception 'Staging entry not found or already moved' using errcode = 'P0002';
  end if;

  v_photos := coalesce(p_photo_urls, v_src.photo_urls, array[]::text[]);
  v_pmd := coalesce(nullif(trim(p_pmd_email), ''), trim(p_picked_by));

  insert into public.shipped (
    so, customer, type, qty, carrier, location, weight, comments,
    shipped_by, pmd_email, photo_urls, notification_status
  ) values (
    v_src.so, v_src.customer, v_src.type, v_src.qty, 'RETURNED TO STOCK',
    v_src.location, v_src.weight, v_src.comments, trim(p_returned_by),
    v_pmd, v_photos, v_notif
  )
  returning * into v_shipped;

  delete from public.staging where id = v_src.id;

  perform public._write_changelog('staging', 'Returned to Stock SO: ' || v_src.so);
  perform public._write_changelog('shipped', 'Added Return to Stock log for SO: ' || v_src.so);

  return to_jsonb(v_shipped);
end;
$$;

revoke all on function public.return_staging_to_stock(
  uuid, text, text, text, text[], text, text
) from public;
grant execute on function public.return_staging_to_stock(
  uuid, text, text, text, text[], text, text
) to authenticated;

-- ---------------------------------------------------------------------------
-- undo_shipment: move shipped row back to staging
-- ---------------------------------------------------------------------------
create or replace function public.undo_shipment(
  p_shipped_id uuid,
  p_allow_existing_so boolean default false
)
returns jsonb
language plpgsql
security invoker
set search_path = public
as $$
declare
  v_src public.shipped%rowtype;
  v_staging public.staging%rowtype;
begin
  if auth.uid() is null then
    raise exception 'Authentication required' using errcode = '42501';
  end if;

  select * into v_src from public.shipped where id = p_shipped_id for update;
  if not found then
    raise exception 'Shipped entry not found' using errcode = 'P0002';
  end if;

  if not p_allow_existing_so and exists (
    select 1 from public.staging s
    where lower(trim(s.so)) = lower(trim(v_src.so))
  ) then
    raise exception 'Cannot undo: SO % already exists in Staging', v_src.so
      using errcode = '23505';
  end if;

  insert into public.staging (
    so, customer, type, qty, location, weight, comments, status, photo_urls
  ) values (
    v_src.so, v_src.customer, v_src.type, v_src.qty, v_src.location,
    v_src.weight, v_src.comments, 'Partial', coalesce(v_src.photo_urls, array[]::text[])
  )
  returning * into v_staging;

  delete from public.shipped where id = v_src.id;

  perform public._write_changelog('shipped', 'Undo Shipment Action for SO: ' || v_src.so);
  perform public._write_changelog('staging', 'Restored to Staging via Undo for SO: ' || v_src.so);

  return to_jsonb(v_staging);
end;
$$;

revoke all on function public.undo_shipment(uuid, boolean) from public;
grant execute on function public.undo_shipment(uuid, boolean) to authenticated;

-- ---------------------------------------------------------------------------
-- split_staging
-- ---------------------------------------------------------------------------
create or replace function public.split_staging(
  p_staging_id uuid,
  p_first_type text,
  p_first_qty integer,
  p_second_type text,
  p_second_qty integer
)
returns jsonb
language plpgsql
security invoker
set search_path = public
as $$
declare
  v_src public.staging%rowtype;
  v_a public.staging%rowtype;
  v_b public.staging%rowtype;
begin
  if auth.uid() is null then
    raise exception 'Authentication required' using errcode = '42501';
  end if;
  if p_first_qty is null or p_first_qty <= 0 or p_second_qty is null or p_second_qty <= 0 then
    raise exception 'Both split parts need at least one container' using errcode = '22023';
  end if;

  select * into v_src from public.staging where id = p_staging_id for update;
  if not found then
    raise exception 'Staging entry not found' using errcode = 'P0002';
  end if;

  if (p_first_qty + p_second_qty) <> v_src.qty then
    raise exception 'Split parts must add up to the original quantity (%)', v_src.qty
      using errcode = '22023';
  end if;

  insert into public.staging (
    so, customer, status, location, type, qty, weight, comments, staged_by, photo_urls, coords
  ) values (
    v_src.so, v_src.customer, v_src.status, v_src.location, p_first_type, p_first_qty,
    v_src.weight, v_src.comments, v_src.staged_by, v_src.photo_urls, v_src.coords
  ) returning * into v_a;

  insert into public.staging (
    so, customer, status, location, type, qty, weight, comments, staged_by, photo_urls, coords
  ) values (
    v_src.so, v_src.customer, v_src.status, v_src.location, p_second_type, p_second_qty,
    v_src.weight, v_src.comments, v_src.staged_by, v_src.photo_urls, v_src.coords
  ) returning * into v_b;

  delete from public.staging where id = v_src.id;

  perform public._write_changelog(
    'staging',
    'Split SO ' || v_src.so || ': ' || v_src.id || ' → ' || v_a.id || ', ' || v_b.id
  );

  return jsonb_build_object('a', to_jsonb(v_a), 'b', to_jsonb(v_b));
end;
$$;

revoke all on function public.split_staging(uuid, text, integer, text, integer) from public;
grant execute on function public.split_staging(uuid, text, integer, text, integer) to authenticated;

-- ---------------------------------------------------------------------------
-- consolidate_staging
-- ---------------------------------------------------------------------------
create or replace function public.consolidate_staging(
  p_source_ids uuid[],
  p_type text,
  p_qty integer,
  p_photo_urls text[] default null
)
returns jsonb
language plpgsql
security invoker
set search_path = public
as $$
declare
  v_keep public.staging%rowtype;
  v_merged public.staging%rowtype;
  v_id uuid;
  v_so text;
  v_count integer := 0;
  v_old_ids text := '';
  v_sources jsonb := '[]'::jsonb;
  v_undo_id uuid;
begin
  if auth.uid() is null then
    raise exception 'Authentication required' using errcode = '42501';
  end if;
  if p_source_ids is null or cardinality(p_source_ids) < 2 then
    raise exception 'Select at least two staging rows to consolidate' using errcode = '22023';
  end if;
  if p_qty is null or p_qty <= 0 or nullif(trim(p_type), '') is null then
    raise exception 'Consolidated type and quantity are required' using errcode = '22023';
  end if;

  -- Lock all source rows in id order to avoid deadlocks.
  for v_id in
    select unnest(p_source_ids) as id order by 1
  loop
    select * into v_keep from public.staging where id = v_id for update;
    if not found then
      raise exception 'Staging entry % not found (stale selection)', v_id
        using errcode = 'P0002';
    end if;
    if v_count = 0 then
      v_so := lower(trim(v_keep.so));
    elsif lower(trim(v_keep.so)) <> v_so then
      raise exception 'Consolidate requires the same SO on every row' using errcode = '22023';
    end if;
    v_sources := v_sources || jsonb_build_array(to_jsonb(v_keep));
    v_old_ids := case when v_old_ids = '' then v_id::text else v_old_ids || ', ' || v_id::text end;
    v_count := v_count + 1;
  end loop;

  -- Re-read first row as template (already locked).
  select * into v_keep from public.staging where id = p_source_ids[1];

  insert into public.staging (
    so, customer, status, location, type, qty, weight, comments, staged_by, photo_urls, coords
  ) values (
    v_keep.so, v_keep.customer, v_keep.status, v_keep.location, trim(p_type), p_qty,
    v_keep.weight, v_keep.comments, v_keep.staged_by,
    coalesce(p_photo_urls, v_keep.photo_urls, array[]::text[]),
    v_keep.coords
  ) returning * into v_merged;

  delete from public.staging where id = any (p_source_ids);

  insert into public.consolidation_undo (user_id, merged_id, sources, expires_at)
  values (auth.uid(), v_merged.id, v_sources, now() + interval '2 minutes')
  returning id into v_undo_id;

  perform public._write_changelog(
    'staging',
    'Consolidated ' || v_count || ' rows for SO ' || v_keep.so || ': ' ||
    v_old_ids || ' → ' || v_merged.id
  );

  return jsonb_build_object(
    'merged', to_jsonb(v_merged),
    'undo_id', v_undo_id,
    'expires_at', (now() + interval '2 minutes')
  );
end;
$$;

revoke all on function public.consolidate_staging(uuid[], text, integer, text[]) from public;
grant execute on function public.consolidate_staging(uuid[], text, integer, text[]) to authenticated;

-- ---------------------------------------------------------------------------
-- reverse_consolidation
-- ---------------------------------------------------------------------------
create or replace function public.reverse_consolidation(p_undo_id uuid)
returns jsonb
language plpgsql
security invoker
set search_path = public
as $$
declare
  v_undo public.consolidation_undo%rowtype;
  v_src jsonb;
  v_restored uuid[] := array[]::uuid[];
  v_new public.staging%rowtype;
  v_so text;
begin
  if auth.uid() is null then
    raise exception 'Authentication required' using errcode = '42501';
  end if;

  select * into v_undo
  from public.consolidation_undo
  where id = p_undo_id and user_id = auth.uid()
  for update;

  if not found then
    raise exception 'Consolidation undo token not found' using errcode = 'P0002';
  end if;
  if v_undo.consumed_at is not null then
    raise exception 'Consolidation undo already used' using errcode = '22023';
  end if;
  if v_undo.expires_at < now() then
    raise exception 'Consolidation can only be reversed within two minutes'
      using errcode = '22023';
  end if;

  -- Ensure merged row still exists and was not further mutated away.
  if not exists (select 1 from public.staging where id = v_undo.merged_id for update) then
    raise exception 'Merged row no longer exists; cannot reverse' using errcode = 'P0002';
  end if;

  delete from public.staging where id = v_undo.merged_id;

  for v_src in select * from jsonb_array_elements(v_undo.sources)
  loop
    insert into public.staging (
      so, customer, status, location, type, qty, weight, comments, staged_by, photo_urls, coords
    ) values (
      v_src ->> 'so',
      v_src ->> 'customer',
      coalesce(v_src ->> 'status', 'Partial'),
      coalesce(v_src ->> 'location', ''),
      coalesce(v_src ->> 'type', ''),
      coalesce((v_src ->> 'qty')::integer, 0),
      v_src ->> 'weight',
      v_src ->> 'comments',
      v_src ->> 'staged_by',
      coalesce(
        (select array_agg(x) from jsonb_array_elements_text(coalesce(v_src -> 'photo_urls', '[]'::jsonb)) as t(x)),
        array[]::text[]
      ),
      v_src ->> 'coords'
    ) returning * into v_new;
    v_restored := array_append(v_restored, v_new.id);
    v_so := v_src ->> 'so';
  end loop;

  update public.consolidation_undo
  set consumed_at = now()
  where id = v_undo.id;

  perform public._write_changelog(
    'staging',
    'Reversed consolidation for SO ' || coalesce(v_so, '') || ': ' ||
    v_undo.merged_id || ' → ' || array_to_string(v_restored, ', ')
  );

  return jsonb_build_object('restored_ids', to_jsonb(v_restored));
end;
$$;

revoke all on function public.reverse_consolidation(uuid) from public;
grant execute on function public.reverse_consolidation(uuid) to authenticated;

-- ---------------------------------------------------------------------------
-- update_shipped_notification_status
-- ---------------------------------------------------------------------------
create or replace function public.update_shipped_notification_status(
  p_shipped_id uuid,
  p_status text,
  p_error text default null
)
returns void
language plpgsql
security invoker
set search_path = public
as $$
begin
  if auth.uid() is null then
    raise exception 'Authentication required' using errcode = '42501';
  end if;
  if p_status not in ('none', 'pending', 'sent', 'failed') then
    raise exception 'Invalid notification status' using errcode = '22023';
  end if;

  update public.shipped
  set
    notification_status = p_status,
    notification_error = case when p_status = 'failed' then p_error else null end,
    notified_at = case when p_status = 'sent' then now() else notified_at end
  where id = p_shipped_id;

  if not found then
    raise exception 'Shipped entry not found' using errcode = 'P0002';
  end if;
end;
$$;

revoke all on function public.update_shipped_notification_status(uuid, text, text) from public;
grant execute on function public.update_shipped_notification_status(uuid, text, text) to authenticated;

-- ---------------------------------------------------------------------------
-- Atomic watch pairing code claim (service_role / Edge Function)
-- ---------------------------------------------------------------------------
create or replace function public.claim_watch_pairing_code(p_code_hash text)
returns public.watch_pairing_codes
language plpgsql
security definer
set search_path = public
as $$
declare
  v_row public.watch_pairing_codes;
begin
  update public.watch_pairing_codes
  set consumed_at = now()
  where id = (
    select id
    from public.watch_pairing_codes
    where code_hash = p_code_hash
      and consumed_at is null
      and expires_at > now()
    for update skip locked
    limit 1
  )
  returning * into v_row;

  if not found then
    return null;
  end if;
  return v_row;
end;
$$;

revoke all on function public.claim_watch_pairing_code(text) from public, anon, authenticated;
grant execute on function public.claim_watch_pairing_code(text) to service_role;

-- Replace active codes for a user atomically (service_role)
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

revoke all on function public.replace_watch_pairing_code(uuid, text, timestamptz)
  from public, anon, authenticated;
grant execute on function public.replace_watch_pairing_code(uuid, text, timestamptz)
  to service_role;
