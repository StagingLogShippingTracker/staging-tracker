-- Remove unused SMS gateway column; notifications are email-only.
alter table public.notification_log
  drop column if exists pm_phone_gateway;

comment on table public.notification_log is
  'Append-only log of notify-pm email deliveries for Filters/Export on the Notifications page.';
