-- Commercial Voucher canonical rebuild baseline
-- Status: REBUILD-ONLY / NOT FOR LIVE APPLY
-- Layer: 005 Supporting / Public / Reporting RPCs
-- Source: verified live Commercial schema snapshot 2026-09-05
-- Neutralized:
--   * no Evolution Optical share copy
--   * no RM hard-coded labels
--   * no Asia/Kuala_Lumpur timezone assumption

create or replace function public.get_public_voucher(p_token uuid)
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
    'success', true,
    'voucher_code', v.voucher_code,
    'voucher_type', v.voucher_type,
    'customer_name', v.customer_name,
    'partner_name', p.partner_name,
    'expiry_date', v.expiry_date,
    'status', case
      when lower(coalesce(v.status,''))='redeemed' then 'redeemed'
      when lower(coalesce(v.status,''))='revoked' then 'revoked'
      when v.expiry_date < current_date then 'expired'
      else lower(coalesce(v.status,'valid'))
    end,
    'issued_at', v.issued_at,
    'all_branches', coalesce(v.all_branches,false),
    'greeting_text', nullif(trim(coalesce(v.metadata->>'greeting_text','')),''),
    'theme_code', nullif(trim(coalesce(v.metadata->>'theme_code','')),''),
    'theme_config', coalesce(v.metadata->'theme_config','{}'::jsonb),
    'terms_text', nullif(trim(coalesce(v.metadata->>'terms_text','')),''),
    'branches', coalesce(
      case
        when coalesce(v.all_branches,false) then (
          select jsonb_agg(jsonb_build_object(
            'branch_code',b.branch_code,
            'branch_name',b.branch_name,
            'address',b.address,
            'phone',b.phone
          ) order by b.branch_name)
          from public.branches b
          where lower(coalesce(b.status,'active'))='active'
        )
        else (
          select jsonb_agg(jsonb_build_object(
            'branch_code',b.branch_code,
            'branch_name',b.branch_name,
            'address',b.address,
            'phone',b.phone
          ) order by b.branch_name)
          from public.voucher_branches vb
          join public.branches b on b.id=vb.branch_id
          where vb.voucher_id=v.id
            and lower(coalesce(b.status,'active'))='active'
        )
      end,
      '[]'::jsonb
    )
  ) into v_result
  from public.vouchers v
  left join public.partners p on p.id=v.partner_id
  where v.public_token=p_token
  limit 1;

  if v_result is null then
    return jsonb_build_object('success',false,'error','Voucher not found');
  end if;

  return v_result;
end;
$$;

create or replace function public.get_partner_voucher_share(p_voucher_id uuid)
returns jsonb
language plpgsql
stable
security definer
set search_path to 'public'
as $$
declare
  v_uid uuid := auth.uid();
  v_partner_id uuid;
  v_code text;
  v_type text;
  v_expiry date;
  v_customer text;
  v_all boolean;
  v_greeting text;
  v_branches jsonb := '[]'::jsonb;
  v_branch_text text := '';
  v_message text;
