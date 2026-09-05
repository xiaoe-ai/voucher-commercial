-- Commercial Voucher neutralization Phase 2E
-- Scope: apply_voucher_version_expiry_v2() only.
-- Preserve trigger behavior and validity calculations.
-- Neutralize fixed Kuala Lumpur timezone.

create or replace function public.apply_voucher_version_expiry_v2()
returns trigger
language plpgsql
set search_path to 'public'
as $$
declare
  v_mode text;
  v_days integer;
  v_months integer;
  v_issue_date date;
begin
  if new.version_id is null then return new; end if;

  select validity_mode_v2, valid_days, valid_months
    into v_mode, v_days, v_months
  from public.voucher_versions
  where id = new.version_id;

  if v_mode is null then return new; end if;

  v_issue_date := coalesce(new.activated_at, now())::date;

  if v_mode = 'days_after_issue' then
    if coalesce(v_days,0) < 1 then raise exception 'Voucher valid days is not configured'; end if;
    new.expiry_date := v_issue_date + v_days;
  elsif v_mode = 'calendar_months_after_issue' then
    if coalesce(v_months,0) < 1 then raise exception 'Voucher valid months is not configured'; end if;
    new.expiry_date := (v_issue_date::timestamp + make_interval(months => v_months))::date;
  else
    raise exception 'Unsupported voucher validity mode';
  end if;

  return new;
end;
$$;
