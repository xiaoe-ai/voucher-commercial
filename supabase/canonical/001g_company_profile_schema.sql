-- Commercial Voucher canonical rebuild baseline
-- Status: REBUILD-ONLY / NOT FOR LIVE APPLY
-- Layer: 001G Company Profile schema only
-- Source: verified existing Commercial migration 20260905053000_company_profile.sql

create table public.company_profile (
  id text primary key default 'default' check (id='default'),
  company_name text not null,
  company_legal_name text,
  registration_no text,
  tagline text,
  phone text,
  website text,
  logo_url text,
  updated_at timestamptz not null default now(),
  updated_by uuid
);

alter table public.company_profile enable row level security;

insert into public.company_profile(id,company_name,tagline)
values ('default','Your Company','Voucher Platform');

-- Policies and trigger behavior depend on authorization helpers created in 002.
-- They are defined in 002a_company_profile_authorization.sql.
-- Grants are defined in 004_privileges_grants.sql.
