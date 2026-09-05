-- Commercial Voucher canonical rebuild baseline
-- Status: REBUILD-ONLY / NOT FOR LIVE APPLY
-- Layer: 002A Company Profile authorization and trigger
-- Depends on 001G company_profile and 002 authorization helpers.

create policy company_profile_public_read
on public.company_profile
for select
to anon, authenticated
using (id='default');

create policy company_profile_admin_insert
on public.company_profile
for insert
to authenticated
with check (public.is_voucher_admin());

create policy company_profile_admin_update
on public.company_profile
for update
to authenticated
using (public.is_voucher_admin())
with check (public.is_voucher_admin());

create or replace function public.touch_company_profile_updated_at()
returns trigger
language plpgsql
security invoker
set search_path to 'public'
as $$
begin
  new.updated_at:=now();
  new.updated_by:=auth.uid();
  return new;
end;
$$;

create trigger trg_company_profile_updated_at
before update on public.company_profile
for each row execute function public.touch_company_profile_updated_at();
