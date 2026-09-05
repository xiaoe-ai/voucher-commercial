# Commercial Backend Dependency Manifest V1

Status: ACTIVE CANONICAL
Date: 2026-09-05
Repository: `xiaoe-ai/voucher-commercial`
Commercial Supabase project ref: `hukihbcyyqhanaqrizvm`

## Purpose

This manifest records the backend surface required by the current Commercial Voucher Admin, Partner, Staff and Voucher Engine portals. It is the minimum dependency checklist for backend canonicalization, rebuild and release verification.

## Runtime tables observed from current portals

- `company_profile`
- `partners`
- `partner_users`
- `branches`
- `vouchers`
- `voucher_branches`
- `voucher_templates`
- `voucher_versions`
- `voucher_version_branches`
- `partner_voucher_allocations`
- `redemptions`

All table schema, constraints, indexes, grants and RLS policies required by these surfaces must be captured into canonical migrations before `COMMERCIAL_READY`.

## RPC / database functions observed

### Admin / Voucher Engine
- `is_voucher_admin`
- `admin_get_partner_claim_access`
- `admin_set_partner_claim_access`
- `admin_create_voucher_template_theme`
- `admin_publish_voucher_version_theme`

### Partner
- `get_my_partner_dashboard`
- `get_my_partner_claim_access`
- `partner_staff_capacity`
- `partner_set_staff_access`
- `create_partner_multi_voucher_controlled`

### Staff / Redemption
- `verify_voucher`
- `redeem_voucher`

All function definitions, ownership, SECURITY DEFINER settings, search_path settings, grants and caller authorization rules must be canonicalized.

## Edge Functions observed

- `create-partner`
- `create-staff`
- `reset-partner-password`
- `admin-set-partner-staff-limit`
- `manage-partner-staff`
- `voucher-engine-admin`
- `xiaoe-voucher-bridge`

For every Edge Function, canonical source must include:
- source code
- entrypoint
- JWT verification setting
- required secret names only
- caller authorization behavior
- deployment order

Never commit secret values.

## Authentication / authorization model observed

### Admin
- Supabase Auth session
- Admin role resolved from `partner_users` and/or `is_voucher_admin`

### Partner
- Supabase Auth session
- Partner role and dashboard resolved by `get_my_partner_dashboard`
- Partner staff permissions constrained by partner staff access controls and allocation scope

### Staff
- Supabase Auth session
- Branch-restricted voucher verification and redemption
- Redemption controlled by `verify_voucher` and `redeem_voucher`

## Rebuild order

1. Base extensions / enums if any
2. Core tables and foreign keys
3. Indexes / constraints
4. RLS enablement
5. RLS policies / grants
6. RPC / database functions
7. Seed-free default system records required by application logic
8. Edge Functions
9. Required secret names configured outside source control
10. Admin bootstrap
11. Company Profile setup
12. E2E Admin -> Partner -> Staff -> issue -> redeem verification

## Release blockers discovered during dependency extraction

### 1. Partner Portal contains customer-specific outlet data

Current `partner.html` contains hard-coded outlet names, addresses and phone numbers belonging to the EVO / Evolution Optical operating footprint, including The Mines, Damai Perdana, Bangi, Bahau, Semenyih Vista Valley, Semenyih Eco Taipan and Pertama Complex.

This violates Commercial white-label requirements.

Required fix:
- remove all customer-specific outlet constants from canonical frontend code
- load redemption locations from Commercial Supabase application data
- if address / phone fields are required, add them to canonical branch/location schema rather than keeping frontend constants

### 2. Staff Portal contains EVO-style voucher placeholder

Current `staff.html` includes the user-visible placeholder `EO-20260808-XXXXXXX`.

Required fix:
- replace with generic placeholder such as `VCH-20260905-XXXXXXX` or `Enter voucher code`
- voucher code generation rules must be customer-neutral unless explicitly configured by customer data

## Canonicalization completion criteria

Backend canonicalization is complete only when:
- every dependency in this manifest exists in canonical source
- an isolated blank target can be rebuilt without copying EVO Production state
- Admin / Partner / Staff authorization is verified
- issue -> QR -> verify -> redeem passes end to end
- cross-role and cross-project negative tests are rejected
- Commercial bridge health/read passes after rebuild

## Relationship to Issue #1

This manifest is the implementation checklist for GitHub Issue #1: `Pre-launch blocker: canonicalize Commercial backend schema, RLS and Edge Functions`.
