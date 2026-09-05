-- Commercial Voucher canonical rebuild baseline
-- Status: REBUILD-ONLY / NOT FOR LIVE APPLY
-- Layer: 003E Allocation Engine RPCs
-- Source: verified live Commercial schema snapshot 2026-09-05
-- Customer-neutral: no EVO / Evolution Optical / regional assumptions.

create or replace function public.is_trusted_service_role()
returns boolean
language sql
stable
set search_path to 'public'
as $$
  select coalesce((auth.jwt() ->> 'role')='service_role',false);
$$;

create or replace function public.svc_admin_allocate_voucher_to_partner(
  p_actor_user_id uuid,
  p_partner_id uuid,
  p_version_id uuid,
  p_quantity integer,
  p_valid_from timestamptz default null,
  p_valid_until timestamptz default null
)
returns uuid
language plpgsql
security definer
set search_path to 'public'
as $$
declare
  v_template_id uuid;
  v_allocation_id uuid;
  v_existing_qty integer;
begin
  if p_quantity <= 0 then
    raise exception 'Quantity must be greater than zero';
  end if;

  if not exists (
    select 1 from public.partner_users
    where user_id=p_actor_user_id and role='admin' and status='active'
  ) then
    raise exception 'Admin access required';
  end if;

  if not exists (select 1 from public.partners where id=p_partner_id) then
    raise exception 'Partner not found';
  end if;

  select template_id
  into v_template_id
  from public.voucher_versions
  where id=p_version_id and status='active';

  if v_template_id is null then
    raise exception 'Active voucher version not found';
  end if;

  insert into public.partner_voucher_access(
    partner_id,template_id,status,quota_type,quota_limit,
    valid_from,valid_until,created_by
  ) values (
    p_partner_id,v_template_id,'active','total',p_quantity,
    p_valid_from,p_valid_until,p_actor_user_id
  )
  on conflict (partner_id,template_id) do update
    set status='active',
        quota_type='total',
        quota_limit=coalesce(public.partner_voucher_access.quota_limit,0)+excluded.quota_limit,
        valid_from=coalesce(excluded.valid_from,public.partner_voucher_access.valid_from),
        valid_until=coalesce(excluded.valid_until,public.partner_voucher_access.valid_until),
        updated_at=now();

  select id,quantity_allocated
  into v_allocation_id,v_existing_qty
  from public.partner_voucher_allocations
  where partner_id=p_partner_id
    and version_id=p_version_id
    and status='active'
  order by created_at desc
  limit 1
  for update;

  if v_allocation_id is null then
    insert into public.partner_voucher_allocations(
      partner_id,version_id,quantity_allocated,
      valid_from,valid_until,created_by,status
    ) values (
      p_partner_id,p_version_id,p_quantity,
      p_valid_from,p_valid_until,p_actor_user_id,'active'
    )
    returning id into v_allocation_id;

    insert into public.voucher_allocation_events(
      allocation_id,partner_id,version_id,event_type,quantity,actor_user_id
    ) values (
      v_allocation_id,p_partner_id,p_version_id,'allocated',p_quantity,p_actor_user_id
    );
  else
    update public.partner_voucher_allocations
    set quantity_allocated=quantity_allocated+p_quantity,
        valid_from=coalesce(p_valid_from,valid_from),
        valid_until=coalesce(p_valid_until,valid_until),
        updated_at=now()
    where id=v_allocation_id;

    insert into public.voucher_allocation_events(
      allocation_id,partner_id,version_id,event_type,quantity,actor_user_id
    ) values (
      v_allocation_id,p_partner_id,p_version_id,'increased',p_quantity,p_actor_user_id
    );
  end if;

  insert into public.admin_audit_log(
    actor_user_id,action_type,entity_type,entity_id,partner_id,after_data,metadata
  ) values (
    p_actor_user_id,
    'voucher_allocated_to_partner',
    'partner_voucher_allocations',
    v_allocation_id::text,
    p_partner_id,
    jsonb_build_object('version_id',p_version_id,'quantity',p_quantity),
    jsonb_build_object('source','commercial_voucher_engine')
  );

  return v_allocation_id;
end;
$$;

