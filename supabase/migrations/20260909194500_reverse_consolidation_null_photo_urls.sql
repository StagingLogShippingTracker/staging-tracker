-- Hardening found while verifying the prepared_for_shipping migration:
-- reverse_consolidation crashes ("cannot extract elements from a scalar")
-- if a consolidated source row had a NULL photo_urls at merge time, because
-- to_jsonb() serializes SQL NULL as the JSON *value* null, and
-- coalesce(v_src -> 'photo_urls', '[]'::jsonb) does not treat that as
-- absent — the jsonb null passes through and jsonb_array_elements_text()
-- then fails on it (a scalar, not an array).
--
-- The app itself always sends photo_urls: [] (never omits it — see
-- StagingEntry(photoUrls = const [])), so this hasn't been hit in practice,
-- but the `photo_urls` column has no NOT NULL / default, so nothing else
-- guarantees that. Made the extraction NULL/scalar-safe.
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
      case
        when jsonb_typeof(v_src -> 'photo_urls') = 'array' then
          coalesce(
            (select array_agg(x) from jsonb_array_elements_text(v_src -> 'photo_urls') as t(x)),
            array[]::text[]
          )
        else array[]::text[]
      end,
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