begin
  select v.partner_id,v.voucher_code,v.voucher_type,v.expiry_date,v.customer_name,v.all_branches,
         nullif(trim(coalesce(v.metadata->>'greeting_text','')),'')
    into v_partner_id,v_code,v_type,v_expiry,v_customer,v_all,v_greeting
  from public.vouchers v
  where v.id=p_voucher_id;

  if not found then
    raise exception 'Voucher not found';
  end if;

  if not public.is_voucher_admin() and not exists(
    select 1
    from public.partner_users pu
    join public.partners p on p.id=pu.partner_id
    where pu.user_id=v_uid
      and pu.partner_id=v_partner_id
      and lower(coalesce(pu.status,''))='active'
      and pu.removed_at is null
      and lower(coalesce(pu.role,'')) in ('partner_admin','partner_staff')
      and lower(coalesce(p.status,''))='active'
  ) then
    raise exception 'Partner access required';
  end if;

  if v_all then
    select coalesce(jsonb_agg(jsonb_build_object(
      'branch_code',b.branch_code,
      'branch_name',b.branch_name,
      'address',b.address,
      'phone',b.phone
    ) order by b.branch_name),'[]'::jsonb),
    coalesce(string_agg(
      b.branch_name || case
        when nullif(trim(coalesce(b.address,'')),'') is not null then ' — '||b.address
        else ''
      end,
      E'\n' order by b.branch_name
    ),'')
    into v_branches,v_branch_text
    from public.branches b
    where lower(coalesce(b.status,''))='active';
  else
    select coalesce(jsonb_agg(jsonb_build_object(
      'branch_code',b.branch_code,
      'branch_name',b.branch_name,
      'address',b.address,
      'phone',b.phone
    ) order by b.branch_name),'[]'::jsonb),
    coalesce(string_agg(
      b.branch_name || case
        when nullif(trim(coalesce(b.address,'')),'') is not null then ' — '||b.address
        else ''
      end,
      E'\n' order by b.branch_name
    ),'')
    into v_branches,v_branch_text
    from public.voucher_branches vb
    join public.branches b on b.id=vb.branch_id
    where vb.voucher_id=p_voucher_id
      and lower(coalesce(b.status,''))='active';
  end if;

  v_message := E'Hi 👋\nA little gift for you 🎁✨\nHere is your voucher.'
    || case when v_greeting is not null then E'\n\n'||v_greeting else '' end
    || E'\n\nVoucher: '||coalesce(v_type,'Voucher')
    || E'\nCode: '||coalesce(v_code,'')
    || case when nullif(trim(coalesce(v_customer,'')),'') is not null then E'\nFor: '||v_customer else '' end
    || case when v_expiry is not null then E'\nExpiry: '||v_expiry::text else '' end
    || case when nullif(v_branch_text,'') is not null then E'\n\nRedeem at:\n'||v_branch_text else '' end;

  return jsonb_build_object(
    'success',true,
    'voucher_id',p_voucher_id,
    'voucher_code',v_code,
    'voucher_type',v_type,
    'expiry_date',v_expiry,
    'greeting_text',v_greeting,
    'branches',v_branches,
    'message_body',v_message
  );
end;
$$;

create or replace function public.issue_engine_voucher(
  p_version_id uuid,
  p_customer_name text,
  p_customer_phone text default null::text
)
returns jsonb
language sql
security definer
set search_path to 'public'
as $$
  select public.create_partner_multi_voucher_controlled(
    p_version_id,
    p_customer_name,
    p_customer_phone
  );
$$;

create or replace function public.partner_recent_vouchers(p_limit integer default 50)
returns table(
  voucher_id uuid,
  voucher_code text,
  customer_name text,
  customer_phone text,
  voucher_type text,
  voucher_status text,
  expiry_date date,
  issued_at timestamptz,
  issued_by_name text,
  usage_count integer,
  usage_limit integer,
  last_redeemed_at timestamptz,
  last_branch_name text
)
language plpgsql
stable
security definer
set search_path to 'public'
as $$
declare
  v_partner_id uuid;
begin
  select pu.partner_id
  into v_partner_id
  from public.partner_users pu
  join public.partners p on p.id=pu.partner_id
  where pu.user_id=auth.uid()
    and lower(coalesce(pu.status,''))='active'
    and pu.removed_at is null
    and lower(coalesce(pu.role,'')) in ('admin','partner_admin','partner_staff')
    and lower(coalesce(p.status,''))='active'
  order by case when lower(coalesce(pu.role,''))='admin' then 0 else 1 end
  limit 1;

  if v_partner_id is null then
    raise exception 'Active Partner account not found';
  end if;

  if p_limit is null or p_limit<1 or p_limit>500 then
    raise exception 'Limit must be between 1 and 500';
  end if;

  return query
  select
    v.id,
    v.voucher_code,
    v.customer_name,
    v.customer_phone,
    v.voucher_type,
    case
      when lower(coalesce(v.status,''))='revoked' then 'revoked'
      when lower(coalesce(v.status,''))='expired'
        or (lower(coalesce(v.status,'')) in ('valid','active') and v.expiry_date<current_date)
        then 'expired'
      when lower(coalesce(v.status,''))='redeemed' then 'redeemed'
      else 'active'
    end,
    v.expiry_date,
    v.issued_at,
    v.issued_by_name,
    case
      when lower(coalesce(v.status,''))='redeemed' then greatest(coalesce(v.usage_count,0),1)
      else coalesce(v.usage_count,0)
    end,
    1::integer,
    lr.redeemed_at,
    lr.branch_name
  from public.vouchers v
  left join lateral (
    select r.redeemed_at,b.branch_name
    from public.redemptions r
    left join public.branches b on b.id=r.branch_id
    where r.voucher_id=v.id
      and lower(coalesce(r.status,'')) in ('success','completed')
    order by r.redeemed_at desc
    limit 1
  ) lr on true
  where v.partner_id=v_partner_id
  order by v.issued_at desc nulls last
  limit p_limit;
end;
$$;

