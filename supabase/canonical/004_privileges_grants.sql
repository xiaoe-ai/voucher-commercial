-- Commercial Voucher canonical rebuild baseline
-- Status: REBUILD-ONLY / NOT FOR LIVE APPLY
-- Layer: 004 Privileges / GRANT / REVOKE
-- Source: verified live Commercial privilege snapshot 2026-09-05
-- Snapshot workflow run: 33957214910
--
-- Goal:
--   1. preserve required authenticated frontend access behind RLS,
--   2. remove anonymous write capability from canonical rebuild,
--   3. keep service-only RPCs unavailable to normal authenticated users,
--   4. revoke PUBLIC execution on application RPCs before granting explicitly.

-- -----------------------------------------------------------------------------
-- Schema usage
-- -----------------------------------------------------------------------------
revoke all on schema public from public;
grant usage on schema public to anon, authenticated, service_role;

-- -----------------------------------------------------------------------------
-- Table privileges
-- -----------------------------------------------------------------------------
-- Start from a deny-by-default posture for application roles.
revoke all on all tables in schema public from anon, authenticated;

-- service_role is the trusted backend role used by Edge Functions / server paths.
grant select, insert, update, delete on all tables in schema public to service_role;

-- Authenticated clients still need direct access to RLS-protected application
-- tables used by Admin / Partner / Staff frontends. RLS remains the row boundary.
grant select, insert, update, delete on table
  public.company_profile,
  public.partners,
  public.branches,
  public.partner_users,
  public.staff_users,
  public.voucher_templates,
  public.voucher_versions,
  public.voucher_version_branches,
  public.partner_voucher_access,
  public.partner_voucher_allocations,
  public.partner_claim_settings,
  public.partner_claim_branches,
  public.voucher_branches,
  public.vouchers,
  public.redemptions
  to authenticated;

-- Audit/event tables are read-only to authenticated users; writes occur through
-- SECURITY DEFINER or service-role paths.
grant select on table
  public.admin_audit_log,
  public.voucher_allocation_events
  to authenticated;

-- Allocation branch scope is server-managed in canonical rebuild.
grant select on table
  public.voucher_allocation_branches
  to authenticated;

-- Canonical anonymous access is intentionally narrow. Public voucher viewing
-- should use a dedicated public RPC rather than direct table reads.
grant select on table
  public.company_profile,
  public.branches
  to anon;

-- No anon INSERT / UPDATE / DELETE / TRUNCATE / TRIGGER / REFERENCES grants.

-- -----------------------------------------------------------------------------
-- Function privilege helper policy
-- -----------------------------------------------------------------------------
-- Every application RPC below is explicitly revoked from PUBLIC/anon first.
-- PostgreSQL owner/postgres retains owner rights automatically.

-- Auth / authorization helpers used by authenticated RLS / frontend paths.
revoke all on function public.is_admin() from public, anon, authenticated, service_role;
grant execute on function public.is_admin() to authenticated, service_role;

revoke all on function public.is_voucher_admin() from public, anon, authenticated, service_role;
grant execute on function public.is_voucher_admin() to authenticated, service_role;

revoke all on function public.is_partner_admin_for_partner(uuid) from public, anon, authenticated, service_role;
grant execute on function public.is_partner_admin_for_partner(uuid) to authenticated, service_role;

-- Trusted service-role detector must not be callable as an application feature.
-- Even though the live snapshot currently grants EXECUTE to authenticated,
-- canonical rebuild narrows it to service_role only.
revoke all on function public.is_trusted_service_role() from public, anon, authenticated, service_role;
grant execute on function public.is_trusted_service_role() to service_role;

-- -----------------------------------------------------------------------------
-- Staff user-facing RPCs
-- -----------------------------------------------------------------------------
revoke all on function public.verify_voucher(text) from public, anon, authenticated, service_role;
grant execute on function public.verify_voucher(text) to authenticated, service_role;

revoke all on function public.redeem_voucher(text,text) from public, anon, authenticated, service_role;
grant execute on function public.redeem_voucher(text,text) to authenticated, service_role;

-- -----------------------------------------------------------------------------
-- Partner user-facing RPCs
-- -----------------------------------------------------------------------------
revoke all on function public.get_my_partner_dashboard() from public, anon, authenticated, service_role;
grant execute on function public.get_my_partner_dashboard() to authenticated, service_role;

revoke all on function public.get_my_partner_claim_access() from public, anon, authenticated, service_role;
grant execute on function public.get_my_partner_claim_access() to authenticated, service_role;

revoke all on function public.partner_staff_capacity() from public, anon, authenticated, service_role;
grant execute on function public.partner_staff_capacity() to authenticated, service_role;

revoke all on function public.partner_set_staff_access(boolean) from public, anon, authenticated, service_role;
grant execute on function public.partner_set_staff_access(boolean) to authenticated, service_role;

revoke all on function public.create_partner_multi_voucher_controlled(uuid,text,text) from public, anon, authenticated, service_role;
grant execute on function public.create_partner_multi_voucher_controlled(uuid,text,text) to authenticated, service_role;

