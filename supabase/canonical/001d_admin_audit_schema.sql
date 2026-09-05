-- Commercial Voucher canonical rebuild baseline
-- Status: REBUILD-ONLY / NOT FOR LIVE APPLY
-- Layer: 001D Admin audit schema
-- Source: verified live Commercial schema snapshot 2026-09-05

create table public.admin_audit_log (
  id uuid primary key default gen_random_uuid(),
  actor_user_id uuid,
  action_type text not null,
  entity_type text not null,
  entity_id text,
  partner_id uuid,
  before_data jsonb,
  after_data jsonb,
  metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now()
);

create index idx_admin_audit_log_actor
  on public.admin_audit_log(actor_user_id, created_at desc);
create index idx_admin_audit_log_created_at
  on public.admin_audit_log(created_at desc);
create index idx_admin_audit_log_partner
  on public.admin_audit_log(partner_id, created_at desc);

alter table public.admin_audit_log enable row level security;

-- RLS policy and grants are handled in later canonical layers.
-- No EVO / Evolution Optical / regional assumptions are present here.
