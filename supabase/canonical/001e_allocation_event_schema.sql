-- Commercial Voucher canonical rebuild baseline
-- Status: REBUILD-ONLY / NOT FOR LIVE APPLY
-- Layer: 001E allocation event schema
-- Source: verified live Commercial schema snapshot 2026-09-05

create table public.voucher_allocation_events (
  id uuid primary key default gen_random_uuid(),
  allocation_id uuid not null references public.partner_voucher_allocations(id) on delete restrict,
  partner_id uuid not null references public.partners(id) on delete restrict,
  version_id uuid not null references public.voucher_versions(id) on delete restrict,
  event_type text not null,
  quantity integer not null,
  reason text,
  actor_user_id uuid,
  created_at timestamptz not null default now(),
  constraint voucher_allocation_events_event_type_check
    check (event_type in ('allocated','increased','revoked_unissued','closed')),
  constraint voucher_allocation_events_quantity_check
    check (quantity >= 0)
);

create index idx_voucher_allocation_events_allocation
  on public.voucher_allocation_events(allocation_id, created_at desc);
create index idx_voucher_allocation_events_partner
  on public.voucher_allocation_events(partner_id, created_at desc);
create index idx_voucher_allocation_events_version_id
  on public.voucher_allocation_events(version_id);

alter table public.voucher_allocation_events enable row level security;

-- No customer-specific seed rows.
-- Policies and grants remain in their dedicated canonical layers.
