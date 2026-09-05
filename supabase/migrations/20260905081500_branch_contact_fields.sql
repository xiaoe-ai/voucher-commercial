alter table if exists public.branches
  add column if not exists address_line1 text,
  add column if not exists address_line2 text,
  add column if not exists city text,
  add column if not exists state text,
  add column if not exists postcode text,
  add column if not exists country text,
  add column if not exists phone text,
  add column if not exists whatsapp text,
  add column if not exists map_url text;

comment on column public.branches.address_line1 is 'Customer-configured branch address line 1 for Commercial white-label display';
comment on column public.branches.address_line2 is 'Customer-configured branch address line 2 for Commercial white-label display';
comment on column public.branches.city is 'Customer-configured branch city';
comment on column public.branches.state is 'Customer-configured branch state/region';
comment on column public.branches.postcode is 'Customer-configured branch postcode';
comment on column public.branches.country is 'Customer-configured branch country';
comment on column public.branches.phone is 'Customer-configured branch contact phone';
comment on column public.branches.whatsapp is 'Customer-configured branch WhatsApp contact';
comment on column public.branches.map_url is 'Optional customer-configured map URL';

-- This migration intentionally does not seed EVO / Evolution Optical branch data.
-- Existing branch rows remain unchanged until the Commercial customer configures them.
-- Country is intentionally not defaulted; Commercial Voucher must remain customer- and region-neutral.