-- -----------------------------------------------------------------------------
-- Admin authenticated wrappers
-- -----------------------------------------------------------------------------
revoke all on function public.admin_create_voucher_template_theme(text,text,text,text,text)
  from public, anon, authenticated, service_role;
grant execute on function public.admin_create_voucher_template_theme(text,text,text,text,text)
  to authenticated, service_role;

revoke all on function public.admin_publish_voucher_version_theme(uuid,text,numeric,numeric,text,integer,integer,numeric,numeric,integer,boolean,text,integer,boolean,text)
  from public, anon, authenticated, service_role;
grant execute on function public.admin_publish_voucher_version_theme(uuid,text,numeric,numeric,text,integer,integer,numeric,numeric,integer,boolean,text,integer,boolean,text)
  to authenticated, service_role;

revoke all on function public.admin_get_partner_claim_access(uuid)
  from public, anon, authenticated, service_role;
grant execute on function public.admin_get_partner_claim_access(uuid)
  to authenticated, service_role;

revoke all on function public.admin_set_partner_claim_access(uuid,boolean,text[])
  from public, anon, authenticated, service_role;
grant execute on function public.admin_set_partner_claim_access(uuid,boolean,text[])
  to authenticated, service_role;

-- -----------------------------------------------------------------------------
-- Service-only voucher engine RPCs
-- -----------------------------------------------------------------------------
revoke all on function public.svc_admin_create_voucher_template_v2(uuid,text,text,text,text,text)
  from public, anon, authenticated, service_role;
grant execute on function public.svc_admin_create_voucher_template_v2(uuid,text,text,text,text,text)
  to service_role;

revoke all on function public.svc_admin_publish_voucher_version_v3(uuid,uuid,text,numeric,numeric,text,integer,integer,numeric,numeric,integer,boolean,text,integer,boolean,text)
  from public, anon, authenticated, service_role;
grant execute on function public.svc_admin_publish_voucher_version_v3(uuid,uuid,text,numeric,numeric,text,integer,integer,numeric,numeric,integer,boolean,text,integer,boolean,text)
  to service_role;

revoke all on function public.svc_admin_allocate_voucher_to_partner(uuid,uuid,uuid,integer,timestamptz,timestamptz)
  from public, anon, authenticated, service_role;
grant execute on function public.svc_admin_allocate_voucher_to_partner(uuid,uuid,uuid,integer,timestamptz,timestamptz)
  to service_role;

revoke all on function public.svc_admin_allocate_voucher_to_all_partners(uuid,uuid,integer,timestamptz,timestamptz)
  from public, anon, authenticated, service_role;
grant execute on function public.svc_admin_allocate_voucher_to_all_partners(uuid,uuid,integer,timestamptz,timestamptz)
  to service_role;

revoke all on function public.svc_admin_revoke_unissued_allocation(uuid,uuid,integer,text)
  from public, anon, authenticated, service_role;
grant execute on function public.svc_admin_revoke_unissued_allocation(uuid,uuid,integer,text)
  to service_role;

revoke all on function public.svc_admin_retire_voucher_version(uuid,uuid,text)
  from public, anon, authenticated, service_role;
grant execute on function public.svc_admin_retire_voucher_version(uuid,uuid,text)
  to service_role;

-- Service-role admin engine wrappers.
revoke all on function public.admin_engine_allocate(uuid,uuid,integer,timestamptz,timestamptz)
  from public, anon, authenticated, service_role;
grant execute on function public.admin_engine_allocate(uuid,uuid,integer,timestamptz,timestamptz)
  to service_role;

revoke all on function public.admin_engine_allocate_all(uuid,integer,timestamptz,timestamptz)
  from public, anon, authenticated, service_role;
grant execute on function public.admin_engine_allocate_all(uuid,integer,timestamptz,timestamptz)
  to service_role;

revoke all on function public.admin_engine_revoke_unissued(uuid,integer,text)
  from public, anon, authenticated, service_role;
grant execute on function public.admin_engine_revoke_unissued(uuid,integer,text)
  to service_role;

revoke all on function public.admin_engine_retire_version(uuid,text)
  from public, anon, authenticated, service_role;
grant execute on function public.admin_engine_retire_version(uuid,text)
  to service_role;

-- -----------------------------------------------------------------------------
-- Default privileges for future canonical objects
-- -----------------------------------------------------------------------------
-- Avoid PostgreSQL's default PUBLIC EXECUTE on newly-created functions.
alter default privileges in schema public revoke execute on functions from public;

-- New service-owned tables should not automatically become anonymous-writeable.
alter default privileges in schema public revoke all on tables from anon, authenticated;
alter default privileges in schema public grant select, insert, update, delete on tables to service_role;

-- Notes:
-- * This layer intentionally does NOT reproduce live anon CRUD grants.
-- * RLS remains mandatory on every application table.
-- * Public voucher viewing should be canonicalized as an explicit safe RPC.
-- * Additional frontend/reporting RPCs will receive grants in their own canonical layers.