create or replace function public.svc_admin_allocate_voucher_to_all_partners(
  p_actor_user_id uuid,
  p_version_id uuid,
  p_quantity integer,
  p_valid_from timestamptz default null,
  p_valid_until timestamptz default null
)
returns jsonb
language plpgsql
security definer
set search_path to 'public'
as $$
declare
  v_partner record;
  v_count integer:=0;
  v_allocation_id uuid;
begin
  if p_quantity <= 0 then
    raise exception 'Quantity must be greater than zero';
  end if;

  if not exists (
    select 1 from public.partner_users
    where user_id=p_actor_user_id and role='admin' and status='active'
  ) then
    raise exception 'Admin access required';
  end if;

  if not exists (
    select 1 from public.voucher_versions
    where id=p_version_id and status='active'
  ) then
    raise exception 'Active voucher version not found';
  end if;

  for v_partner in
    select id
    from public.partners
    where status='active'
      and upper(coalesce(partner_code,'')) <> 'ADMIN'
    order by partner_code
  loop
    v_allocation_id := public.svc_admin_allocate_voucher_to_partner(
      p_actor_user_id,
      v_partner.id,
      p_version_id,
      p_quantity,
      p_valid_from,
      p_valid_until
    );
    v_count:=v_count+1;
  end loop;

  return jsonb_build_object(
    'partners_allocated',v_count,
    'quantity_each',p_quantity,
    'version_id',p_version_id
  );
end;
$$;

create or replace function public.svc_admin_revoke_unissued_allocation(
  p_actor_user_id uuid,
  p_allocation_id uuid,
  p_quantity integer,
  p_reason text default null
)
returns jsonb
language plpgsql
security definer
set search_path to 'public'
as $$
declare
  a public.partner_voucher_allocations%rowtype;
  v_issued integer;
  v_available integer;
begin
  if p_quantity <= 0 then
    raise exception 'Quantity must be greater than zero';
  end if;

  if not exists (
    select 1 from public.partner_users
    where user_id=p_actor_user_id and role='admin' and status='active'
  ) then
    raise exception 'Admin access required';
  end if;

  select * into a
  from public.partner_voucher_allocations
  where id=p_allocation_id
  for update;

  if not found then
    raise exception 'Allocation not found';
  end if;

  select count(*)
  into v_issued
  from public.vouchers
  where allocation_id=p_allocation_id;

  v_available:=a.quantity_allocated-a.quantity_revoked-v_issued;

  if p_quantity>v_available then
    raise exception 'Cannot revoke % vouchers; only % unissued vouchers remain',
      p_quantity,v_available;
  end if;

  update public.partner_voucher_allocations
  set quantity_revoked=quantity_revoked+p_quantity,
      status=case
        when quantity_allocated-(quantity_revoked+p_quantity)-v_issued=0 then 'closed'
        else status
      end,
      updated_at=now()
  where id=p_allocation_id;

  insert into public.voucher_allocation_events(
    allocation_id,partner_id,version_id,event_type,quantity,reason,actor_user_id
  ) values (
    p_allocation_id,a.partner_id,a.version_id,
    'revoked_unissued',p_quantity,p_reason,p_actor_user_id
  );

  insert into public.admin_audit_log(
    actor_user_id,action_type,entity_type,entity_id,partner_id,
    before_data,after_data,metadata
  ) values (
    p_actor_user_id,
    'voucher_unissued_allocation_revoked',
    'partner_voucher_allocations',
    p_allocation_id::text,
    a.partner_id,
    jsonb_build_object('available_unissued',v_available),
    jsonb_build_object(
      'revoked_quantity',p_quantity,
      'remaining_unissued',v_available-p_quantity
    ),
    jsonb_build_object('source','commercial_voucher_engine','reason',p_reason)
  );

  return jsonb_build_object(
    'allocation_id',p_allocation_id,
    'issued_vouchers_untouched',v_issued,
    'revoked_unissued',p_quantity,
    'remaining_unissued',v_available-p_quantity
  );
end;
$$;

create or replace function public.svc_admin_retire_voucher_version(
  p_actor_user_id uuid,
  p_version_id uuid,
  p_reason text default null
)
returns void
language plpgsql
security definer
set search_path to 'public'
as $$
declare
  v_template_id uuid;
