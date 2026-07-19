-- Tighten RLS: anonymous clients may read; only authenticated users may write.
-- Storage uploads require authentication; public read for freight photos remains.

-- staging
drop policy if exists "Allow public access to staging" on public.staging;
create policy "staging_select_all"
  on public.staging for select
  to anon, authenticated
  using (true);
create policy "staging_insert_authenticated"
  on public.staging for insert
  to authenticated
  with check (true);
create policy "staging_update_authenticated"
  on public.staging for update
  to authenticated
  using (true)
  with check (true);
create policy "staging_delete_authenticated"
  on public.staging for delete
  to authenticated
  using (true);

-- shipped
drop policy if exists "Allow public access to shipped" on public.shipped;
create policy "shipped_select_all"
  on public.shipped for select
  to anon, authenticated
  using (true);
create policy "shipped_insert_authenticated"
  on public.shipped for insert
  to authenticated
  with check (true);
create policy "shipped_update_authenticated"
  on public.shipped for update
  to authenticated
  using (true)
  with check (true);
create policy "shipped_delete_authenticated"
  on public.shipped for delete
  to authenticated
  using (true);

-- changelog
drop policy if exists "Allow public access to changelog" on public.changelog;
create policy "changelog_select_all"
  on public.changelog for select
  to anon, authenticated
  using (true);
create policy "changelog_insert_authenticated"
  on public.changelog for insert
  to authenticated
  with check (true);

-- dropdown_roster: keep select for anon/authenticated; insert already authenticated-only
drop policy if exists "dropdown_roster_select_anon" on public.dropdown_roster;
drop policy if exists "dropdown_roster_select_authenticated" on public.dropdown_roster;
create policy "dropdown_roster_select_all"
  on public.dropdown_roster for select
  to anon, authenticated
  using (true);

-- storage: freight-photos — public read, authenticated write
drop policy if exists "Public Upload Access" on storage.objects;
create policy "freight_photos_insert_authenticated"
  on storage.objects for insert
  to authenticated
  with check (bucket_id = 'freight-photos');
create policy "freight_photos_update_authenticated"
  on storage.objects for update
  to authenticated
  using (bucket_id = 'freight-photos')
  with check (bucket_id = 'freight-photos');
create policy "freight_photos_delete_authenticated"
  on storage.objects for delete
  to authenticated
  using (bucket_id = 'freight-photos');
