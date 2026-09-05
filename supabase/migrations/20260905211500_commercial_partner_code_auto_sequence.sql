-- Commercial Voucher Partner code auto-generation
-- Keeps ADMIN outside the sequence and generates P001, P002, ... safely.

create or replace function public.service_provision_partner(
  p_actor_user_id uuid,
  p_new_user_id uuid,
  p_partner_code text,
  p_partner_name text,
  p_contact_person text default null::text,
  p_contact_phone text default null::text,
  p_voucher_limit integer default 0,
  p_staff_limit integer default 0,
  p_login_email text default null::text
)
returns jsonb
language plpgsql
security definer
set search_path to 'public'
as $$
declare
  v_partner_id uuid;
  v_code text := upper(trim(coalesce(p_partner_code,'')));
  v_name text := trim(coalesce(p_partner_name,''));
  v_next integer;
begin
  if not exists(
    select 1 from public.partner_users pu
    where pu.user_id=p_actor_user_id
      and lower(coalesce(pu.role,''))='admin'
      and lower(coalesce(pu.status,''))='active'
      and pu.removed_at is null
  ) then
    raise exception 'Admin access required';
  end if;

  if p_new_user_id is null then raise exception 'New Auth user is required'; end if;
  if v_name='' then raise exception 'Partner name is required'; end if;
  if coalesce(p_voucher_limit,0)<0 or coalesce(p_staff_limit,0)<0 then raise exception 'Limits must be zero or greater'; end if;

  if v_code='' then
    perform pg_advisory_xact_lock(hashtext('commercial_partner_code_sequence'));
    select coalesce(max(substring(p.partner_code from '^P([0-9]+)$')::integer),0)+1
      into v_next
    from public.partners p
    where p.partner_code ~ '^P[0-9]+$';
    v_code := 'P' || lpad(v_next::text,3,'0');
  end if;

  if v_code !~ '^[A-Z0-9_-]+$' then raise exception 'Invalid Partner code'; end if;
  if exists(select 1 from public.partners p where upper(p.partner_code)=v_code) then raise exception 'Partner code already exists'; end if;
  if exists(select 1 from public.partner_users pu where pu.user_id=p_new_user_id) then raise exception 'Auth user already linked'; end if;

  insert into public.partners(
    partner_code,partner_name,contact_person,contact_phone,
    voucher_limit,vouchers_issued,status,staff_limit,staff_access_enabled
  ) values (
    v_code,v_name,nullif(trim(coalesce(p_contact_person,'')),''),nullif(trim(coalesce(p_contact_phone,'')),''),
    coalesce(p_voucher_limit,0),0,'active',coalesce(p_staff_limit,0),false
  ) returning id into v_partner_id;

  insert into public.partner_users(
    user_id,partner_id,role,status,login_email,removed_at
  ) values (
    p_new_user_id,v_partner_id,'partner_admin','active',nullif(lower(trim(coalesce(p_login_email,''))),''),null
  );

  insert into public.admin_audit_log(
    actor_user_id,action_type,entity_type,entity_id,partner_id,after_data,metadata
  ) values (
    p_actor_user_id,'partner_created','partner',v_partner_id::text,v_partner_id,
    jsonb_build_object('partner_code',v_code,'partner_name',v_name,'voucher_limit',coalesce(p_voucher_limit,0),'staff_limit',coalesce(p_staff_limit,0)),
    jsonb_build_object('source','service_provision_partner','partner_code_mode','auto_sequence')
  );

  return jsonb_build_object(
    'success',true,
    'partner',jsonb_build_object(
      'id',v_partner_id,
      'partner_code',v_code,
      'partner_name',v_name,
      'voucher_limit',coalesce(p_voucher_limit,0),
      'staff_limit',coalesce(p_staff_limit,0),
      'status','active'
    )
  );
end;
$$;