create or replace function public.partner_voucher_summary()
returns jsonb
language plpgsql
stable
security definer
set search_path to 'public'
as $$
declare
  v_partner_id uuid;
  v_today date := current_date;
begin
  select pu.partner_id
  into v_partner_id
  from public.partner_users pu
  join public.partners p on p.id=pu.partner_id
  where pu.user_id=auth.uid()
    and lower(coalesce(pu.status,''))='active'
    and pu.removed_at is null
    and lower(coalesce(pu.role,'')) in ('admin','partner_admin','partner_staff')
    and lower(coalesce(p.status,''))='active'
  order by case when lower(coalesce(pu.role,''))='admin' then 0 else 1 end
  limit 1;

  if v_partner_id is null then
    raise exception 'Active Partner account not found';
  end if;

  return jsonb_build_object(
    'partner_id',v_partner_id,
    'issued_total',(select count(*) from public.vouchers v where v.partner_id=v_partner_id),
    'active_total',(select count(*) from public.vouchers v where v.partner_id=v_partner_id and lower(coalesce(v.status,'')) in ('valid','active') and v.expiry_date>=v_today),
    'redeemed_total',(select count(*) from public.vouchers v where v.partner_id=v_partner_id and lower(coalesce(v.status,''))='redeemed'),
    'expired_total',(select count(*) from public.vouchers v where v.partner_id=v_partner_id and (lower(coalesce(v.status,''))='expired' or (lower(coalesce(v.status,'')) in ('valid','active') and v.expiry_date<v_today))),
    'revoked_total',(select count(*) from public.vouchers v where v.partner_id=v_partner_id and lower(coalesce(v.status,''))='revoked'),
    'completed_redemptions',(select count(*) from public.redemptions r where r.partner_id=v_partner_id and lower(coalesce(r.status,'')) in ('success','completed'))
  );
end;
$$;

create or replace function public.staff_operational_context()
returns jsonb
language plpgsql
stable
security definer
set search_path to 'public'
as $$
declare
  v_staff public.staff_users%rowtype;
  v_branch public.branches%rowtype;
  v_branches jsonb := '[]'::jsonb;
begin
  select *
  into v_staff
  from public.staff_users su
  where su.user_id=auth.uid()
    and lower(coalesce(su.status,''))='active'
  limit 1;

  if not found then
    raise exception 'Active Staff account not found';
  end if;

  if lower(coalesce(v_staff.role,''))='all_branch_manager' then
    select coalesce(jsonb_agg(jsonb_build_object(
      'branch_id',b.id,
      'branch_code',b.branch_code,
      'branch_name',b.branch_name,
      'address',b.address,
      'phone',b.phone
    ) order by b.branch_name),'[]'::jsonb)
    into v_branches
    from public.branches b
    where lower(coalesce(b.status,''))='active';
  else
    if v_staff.branch_id is null then
      raise exception 'Staff account has no branch assigned';
    end if;

    select *
    into v_branch
    from public.branches b
    where b.id=v_staff.branch_id
      and lower(coalesce(b.status,''))='active';

    if not found then
      raise exception 'Assigned branch is not active';
    end if;

    v_branches:=jsonb_build_array(jsonb_build_object(
      'branch_id',v_branch.id,
      'branch_code',v_branch.branch_code,
      'branch_name',v_branch.branch_name,
      'address',v_branch.address,
      'phone',v_branch.phone
    ));
  end if;

  return jsonb_build_object(
    'success',true,
    'staff_user_id',v_staff.id,
    'staff_name',v_staff.staff_name,
    'role',v_staff.role,
    'branch_id',v_staff.branch_id,
    'branch_selection_required',lower(coalesce(v_staff.role,''))='all_branch_manager',
    'branches',v_branches
  );
end;
$$;

create or replace function public.staff_recent_redemptions(p_limit integer default 20)
returns table(
  redemption_id uuid,
  voucher_id uuid,
  voucher_code text,
  customer_name text,
  voucher_type text,
  partner_name text,
  branch_id uuid,
  branch_name text,
  staff_name text,
  redeem_method text,
  redemption_status text,
  redeemed_at timestamptz,
  notes text
)
language plpgsql
stable
security definer
set search_path to 'public'
as $$
declare
  v_staff public.staff_users%rowtype;
