-- Commercial Voucher neutralization Phase 2G-B
-- Scope:
--   1) system_integrity_health_check(): replace old fixed 3-month/KL validity assumption
--      with voucher-version-aware validity checks.
--   2) pg_cron job name: evolution_integrity_health_hourly -> commercial_integrity_health_hourly
-- Preserve monitor function, schedule, command and alert behavior.

create or replace function public.system_integrity_health_check()
returns jsonb
language sql
security definer
set search_path to 'public'
as $$
with c as (
  select
    (select count(*) from public.vouchers v left join public.partners p on p.id=v.partner_id where p.id is null) as orphan_vouchers_partner,
    (select count(*) from public.redemptions r left join public.vouchers v on v.id=r.voucher_id where v.id is null) as orphan_redemptions_voucher,
    (select count(*) from public.redemptions r left join public.branches b on b.id=r.branch_id where b.id is null) as orphan_redemptions_branch,
    (select count(*) from public.redemptions r left join public.staff_users s on s.id=r.staff_user_id where s.id is null) as orphan_redemptions_staff,
    (select count(*) from public.voucher_branches vb left join public.vouchers v on v.id=vb.voucher_id where v.id is null) as orphan_voucher_branches_voucher,
    (select count(*) from public.voucher_branches vb left join public.branches b on b.id=vb.branch_id where b.id is null) as orphan_voucher_branches_branch,
    (select count(*) from public.partner_users pu left join public.partners p on p.id=pu.partner_id where pu.partner_id is not null and p.id is null) as orphan_partner_users,
    (select count(*) from public.partner_claim_settings pcs left join public.partners p on p.id=pcs.partner_id where p.id is null) as orphan_claim_settings,
    (select count(*) from public.partner_claim_branches pcb left join public.partners p on p.id=pcb.partner_id where p.id is null) as orphan_claim_branches_partner,
    (select count(*) from public.partner_claim_branches pcb left join public.branches b on b.id=pcb.branch_id where b.id is null) as orphan_claim_branches_branch,
    (select count(*) from public.vouchers where lower(coalesce(status,''))='redeemed' and redeemed_at is null) as redeemed_missing_time,
    (select count(*) from public.vouchers where lower(coalesce(status,''))<>'redeemed' and redeemed_at is not null) as nonredeemed_has_time,
    (select count(*) from public.redemptions r join public.vouchers v on v.id=r.voucher_id where lower(coalesce(v.status,''))<>'redeemed') as redemption_status_mismatch,
    (select count(*) from public.vouchers where expiry_date is null) as missing_expiry,
    (select count(*) from public.vouchers where activated_at is null) as missing_activation,
    (select count(*) from public.partners p where p.vouchers_issued<>(select count(*) from public.vouchers v where v.partner_id=p.id)) as quota_counter_mismatch_partners,
    (
      select count(*)
      from public.vouchers v
      join public.voucher_versions vv on vv.id=v.version_id
      where lower(coalesce(v.status,''))='valid'
        and v.activated_at is not null
        and v.expiry_date is not null
        and v.expiry_date is distinct from (
          case
            when coalesce(
              vv.validity_mode,
              vv.validity_mode_v2,
              case lower(coalesce(vv.validity_type,''))
                when 'fixed' then 'fixed'
                else 'days_after_issue'
              end
            )='fixed'
              then vv.valid_until
            when coalesce(
              vv.validity_mode,
              vv.validity_mode_v2,
              case lower(coalesce(vv.validity_type,''))
                when 'fixed' then 'fixed'
                else 'days_after_issue'
              end
            )='calendar_months_after_issue'
              and coalesce(vv.valid_months,0)>0
              then (v.activated_at::date + make_interval(months=>vv.valid_months))::date
            when coalesce(vv.valid_days,0)>0
              then v.activated_at::date + vv.valid_days
            else v.expiry_date
          end
        )
    ) as active_validity_mismatch,
    (select count(*) from (select voucher_id,count(*) from public.redemptions group by voucher_id having count(*)>1) x) as duplicate_redemption_vouchers
)
select jsonb_build_object(
  'healthy',
    orphan_vouchers_partner=0 and orphan_redemptions_voucher=0 and orphan_redemptions_branch=0 and orphan_redemptions_staff=0 and
    orphan_voucher_branches_voucher=0 and orphan_voucher_branches_branch=0 and orphan_partner_users=0 and orphan_claim_settings=0 and
    orphan_claim_branches_partner=0 and orphan_claim_branches_branch=0 and redeemed_missing_time=0 and nonredeemed_has_time=0 and
    redemption_status_mismatch=0 and missing_expiry=0 and missing_activation=0 and quota_counter_mismatch_partners=0 and
    active_validity_mismatch=0 and duplicate_redemption_vouchers=0,
  'checked_at',now(),
  'checks',to_jsonb(c)
) from c;
$$;

do $$
declare
  v_old_job_id bigint;
  v_new_job_id bigint;
begin
  select jobid into v_old_job_id
  from cron.job
  where jobname='evolution_integrity_health_hourly'
  order by jobid
  limit 1;

  if v_old_job_id is not null then
    perform cron.unschedule(v_old_job_id);
  end if;

  select jobid into v_new_job_id
  from cron.job
  where jobname='commercial_integrity_health_hourly'
  order by jobid
  limit 1;

  if v_new_job_id is null then
    perform cron.schedule(
      'commercial_integrity_health_hourly',
      '7 * * * *',
      'select public.run_system_integrity_monitor();'
    );
  else
    perform cron.alter_job(
      v_new_job_id,
      schedule => '7 * * * *',
      command => 'select public.run_system_integrity_monitor();',
      active => true
    );
  end if;
end $$;
