-- Read-only inspection for remaining system-layer RPCs.
select
  p.proname as function_name,
  pg_get_function_identity_arguments(p.oid) as identity_arguments,
  pg_get_functiondef(p.oid) as function_definition
from pg_proc p
join pg_namespace n on n.oid=p.pronamespace
where n.nspname='public'
  and p.proname in ('service_bootstrap_first_admin','system_integrity_health_check')
order by p.proname, pg_get_function_identity_arguments(p.oid);

-- Callers/dependencies referencing these functions.
select
  caller.proname as caller_function,
  pg_get_function_identity_arguments(caller.oid) as caller_identity_arguments,
  target_name
from pg_proc caller
join pg_namespace n on n.oid=caller.pronamespace
cross join lateral unnest(array['service_bootstrap_first_admin','system_integrity_health_check']) target_name
where n.nspname='public'
  and pg_get_functiondef(caller.oid) ilike '%' || target_name || '%'
order by target_name, caller.proname;

-- Cron jobs whose command or name looks related to health/integrity/bootstrap.
do $$
begin
  if to_regclass('cron.job') is not null then
    raise notice 'CRON_AVAILABLE';
  else
    raise notice 'CRON_UNAVAILABLE';
  end if;
end $$;

select jobid, jobname, schedule, command, active
from cron.job
where to_regclass('cron.job') is not null
  and (
    lower(coalesce(jobname,'')) like '%health%'
    or lower(coalesce(jobname,'')) like '%integrity%'
    or lower(coalesce(jobname,'')) like '%bootstrap%'
    or lower(coalesce(command,'')) like '%system_integrity_health_check%'
    or lower(coalesce(command,'')) like '%service_bootstrap_first_admin%'
  )
order by jobid;
