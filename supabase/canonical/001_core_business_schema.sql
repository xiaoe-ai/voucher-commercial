-- Commercial Voucher canonical rebuild baseline
-- Status: REBUILD-ONLY / NOT FOR LIVE APPLY
-- Source: verified live Commercial schema snapshot 2026-09-05
-- Purpose: establish customer-neutral core business tables, constraints and indexes.
-- Do not execute against the current live Commercial database because these objects already exist there.

create extension if not exists pgcrypto;

create table public.partners (
  id uuid primary key default gen_random_uuid(),
  partner_code text not null unique,
  partner_name text not null,
  contact_person text,
  contact_phone text,
  voucher_limit integer default 0,
  vouchers_issued integer default 0,
  status text default 'active',
  created_at timestamptz default now(),
  staff_limit integer not null default 0,
  staff_access_enabled boolean not null default false,
  constraint partners_staff_limit_check check (staff_limit >= 0),
  constraint partners_status_check check (status in ('active','suspended','inactive'))
);

create table public.branches (
  id uuid primary key default gen_random_uuid(),
  branch_code text not null unique,
  branch_name text not null,
  address text,
  phone text,
  status text default 'active',
  created_at timestamptz default now(),
  constraint branches_status_check check (status in ('active','inactive'))
);

create table public.partner_users (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null unique references auth.users(id) on delete cascade,
  partner_id uuid not null references public.partners(id) on delete cascade,
  role text default 'partner_admin',
  status text default 'active',
  created_at timestamptz default now(),
  staff_name text,
  updated_at timestamptz not null default now(),
  removed_at timestamptz,
  login_email text,
  constraint partner_users_role_check check (role in ('partner_admin','partner_staff','admin')),
  constraint partner_users_status_check check (status in ('active','suspended','inactive'))
);

create table public.staff_users (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null unique references auth.users(id) on delete cascade,
  branch_id uuid references public.branches(id),
  staff_name text not null,
  staff_code text not null,
  role text default 'staff',
  status text default 'active',
  created_at timestamptz default now(),
  name text,
  constraint staff_users_role_check check (role in ('staff','manager','all_branch_manager')),
  constraint staff_users_status_check check (status in ('active','suspended','inactive'))
);

create unique index staff_users_staff_code_uidx on public.staff_users (upper(staff_code));

create table public.voucher_templates (
  id uuid primary key default gen_random_uuid(),
  template_code text not null unique,
  template_name text not null,
  voucher_category text not null default 'custom',
  description text,
  status text not null default 'draft',
  created_by uuid,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  current_version_id uuid,
  theme_code text not null default 'classic',
  theme_config jsonb not null default '{}'::jsonb,
  constraint voucher_templates_status_check check (status in ('draft','active','retired','archived')),
  constraint voucher_templates_voucher_category_check check (voucher_category in ('cash','discount','service','product','custom'))
);

create table public.voucher_versions (
  id uuid primary key default gen_random_uuid(),
  template_id uuid not null references public.voucher_templates(id) on delete restrict,
  version_no integer not null,
  version_name text,
  face_value numeric(12,2),
  discount_percent numeric(7,4),
  validity_type text not null default 'days_after_issue',
  valid_days integer,
  valid_from date,
  valid_until date,
  min_spend numeric(12,2),
  max_discount numeric(12,2),
  usage_limit integer not null default 1,
  transferable boolean not null default true,
  terms_text text,
  supply_limit integer,
  status text not null default 'draft',
  effective_from timestamptz,
  created_by uuid,
  created_at timestamptz not null default now(),
  all_branches boolean not null default false,
  valid_months integer,
  validity_mode_v2 text,
  theme_override_code text,
  theme_override_config jsonb not null default '{}'::jsonb,
  validity_mode text,
  greeting_text text,
  constraint voucher_versions_template_id_version_no_key unique (template_id, version_no),
  constraint voucher_versions_check check (
    (validity_type='days_after_issue' and valid_days is not null and valid_days>0)
    or
    (validity_type='fixed' and valid_from is not null and valid_until is not null and valid_until>=valid_from)
  ),
  constraint voucher_versions_discount_percent_check check (discount_percent is null or (discount_percent>=0 and discount_percent<=100)),
  constraint voucher_versions_status_check check (status in ('draft','active','retired','archived','revoked')),
  constraint voucher_versions_supply_limit_check check (supply_limit is null or supply_limit>=0),
  constraint voucher_versions_usage_limit_check check (usage_limit>0),
  constraint voucher_versions_validity_type_check check (validity_type in ('fixed','days_after_issue')),
  constraint voucher_versions_version_no_check check (version_no>0)
);

alter table public.voucher_templates
  add constraint voucher_templates_current_version_id_fkey
  foreign key (current_version_id) references public.voucher_versions(id) on delete set null;

create table public.voucher_version_branches (
  version_id uuid not null references public.voucher_versions(id) on delete restrict,
  branch_id uuid not null references public.branches(id) on delete restrict,
  created_at timestamptz not null default now(),
  primary key (version_id, branch_id)
);

