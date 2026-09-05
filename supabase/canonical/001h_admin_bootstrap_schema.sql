-- Commercial Voucher canonical rebuild baseline
-- Status: REBUILD-ONLY / NOT FOR LIVE APPLY
-- Layer: 001H First Admin bootstrap configuration
-- Purpose: recreate one-time bootstrap state without customer-specific defaults.

create table public.admin_bootstrap_config (
  singleton boolean primary key default true check (singleton = true),
  setup_code_hash text,
  enabled boolean not null default false,
  consumed_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

insert into public.admin_bootstrap_config(singleton, setup_code_hash, enabled)
values (true, null, false);

alter table public.admin_bootstrap_config enable row level security;

-- Service-controlled state: no direct anon/authenticated policy here.
