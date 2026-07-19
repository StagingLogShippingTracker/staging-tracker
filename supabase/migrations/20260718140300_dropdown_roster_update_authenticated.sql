create policy "dropdown_roster_update_authenticated"
  on public.dropdown_roster for update
  to authenticated
  using (true)
  with check (true);
