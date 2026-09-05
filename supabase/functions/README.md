# Commercial Voucher Edge Functions

Status: LIVE SOURCE ARCHIVED / DEPLOYMENT REHEARSAL PENDING
Date: 2026-09-05
Repository: `xiaoe-ai/voucher-commercial`
Commercial Supabase project ref: `hukihbcyyqhanaqrizvm`

This directory is the canonical home for Commercial Voucher Supabase Edge Function source.

On 2026-09-05 the Commercial Supabase Management API was connected directly and the live source inventory for project `hukihbcyyqhanaqrizvm` was verified. All nine active Commercial Edge Functions are readable from the live project and their source has been archived into this repository. No live deployment was changed during this archive pass.

## Live inventory and canonical source

### `create-partner`
- Live status: ACTIVE
- Live version: 10
- `verify_jwt=true`
- Canonical source: `supabase/functions/create-partner/index.ts`
- Live behavior uses `current_operational_realm()` and `service_provision_partner`.
- Commercial-neutral; no legacy `admin_users` or hard-coded EVO password path in the live source.

### `create-staff`
- Live status: ACTIVE
- Live version: 11
- `verify_jwt=true`
- Canonical source: `supabase/functions/create-staff/index.ts`
- Live behavior authorizes Admin or Manager via `current_operational_realm()` and provisions through `admin_provision_staff`.

### `reset-partner-password`
- Live status: ACTIVE
- Live version: 7
- `verify_jwt=true`
- Canonical source: `supabase/functions/reset-partner-password/index.ts`
- Admin authorization is based on active `partner_users.role='admin'`.
- Password material is not written to audit logs.

### `manage-partner-staff`
- Live status: ACTIVE
- Live version: 7
- `verify_jwt=true`
- Canonical source: `supabase/functions/manage-partner-staff/index.ts`
- Partner Admin is scoped to its own `partner_id` before Staff create/rename/reset/suspend/activate/remove operations.

### `admin-set-partner-staff-limit`
- Live status: ACTIVE
- Live version: 6
- `verify_jwt=true`
- Canonical source: `supabase/functions/admin-set-partner-staff-limit/index.ts`
- Admin-only Staff-limit update with audit entry.

### `voucher-engine-admin`
- Live status: ACTIVE
- Live version: 9
- `verify_jwt=true`
- Canonical source: `supabase/functions/voucher-engine-admin/index.ts`
- Supports Admin template/version/allocation/revoke/retire operations through service RPCs.

### `bootstrap-admin`
- Live status: ACTIVE
- Live version: 5
- `verify_jwt=false`
- Canonical source: `supabase/functions/bootstrap-admin/index.ts`
- Custom one-time setup gate is enforced by `admin_bootstrap_status` and `service_bootstrap_first_admin`.

### `voucher-engine`
- Live status: ACTIVE
- Live version: 5
- `verify_jwt=true`
- Canonical source: `supabase/functions/voucher-engine/index.ts`
- Admin-only wrapper for allocate / allocate_all / revoke_unissued / retire_version.

### `xiaoe-voucher-bridge`
- Live status: ACTIVE
- Live version: 4
- `verify_jwt=false`
- Canonical source: `supabase/functions/xiaoe-voucher-bridge/index.ts`
- Canonical file was aligned to the verified live v4 source.
- Hard-coded project identity is only Commercial project ref `hukihbcyyqhanaqrizvm`.
- Dedicated secret name: `XIAOE_VOUCHER_COMMERCIAL_BRIDGE_TOKEN`.
- Supported actions: `health`, `read`, `insert`, `update`, `upsert`, `delete`, `rpc`.
- Full-table delete is blocked; update/delete require filters.

## Canonicalization rules

- Live Commercial source is the primary source of truth for this archive pass.
- Secret values are never committed; only environment variable names may appear in source.
- No EVO Production / Stage / Daughter source is treated as canonical for Commercial.
- Historical EVO/Stage code may be used only as read-only reference when diagnosing differences.

## Recovery status

PASS:
- live Edge Function inventory readable from Commercial Supabase Management API
- all nine live source files archived in GitHub
- `verify_jwt` settings captured
- Commercial bridge source aligned to live v4
- secret values not committed

PENDING:
- deploy these archived sources into an isolated recovery target
- restore required environment secret names in the isolated target
- verify Admin / Partner / Staff authorization after deployment
- run Admin -> Partner -> Staff -> issue -> verify -> redeem recovery flow
- verify XiaoE bridge health/read against the rebuilt target

Do not mark the full application recovery gate PASS until the isolated Edge Function deployment and post-recovery E2E checks pass.
