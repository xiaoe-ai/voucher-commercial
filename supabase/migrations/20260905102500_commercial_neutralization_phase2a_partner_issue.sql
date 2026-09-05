-- Commercial Voucher neutralization Phase 2A
-- Scope: replace the live controlled partner issuance RPC with the verified
-- customer-neutral canonical implementation.
-- Safety: no table data rewrite; CREATE OR REPLACE FUNCTION only.

create or replace function public.create_partner_multi_voucher_controlled(
  p_version_id uuid,
  p_customer_name text,
  p_customer_phone text default null::text
)
returns jsonb
language plpgsql
security definer
set search_path to 'public'
as $$
declare
  v_partner_id uuid;
  v_role text;
  v_staff_name text;
  v_staff_access_enabled boolean;
  v_partner_status text;

  v_template_id uuid;
  v_template_code text;
  v_template_name text;
  v_version_no integer;
  v_version_name text;
  v_face_value numeric;
  v_discount_percent numeric;
  v_validity_type text;
  v_validity_mode text;
  v_valid_days integer;
  v_valid_months integer;
  v_valid_from date;
  v_valid_until date;
  v_version_all_branches boolean;

  v_allocation_id uuid;
  v_allocated integer;
  v_revoked integer;
  v_issued integer;
  v_allocation_all_branches boolean;

  v_partner_all_branches boolean;
  v_effective_branch_ids uuid[];
  v_voucher_all_branches boolean;

  v_voucher_id uuid;
  v_voucher_code text;
  v_public_token uuid;
  v_issue_date date := current_date;
  v_expiry_date date;
  v_voucher_type text;
  v_actor_name text;
