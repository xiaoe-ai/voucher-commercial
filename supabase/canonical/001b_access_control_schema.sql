-- Commercial Voucher canonical rebuild baseline
-- Status: REBUILD-ONLY / NOT FOR LIVE APPLY
-- Layer: 001B access-control schema dependencies
-- Source: verified live Commercial schema snapshot 2026-09-05

create table public.partner_voucher_access (
  id uuid primary key default gen_random_uuid(),
  partner_id uuid not null references public.partners(id) on delete restrict,
  template_id uuid not null references public.voucher_templates(id) on delete restrict,
  status text not null default 'active',
  quota_type text not null default 'unlimited',
  quota_limit integer,
  valid_from timestamptz,
  valid_until timestamptz,
  created_by uuid,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (partner_id, template_id),
  constraint partner_voucher_access_check check (
    (quota_type='unlimited' and quota_limit is null)
    or
    (quota_type in ('total','monthly') and quota_limit is not null)
  ),
  constraint partner_voucher_access_quota_limit_check check (quota_limit is null or quota_limit >= 0),
  constraint partner_voucher_access_quota_type_check check (quota_type in ('unlimited','total','monthly')),
  constraint partner_voucher_access_status_check check (status in ('active','suspended','ended'))
);

create index idx_partner_voucher_access_partner_status
  on public.partner_voucher_access(partner_id, status);
create index idx_partner_voucher_access_template_id
  on public.partner_voucher_access(template_id);

create table public.partner_claim_settings (
  partner_id uuid primary key references public.partners(id) on delete cascade,
  all_branches boolean not null default false,
  updated_at timestamptz not null default now(),
  updated_by uuid
);

create table public.partner_claim_branches (
  partner_id uuid not null references public.partners(id) on delete cascade,
  branch_id uuid not null references public.branches(id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (partner_id, branch_id)
);

create index idx_partner_claim_branches_branch_id
  on public.partner_claim_branches(branch_id);

alter table public.partner_voucher_access enable row level security;
alter table public.partner_claim_settings enable row level security;
alter table public.partner_claim_branches enable row level security;

-- Intentionally no customer-specific seed rows.
-- RLS policies are defined in the next canonical layer.