begin
  if p_limit is null or p_limit<1 or p_limit>100 then
    raise exception 'Limit must be between 1 and 100';
  end if;

  select *
  into v_staff
  from public.staff_users su
  where su.user_id=auth.uid()
    and lower(coalesce(su.status,''))='active'
  limit 1;

  if not found then
    raise exception 'Active Staff account not found';
  end if;

  return query
  select
    r.id,
    r.voucher_id,
    v.voucher_code,
    v.customer_name,
    v.voucher_type,
    p.partner_name,
    r.branch_id,
    b.branch_name,
    coalesce(r.staff_name_snapshot,su.staff_name),
    r.redeem_method,
    case
      when lower(coalesce(r.status,'')) in ('success','completed') then 'completed'
      else lower(coalesce(r.status,''))
    end,
    r.redeemed_at,
    r.notes
  from public.redemptions r
  join public.vouchers v on v.id=r.voucher_id
  left join public.partners p on p.id=coalesce(r.partner_id,v.partner_id)
  left join public.branches b on b.id=r.branch_id
  left join public.staff_users su on su.id=r.staff_user_id
  where lower(coalesce(v_staff.role,''))='all_branch_manager'
     or (lower(coalesce(v_staff.role,''))='manager' and r.branch_id=v_staff.branch_id)
     or (lower(coalesce(v_staff.role,''))='staff' and r.staff_user_id=v_staff.id)
  order by r.redeemed_at desc nulls last
  limit p_limit;
end;
$$;

create or replace function public.staff_today_summary()
returns jsonb
language plpgsql
stable
security definer
set search_path to 'public'
as $$
declare
  v_staff public.staff_users%rowtype;
  v_count bigint;
begin
  select *
  into v_staff
  from public.staff_users su
  where su.user_id=auth.uid()
    and lower(coalesce(su.status,''))='active'
  limit 1;

  if not found then
    raise exception 'Active Staff account not found';
  end if;

  select count(*)
  into v_count
  from public.redemptions r
  where lower(coalesce(r.status,'')) in ('success','completed')
    and r.redeemed_at::date=current_date
    and (
      lower(coalesce(v_staff.role,''))='all_branch_manager'
      or (lower(coalesce(v_staff.role,''))='manager' and r.branch_id=v_staff.branch_id)
      or (lower(coalesce(v_staff.role,''))='staff' and r.staff_user_id=v_staff.id)
    );

  return jsonb_build_object(
    'success',true,
    'staff_user_id',v_staff.id,
    'staff_name',v_staff.staff_name,
    'role',v_staff.role,
    'branch_id',v_staff.branch_id,
    'today_redeemed',v_count
  );
end;
$$;

create or replace function public.admin_dashboard_summary()
returns jsonb
language plpgsql
stable
security definer
set search_path to 'public'
as $$
declare
  v_today date := current_date;
  v_result jsonb;
begin
  if not public.is_voucher_admin() then
    raise exception 'Admin access required';
  end if;

  select jsonb_build_object(
    'partners_total',(select count(*) from public.partners p where upper(coalesce(p.partner_code,''))<>'ADMIN' and lower(coalesce(p.status,''))<>'archived'),
    'partners_active',(select count(*) from public.partners p where upper(coalesce(p.partner_code,''))<>'ADMIN' and lower(coalesce(p.status,''))='active'),
    'vouchers_total',(select count(*) from public.vouchers),
    'vouchers_active',(select count(*) from public.vouchers v where lower(coalesce(v.status,'')) in ('valid','active') and v.expiry_date>=v_today),
    'vouchers_redeemed',(select count(*) from public.vouchers v where lower(coalesce(v.status,''))='redeemed' or (coalesce(v.usage_count,0)>0 and lower(coalesce(v.status,'')) not in ('revoked','expired'))),
    'vouchers_expired',(select count(*) from public.vouchers v where lower(coalesce(v.status,''))='expired' or (lower(coalesce(v.status,'')) in ('valid','active') and v.expiry_date<v_today)),
    'vouchers_revoked',(select count(*) from public.vouchers v where lower(coalesce(v.status,''))='revoked'),
    'redemptions_completed',(select count(*) from public.redemptions r where lower(coalesce(r.status,'')) in ('success','completed')),
    'redemptions_reversed',(select count(*) from public.redemptions r where lower(coalesce(r.status,''))='reversed'),
    'redemptions_today',(select count(*) from public.redemptions r where lower(coalesce(r.status,'')) in ('success','completed') and r.redeemed_at::date=v_today)
  ) into v_result;

  return v_result;
end;
$$;

