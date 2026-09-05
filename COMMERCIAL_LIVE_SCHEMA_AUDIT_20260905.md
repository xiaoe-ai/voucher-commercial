# Commercial Live Schema Audit — 2026-09-05

Status: VERIFIED SNAPSHOT / NOT YET CANONICAL
Repository: `xiaoe-ai/voucher-commercial`
Commercial Supabase project ref: `hukihbcyyqhanaqrizvm`
Source workflow run: `Commercial Schema Snapshot V1` run `33956255698`
Snapshot artifact: `commercial-schema-snapshot-33956255698`
Snapshot SHA256: `fc5a7f778b8e28eb19c14fea9fe553ca0cd34fb166db84f0230769300ab71682`

## Snapshot facts

The read-only live snapshot completed successfully with PostgreSQL 17 tooling.

Verified live public database surface:
- 25 public tables
- 82 public functions / RPC definitions in the inventory
- 74 public RLS policies
- all 25 public base tables currently have Row Level Security enabled

No business row data was exported. No secret values were included in the artifact.

## Live public tables discovered

- `admin_audit_log`
- `admin_bootstrap_config`
- `branches`
- `company_profile`
- `frontend_deployment_manifest`
- `frontend_deployment_observed`
- `partner_claim_branches`
- `partner_claim_settings`
- `partner_users`
- `partner_voucher_access`
- `partner_voucher_allocations`
- `partners`
- `redemptions`
- `staff_users`
- `system_health_alerts`
- `system_health_check_runs`
- `system_recovery_manifest`
- `voucher_allocation_branches`
- `voucher_allocation_events`
- `voucher_branches`
- `voucher_rules`
- `voucher_templates`
- `voucher_version_branches`
- `voucher_versions`
- `vouchers`

This is broader than the earlier dependency manifest. The additional operational / recovery / deployment tables must be assessed before a blank rebuild is considered complete.

## Important finding: live Commercial backend still contains EVO / Evolution-specific logic

The live schema snapshot contains customer-specific / legacy identifiers and behavior that must NOT be copied blindly into canonical Commercial migrations.

Verified residual examples include:

- voucher template code `EVO-FREE-GLASSES`
- user-facing share text containing `Evolution Optical Voucher`
- bootstrap display name `Evolution Optical Admin`
- recovery manifest key `evolution_voucher_system`
- health cron job name `evolution_integrity_health_hourly`
- advisory lock key `evolution_voucher:first_admin_bootstrap`

These are backend-level residuals, not only frontend labels.

## Consequence

The live snapshot is evidence of current operating state, but it is NOT yet the desired Commercial-neutral canonical source.

Do not copy `commercial-public-schema.sql` wholesale into `supabase/migrations/` and call it complete.

Canonicalization must instead:
1. preserve required schema / RLS / RPC behavior,
2. remove EVO / Evolution customer identity assumptions,
3. replace customer-specific bootstrap defaults with generic Commercial defaults,
4. replace hard-coded voucher template assumptions with configurable application data,
5. neutralize recovery / monitoring identifiers,
6. verify authorization behavior remains correct,
7. rebuild and test in an isolated Commercial target before changing live production behavior.

## RPC coverage

The live function inventory includes the known application-critical RPCs, including:
- `is_voucher_admin`
- `admin_get_partner_claim_access`
- `admin_set_partner_claim_access`
- `admin_create_voucher_template_theme`
- `admin_publish_voucher_version_theme`
- `get_my_partner_dashboard`
- `get_my_partner_claim_access`
- `partner_staff_capacity`
- `partner_set_staff_access`
- `create_partner_multi_voucher_controlled`
- `verify_voucher`
- `redeem_voucher`

It also contains additional operational and service-layer functions such as admin engine, provisioning, health, recovery and compatibility functions. These must be classified into:
- canonical required
- compatibility temporary
- legacy removable

## RLS status

Every discovered public base table has RLS enabled in the live snapshot.

This is positive evidence, but RLS enablement alone is not sufficient. Policy definitions and grants still require canonical review and negative authorization testing.

## Safe next step

Create a Commercial-neutral canonical migration set from the verified snapshot in layers:

1. core tables / constraints / indexes
2. RLS enablement and policies
3. essential RPCs
4. operational / health / recovery support
5. compatibility cleanup
6. isolated rebuild
7. E2E Admin -> Partner -> Staff -> issue -> verify -> redeem
8. only then consider live migration

## Release impact

Commercial Voucher remains `PRE-LAUNCH / GATED`.

This audit resolves uncertainty about the live backend surface, but it also confirms a new launch blocker: EVO/Evolution-specific backend logic must be removed or converted to configurable Commercial behavior before `COMMERCIAL_READY`.
