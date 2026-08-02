-- Log rows are written only by notify-pm (service_role). Clients retain SELECT.
drop policy if exists notification_log_insert_authenticated on public.notification_log;
revoke insert on public.notification_log from authenticated;
grant select on public.notification_log to authenticated;
grant all on public.notification_log to service_role;