create table public.partner_voucher_allocations (
  id uuid primary key default gen_random_uuid(),
  partner_id uuid not null references public.partners(id) on delete restrict,
  version_id uuid not null references public.voucher_versions(id) on delete restrict,
  quantity_allocated integer not null,
  quantity_revoked integer not null default 0,
  status text not null default 'active',
  valid_from timestamptz,
  valid_until timestamptz,
  created_by uuid,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  validity_anchor text not null default 'issue',
  allocation_valid_days integer,
  all_branches boolean not null default true,
  constraint partner_voucher_allocations_check check (quantity_revoked <= quantity_allocated),
  constraint partner_voucher_allocations_quantity_allocated_check check (quantity_allocated >= 0),
  constraint partner_voucher_allocations_quantity_revoked_check check (quantity_revoked >= 0),
  constraint partner_voucher_allocations_status_check check (status in ('active','closed','revoked'))
);

create table public.vouchers (
  id uuid primary key default gen_random_uuid(),
  voucher_code text not null unique,
  partner_id uuid references public.partners(id),
  customer_name text not null,
  customer_phone text,
  customer_ic text,
  voucher_type text,
  expiry_date date not null,
  status text default 'valid',
  issued_at timestamptz default now(),
  redeemed_at timestamptz,
  redeemed_by text,
  all_branches boolean not null default false,
  activated_at timestamptz not null default now(),
  public_token uuid not null default gen_random_uuid(),
  issued_by_user_id uuid references auth.users(id) on delete set null,
  issued_by_name text,
  template_id uuid references public.voucher_templates(id) on delete restrict,
  version_id uuid references public.voucher_versions(id) on delete restrict,
  allocation_id uuid references public.partner_voucher_allocations(id) on delete set null,
  metadata jsonb not null default '{}'::jsonb,
  usage_count integer not null default 0,
  revoked_at timestamptz,
  revoked_by_user_id uuid,
  revoke_reason text,
  constraint vouchers_status_check check (status in ('valid','redeemed','expired','cancelled')),
  constraint vouchers_usage_count_check check (usage_count >= 0)
);

create unique index vouchers_public_token_key on public.vouchers(public_token);

create table public.voucher_branches (
  id uuid primary key default gen_random_uuid(),
  voucher_id uuid not null references public.vouchers(id) on delete cascade,
  branch_id uuid not null references public.branches(id) on delete cascade,
  created_at timestamptz default now(),
  unique (voucher_id, branch_id)
);

create table public.redemptions (
  id uuid primary key default gen_random_uuid(),
  voucher_id uuid not null references public.vouchers(id),
  branch_id uuid not null references public.branches(id),
  staff_user_id uuid not null references public.staff_users(id),
  redeemed_at timestamptz default now(),
  notes text,
  created_at timestamptz default now(),
  partner_id uuid references public.partners(id),
  staff_name_snapshot text,
  redeem_method text not null default 'qr_scan',
  status text not null default 'success',
  reversed_at timestamptz,
  reversed_by_user_id uuid,
  reversed_by_name text,
  reverse_reason text,
  constraint redemptions_redeem_method_check check (redeem_method in ('qr_scan','manual')),
  constraint redemptions_status_check check (status in ('success','reversed'))
);

create index idx_partner_users_partner_id on public.partner_users(partner_id);
create index idx_partner_users_partner_login_email on public.partner_users(partner_id, login_email) where login_email is not null;
create index idx_partner_users_partner_role_status on public.partner_users(partner_id, role, status);
create index idx_staff_users_branch_id on public.staff_users(branch_id);
create index idx_voucher_templates_current_version_id on public.voucher_templates(current_version_id);
create index idx_voucher_versions_template_status on public.voucher_versions(template_id, status);
create index idx_voucher_version_branches_branch_id on public.voucher_version_branches(branch_id);
create index idx_partner_voucher_allocations_partner_version on public.partner_voucher_allocations(partner_id, version_id, status);
create index idx_partner_voucher_allocations_version_id on public.partner_voucher_allocations(version_id);
create index idx_vouchers_partner_id on public.vouchers(partner_id);
create index idx_vouchers_issued_by_user_id on public.vouchers(issued_by_user_id);
create index idx_vouchers_template_version on public.vouchers(template_id, version_id);
create index idx_vouchers_version_id on public.vouchers(version_id);
create index idx_vouchers_allocation on public.vouchers(allocation_id);
create index idx_voucher_branches_branch_id on public.voucher_branches(branch_id);
create index idx_redemptions_branch_id on public.redemptions(branch_id);
create index idx_redemptions_partner_id on public.redemptions(partner_id);
create index idx_redemptions_redeemed_at on public.redemptions(redeemed_at desc);
create index idx_redemptions_staff_user_id on public.redemptions(staff_user_id);
create unique index uq_redemptions_one_success_per_voucher on public.redemptions(voucher_id) where status='success';

alter table public.partners enable row level security;
alter table public.branches enable row level security;
alter table public.partner_users enable row level security;
alter table public.staff_users enable row level security;
alter table public.voucher_templates enable row level security;
alter table public.voucher_versions enable row level security;
alter table public.voucher_version_branches enable row level security;
alter table public.partner_voucher_allocations enable row level security;
alter table public.vouchers enable row level security;
alter table public.voucher_branches enable row level security;
alter table public.redemptions enable row level security;

-- Customer-specific defaults, seed values and regional business assumptions are intentionally omitted.
-- RLS policies, RPCs, triggers and operational health/recovery objects are handled in later canonical layers.
