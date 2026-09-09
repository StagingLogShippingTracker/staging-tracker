-- Carry the informational "Prepared for Shipping" marker through the three
-- staging row-transformation RPCs, which previously all reset it to the
-- column default (false) because their explicit insert column lists never
-- mentioned it. Ship / Quick Ship / Return remain fully unaffected — this
-- only touches Split, Consolidate, and Consolidate-undo.
--
-- Design:
--   * Split: nothing physically changed about readiness, so both new rows
--     inherit the source row's value.
--   * Consolidate: the merged row is only "prepared" if every source row
--     was — a partially-ready consolidation must not claim to be fully
--     ready.
--   * Reverse consolidation (undo): restores each row's original value from
--     the undo snapshot's jsonb, which already captured the full source row
--     via to_jsonb() — the data was there, just never read back out.

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
    so, customer, status, location, type, qty, weight, comments, staged_by,
    photo_urls, coords, prepared_for_shipping
  ) values (
    v_src.so, v_src.customer, v_src.status, v_src.location, p_first_type, p_first_qty,
    v_src.weight, v_src.comments, v_src.staged_by, v_src.photo_urls, v_src.coords,
    v_src.prepared_for_shipping
  ) returning * into v_a;

  insert into public.staging (
    so, customer, status, location, type, qty, weight, comments, staged_by,
    photo_urls, coords, prepared_for_shipping
  ) values (
    v_src.so, v_src.customer, v_src.status, v_src.location, p_second_type, p_second_qty,
    v_src.weight, v_src.comments, v_src.staged_by, v_src.photo_urls, v_src.coords,
    v_src.prepared_for_shipping
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
  v_all_prepared boolean := true;
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
    -- The merged row can only claim to be prepared if every source row was
    -- — a partially-ready consolidation must not silently look fully ready.
    v_all_prepared := v_all_prepared and coalesce(v_keep.prepared_for_shipping, false);
    v_sources := v_sources || jsonb_build_array(to_jsonb(v_keep));
    v_old_ids := case when v_old_ids = '' then v_id::text else v_old_ids || ', ' || v_id::text end;
    v_count := v_count + 1;
  end loop;

  -- Re-read first row as template (already locked).
  select * into v_keep from public.staging where id = p_source_ids[1];

  insert into public.staging (
    so, customer, status, location, type, qty, weight, comments, staged_by,
    photo_urls, coords, prepared_for_shipping
  ) values (
    v_keep.so, v_keep.customer, v_keep.status, v_keep.location, trim(p_type), p_qty,
    v_keep.weight, v_keep.comments, v_keep.staged_by,
    coalesce(p_photo_urls, v_keep.photo_urls, array[]::text[]),
    v_keep.coords, v_all_prepared
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
      so, customer, status, location, type, qty, weight, comments, staged_by,
      photo_urls, coords, prepared_for_shipping
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
      v_src ->> 'coords',
      coalesce((v_src ->> 'prepared_for_shipping')::boolean, false)
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
