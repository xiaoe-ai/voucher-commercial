-- Commercial Voucher neutralization Phase 2D
-- Scope: partner_issuable_voucher_catalog() only.
-- Preserve return structure and access/allocation logic.
-- Neutralize fixed Kuala Lumpur date and hardcoded RM label.

create or replace function public.partner_issuable_voucher_catalog()
returns table(
  version_id uuid,
  template_id uuid,
  template_code text,
  template_name text,
  version_no integer,
  version_name text,
  voucher_label text,
  face_value numeric,
  discount_percent numeric,
  validity_mode text,
  valid_days integer,
  valid_months integer,
  valid_until date,
  usage_limit integer,
  transferable boolean,
  terms_text text,
  remaining_allocation bigint,
  remaining_supply bigint
)
language plpgsql
stable
security definer
set search_path to 'public'
as $$
declare
  v_partner_id uuid;
  v_role text;
  v_staff_access_enabled boolean;
  v_today date := current_date;
begin
  select pu.partner_id,lower(coalesce(pu.role,'')),coalesce(p.staff_access_enabled,false)
    into v_partner_id,v_role,v_staff_access_enabled
  from public.partner_users pu
  join public.partners p on p.id=pu.partner_id
  where pu.user_id=(select auth.uid())
    and lower(coalesce(pu.status,''))='active'
    and pu.removed_at is null
    and lower(coalesce(pu.role,'')) in ('admin','partner_admin','partner_staff')
    and lower(coalesce(p.status,''))='active'
  order by case when lower(coalesce(pu.role,''))='admin' then 0 else 1 end
  limit 1;

  if v_partner_id is null then raise exception 'Active Partner account not found'; end if;
  if v_role='partner_staff' and not v_staff_access_enabled then raise exception 'Staff access is disabled by Partner Admin'; end if;

  return query
  select vv.id,vt.id,vt.template_code,vt.template_name,vv.version_no,vv.version_name,
    case
      when vv.face_value is not null then trim(to_char(vv.face_value,'FM999999990.##'))||' '||vt.template_name
      when vv.discount_percent is not null then trim(to_char(vv.discount_percent,'FM999999990.##'))||'% '||vt.template_name
      else vt.template_name
    end,
    vv.face_value,vv.discount_percent,
    coalesce(vv.validity_mode,vv.validity_mode_v2,case lower(coalesce(vv.validity_type,'')) when 'fixed' then 'fixed' else 'days_after_issue' end),
    vv.valid_days,vv.valid_months,vv.valid_until,coalesce(vv.usage_limit,1),coalesce(vv.transferable,true),vv.terms_text,
    coalesce(lots.remaining_allocation,0)::bigint,
    case when vv.supply_limit is null then null else greatest(0,vv.supply_limit-coalesce(vi.issued_count,0))::bigint end
  from public.voucher_versions vv
  join public.voucher_templates vt on vt.id=vv.template_id and lower(coalesce(vt.status,''))='active'
  join public.partner_voucher_access pva on pva.partner_id=v_partner_id and pva.template_id=vv.template_id and lower(coalesce(pva.status,''))='active' and (pva.valid_from is null or pva.valid_from<=now()) and (pva.valid_until is null or pva.valid_until>=now())
  join lateral (
    select sum(greatest(0,(a.quantity_allocated-a.quantity_revoked)-coalesce(x.issued_count,0)))::bigint as remaining_allocation
    from public.partner_voucher_allocations a
    left join lateral (select count(*)::bigint issued_count from public.vouchers v where v.allocation_id=a.id) x on true
    where a.partner_id=v_partner_id and a.version_id=vv.id and lower(coalesce(a.status,''))='active'
      and (a.valid_from is null or a.valid_from<=now()) and (a.valid_until is null or a.valid_until>=now())
  ) lots on coalesce(lots.remaining_allocation,0)>0
  left join lateral (select count(*)::bigint issued_count from public.vouchers v where v.version_id=vv.id) vi on true
  where lower(coalesce(vv.status,''))='active'
    and (
      coalesce(vv.validity_mode,vv.validity_mode_v2,case lower(coalesce(vv.validity_type,'')) when 'fixed' then 'fixed' else 'days_after_issue' end)<>'fixed'
      or (vv.valid_until is not null and vv.valid_until>=v_today and (vv.valid_from is null or vv.valid_from<=v_today))
    )
    and (vv.supply_limit is null or vv.supply_limit-coalesce(vi.issued_count,0)>0)
  order by vt.template_name,vv.version_no desc;
end;
$$;