create or replace function public.admin_redemption_report(
  p_partner_id uuid default null::uuid,
  p_limit integer default 500
)
returns table(
  redemption_id uuid,
  voucher_id uuid,
  voucher_code text,
  partner_id uuid,
  partner_name text,
  branch_id uuid,
  branch_name text,
  staff_user_id uuid,
  staff_name text,
  redeem_method text,
  redemption_status text,
  redeemed_at timestamptz,
  notes text,
  reversed_at timestamptz,
  reversed_by_name text,
  reverse_reason text
)
language plpgsql
stable
security definer
set search_path to 'public'
as $$
begin
  if not public.is_voucher_admin() then
    raise exception 'Admin access required';
  end if;

  if p_limit is null or p_limit<1 or p_limit>5000 then
    raise exception 'Limit must be between 1 and 5000';
  end if;

  return query
  select
    r.id,
    r.voucher_id,
    v.voucher_code,
    coalesce(r.partner_id,v.partner_id),
    p.partner_name,
    r.branch_id,
    b.branch_name,
    r.staff_user_id,
    coalesce(r.staff_name_snapshot,su.staff_name),
    r.redeem_method,
    case
      when lower(coalesce(r.status,'')) in ('success','completed') then 'completed'
      when lower(coalesce(r.status,''))='reversed' then 'reversed'
      else lower(coalesce(r.status,''))
    end,
    r.redeemed_at,
    r.notes,
    r.reversed_at,
    r.reversed_by_name,
    r.reverse_reason
  from public.redemptions r
  join public.vouchers v on v.id=r.voucher_id
  left join public.partners p on p.id=coalesce(r.partner_id,v.partner_id)
  left join public.branches b on b.id=r.branch_id
  left join public.staff_users su on su.id=r.staff_user_id
  where p_partner_id is null or coalesce(r.partner_id,v.partner_id)=p_partner_id
  order by r.redeemed_at desc nulls last
  limit p_limit;
end;
$$;

create or replace function public.admin_voucher_report(
  p_partner_id uuid default null::uuid,
  p_limit integer default 500
)
returns table(
  voucher_id uuid,
  voucher_code text,
  partner_id uuid,
  partner_name text,
  customer_name text,
  customer_phone text,
  voucher_type text,
  voucher_status text,
  expiry_date date,
  issued_at timestamptz,
  issued_by_name text,
  usage_count integer,
  usage_limit integer,
  last_redeemed_at timestamptz,
  last_branch_name text,
  last_staff_name text,
  completed_redemptions bigint,
  reversed_redemptions bigint
)
language plpgsql
stable
security definer
set search_path to 'public'
as $$
begin
  if not public.is_voucher_admin() then
    raise exception 'Admin access required';
  end if;

  if p_limit is null or p_limit<1 or p_limit>5000 then
    raise exception 'Limit must be between 1 and 5000';
  end if;

  return query
  select
    v.id,
    v.voucher_code,
    v.partner_id,
    p.partner_name,
    v.customer_name,
    v.customer_phone,
    v.voucher_type,
    case
      when lower(coalesce(v.status,''))='revoked' then 'revoked'
      when lower(coalesce(v.status,''))='expired'
        or (lower(coalesce(v.status,'')) in ('valid','active') and v.expiry_date<current_date)
        then 'expired'
      when lower(coalesce(v.status,''))='redeemed' or coalesce(v.usage_count,0)>0 then 'redeemed'
      else 'active'
    end,
    v.expiry_date,
    v.issued_at,
    v.issued_by_name,
    greatest(coalesce(v.usage_count,0),case when lower(coalesce(v.status,''))='redeemed' then 1 else 0 end),
    1::integer,
    lr.redeemed_at,
    lr.branch_name,
    lr.staff_name_snapshot,
    coalesce(rc.completed_count,0),
    coalesce(rc.reversed_count,0)
  from public.vouchers v
  left join public.partners p on p.id=v.partner_id
  left join lateral (
    select r.redeemed_at,b.branch_name,r.staff_name_snapshot
    from public.redemptions r
    left join public.branches b on b.id=r.branch_id
    where r.voucher_id=v.id
      and lower(coalesce(r.status,'')) in ('success','completed')
    order by r.redeemed_at desc
    limit 1
  ) lr on true
  left join lateral (
    select
      count(*) filter (where lower(coalesce(r.status,'')) in ('success','completed'))::bigint as completed_count,
      count(*) filter (where lower(coalesce(r.status,''))='reversed')::bigint as reversed_count
    from public.redemptions r
    where r.voucher_id=v.id
  ) rc on true
  where p_partner_id is null or v.partner_id=p_partner_id
  order by v.issued_at desc nulls last
  limit p_limit;
end;
$$;

-- partner_issuable_voucher_catalog is intentionally deferred because its live
-- label formatting still embeds a hard-coded currency presentation layer.
-- The canonical rebuild will add it only after currency/display configuration
-- is represented as application data rather than SQL text formatting.
