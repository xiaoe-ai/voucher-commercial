-- Commercial Voucher live neutralization Phase 1
-- Status: REVIEWED FOR DRY-RUN FIRST / DO NOT APPLY BLINDLY
-- Scope: low-risk defaults + privilege tightening only.
-- No business data deletion. No voucher rows are modified.

-- 1) Remove customer-specific voucher type default.
-- Existing voucher records keep their current stored voucher_type values.
alter table public.vouchers
  alter column voucher_type drop default;

-- 2) Tighten helper execution: normal authenticated clients do not need to
-- call the trusted service-role detector as an application RPC.
revoke all on function public.is_trusted_service_role()
  from public, anon, authenticated, service_role;
grant execute on function public.is_trusted_service_role()
  to service_role;

-- 3) Post-change assertions.
do $$
begin
  if exists (
    select 1
    from information_schema.columns
    where table_schema='public'
      and table_name='vouchers'
      and column_name='voucher_type'
      and column_default is not null
  ) then
    raise exception 'voucher_type default was not removed';
  end if;

  if has_function_privilege('authenticated','public.is_trusted_service_role()','EXECUTE') then
    raise exception 'authenticated still has EXECUTE on is_trusted_service_role()';
  end if;

  if not has_function_privilege('service_role','public.is_trusted_service_role()','EXECUTE') then
    raise exception 'service_role lost EXECUTE on is_trusted_service_role()';
  end if;
end
$$;

select 'COMMERCIAL_NEUTRALIZATION_PHASE1_OK' as status;
