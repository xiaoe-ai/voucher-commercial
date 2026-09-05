-- Commercial Voucher neutralization Phase 2F
-- Scope: legacy issuance compatibility RPCs + obsolete single-template sync trigger function.
-- Preserve legacy signatures but route supported issuance through the generic Voucher Engine.
-- No customer-specific template code, brand, currency, voucher-code prefix or fixed regional timezone.

create or replace function public.create_partner_voucher_controlled(
  p_customer_name text,
  p_customer_phone text,
  p_customer_ic text,
  p_voucher_type text,
  p_expiry_date date default null::date
)
returns jsonb
language plpgsql
security definer
set search_path to 'public'
as $$
declare
  v_version_id uuid;
  v_result jsonb;
  v_voucher_id uuid;
begin
  if p_expiry_date is not null then
    raise exception 'Legacy custom expiry is not supported. Configure validity in Voucher Engine.';
  end if;

  select vt.current_version_id
  into v_version_id
  from public.voucher_templates vt
  join public.voucher_versions vv on vv.id=vt.current_version_id
  where lower(coalesce(vt.status,''))='active'
    and lower(coalesce(vv.status,''))='active'
    and (
      lower(vt.template_code)=lower(trim(coalesce(p_voucher_type,'')))
      or lower(vt.template_name)=lower(trim(coalesce(p_voucher_type,'')))
    )
  order by vt.created_at desc
  limit 1;

  if v_version_id is null then
    raise exception 'Active voucher type not found. Use Voucher Engine to select an active voucher version.';
  end if;

  v_result := public.create_partner_multi_voucher_controlled(
    v_version_id,
    p_customer_name,
    p_customer_phone
  );

  v_voucher_id := nullif(v_result->>'voucher_id','')::uuid;
  if v_voucher_id is not null and nullif(trim(coalesce(p_customer_ic,'')),'') is not null then
    update public.vouchers
    set customer_ic=trim(p_customer_ic)
    where id=v_voucher_id;
  end if;

  return v_result || jsonb_build_object('compatibility_entry_point','create_partner_voucher_controlled');
end;
$$;

create or replace function public.create_partner_voucher(
  p_customer_name text,
  p_customer_phone text,
  p_customer_ic text,
  p_voucher_type text,
  p_expiry_date date default null::date,
  p_all_branches boolean default false,
  p_branch_codes text[] default array[]::text[]
)
returns json
language plpgsql
security definer
set search_path to 'public'
as $$
declare
  v_result jsonb;
begin
  if p_expiry_date is not null then
    raise exception 'Legacy custom expiry is not supported. Configure validity in Voucher Engine.';
  end if;

  if coalesce(p_all_branches,false)=false and coalesce(array_length(p_branch_codes,1),0)>0 then
    raise exception 'Legacy direct branch override is not supported. Configure Partner, Version and Allocation branch scope in Voucher Engine.';
  end if;

  v_result := public.create_partner_voucher_controlled(
    p_customer_name,
    p_customer_phone,
    p_customer_ic,
    p_voucher_type,
    null
  );

  return (v_result || jsonb_build_object('compatibility_entry_point','create_partner_voucher'))::json;
end;
$$;

create or replace function public.sync_single_voucher_partner_engine()
returns trigger
language plpgsql
security definer
set search_path to 'public'
as $$
begin
  -- Generic Commercial Voucher supports multiple templates and allocations.
  -- A Partner insert or voucher_limit update cannot safely infer one voucher template.
  -- Explicit access/allocation is managed by the Voucher Engine.
  return new;
end;
$$;
