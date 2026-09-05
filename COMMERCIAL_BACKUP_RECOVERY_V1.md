# Commercial Voucher Backup & Recovery V1

Status: ACTIVE CANONICAL
Date: 2026-09-05
Commercial Supabase project ref: `hukihbcyyqhanaqrizvm`
Repository: `xiaoe-ai/voucher-commercial`

## Purpose

This procedure defines the minimum backup, restore and recovery controls required before Commercial Voucher is marked `COMMERCIAL_READY` or used by a paying customer.

Commercial must be recoverable without copying EVO Production or Voucher Stage state.

## Backup scope

A valid Commercial backup set must cover:

1. Database schema
   - tables
   - constraints
   - indexes
   - enums/extensions if used
   - RLS enablement and policies
   - grants
   - RPC/database functions

2. Business data
   - company_profile
   - partners
   - partner_users
   - branches
   - voucher templates and versions
   - partner allocations
   - vouchers
   - voucher branch scope
   - redemptions
   - other Commercial-only business tables discovered during canonicalization

3. Application source
   - GitHub main branch commit SHA
   - canonical migrations
   - Edge Function source
   - release gate / route lock / backend dependency manifest

4. Runtime configuration inventory
   - required secret NAMES only
   - project ref
   - Edge Function names and verify_jwt settings
   - migration channel configuration

Never store secret VALUES in GitHub backup documentation.

## When a backup checkpoint is required

Create or confirm a recoverable checkpoint before:

- first paying customer onboarding
- applying a schema migration to Commercial live DB
- changing RLS or role authorization
- replacing or deleting Edge Functions
- major voucher engine changes
- bulk imports or data repair
- release marked `COMMERCIAL_READY`

## Backup naming convention

Recommended logical label:

`commercial-voucher-YYYYMMDD-HHMM-<git-short-sha>`

The backup record must include:
- UTC timestamp
- Commercial project ref `hukihbcyyqhanaqrizvm`
- Git commit SHA
- migration head / latest canonical migration filename
- operator
- reason for checkpoint
- backup method
- restore target used for rehearsal, if any

## Recovery order

1. Freeze writes to affected Commercial environment if data integrity is in doubt.
2. Confirm incident is Commercial only; do not touch EVO Production / Stage / Daughter.
3. Record current Git commit and database state before repair.
4. Restore schema to an isolated Commercial recovery target first whenever possible.
5. Restore data.
6. Deploy RPC/database functions.
7. Deploy Edge Functions.
8. Configure required secrets outside source control.
9. Bootstrap authorized Admin only if required.
10. Run Commercial bridge health/read.
11. Run Admin -> Partner -> Staff authorization checks.
12. Run issue -> verify -> redeem E2E test using test data only.
13. Compare critical row counts / business totals with backup record.
14. Only after validation, approve production cutover or live repair.

## Restore rehearsal requirement

Before `COMMERCIAL_READY`, run at least one restore rehearsal into an isolated target.

Minimum PASS evidence:
- blank isolated target used
- canonical migrations applied successfully
- required RPCs/functions available
- required Edge Functions deployed
- test Admin login succeeds
- test Partner flow succeeds
- test Staff verify/redeem succeeds
- Commercial route does not fall back to EVO Production or Stage
- no customer-specific EVO seed data appears

## Live recovery safety rules

- Do not restore over live Commercial merely to test recovery.
- Do not point Commercial recovery at EVO Production or Stage.
- Do not use Production customer data as Commercial seed data.
- Do not disable RLS as a shortcut during recovery.
- Do not commit service-role keys, database passwords or runtime tokens.
- Use transaction / dry-run controls for repair SQL where supported.
- If two recovery attempts fail, stop and inspect before further mutation.

## Data integrity checks after restore

At minimum compare:
- partner count
- active partner_users count
- branch count
- voucher template/version counts
- active voucher count by status
- redemption count
- allocation balances where applicable
- company_profile presence

Also validate:
- no duplicate primary/business keys
- no orphan branch/voucher relations
- no cross-partner authorization leakage
- no ability for Staff to redeem outside authorized branch scope

## Relationship to canonical files

This procedure must be used together with:
- `COMMERCIAL_BACKEND_DEPENDENCY_MANIFEST_V1.md`
- `COMMERCIAL_MIGRATION_CHANNEL_V1.md`
- `COMMERCIAL_ROUTE_LOCK.json`
- `COMMERCIAL_RELEASE_GATE_V1.md`

## Release status rule

Documentation of this procedure satisfies the release-gate requirement to document backup/recovery procedure.

It does NOT satisfy the restore rehearsal requirement. That remains PENDING until an actual isolated restore is completed with evidence.