begin
  if not exists (
    select 1 from public.partner_users
    where user_id=p_actor_user_id and role='admin' and status='active'
  ) then
    raise exception 'Admin access required';
  end if;

  select template_id
  into v_template_id
  from public.voucher_versions
  where id=p_version_id;

  if v_template_id is null then
    raise exception 'Voucher version not found';
  end if;

  update public.voucher_versions
  set status='retired'
  where id=p_version_id;

  update public.partner_voucher_allocations
  set status='closed',updated_at=now()
  where version_id=p_version_id and status='active';

  update public.voucher_templates vt
  set current_version_id=(
      select vv.id
      from public.voucher_versions vv
      where vv.template_id=v_template_id
        and vv.status='active'
        and vv.id<>p_version_id
      order by vv.version_no desc
      limit 1
    ),
    updated_at=now()
  where vt.id=v_template_id
    and vt.current_version_id=p_version_id;

  insert into public.admin_audit_log(
    actor_user_id,action_type,entity_type,entity_id,after_data,metadata
  ) values (
    p_actor_user_id,
    'voucher_version_retired',
    'voucher_versions',
    p_version_id::text,
    jsonb_build_object('status','retired'),
    jsonb_build_object('source','commercial_voucher_engine','reason',p_reason)
  );
end;
$$;

create or replace function public.admin_engine_allocate(
  p_partner_id uuid,
  p_version_id uuid,
  p_quantity integer,
  p_actor_user_id uuid default null
)
returns jsonb
language plpgsql
security definer
set search_path to 'public'
as $$
declare
  v_allocation_id uuid;
begin
  if not public.is_trusted_service_role() then
    raise exception 'Trusted server context required';
  end if;
  if p_actor_user_id is null then
    raise exception 'Admin actor is required';
  end if;

  v_allocation_id:=public.svc_admin_allocate_voucher_to_partner(
    p_actor_user_id,p_partner_id,p_version_id,p_quantity,null,null
  );

  return jsonb_build_object(
    'success',true,
    'allocation_id',v_allocation_id,
    'partner_id',p_partner_id,
    'version_id',p_version_id,
    'quantity_added',p_quantity
  );
end;
$$;

create or replace function public.admin_engine_allocate_all(
  p_version_id uuid,
  p_quantity integer,
  p_actor_user_id uuid default null
)
returns jsonb
language plpgsql
security definer
set search_path to 'public'
as $$
declare
  v_result jsonb;
begin
  if not public.is_trusted_service_role() then
    raise exception 'Trusted server context required';
  end if;
  if p_actor_user_id is null then
    raise exception 'Admin actor is required';
  end if;

  v_result:=public.svc_admin_allocate_voucher_to_all_partners(
    p_actor_user_id,p_version_id,p_quantity,null,null
  );

  return coalesce(v_result,'{}'::jsonb)||jsonb_build_object('success',true);
end;
$$;

create or replace function public.admin_engine_revoke_unissued(
  p_allocation_id uuid,
  p_quantity integer,
  p_reason text default null,
  p_actor_user_id uuid default null
)
returns jsonb
language plpgsql
security definer
set search_path to 'public'
as $$
declare
  v_result jsonb;
begin
  if not public.is_trusted_service_role() then
    raise exception 'Trusted server context required';
  end if;
  if p_actor_user_id is null then
    raise exception 'Admin actor is required';
  end if;

  v_result:=public.svc_admin_revoke_unissued_allocation(
    p_actor_user_id,p_allocation_id,p_quantity,p_reason
  );

  return coalesce(v_result,'{}'::jsonb)||jsonb_build_object('success',true);
end;
$$;

create or replace function public.admin_engine_retire_version(
  p_version_id uuid,
  p_reason text default null,
  p_actor_user_id uuid default null
)
returns jsonb
language plpgsql
security definer
set search_path to 'public'
as $$
begin
  if not public.is_trusted_service_role() then
    raise exception 'Trusted server context required';
  end if;
  if p_actor_user_id is null then
    raise exception 'Admin actor is required';
  end if;

  perform public.svc_admin_retire_voucher_version(
    p_actor_user_id,p_version_id,p_reason
  );

  return jsonb_build_object(
    'success',true,
    'version_id',p_version_id,
    'status','retired'
  );
end;
$$;

-- Execute grants are intentionally deferred to the dedicated privilege layer.
