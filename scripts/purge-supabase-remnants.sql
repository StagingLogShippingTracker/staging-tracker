-- Purge SLST remnant production data (run in Supabase SQL Editor).
-- Safe to re-run. Does not touch staging/shipped if you already cleared those tables.

DELETE FROM public.dropdown_roster;
DELETE FROM public.changelog;
DELETE FROM storage.objects WHERE bucket_id = 'freight-photos';
