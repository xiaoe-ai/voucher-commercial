# Commercial Voucher Edge Functions

Status: CANONICAL INVENTORY / SOURCE EXTRACTION PENDING
Date: 2026-09-05
Repository: `xiaoe-ai/voucher-commercial`
Commercial Supabase project ref: `hukihbcyyqhanaqrizvm`

This directory is the canonical home for Commercial Voucher Supabase Edge Function source.

The live Commercial application depends on the functions listed below, but their verified source is not yet present in this repository. Do not mark Commercial backend as rebuildable until each function has a source directory, deployment settings, required secret names and authorization behavior captured here.

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

Status: SOURCE MISSING / EXTRACTION REQUIRED

### `create-staff`
Purpose:
- provision Staff access used by the Staff portal

Required canonical evidence:
- `supabase/functions/create-staff/index.ts`
- JWT verification setting
- required secret names only
- caller authorization checks
- relationship with `staff_users`

Status: SOURCE MISSING / EXTRACTION REQUIRED

### `reset-partner-password`
Purpose:
- privileged Partner password reset flow used by Admin tooling

Status: SOURCE MISSING / EXTRACTION REQUIRED

### `admin-set-partner-staff-limit`
Purpose:
- Admin-controlled Partner Staff capacity / limits

Status: SOURCE MISSING / EXTRACTION REQUIRED

### `manage-partner-staff`
Purpose:
- Partner Admin Staff management flow
- current Partner portal invokes this function for create / rename / password reset / status / removal operations

Required canonical evidence:
- action allow-list
- authorization checks proving caller belongs to the correct Partner
- service-role usage, if any, isolated inside the Edge Function
- no cross-partner mutation path

Status: SOURCE MISSING / EXTRACTION REQUIRED

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

Status: SOURCE MISSING / EXTRACTION REQUIRED

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
