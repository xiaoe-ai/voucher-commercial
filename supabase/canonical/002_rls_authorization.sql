-- Commercial Voucher canonical rebuild baseline
-- Status: REBUILD-ONLY / NOT FOR LIVE APPLY
-- Layer: 002 RLS / authorization helpers and core policies
-- Source: verified live Commercial schema snapshot 2026-09-05
-- Important: GRANT / REVOKE privileges are NOT canonicalized in this file because
-- the source snapshot was created with --no-privileges. Do not infer grants.

-- -----------------------------------------------------------------------------
-- Authorization helpers
-- -----------------------------------------------------------------------------

create or replace function public.is_admin()
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1
    from public.partner_users
    where user_id = auth.uid()
      and role = 'admin'
      and status = 'active'
  );
$$;

create or replace function public.is_voucher_admin()
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1
    from public.partner_users pu
    where pu.user_id = auth.uid()
      and lower(coalesce(pu.role,'')) = 'admin'
      and lower(coalesce(pu.status,'')) = 'active'
  );
$$;

create or replace function public.is_partner_admin_for_partner(target_partner_id uuid)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1
    from public.partner_users pu
    where pu.user_id = auth.uid()
      and pu.partner_id = target_partner_id
      and pu.role = 'partner_admin'
      and pu.status = 'active'
      and pu.removed_at is null
  );
$$;

-- -----------------------------------------------------------------------------
-- branches
-- -----------------------------------------------------------------------------

create policy branches_admin_select_all
on public.branches
for select
to authenticated
using (public.is_admin());

create policy branches_all_branch_manager_read
on public.branches
for select
to authenticated
using (
  exists (
    select 1
    from public.staff_users su
    where su.user_id = auth.uid()
      and su.status = 'active'
      and su.role = 'all_branch_manager'
  )
);

create policy branches_staff_read_own
on public.branches
for select
to authenticated
using (
  id in (
    select su.branch_id
    from public.staff_users su
    where su.user_id = auth.uid()
      and su.status = 'active'
  )
);

-- -----------------------------------------------------------------------------
-- partner_users
-- -----------------------------------------------------------------------------

create policy partner_users_read_own
on public.partner_users
for select
to authenticated
using (user_id = auth.uid());

create policy partner_admin_read_own_staff
on public.partner_users
for select
to authenticated
using (public.is_partner_admin_for_partner(partner_id));

-- -----------------------------------------------------------------------------
-- partners
-- -----------------------------------------------------------------------------

create policy partners_admin_select_all
on public.partners
for select
to authenticated
using (public.is_admin());

create policy partners_admin_update_all
on public.partners
for update
to authenticated
using (public.is_admin())
with check (public.is_admin());

create policy partners_read_own_profile
on public.partners
for select
to authenticated
using (
  id in (
    select pu.partner_id
    from public.partner_users pu
    where pu.user_id = auth.uid()
      and pu.status = 'active'
  )
);

-- -----------------------------------------------------------------------------
-- staff_users
-- -----------------------------------------------------------------------------

create policy staff_users_read_own
on public.staff_users
for select
to authenticated
using (user_id = auth.uid());

-- -----------------------------------------------------------------------------
-- partner_voucher_access
-- -----------------------------------------------------------------------------

create policy partner_voucher_access_admin_all
on public.partner_voucher_access
to authenticated
using (public.is_admin())
with check (public.is_admin());

create policy partner_voucher_access_read_own
on public.partner_voucher_access
for select
to authenticated
using (
  partner_id in (
    select pu.partner_id
    from public.partner_users pu
    where pu.user_id = auth.uid()
      and pu.status = 'active'
  )
);

-- -----------------------------------------------------------------------------
-- partner_voucher_allocations
-- -----------------------------------------------------------------------------

create policy partner_voucher_allocations_admin_all
on public.partner_voucher_allocations
to authenticated
using (public.is_admin())
with check (public.is_admin());

create policy partner_voucher_allocations_read_own
on public.partner_voucher_allocations
for select
to authenticated
using (
  partner_id in (
    select pu.partner_id
    from public.partner_users pu
    where pu.user_id = auth.uid()
      and pu.status = 'active'
  )
);

