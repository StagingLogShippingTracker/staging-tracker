-- Authenticated-only reads for public app data tables.
-- Anonymous clients may no longer SELECT staging/shipped/changelog/dropdown_roster.
-- Write policies remain authenticated-only (unchanged).
--
-- Also enable RLS on private.app_secrets with NO policies (intentional).
-- Access stays via service_role (bypasses RLS) and public.get_app_secret
-- (SECURITY DEFINER, owner postgres, EXECUTE granted only to service_role).

-- staging
drop policy if exists "staging_select_all" on public.staging;
create policy "staging_select_authenticated"
  on public.staging for select
  to authenticated
  using (true);

-- shipped
drop policy if exists "shipped_select_all" on public.shipped;
create policy "shipped_select_authenticated"
  on public.shipped for select
  to authenticated
  using (true);

-- changelog
drop policy if exists "changelog_select_all" on public.changelog;
create policy "changelog_select_authenticated"
  on public.changelog for select
  to authenticated
  using (true);

-- dropdown_roster
drop policy if exists "dropdown_roster_select_all" on public.dropdown_roster;
create policy "dropdown_roster_select_authenticated"
  on public.dropdown_roster for select
  to authenticated
  using (true);

-- private.app_secrets defense-in-depth (advisor: RLS disabled)
alter table private.app_secrets enable row level security;
