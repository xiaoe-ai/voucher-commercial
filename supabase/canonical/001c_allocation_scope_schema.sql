-- Commercial Voucher canonical rebuild baseline
-- Status: REBUILD-ONLY / NOT FOR LIVE APPLY
-- Layer: 001C allocation branch scope
-- Source: verified live Commercial schema snapshot 2026-09-05

create table public.voucher_allocation_branches (
  allocation_id uuid not null references public.partner_voucher_allocations(id) on delete restrict,
  branch_id uuid not null references public.branches(id) on delete restrict,
  created_at timestamptz not null default now(),
  primary key (allocation_id, branch_id)
);

create index idx_voucher_allocation_branches_branch_id
  on public.voucher_allocation_branches(branch_id);

alter table public.voucher_allocation_branches enable row level security;

-- RLS policies for this table are defined in the authorization layer.
-- No customer-specific branch seed rows are included.
