-- Commercial Voucher neutralization Phase 2G-A
-- Scope: service_bootstrap_first_admin() only.
-- Preserve setup-code, first-admin, one-time consume, partner/user creation behavior.
-- Neutralize customer-specific advisory lock and display names.

create or replace function public.service_bootstrap_first_admin(
  p_user_id uuid,
  p_login_email text,
  p_setup_code text
)
returns jsonb
language plpgsql
security definer
set search_path to 'public','extensions'
as $$
declare
  v_admin_partner_id uuid;
  v_cfg public.admin_bootstrap_config%rowtype;
begin
  if p_user_id is null then raise exception 'Auth user_id is required'; end if;
  if nullif(trim(coalesce(p_login_email,'')),'') is null then raise exception 'Login email is required'; end if;
  if nullif(coalesce(p_setup_code,''),'') is null then raise exception 'Setup code is required'; end if;

  perform pg_advisory_xact_lock(hashtextextended('commercial_voucher:first_admin_bootstrap',0));

  if exists(
    select 1 from public.partner_users pu
    where lower(coalesce(pu.role,''))='admin'
      and lower(coalesce(pu.status,''))='active'
      and pu.removed_at is null
  ) then
    raise exception 'First Admin setup is already complete';
  end if;

  select * into v_cfg
  from public.admin_bootstrap_config c
  where c.singleton=true
  for update;

  if not found or not coalesce(v_cfg.enabled,false) or v_cfg.setup_code_hash is null then
    raise exception 'First Admin setup is not enabled';
  end if;

  if encode(digest(p_setup_code,'sha256'),'hex') <> v_cfg.setup_code_hash then
    raise exception 'Invalid setup code';
  end if;

  select p.id into v_admin_partner_id
  from public.partners p
  where upper(coalesce(p.partner_code,''))='ADMIN'
  order by p.created_at nulls last
  limit 1
  for update;

  if v_admin_partner_id is null then
    insert into public.partners(
      partner_code,partner_name,voucher_limit,vouchers_issued,status,staff_limit,staff_access_enabled
    ) values (
      'ADMIN','Commercial Voucher Admin',0,0,'active',0,false
    ) returning id into v_admin_partner_id;
  else
    update public.partners
    set status='active'
    where id=v_admin_partner_id;
  end if;

  insert into public.partner_users(
    user_id,partner_id,role,status,login_email,staff_name,removed_at
  ) values (
    p_user_id,v_admin_partner_id,'admin','active',lower(trim(p_login_email)),'Commercial Voucher Admin',null
  );

  update public.admin_bootstrap_config
  set enabled=false,
      consumed_at=now(),
      updated_at=now()
  where singleton=true;

  return jsonb_build_object(
    'success',true,
    'user_id',p_user_id,
    'realm','admin',
    'partner_id',v_admin_partner_id
  );
end;
$$;
