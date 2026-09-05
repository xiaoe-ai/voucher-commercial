# Commercial Voucher Schema / RLS / RPC Inventory V1

Status: CANONICAL INVENTORY / EXTRACTION PENDING
Date: 2026-09-05
Repository: `xiaoe-ai/voucher-commercial`
Commercial Supabase project ref: `hukihbcyyqhanaqrizvm`

This file defines the minimum database surface that must exist in canonical source before Commercial Voucher is considered rebuildable.

## Required tables

The current portals reference at least these tables:

- `company_profile`
- `partners`
- `partner_users`
- `staff_users`
- `branches`
- `vouchers`
- `voucher_branches`
- `voucher_templates`
- `voucher_versions`
- `voucher_version_branches`
- `partner_voucher_allocations`
- `redemptions`

For each table, canonical migrations must capture:
- columns and types
- primary keys
- unique/business keys
- foreign keys
- check constraints
- indexes
- default values
- generated columns / triggers, if any
- RLS enabled/disabled state
- grants
- seed-free required defaults only

## Required RPC / database functions

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

For each RPC, canonical source must capture:
- exact signature and argument types
- return type
- language
- volatility / parallel settings where relevant
- SECURITY DEFINER / INVOKER
- explicit `search_path` where required
- owner
- execute grants
- authorization checks
- cross-partner / cross-branch protections
- transaction expectations

## Required RLS verification areas

Canonicalization is incomplete until policies / grants for these access boundaries are represented and tested:

### Company Profile
- unauthorized users cannot rewrite another customer's company profile
- authorized Commercial Admin can manage the active Commercial company profile

### Partners / partner_users
- Partner users cannot access another Partner's private records
- Partner Staff cannot escalate to Partner Admin
- Admin operations are explicit and server-authorized

### staff_users / branches
- Staff identity is tied to allowed branch scope
- Staff cannot self-assign another branch
- Staff cannot read/write another Staff identity outside permitted scope

### Voucher Engine
- Partner can issue only against its valid allocation
- Partner cannot alter template/version/admin configuration directly
- quantity and allocation enforcement must occur server-side

### Redemption
- Staff can verify/redeem only through authorized server-side paths
- branch scope must be enforced
- already-redeemed / expired / revoked vouchers must be rejected
- redemption history must not leak cross-partner/customer data

## Canonical extraction rule

Do not invent live-equivalent schemas, policies or RPC definitions from frontend assumptions alone.

Acceptable paths:
1. extract verified definitions from the Commercial Supabase project, or
2. reconstruct from a reviewed specification and validate in an isolated Commercial target.

EVO Production / Voucher Stage may only be used as read-only reference. Their customer-specific data, routes, secrets and assumptions must not be copied into Commercial.

## Current canonical coverage

Present in GitHub migrations:
- `20260905053000_company_profile.sql`
- `20260905081500_branch_contact_fields.sql`

Known gap:
- the business schema for Partner / Staff / Voucher / Redemption is not yet fully represented
- RLS policies are not yet fully represented
- RPC definitions are not yet fully represented

## Completion evidence required

Before `COMMERCIAL_READY`:
- every required table exists in canonical migrations
- every required RPC exists in canonical migrations
- RLS and grants are represented in source
- isolated blank rebuild succeeds
- Admin / Partner / Staff positive tests pass
- cross-role / cross-partner / cross-branch negative tests fail as expected
- issue -> verify -> redeem passes end-to-end
- Commercial bridge health/read succeeds after rebuild
