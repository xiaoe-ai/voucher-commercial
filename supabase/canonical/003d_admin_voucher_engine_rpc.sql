-- Commercial Voucher canonical rebuild baseline
-- Status: REBUILD-ONLY / NOT FOR LIVE APPLY
-- Layer: 003D Admin / Voucher Engine RPCs
-- Source: verified live Commercial schema snapshot 2026-09-05
-- Customer-neutral: no EVO / Evolution Optical / Malaysia / Kuala Lumpur assumptions.

create or replace function public.svc_admin_create_voucher_template_v2(
  p_actor_user_id uuid,
  p_template_code text,
  p_template_name text,
  p_voucher_category text,
  p_description text default null::text,
  p_theme_code text default 'classic'::text
)
returns uuid
language plpgsql
security definer
set search_path to 'public'
as $$
declare
  v_id uuid;
begin
  if not exists (
    select 1
    from public.partner_users
    where user_id=p_actor_user_id
      and role='admin'
      and status='active'
  ) then
    raise exception 'Admin access required';
  end if;

  insert into public.voucher_templates(
    template_code,
    template_name,
    voucher_category,
    description,
    status,
    created_by,
    theme_code
  ) values (
    upper(trim(p_template_code)),
    trim(p_template_name),
    p_voucher_category,
    p_description,
    'draft',
    p_actor_user_id,
    coalesce(nullif(trim(p_theme_code),''),'classic')
  )
  returning id into v_id;

  insert into public.admin_audit_log(
    actor_user_id,
    action_type,
    entity_type,
    entity_id,
    after_data,
    metadata
  ) values (
    p_actor_user_id,
    'voucher_template_created',
    'voucher_templates',
    v_id::text,
    jsonb_build_object(
      'template_code',upper(trim(p_template_code)),
      'template_name',trim(p_template_name),
      'voucher_category',p_voucher_category,
      'theme_code',coalesce(nullif(trim(p_theme_code),''),'classic')
    ),
    jsonb_build_object('source','commercial_voucher_engine')
  );

  return v_id;
end;
$$;

create or replace function public.admin_create_voucher_template_theme(
  p_template_code text,
  p_template_name text,
  p_voucher_category text,
  p_description text default null::text,
  p_theme_code text default 'classic'::text
)
returns uuid
language plpgsql
security definer
set search_path to 'public'
as $$
begin
  if auth.uid() is null
     or not exists (
       select 1
       from public.partner_users
       where user_id=auth.uid()
         and role='admin'
         and status='active'
     ) then
    raise exception 'Admin access required';
  end if;

  return public.svc_admin_create_voucher_template_v2(
    auth.uid(),
    p_template_code,
    p_template_name,
    p_voucher_category,
    p_description,
    p_theme_code
  );
end;
$$;

create or replace function public.svc_admin_publish_voucher_version_v3(
  p_actor_user_id uuid,
  p_template_id uuid,
  p_version_name text,
  p_face_value numeric default null::numeric,
  p_discount_percent numeric default null::numeric,
  p_validity_mode text default 'days_after_issue'::text,
  p_valid_days integer default null::integer,
  p_valid_months integer default null::integer,
  p_min_spend numeric default null::numeric,
  p_max_discount numeric default null::numeric,
  p_usage_limit integer default 1,
  p_transferable boolean default true,
  p_terms_text text default null::text,
  p_supply_limit integer default null::integer,
  p_all_branches boolean default false,
  p_theme_override_code text default null::text
)
returns uuid
language plpgsql
security definer
set search_path to 'public'
as $$
declare
  v_id uuid;
  v_no integer;
  v_legacy_days integer;
begin
  if not exists (
    select 1
    from public.partner_users
    where user_id=p_actor_user_id
      and role='admin'
      and status='active'
  ) then
    raise exception 'Admin access required';
  end if;

  if p_validity_mode not in ('days_after_issue','calendar_months_after_issue') then
    raise exception 'Unsupported validity mode';
  end if;

  if p_validity_mode='days_after_issue' and coalesce(p_valid_days,0)<1 then
    raise exception 'Valid days must be at least 1';
  end if;

  if p_validity_mode='calendar_months_after_issue' and coalesce(p_valid_months,0)<1 then
    raise exception 'Valid months must be at least 1';
  end if;

  perform 1
  from public.voucher_templates
  where id=p_template_id
  for update;

  if not found then
    raise exception 'Voucher template not found';
  end if;

  select coalesce(max(version_no),0)+1
  into v_no
  from public.voucher_versions
  where template_id=p_template_id;

  v_legacy_days:=case
    when p_validity_mode='days_after_issue' then p_valid_days
    else 1
  end;

  insert into public.voucher_versions(
    template_id,
    version_no,
    version_name,
    face_value,
    discount_percent,
    validity_type,
    validity_mode,
    validity_mode_v2,
    valid_days,
    valid_months,
    valid_from,
    valid_until,
    min_spend,
    max_discount,
    usage_limit,
    transferable,
    terms_text,
    supply_limit,
    status,
    effective_from,
    created_by,
    all_branches,
    theme_override_code
  ) values (
    p_template_id,
    v_no,
    p_version_name,
    p_face_value,
    p_discount_percent,
    'days_after_issue',
    p_validity_mode,
    p_validity_mode,
    v_legacy_days,
    case when p_validity_mode='calendar_months_after_issue' then p_valid_months else null end,
    null,
    null,
    p_min_spend,
    p_max_discount,
    p_usage_limit,
    p_transferable,
    p_terms_text,
    p_supply_limit,
    'active',
    now(),
    p_actor_user_id,
    p_all_branches,
    nullif(trim(coalesce(p_theme_override_code,'')),'')
  )
  returning id into v_id;

  update public.voucher_templates
  set current_version_id=v_id,
      status='active',
      updated_at=now()
  where id=p_template_id;

  insert into public.admin_audit_log(
    actor_user_id,
    action_type,
    entity_type,
    entity_id,
    after_data,
    metadata
  ) values (
    p_actor_user_id,
    'voucher_version_published',
    'voucher_versions',
    v_id::text,
    jsonb_build_object(
      'template_id',p_template_id,
      'version_no',v_no,
      'version_name',p_version_name,
      'validity_mode',p_validity_mode,
      'valid_days',p_valid_days,
      'valid_months',p_valid_months,
      'theme_override_code',nullif(trim(coalesce(p_theme_override_code,'')),'')
    ),
    jsonb_build_object('source','commercial_voucher_engine')
  );

  return v_id;
