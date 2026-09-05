-- Read-only inspection for Phase 2C. No DDL/DML.
select
  p.proname as function_name,
  pg_get_function_identity_arguments(p.oid) as identity_arguments,
  pg_get_functiondef(p.oid) as function_definition
from pg_proc p
join pg_namespace n on n.oid=p.pronamespace
where n.nspname='public'
  and p.proname in ('verify_voucher','redeem_voucher')
order by p.proname, pg_get_function_identity_arguments(p.oid);
