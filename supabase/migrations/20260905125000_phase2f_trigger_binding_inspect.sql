-- Read-only trigger binding inspection for sync_single_voucher_partner_engine().
select
  t.tgname as trigger_name,
  n.nspname as table_schema,
  c.relname as table_name,
  t.tgenabled as enabled_state,
  pg_get_triggerdef(t.oid, true) as trigger_definition
from pg_trigger t
join pg_class c on c.oid=t.tgrelid
join pg_namespace n on n.oid=c.relnamespace
join pg_proc p on p.oid=t.tgfoid
where not t.tgisinternal
  and n.nspname='public'
 