-- Open floor-app tables, storage, and RPCs to the anon key so the client
-- can run without a signed-in user. Secrets stay service-role only.

-- ---------------------------------------------------------------------------
-- Table grants + RLS (anon + authenticated)
-- ---------------------------------------------------------------------------
grant usage on schema public to anon;

grant select, insert, update, delete on public.staging to anon, authenticated;
grant select, insert, update, delete on public.shipped to anon, authenticated;
grant select, insert, update, delete on public.changelog to anon, authenticated;
grant select, insert, update, delete on public.dropdown_roster to anon, authenticated;
grant select, insert, update, delete on public.verification_audit_state to anon, authenticated;
grant select, insert, update, delete on public.consolidation_undo to anon, authenticated;
grant select on public.notification_log to anon, authenticated;

alter table public.consolidation_undo
  alter column user_id drop not null;

alter table public.consolidation_undo
  drop constraint if exists consolidation_undo_user_id_fkey;

-- staging
drop policy if exists "staging_select_authenticated" on public.staging;
drop policy if exists "staging_select_all" on public.staging;
drop policy if exists "staging_insert_authenticated" on public.staging;
drop policy if exists "staging_update_authenticated" on public.staging;
drop policy if exists "staging_delete_authenticated" on public.staging;
create policy "staging_select_open" on public.staging for select to anon, authenticated using (true);
create policy "staging_insert_open" on public.staging for insert to anon, authenticated with check (true);
create policy "staging_update_open" on public.staging for update to anon, authenticated using (true) with check (true);
create policy "staging_delete_open" on public.staging for delete to anon, authenticated using (true);

-- shipped
drop policy if exists "shipped_select_authenticated" on public.shipped;
drop policy if exists "shipped_select_all" on public.shipped;
drop policy if exists "shipped_insert_authenticated" on public.shipped;
drop policy if exists "shipped_update_authenticated" on public.shipped;
drop policy if exists "shipped_delete_authenticated" on public.shipped;
create policy "shipped_select_open" on public.shipped for select to anon, authenticated using (true);
create policy "shipped_insert_open" on public.shipped for insert to anon, authenticated with check (true);
create policy "shipped_update_open" on public.shipped for update to anon, authenticated using (true) with check (true);
create policy "shipped_delete_open" on public.shipped for delete to anon, authenticated using (true);

-- changelog
drop policy if exists "changelog_select_authenticated" on public.changelog;
drop policy if exists "changelog_select_all" on public.changelog;
drop policy if exists "changelog_insert_authenticated" on public.changelog;
create policy "changelog_select_open" on public.changelog for select to anon, authenticated using (true);
create policy "changelog_insert_open" on public.changelog for insert to anon, authenticated with check (true);

-- dropdown_roster
drop policy if exists "dropdown_roster_select_authenticated" on public.dropdown_roster;
drop policy if exists "dropdown_roster_select_all" on public.dropdown_roster;
drop policy if exists "dropdown_roster_update_authenticated" on public.dropdown_roster;
create policy "dropdown_roster_select_open" on public.dropdown_roster for select to anon, authenticated using (true);
create policy "dropdown_roster_insert_open" on public.dropdown_roster for insert to anon, authenticated with check (true);
create policy "dropdown_roster_update_open" on public.dropdown_roster for update to anon, authenticated using (true) with check (true);

-- verification_audit_state
drop policy if exists "verification_audit_state_select_own" on public.verification_audit_state;
drop policy if exists "verification_audit_state_insert_own" on public.verification_audit_state;
drop policy if exists "verification_audit_state_update_own" on public.verification_audit_state;
drop policy if exists "verification_audit_state_delete_own" on public.verification_audit_state;
create policy "verification_audit_state_open_select" on public.verification_audit_state for select to anon, authenticated using (true);
create policy "verification_audit_state_open_insert" on public.verification_audit_state for insert to anon, authenticated with check (true);
create policy "verification_audit_state_open_update" on public.verification_audit_state for update to anon, authenticated using (true) with check (true);
create policy "verification_audit_state_open_delete" on public.verification_audit_state for delete to anon, authenticated using (true);

-- consolidation_undo
drop policy if exists "consolidation_undo_select_own" on public.consolidation_undo;
drop policy if exists "consolidation_undo_insert_own" on public.consolidation_undo;
drop policy if exists "consolidation_undo_update_own" on public.consolidation_undo;
drop policy if exists "consolidation_undo_delete_own" on public.consolidation_undo;
create policy "consolidation_undo_open_select" on public.consolidation_undo for select to anon, authenticated using (true);
create policy "consolidation_undo_open_insert" on public.consolidation_undo for insert to anon, authenticated with check (true);
create policy "consolidation_undo_open_update" on public.consolidation_undo for update to anon, authenticated using (true) with check (true);
create policy "consolidation_undo_open_delete" on public.consolidation_undo for delete to anon, authenticated using (true);

-- notification_log (reads)
drop policy if exists "notification_log_select_authenticated" on public.notification_log;
create policy "notification_log_select_open" on public.notification_log for select to anon, authenticated using (true);

-- storage: freight-photos writes for anon
drop policy if exists "freight_photos_insert_authenticated" on storage.objects;
drop policy if exists "freight_photos_update_authenticated" on storage.objects;
drop policy if exists "freight_photos_delete_authenticated" on storage.objects;
create policy "freight_photos_insert_open"
  on storage.objects for insert to anon, authenticated
  with check (bucket_id = 'freight-photos');
create policy "freight_photos_update_open"
  on storage.objects for update to anon, authenticated
  using (bucket_id = 'freight-photos')
  with check (bucket_id = 'freight-photos');
create policy "freight_photos_delete_open"
  on storage.objects for delete to anon, authenticated
  using (bucket_id = 'freight-photos');

grant execute on all functions in schema public to anon;

-- Strip "Authentication required" guards from inventory RPCs.
do $$
declare
  r record;
  src text;
begin
  for r in
    select p.oid
    from pg_proc p
    join pg_namespace n on n.oid = p.pronamespace
    where n.nspname = 'public'
      and p.prokind = 'f'
      and pg_get_functiondef(p.oid) like '%Authentication required%'
  loop
    src := pg_get_functiondef(r.oid);
    src := replace(
      src,
      e'  if auth.uid() is null then\n    raise exception \'Authentication required\' using errcode = \'42501\';\n  end if;\n',
      ''
    );
    src := replace(src, 'where id = p_undo_id and user_id = auth.uid()', 'where id = p_undo_id');
    execute src;
  end loop;
end $$;
