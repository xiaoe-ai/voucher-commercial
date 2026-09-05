-- Commercial Voucher canonical live preflight
-- Safety: READ-ONLY checks only. Intended for dry_run through Commercial Migration Channel V1.
-- No DDL/DML changes are performed by this file.

-- 1) Route/database guard visibility
select
  current_database() as database_name,
  current_user as database_user,
  now() as checked_at;

-- 2) Required table presence
with required(name) as (
  values
    ('partners'),('branches'),('partner_users'),('staff_users'),
    ('voucher_templates'),('voucher_versions'),('voucher_version_branches'),
    ('partner_voucher_access'),('partner_voucher_allocations'),
    ('voucher_allocation_branches'),('vouchers'),('voucher_branches'),
    ('redemptions'),('admin_audit_log'),('voucher_allocation_events'),
    ('partner_claim_settings'),('partner_claim_branches'),('company_profile')
), present as (
  select table_name as name
  from information_schema.tables
  where table_schema='public' and table_type='BASE TABLE'
)
select r.name as missing_table
from required r
left join present p using(name)
where p.name is null
order by r.name;

-- 3) Required RPC presence
with required(name) as (
  values
    ('is_admin'),('is_voucher_admin'),('is_partner_admin_for_partner'),
    ('verify_voucher'),('redeem_voucher'),
    ('get_my_partner_dashboard'),('get_my_partner_claim_access'),
    ('partner_staff_capacity'),('partner_set_staff_access'),
    ('create_partner_multi_voucher_controlled'),
    ('admin_create_voucher_template_theme'),
    ('admin_publish_voucher_version_theme'),
    ('admin_get_partner_claim_access'),('admin_set_partner_claim_access'),
    ('admin_engine_allocate'),('admin_engine_allocate_all'),
    ('admin_engine_revoke_unissued'),('admin_engine_retire_version'),
    ('get_public_voucher'),('get_partner_voucher_share'),
    ('partner_recent_vouchers'),('partner_voucher_summary'),
    ('staff_operational_context'),('staff_recent_redemptions'),('staff_today_summary'),
    ('admin_dashboard_summary'),('admin_redemption_report'),('admin_voucher_report')
), present as (
  select distinct p.proname as name
  from pg_proc p
  join pg_namespace n on n.oid=p.pronamespace
  where n.nspname='public'
)
select r.name as missing_rpc
from required r
left join present p using(name)
where p.name is null
order by r.name;

-- 4) RLS status for application tables
select c.relname as table_name, c.relrowsecurity as rls_enabled
from pg_class c
join pg_namespace n on n.oid=c.relnamespace
where n.nspname='public'
  and c.relkind='r'
  and c.relname in (
    'partners','branches','partner_users','staff_users',
    'voucher_templates','voucher_versions','voucher_version_branches',
    'partner_voucher_access','partner_voucher_allocations',
    'voucher_allocation_branches','vouchers','voucher_branches',
    'redemptions','admin_audit_log','voucher_allocation_events',
    'partner_claim_settings','partner_claim_branches','company_profile'
  )
order by c.relname;

-- 5) Customer-specific / regional assumptions still present in live function bodies.
-- Findings are reported only; this preflight does not modify them.
select
  p.proname as function_name,
  pg_get_function_identity_arguments(p.oid) as identity_arguments,
  case
    when pg_get_functiondef(p.oid) ilike '%Evolution Optical%' then 'legacy_brand_copy'
    when pg_get_functiondef(p.oid) ilike '%EVO-FREE-GLASSES%' then 'legacy_template_code'
    when pg_get_functiondef(p.oid) ilike '%Asia/Kuala_Lumpur%' then 'fixed_timezone'
    when pg_get_functiondef(p.oid) ~ '(^|[^A-Za-z0-9_])EO-' then 'legacy_code_prefix'
    when pg_get_functiondef(p.oid) ~ '(^|[^A-Za-z0-9_])RM[0-9]' then 'hardcoded_currency_display'
    else 'other'
  end as finding_type
from pg_proc p
join pg_namespace n on n.oid=p.pronamespace
where n.nspname='public'
  and (
    pg_get_functiondef(p.oid) ilike '%Evolution Optical%'
    or pg_get_functiondef(p.oid) ilike '%EVO-FREE-GLASSES%'
    or pg_get_functiondef(p.oid) ilike '%Asia/Kuala_Lumpur%'
    or pg_get_functiondef(p.oid) ~ '(^|[^A-Za-z0-9_])EO-'
    or pg_get_functiondef(p.oid) ~ '(^|[^A-Za-z0-9_])RM[0-9]'
  )
order by p.proname, pg_get_function_identity_arguments(p.oid);

-- 6) Live default residue check
select
  table_schema,
  table_name,
  column_name,
  column_default
from information_schema.columns
where table_schema='public'
  and table_name='vouchers'
  and column_name='voucher_type';

-- 7) Privilege visibility for critical roles
select routine_name, grantee, privilege_type
from information_schema.role_routine_grants
where routine_schema='public'
  and grantee in ('anon','authenticated','service_role')
  and routine_name in (
    'verify_voucher','redeem_voucher','create_partner_multi_voucher_controlled',
    'admin_engine_allocate','admin_engine_allocate_all',
    'admin_engine_revoke_unissued','admin_engine_retire_version',
    'is_trusted_service_role'
  )
order by routine_name, grantee, privilege_type;

-- 8) Preflight marker
select 'COMMERCIAL_CANONICAL_PREFLIGHT_COMPLETE' as status;
