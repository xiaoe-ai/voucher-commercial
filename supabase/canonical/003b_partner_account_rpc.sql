-- Commercial Voucher canonical rebuild baseline
-- Status: REBUILD-ONLY / NOT FOR LIVE APPLY
-- Layer: 003B Partner account / claim / staff-control RPCs
-- Source: verified live Commercial schema snapshot 2026-09-05
-- Customer-neutral: no EVO / Evolution Optical / Malaysia / Kuala Lumpur assumptions.

create or replace function public.get_my_partner_dashboard()
returns jsonb
language plpgsql
stable
security definer
set search_path to 'public'
as $$
declare
  v_result jsonb;
begin
  select jsonb_build_object(
    'partner_id',p.id,
    'partner_code',p.partner_code,
    'partner_name',p.partner_name,
    'voucher_limit',coalesce(p.voucher_limit,0),
    'vouchers_issued',coalesce(p.vouchers_issued,0),
    'remaining',greatest(0,coalesce(p.voucher_limit,0)-coalesce(p.vouchers_issued,0)),
    'partner_status',p.status,
    'role',pu.role,
    'staff_name',pu.staff_name,
    'staff_access_enabled',coalesce(p.staff_access_enabled,false),
    'staff_limit',coalesce(p.staff_limit,0),
    'can_issue_voucher',case
      when lower(coalesce(pu.role,'')) in ('admin','partner_admin') then true
      when lower(coalesce(pu.role,''))='partner_staff' then coalesce(p.staff_access_enabled,false)
      else false
    end
  ) into v_result
  from public.partner_users pu
  join public.partners p on p.id=pu.partner_id
  where pu.user_id=auth.uid()
    and lower(coalesce(pu.status,''))='active'
    and pu.removed_at is null
    and lower(coalesce(p.status,''))='active'
    and lower(coalesce(pu.role,'')) in ('admin','partner_admin','partner_staff')
  order by case when lower(coalesce(pu.role,''))='admin' then 0 else 1 end
  limit 1;

  if v_result is null then
    raise exception 'Active Partner account not found';
  end if;

  return v_result;
end;
$$;

create or replace function public.get_my_partner_claim_access()
returns jsonb
language plpgsql
security definer
set search_path to 'public'
as $$
declare
  v_partner uuid;
  v_all boolean;
  v_codes text[];
  v_names text[];
begin
  select pu.partner_id
  into v_partner
  from public.partner_users pu
  join public.partners p on p.id=pu.partner_id
  where pu.user_id=auth.uid()
    and lower(coalesce(pu.status,''))='active'
    and pu.removed_at is null
    and lower(coalesce(pu.role,'')) in ('admin','partner_admin','partner_staff')
    and lower(coalesce(p.status,''))='active'
  order by case when lower(coalesce(pu.role,''))='admin' then 0 else 1 end
  limit 1;

  if v_partner is null then
    raise exception 'Active Partner account not found';
  end if;

  select coalesce(s.all_branches,true)
  into v_all
  from public.partner_claim_settings s
  where s.partner_id=v_partner;

  if not found then
    v_all:=true;
  end if;

  select
    coalesce(array_agg(b.branch_code order by b.branch_name),'{}'::text[]),
    coalesce(array_agg(coalesce(b.branch_name,b.branch_code) order by b.branch_name),'{}'::text[])
  into v_codes,v_names
  from public.partner_claim_branches pcb
  join public.branches b on b.id=pcb.branch_id
  where pcb.partner_id=v_partner
    and lower(coalesce(b.status,'active'))='active';

  return jsonb_build_object(
    'success',true,
    'all_branches',v_all,
    'branch_codes',v_codes,
    'branch_names',v_names
  );
end;
$$;

create or replace function public.partner_staff_capacity()
returns table(
  partner_id uuid,
  staff_count bigint,
  staff_limit integer,
  staff_access_enabled boolean
)
language sql
stable
security definer
set search_path to 'public'
as $$
  select p.id,
         count(pu2.id) filter (
           where pu2.role = 'partner_staff'
             and pu2.status <> 'inactive'
             and pu2.removed_at is null
         ) as staff_count,
         p.staff_limit,
         p.staff_access_enabled
  from public.partners p
  join public.partner_users me
    on me.partner_id = p.id
   and me.user_id = auth.uid()
   and me.role = 'partner_admin'
   and me.status = 'active'
   and me.removed_at is null
  left join public.partner_users pu2
    on pu2.partner_id = p.id
  group by p.id, p.staff_limit, p.staff_access_enabled;
$$;

create or replace function public.partner_set_staff_access(enabled boolean)
returns boolean
language plpgsql
security definer
set search_path to 'public'
as $$
declare
  v_partner_id uuid;
begin
  select pu.partner_id
  into v_partner_id
  from public.partner_users pu
  where pu.user_id = auth.uid()
    and pu.role = 'partner_admin'
    and pu.status = 'active'
    and pu.removed_at is null
  limit 1;

  if v_partner_id is null then
    raise exception 'Partner admin access required';
  end if;

  update public.partners
  set staff_access_enabled = enabled
  where id = v_partner_id
    and status = 'active';

  if not found then
    raise exception 'Partner is not active';
  end if;

  return enabled;
end;
$$;

-- Execute grants are intentionally deferred to a dedicated privilege/grant layer.