-- -----------------------------------------------------------------------------
-- voucher_templates / voucher_versions / version branches
-- -----------------------------------------------------------------------------

create policy voucher_templates_admin_all
on public.voucher_templates
to authenticated
using (public.is_admin())
with check (public.is_admin());

create policy voucher_templates_partner_read_allowed
on public.voucher_templates
for select
to authenticated
using (
  exists (
    select 1
    from public.partner_voucher_access pva
    join public.partner_users pu on pu.partner_id = pva.partner_id
    where pva.template_id = voucher_templates.id
      and pva.status = 'active'
      and pu.user_id = auth.uid()
      and pu.status = 'active'
  )
);

create policy voucher_versions_admin_all
on public.voucher_versions
to authenticated
using (public.is_admin())
with check (public.is_admin());

create policy voucher_versions_partner_read_allowed
on public.voucher_versions
for select
to authenticated
using (
  exists (
    select 1
    from public.partner_voucher_access pva
    join public.partner_users pu on pu.partner_id = pva.partner_id
    where pva.template_id = voucher_versions.template_id
      and pva.status = 'active'
      and pu.user_id = auth.uid()
      and pu.status = 'active'
  )
);

create policy voucher_version_branches_admin_all
on public.voucher_version_branches
to authenticated
using (public.is_admin())
with check (public.is_admin());

create policy voucher_version_branches_partner_read_allowed
on public.voucher_version_branches
for select
to authenticated
using (
  exists (
    select 1
    from public.voucher_versions vv
    join public.partner_voucher_access pva on pva.template_id = vv.template_id
    join public.partner_users pu on pu.partner_id = pva.partner_id
    where vv.id = voucher_version_branches.version_id
      and pva.status = 'active'
      and pu.user_id = auth.uid()
      and pu.status = 'active'
  )
);

-- -----------------------------------------------------------------------------
-- vouchers / voucher_branches / redemptions
-- -----------------------------------------------------------------------------

create policy partners_read_own_vouchers
on public.vouchers
for select
to authenticated
using (
  partner_id in (
    select pu.partner_id
    from public.partner_users pu
    where pu.user_id = auth.uid()
      and pu.status = 'active'
  )
);

create policy vouchers_admin_select_all
on public.vouchers
for select
to authenticated
using (public.is_admin());

create policy vouchers_staff_read_redeemed
on public.vouchers
for select
to authenticated
using (
  id in (
    select r.voucher_id
    from public.redemptions r
    join public.staff_users s on s.id = r.staff_user_id
    where s.user_id = auth.uid()
      and s.status = 'active'
  )
);

create policy voucher_branches_admin_select_all
on public.voucher_branches
for select
to authenticated
using (public.is_admin());

create policy redemptions_admin_select_all
on public.redemptions
for select
to authenticated
using (public.is_admin());

create policy redemptions_staff_read_own
on public.redemptions
for select
to authenticated
using (
  staff_user_id in (
    select su.id
    from public.staff_users su
    where su.user_id = auth.uid()
      and su.status = 'active'
  )
);

-- -----------------------------------------------------------------------------
-- partner claim scope
-- -----------------------------------------------------------------------------

create policy partner_claim_settings_admin_all
on public.partner_claim_settings
to authenticated
using (public.is_voucher_admin())
with check (public.is_voucher_admin());

create policy partner_claim_branches_admin_all
on public.partner_claim_branches
to authenticated
using (public.is_voucher_admin())
with check (public.is_voucher_admin());

-- -----------------------------------------------------------------------------
-- Canonicalization notes
-- -----------------------------------------------------------------------------
-- 1. These policies are customer-neutral and contain no EVO / Evolution Optical
--    or Malaysia / Kuala Lumpur assumptions.
-- 2. They preserve the verified live policy logic for the core business tables
--    and access-control dependencies included in canonical layers 001 / 001B.
-- 3. Direct write policies for Partner / Staff business mutations are intentionally
--    not invented here. Existing application flows rely heavily on RPC / Edge
--    Function server-side paths, which will be canonicalized separately.
-- 4. GRANT / REVOKE privileges remain PENDING until a privilege-aware snapshot is
--    captured. Do not assume function/table grants from this file alone.
