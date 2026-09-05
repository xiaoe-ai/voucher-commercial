-- Commercial Voucher: stable automatic Staff codes
-- Staff codes are system-generated globally as S001, S002, S003...

alter table public.staff_users add column if not exists staff_code text;

with ranked as (
  select id, row_number() over (order by created_at, id) as rn
  from public.staff_users
  where staff_code is null or btrim(staff_code)=''
)
update public.staff_users s
set staff_code = 'S' || lpad(r.rn::text, 3, '0')
from ranked r
where s.id = r.id;

create unique index if not exists staff_users_staff_code_uidx
  on public.staff_users (upper(staff_code))
  where staff_code is not null;

alter table public.staff_users alter column staff_code set not null;

create or replace function public.admin_provision_staff(
  p_new_user_id uuid,
  p_staff_name text,
  p_branch_id uuid,
  p_role text,
  p_login_email text,
  p_actor_user_id uuid
)
returns jsonb
language plpgsql
security definer
set search_path to 'public'
as $$
declare
  v_is_admin boolean:=false;
  v_manager public.staff_users%rowtype;
  v_requested_role text:=lower(trim(coalesce(p_role,'')));
  v_staff public.staff_users%rowtype;
  v_next integer;
  v_code text;
begin
  if not public.is_trusted_service_role() then raise exception 'Trusted server context required'; end if;
  if p_actor_user_id is null then raise exception 'Actor user is required'; end if;

  select exists(
    select 1 from public.partner_users pu
    where pu.user_id=p_actor_user_id
      and lower(coalesce(pu.role,''))='admin'
      and lower(coalesce(pu.status,''))='active'
      and pu.removed_at is null
  ) into v_is_admin;

  if not v_is_admin then
    select * into v_manager
    from public.staff_users su
    where su.user_id=p_actor_user_id
      and su.status='active'
      and su.role in ('manager','all_branch_manager')
    limit 1;
    if not found then raise exception 'Active Admin or Manager actor required'; end if;
  end if;

  if p_new_user_id is null or not exists(select 1 from auth.users u where u.id=p_new_user_id) then
    raise exception 'Valid Auth user is required';
  end if;
  if nullif(trim(coalesce(p_staff_name,'')),'') is null then raise exception 'Staff name is required'; end if;
  if v_requested_role not in ('staff','manager') then raise exception 'Allowed roles: staff, manager'; end if;
  if not exists(select 1 from public.branches b where b.id=p_branch_id and b.status='active') then raise exception 'Active branch is required'; end if;

  if not v_is_admin and v_manager.role='manager' then
    if v_requested_role<>'staff' then raise exception 'Branch Manager can only create Staff accounts'; end if;
    if v_manager.branch_id is null or p_branch_id is distinct from v_manager.branch_id then
      raise exception 'Branch Manager can only create Staff at assigned branch';
    end if;
  end if;

  perform pg_advisory_xact_lock(hashtext('commercial_voucher:staff_code'));
  select coalesce(max((substring(upper(staff_code) from '^S([0-9]+)$'))::integer),0)+1
    into v_next
  from public.staff_users
  where upper(staff_code) ~ '^S[0-9]+$';
  v_code := 'S' || lpad(v_next::text, 3, '0');

  insert into public.staff_users(user_id,branch_id,staff_name,staff_code,role,status)
  values(p_new_user_id,p_branch_id,trim(p_staff_name),v_code,v_requested_role,'active')
  returning * into v_staff;

  insert into public.admin_audit_log(actor_user_id,action_type,entity_type,entity_id,after_data,metadata)
  values(
    p_actor_user_id,
    'staff_account_created',
    'staff_users',
    v_staff.id::text,
    jsonb_build_object('staff_code',v_staff.staff_code,'staff_name',v_staff.staff_name,'branch_id',v_staff.branch_id,'role',v_staff.role,'status',v_staff.status),
    jsonb_build_object('login_email',lower(trim(coalesce(p_login_email,''))),'secret_material_logged',false,'provisioning','hosted_adapter')
  );

  return jsonb_build_object('success',true,'staff',to_jsonb(v_staff));
end;
$$;
