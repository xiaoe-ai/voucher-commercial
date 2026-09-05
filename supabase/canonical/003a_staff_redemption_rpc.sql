-- Commercial Voucher canonical rebuild baseline
-- Status: REBUILD-ONLY / NOT FOR LIVE APPLY
-- Layer: 003A Staff verification / redemption RPCs
-- Source: verified live Commercial schema snapshot 2026-09-05
-- Customer-neutral: no EVO / Evolution Optical / Malaysia / Kuala Lumpur assumptions.

create or replace function public.verify_voucher(p_voucher_code text)
returns jsonb
language plpgsql
security definer
set search_path to 'public'
as $$
declare
  v_staff public.staff_users%rowtype;
  v_voucher public.vouchers%rowtype;
  v_branch_name text;
  v_allowed boolean := false;
begin
  select *
  into v_staff
  from public.staff_users
  where user_id = auth.uid()
    and status = 'active'
  limit 1;

  if not found then
    return jsonb_build_object(
      'success', false,
      'error', 'Staff account is not authorised or is suspended'
    );
  end if;

  if v_staff.branch_id is null then
    return jsonb_build_object(
      'success', false,
      'error', 'Staff account has no branch assigned'
    );
  end if;

  select *
  into v_voucher
  from public.vouchers
  where upper(voucher_code) = upper(trim(p_voucher_code))
  limit 1;

  if not found then
    return jsonb_build_object(
      'success', false,
      'error', 'Voucher not found'
    );
  end if;

  if v_voucher.all_branches then
    v_allowed := true;
  else
    select exists (
      select 1
      from public.voucher_branches vb
      where vb.voucher_id = v_voucher.id
        and vb.branch_id = v_staff.branch_id
    )
    into v_allowed;
  end if;

  select branch_name
  into v_branch_name
  from public.branches
  where id = v_staff.branch_id;

  return jsonb_build_object(
    'success', true,
    'voucher_code', v_voucher.voucher_code,
    'customer_name', v_voucher.customer_name,
    'customer_phone', v_voucher.customer_phone,
    'voucher_type', v_voucher.voucher_type,
    'expiry_date', v_voucher.expiry_date,
    'status', v_voucher.status,
    'redeemed_at', v_voucher.redeemed_at,
    'branch_name', v_branch_name,
    'branch_allowed', v_allowed,
    'expired', v_voucher.expiry_date < current_date,
    'can_redeem',
      lower(coalesce(v_voucher.status,'')) = 'valid'
      and v_voucher.expiry_date >= current_date
      and v_allowed
  );
end;
$$;

create or replace function public.redeem_voucher(
  p_voucher_code text,
  p_notes text default null::text
)
returns jsonb
language plpgsql
security definer
set search_path to 'public'
as $$
declare
  v_staff public.staff_users%rowtype;
  v_voucher public.vouchers%rowtype;
  v_branch_name text;
begin
  if auth.uid() is null then
    return jsonb_build_object('success',false,'error','Authentication required');
  end if;

  select * into v_staff
  from public.staff_users
  where user_id=auth.uid() and status='active'
  limit 1;

  if not found then
    return jsonb_build_object('success',false,'error','Staff account is not authorised or is suspended');
  end if;

  if v_staff.branch_id is null then
    return jsonb_build_object('success',false,'error','Staff account has no branch assigned');
  end if;

  select * into v_voucher
  from public.vouchers
  where upper(voucher_code)=upper(trim(p_voucher_code))
  for update;

  if not found then
    return jsonb_build_object('success',false,'error','Voucher not found');
  end if;

  if lower(coalesce(v_voucher.status,'')) <> 'valid' then
    return jsonb_build_object('success',false,'error','Voucher is not valid','status',v_voucher.status);
  end if;

  if v_voucher.expiry_date < current_date then
    return jsonb_build_object('success',false,'error','Voucher has expired');
  end if;

  if not v_voucher.all_branches and not exists (
    select 1 from public.voucher_branches vb
    where vb.voucher_id=v_voucher.id and vb.branch_id=v_staff.branch_id
  ) then
    return jsonb_build_object('success',false,'error','Voucher cannot be redeemed at this branch');
  end if;

  if exists (
    select 1 from public.redemptions r
    where r.voucher_id=v_voucher.id and r.status='success'
  ) then
    return jsonb_build_object('success',false,'error','Voucher has already been redeemed');
  end if;

  select branch_name into v_branch_name
  from public.branches
  where id=v_staff.branch_id;

  insert into public.redemptions(
    voucher_id,
    branch_id,
    staff_user_id,
    partner_id,
    staff_name_snapshot,
    redeem_method,
    status,
    redeemed_at,
    notes
  ) values (
    v_voucher.id,
    v_staff.branch_id,
    v_staff.id,
    v_voucher.partner_id,
    v_staff.staff_name,
    'qr_scan',
    'success',
    now(),
    p_notes
  );

  update public.vouchers
  set status='redeemed',
      redeemed_at=now(),
      redeemed_by=v_staff.staff_name
  where id=v_voucher.id;

  return jsonb_build_object(
    'success',true,
    'voucher_code',v_voucher.voucher_code,
    'customer_name',v_voucher.customer_name,
    'voucher_type',v_voucher.voucher_type,
    'branch_name',v_branch_name,
    'staff_name',v_staff.staff_name,
    'redeemed_at',now()
  );
exception
  when unique_violation then
    return jsonb_build_object('success',false,'error','Voucher has already been redeemed');
end;
$$;

-- Execute grants are intentionally deferred to a dedicated privilege/grant layer.
-- This file preserves verified live application behavior only.