begin
  if nullif(trim(coalesce(p_customer_name,'')),'') is null then
    raise exception 'Customer name is required';
  end if;

  select
    pu.partner_id,
    lower(coalesce(pu.role,'')),
    pu.staff_name,
    coalesce(p.staff_access_enabled,false),
    lower(coalesce(p.status,''))
  into
    v_partner_id,
    v_role,
    v_staff_name,
    v_staff_access_enabled,
    v_partner_status
  from public.partner_users pu
  join public.partners p on p.id=pu.partner_id
  where pu.user_id=auth.uid()
    and lower(coalesce(pu.status,''))='active'
    and pu.removed_at is null
    and lower(coalesce(pu.role,'')) in ('admin','partner_admin','partner_staff')
  order by case when lower(coalesce(pu.role,''))='admin' then 0 else 1 end
  limit 1;

  if v_partner_id is null or v_partner_status<>'active' then
    raise exception 'Active Partner account not found';
  end if;

  if v_role='partner_staff' and not v_staff_access_enabled then
    raise exception 'Staff access is currently disabled by your Partner Admin.';
  end if;

  v_actor_name := case
    when v_role='admin' then 'Admin'
    when v_role='partner_staff' then coalesce(nullif(v_staff_name,''),'Partner Staff')
    else 'Partner Admin'
  end;

  select
    vt.id,
    vt.template_code,
    vt.template_name,
    vv.version_no,
    vv.version_name,
    vv.face_value,
    vv.discount_percent,
    vv.validity_type,
    coalesce(
      vv.validity_mode,
      vv.validity_mode_v2,
      case lower(coalesce(vv.validity_type,''))
        when 'fixed' then 'fixed'
        else 'days_after_issue'
      end
    ),
    vv.valid_days,
    vv.valid_months,
    vv.valid_from,
    vv.valid_until,
    vv.all_branches
  into
    v_template_id,
    v_template_code,
    v_template_name,
    v_version_no,
    v_version_name,
    v_face_value,
    v_discount_percent,
    v_validity_type,
    v_validity_mode,
    v_valid_days,
    v_valid_months,
    v_valid_from,
    v_valid_until,
    v_version_all_branches
  from public.voucher_versions vv
  join public.voucher_templates vt on vt.id=vv.template_id
  where vv.id=p_version_id
    and vv.status='active'
    and vt.status='active'
  limit 1;

  if v_template_id is null then
    raise exception 'Active voucher version not found';
  end if;

  if not exists (
    select 1
    from public.partner_voucher_access pva
    where pva.partner_id=v_partner_id
      and pva.template_id=v_template_id
      and pva.status='active'
      and (pva.valid_from is null or pva.valid_from<=now())
      and (pva.valid_until is null or pva.valid_until>=now())
  ) then
    raise exception 'This Partner is not authorised for this voucher type';
  end if;

  select
    a.id,
    a.quantity_allocated,
    a.quantity_revoked,
    a.all_branches
  into
    v_allocation_id,
    v_allocated,
    v_revoked,
    v_allocation_all_branches
  from public.partner_voucher_allocations a
  where a.partner_id=v_partner_id
    and a.version_id=p_version_id
    and a.status='active'
    and (a.valid_from is null or a.valid_from<=now())
    and (a.valid_until is null or a.valid_until>=now())
    and (a.quantity_allocated-a.quantity_revoked) > (
      select count(*)
      from public.vouchers v
      where v.allocation_id=a.id
    )
  order by a.created_at asc
  limit 1
  for update;

  if v_allocation_id is null then
    raise exception 'No active allocation is available for this voucher type';
  end if;

  select count(*)
  into v_issued
  from public.vouchers
  where allocation_id=v_allocation_id;

  if coalesce(v_allocated,0)-coalesce(v_revoked,0)-coalesce(v_issued,0)<=0 then
    raise exception 'Voucher allocation limit reached';
  end if;

  if v_validity_mode='fixed' or v_validity_type='fixed' then
    if v_valid_from is not null and v_issue_date<v_valid_from then
      raise exception 'Voucher campaign has not started';
    end if;
    if v_valid_until is null or v_issue_date>v_valid_until then
      raise exception 'Voucher campaign has ended';
    end if;
    v_expiry_date:=v_valid_until;
  elsif v_validity_mode='calendar_months_after_issue' then
    if coalesce(v_valid_months,0)<=0 then
      raise exception 'Voucher calendar-month validity is not configured';
    end if;
    v_expiry_date:=(v_issue_date+make_interval(months=>v_valid_months))::date;
  else
    if coalesce(v_valid_days,0)<=0 then
      raise exception 'Voucher validity is not configured';
    end if;
    v_expiry_date:=v_issue_date+v_valid_days;
  end if;

  select coalesce(s.all_branches,true)
  into v_partner_all_branches
  from public.partner_claim_settings s
  where s.partner_id=v_partner_id;

  if not found then
    v_partner_all_branches:=true;
  end if;

  select coalesce(array_agg(b.id order by b.branch_name),'{}'::uuid[])
  into v_effective_branch_ids
  from public.branches b
  where lower(coalesce(b.status,'active'))='active'
    and (
      v_partner_all_branches
      or exists (
        select 1
        from public.partner_claim_branches pcb
        where pcb.partner_id=v_partner_id
          and pcb.branch_id=b.id
      )
    )
    and (
      coalesce(v_version_all_branches,false)
      or exists (
        select 1
        from public.voucher_version_branches vvb
        where vvb.version_id=p_version_id
          and vvb.branch_id=b.id
      )
    )
    and (
      coalesce(v_allocation_all_branches,false)
      or exists (
        select 1
        from public.voucher_allocation_branches vab
        where vab.allocation_id=v_allocation_id
          and vab.branch_id=b.id
      )
    );

  if coalesce(array_length(v_effective_branch_ids,1),0)=0 then
    raise exception 'No valid redemption branch is shared by Partner, Voucher Version and Allocation.';
  end if;

  v_voucher_all_branches :=
    v_partner_all_branches
    and coalesce(v_version_all_branches,false)
    and coalesce(v_allocation_all_branches,false);

  v_voucher_code :=
    'V-' ||
    to_char(v_issue_date,'YYYYMMDD') ||
    '-' ||
    upper(substr(replace(gen_random_uuid()::text,'-',''),1,8));

  v_voucher_type := v_template_name;

  insert into public.vouchers(
    partner_id,
    voucher_code,
    customer_name,
    customer_phone,
    voucher_type,
    activated_at,
    expiry_date,
    status,
    all_branches,
    issued_by_user_id,
    issued_by_name,
    template_id,
    version_id,
    allocation_id,
    metadata
  ) values (
    v_partner_id,
    v_voucher_code,
    trim(p_customer_name),
    nullif(trim(coalesce(p_customer_phone,'')),''),
    v_voucher_type,
    now(),
    v_expiry_date,
    'valid',
    v_voucher_all_branches,
    auth.uid(),
    v_actor_name,
    v_template_id,
    p_version_id,
    v_allocation_id,
    jsonb_build_object(
      'issuance_path','multi_voucher',
      'template_code',v_template_code,
      'version_no',v_version_no,
      'validity_mode',v_validity_mode,
      'allocation_scope_applied',true,
      'face_value',v_face_value,
      'discount_percent',v_discount_percent
    )
  )
  returning id,public_token
  into v_voucher_id,v_public_token;

  if not v_voucher_all_branches then
    insert into public.voucher_branches(voucher_id,branch_id)
    select v_voucher_id,unnest(v_effective_branch_ids);
  end if;

  return jsonb_build_object(
    'success',true,
    'voucher_id',v_voucher_id,
    'voucher_code',v_voucher_code,
    'public_token',v_public_token,
    'partner_id',v_partner_id,
    'template_id',v_template_id,
    'template_code',v_template_code,
    'template_name',v_template_name,
    'version_id',p_version_id,
    'version_no',v_version_no,
    'version_name',v_version_name,
    'allocation_id',v_allocation_id,
    'voucher_type',v_voucher_type,
    'face_value',v_face_value,
    'discount_percent',v_discount_percent,
    'expiry_date',v_expiry_date,
    'validity_mode',v_validity_mode,
    'all_branches',v_voucher_all_branches,
    'remaining_after_issue',greatest(
      0,
      coalesce(v_allocated,0)-coalesce(v_revoked,0)-coalesce(v_issued,0)-1
    ),
    'issued_by_role',v_role,
    'issued_by_name',v_actor_name
  );
end;
$$;