end;
$$;

create or replace function public.admin_publish_voucher_version_theme(
  p_template_id uuid,
  p_version_name text,
  p_face_value numeric default null::numeric,
  p_discount_percent numeric default null::numeric,
  p_validity_mode text default 'days_after_issue'::text,
  p_valid_days integer default null::integer,
  p_valid_months integer default null::integer,
  p_min_spend numeric default null::numeric,
  p_max_discount numeric default null::numeric,
  p_usage_limit integer default 1,
  p_transferable boolean default true,
  p_terms_text text default null::text,
  p_supply_limit integer default null::integer,
  p_all_branches boolean default false,
  p_theme_override_code text default null::text
)
returns uuid
language plpgsql
security definer
set search_path to 'public'
as $$
begin
  if auth.uid() is null
     or not exists (
       select 1
       from public.partner_users
       where user_id=auth.uid()
         and role='admin'
         and status='active'
     ) then
    raise exception 'Admin access required';
  end if;

  return public.svc_admin_publish_voucher_version_v3(
    auth.uid(),
    p_template_id,
    p_version_name,
    p_face_value,
    p_discount_percent,
    p_validity_mode,
    p_valid_days,
    p_valid_months,
    p_min_spend,
    p_max_discount,
    p_usage_limit,
    p_transferable,
    p_terms_text,
    p_supply_limit,
    p_all_branches,
    p_theme_override_code
  );
end;
$$;

create or replace function public.admin_get_partner_claim_access(p_partner_id uuid)
returns jsonb
language plpgsql
security definer
set search_path to 'public'
as $$
declare
  v_all boolean;
  v_codes text[];
begin
  if not public.is_voucher_admin() then
    raise exception 'Admin access required';
  end if;

  select coalesce(s.all_branches,false)
  into v_all
  from public.partner_claim_settings s
  where s.partner_id=p_partner_id;

  if not found then
    v_all:=true;
  end if;

  select coalesce(array_agg(b.branch_code order by b.branch_name),'{}'::text[])
  into v_codes
  from public.partner_claim_branches pcb
  join public.branches b on b.id=pcb.branch_id
  where pcb.partner_id=p_partner_id;

  return jsonb_build_object(
    'success',true,
    'all_branches',v_all,
    'branch_codes',v_codes
  );
end;
$$;

create or replace function public.admin_set_partner_claim_access(
  p_partner_id uuid,
  p_all_branches boolean,
  p_branch_codes text[] default '{}'::text[]
)
returns jsonb
language plpgsql
security definer
set search_path to 'public'
as $$
declare
  v_count integer:=0;
begin
  if not public.is_voucher_admin() then
    raise exception 'Admin access required';
  end if;

  if not exists(select 1 from public.partners where id=p_partner_id) then
    raise exception 'Partner not found';
  end if;

  insert into public.partner_claim_settings(
    partner_id,
    all_branches,
    updated_at,
    updated_by
  ) values (
    p_partner_id,
    coalesce(p_all_branches,false),
    now(),
    auth.uid()
  )
  on conflict(partner_id) do update
    set all_branches=excluded.all_branches,
        updated_at=excluded.updated_at,
        updated_by=excluded.updated_by;

  delete from public.partner_claim_branches
  where partner_id=p_partner_id;

  if not coalesce(p_all_branches,false) then
    insert into public.partner_claim_branches(partner_id,branch_id)
    select p_partner_id,b.id
    from public.branches b
    where b.branch_code=any(coalesce(p_branch_codes,'{}'::text[]))
      and lower(coalesce(b.status,'active'))='active'
    on conflict do nothing;

    get diagnostics v_count=row_count;

    if v_count=0 then
      raise exception 'Select at least one active claim branch';
    end if;
  end if;

  return jsonb_build_object(
    'success',true,
    'partner_id',p_partner_id,
    'all_branches',coalesce(p_all_branches,false),
    'branch_count',v_count
  );
end;
$$;

-- The service-role-only allocation / revoke / retire engine wrappers are not
-- canonicalized in this file yet because their trusted-context helper and
-- lower-level allocation service functions require separate dependency review.
-- Execute grants are deferred to the dedicated privilege layer.
