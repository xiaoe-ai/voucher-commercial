# Commercial Voucher Edge Functions

Status: CANONICALIZATION IN PROGRESS
Date: 2026-09-05
Repository: `xiaoe-ai/voucher-commercial`
Commercial Supabase project ref: `hukihbcyyqhanaqrizvm`

This directory is the canonical home for Commercial Voucher Supabase Edge Function source.

The live Commercial application depends on the functions listed below. Do not mark Commercial backend as fully rebuildable until every required function has canonical source, deployment settings, required secret names and authorization behavior captured and tested here.

## Required functions

### `create-partner`
Purpose:
- provision a Partner account / access path used by Commercial Admin

Required canonical evidence:
- `supabase/functions/create-partner/index.ts`
- JWT verification setting
- required secret names only
- caller authorization checks
- expected request / response contract

Status: SOURCE REVIEW IN PROGRESS
Notes:
- EVO reference source exists, but it is not safe to copy directly because it uses legacy `admin_users` authorization and a hard-coded `EVO12345678` initial password.
- Commercial canonical provisioning RPC equivalence must be verified before this function is written.

### `create-staff`
Purpose:
- provision Staff access used by the Staff portal

Required canonical evidence:
- `supabase/functions/create-staff/index.ts`
- JWT verification setting
- required secret names only
- caller authorization checks
- relationship with `staff_users`

Status: SOURCE REVIEW IN PROGRESS
Notes:
- EVO reference source uses `current_operational_realm` and `admin_provision_staff`; Commercial canonical equivalence still needs verification.

### `reset-partner-password`
Purpose:
- privileged Partner password reset flow used by Admin tooling

Status: SOURCE REVIEW IN PROGRESS
Notes:
- EVO reference source uses legacy `admin_users`; Commercial authorization must be mapped to canonical `partner_users` / Admin role semantics before canonicalization.

### `admin-set-partner-staff-limit`
Purpose:
- Admin-controlled Partner Staff capacity / limits

Status: SOURCE REVIEW IN PROGRESS

### `manage-partner-staff`
Purpose:
- Partner Admin Staff management flow
- current Partner portal invokes this function for create / rename / password reset / status / removal operations

Required canonical evidence:
- action allow-list
- authorization checks proving caller belongs to the correct Partner
- service-role usage, if any, isolated inside the Edge Function
- no cross-partner mutation path

Status: SOURCE REVIEW IN PROGRESS
Notes:
- EVO reference source has strong same-partner scoping and is useful as a design reference, but its RPC dependencies still need Commercial canonical verification.

### `voucher-engine-admin`
Purpose:
- privileged Voucher Engine administration

Required canonical evidence:
- supported action allow-list
- Admin authorization
- database mutation boundaries
- request / response contract

Status: SOURCE MISSING / EXTRACTION REQUIRED

### `xiaoe-voucher-bridge`
Purpose:
- Commercial runtime management bridge used by XiaoE external orchestration

Required canonical evidence:
- Commercial-only target lock
- accepted operation allow-list
- bridge-token authentication behavior
- no Production / Stage / Daughter fallback
- required secret names only

Status: CANONICAL SOURCE PRESENT / NOT YET DEPLOYED
Canonical source:
- `supabase/functions/xiaoe-voucher-bridge/index.ts`
- commit `f9dc976d0f6b39834278abf9d93d9cbf9faea1b9`
Verified design:
- hard-locks `target=commercial`
- hard-locks project ref `hukihbcyyqhanaqrizvm`
- accepts `health`, `read`, `insert`, `update`, `upsert`, `delete`, `rpc`
- authenticates with dedicated Commercial bridge token header `x-xiaoe-bridge-token`
- uses only `SUPABASE_URL`, `SUPABASE_SERVICE_ROLE_KEY`, and the dedicated Commercial bridge-token env name(s)
- contains no EVO Production / Stage / Daughter fallback

## Source extraction rule

Do not fabricate live-equivalent source from frontend assumptions alone.

Acceptable ways to canonicalize a function:
1. extract verified live source from the Commercial Supabase project, or
2. rebuild the function from a reviewed specification and then deploy / test it in an isolated Commercial target before treating it as equivalent.

Reference code from EVO Production or Voucher Stage may be inspected read-only, but it must not be copied blindly. Any imported logic must be made Commercial-neutral and verified against the Commercial dependency manifest.

## Minimum release gate

Before `COMMERCIAL_READY`:
- every required function above has canonical source in this directory
- deployment configuration is documented
- secret VALUES are not committed
- Admin / Partner / Staff authorization tests pass
- XiaoE bridge health/read passes against the rebuilt target
- no cross-project fallback exists
