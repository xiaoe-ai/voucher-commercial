-- Read-only inspection for Phase 2F legacy issuance compatibility RPCs.
select
  p.proname as function_name,
  pg_get_function_identity_arguments(p.oid) as identity_arguments,
  pg_get_functiondef(p.oid) as function_definition
from pg_proc p
join pg_namespace n on n.oid=p.pronamespace
where n.nspname='public'
  and p.proname in (
    'create_partner_voucher',
    'create_partner_voucher_controlled',
    'sync_single_voucher_partner_engine'
  )
order by p.proname, pg_get_function_identity_arguments(p.oid);

-- Also show dependencies where other public functions reference these names.
select
  caller.proname as caller_function,
  pg_get_function_identity_arguments(caller.oid) as caller_identity_arguments,
  target_name
from pg_proc caller
join pg_namespace n on n.oid=caller.pronamespace
cross join lateral unnest(array[
  'create_partner_voucher',
  'create_partner_voucher_controlled',
  'sync_single_voucher_partner_engine'
]) target_name
where n.nspname='public'
  and pg_get_functiondef(caller.oid) ilike '%' || target_name || '%'
order by target_name, caller.proname;
