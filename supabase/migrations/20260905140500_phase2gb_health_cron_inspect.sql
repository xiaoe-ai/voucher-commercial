-- Read-only inspection for Phase 2G-B.
select
  p.proname as function_name,
  pg_get_function_identity_arguments(p.oid) as identity_arguments,
  pg_get_functiondef(p.oid) as function_definition
from pg_proc p
join pg_namespace n on n.oid=p.pronamespace
where n.nspname='public'
  and p.proname='run_system_integrity_monitor';

select
  n.nspname as schema_name,
  p.proname as function_name,
  pg_get_function_identity_arguments(p.oid) as identity_arguments
from pg_proc p
join pg_namespace n on n.oid=p.pronamespace
where n.nspname='cron'
  and p.proname in ('alter_job','schedule','unschedule')
order by p.proname, pg_get_function_identity_arguments(p.oid);

select jobid, jobname, schedule, command, active
from cron.job
where jobname='evolution_integrity_health_hourly'
   or command ilike '%run_system_integrity_monitor%'
order by jobid;
