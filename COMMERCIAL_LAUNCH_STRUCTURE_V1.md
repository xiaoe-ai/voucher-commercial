# Commercial Voucher Launch Structure V1

Status: ACTIVE CANONICAL
Date: 2026-09-05
Repository: `xiaoe-ai/voucher-commercial`
Supabase project ref: `hukihbcyyqhanaqrizvm`

## Objective

Commercial Voucher is the generic, white-label commercial product derived from the proven EVO Voucher operating model, but it must not depend on Evolution Optical branding, customer-specific routes, or EVO production data.

The product is considered commercially launchable only when all eight layers below are present and release-gated.

## Layer 1 — Company Profile / White Label

Purpose: allow each customer to configure its own company identity without code changes.

Canonical components:
- `company-setup.html`
- `commercial-brand.js`
- Supabase `company_profile`

Required behavior:
- Customer can enter company name, legal name, registration number, tagline, phone, website and logo URL.
- Cloud profile is preferred; local fallback may be used only for continuity.
- No EVO / Evolution Optical branding may be hard-coded into user-facing content, exports, filenames or routes.

## Layer 2 — Authentication & Roles

Roles:
- Admin
- Partner
- Staff

Requirements:
- Supabase Auth session required for protected operations.
- Role authorization must be checked after login, not inferred only from the page URL.
- Admin can manage company profile, partners, staff, voucher engine, reporting and settings.
- Partner is restricted to its allocated voucher scope and permitted staff.
- Staff is restricted to assigned branch / redemption scope.

## Layer 3 — Admin Portal

Canonical entry: `admin.html`

Minimum production capabilities:
- Sign in / sign out
- Dashboard
- Partner management
- Staff management
- Voucher allocation / issue / revoke controls
- Branch management
- Voucher search and filters
- Reporting and export
- Company settings link
- Safe refresh / recover behavior

## Layer 4 — Partner Portal

Canonical entry: `partner.html`

Minimum production capabilities:
- Partner authentication
- Partner profile and status
- Voucher balances
- Voucher issue workflow
- Approved voucher presentation / QR
- Staff management within authorized scope
- Activity / redemption visibility where permitted

## Layer 5 — Staff Portal

Canonical entry: `staff.html`

Minimum production capabilities:
- Staff authentication
- Assigned partner / branch identity
- Voucher lookup / QR scan
- Redemption validation
- Redeem action
- Redemption history
- Manager-only controls where explicitly authorized

## Layer 6 — Voucher Engine & Data

Commercial Supabase is the sole runtime data authority for Commercial Voucher.

Project lock: `hukihbcyyqhanaqrizvm`

Data capabilities expected from the EVO-proven model:
- partners
- staff / staff profiles
- branches
- voucher templates
- voucher versions
- voucher allocations
- voucher instances / issued vouchers
- redemption records
- company profile
- audit-safe role policies

Rules:
- No cross-project fallback to EVO Production or Voucher Stage.
- No customer-specific seed data in canonical Commercial release.
- RLS / authorization must enforce tenant and role boundaries.

## Layer 7 — Commercial Main Channel

Commercial Voucher has one logical management route with two isolated modes.

### Runtime mode

`XiaoE -> commercial-invoke-gateway -> external-supabase-bridge -> xiaoe-voucher-bridge -> Commercial DB`

Allowed actions:
- health
- read
- insert
- update
- upsert
- delete
- rpc

### Migration mode

`GitHub manual workflow -> Supabase Session Pooler -> Commercial PostgreSQL`

Canonical workflow:
- `.github/workflows/commercial-migration-channel.yml`

Safety requirements:
- exact migration path under `supabase/migrations/`
- dry-run first
- transactional rollback validation
- explicit confirmation before apply
- commit only if every SQL statement succeeds
- Commercial project ref hard lock

Runtime credentials and migration credentials remain separate even though they belong to one logical Commercial Main Channel.

## Layer 8 — Release / Recovery / Commercial Operations

A release is commercially launchable only when the release gate passes.

Required release checks:
1. GitHub `main` is the canonical source.
2. Public route loads Admin / Partner / Staff / Company Setup.
3. Company Profile can be configured without code changes.
4. Admin authentication works.
5. Partner authentication and voucher issue workflow work.
6. Staff authentication and voucher redemption workflow work.
7. Voucher read/write is isolated to Commercial Supabase.
8. Export/reporting contains no EVO branding.
9. Commercial bridge health returns healthy.
10. Migration dry-run path is available.
11. Backup / recovery procedure is documented and tested before production customer onboarding.
12. No Production / Stage / Daughter project refs are accepted by Commercial routing.

## Commercialization rule

Commercial Voucher must be treated as a product, not as a renamed EVO deployment.

New customers configure their identity through Company Profile. Customer-specific branding, company names, logos, partner data, staff data and issued vouchers live in customer-controlled application data, not in the canonical source code.

## Current known cleanup item

At the time this canonical structure was created, one legacy export filename was observed in `admin.html` using `evolution-vouchers-<date>.xlsx`. This must be changed to a generic Commercial/customer-derived export filename before the release gate can be marked PASS.

## Canonical routing references

- `COMMERCIAL_ROUTE_LOCK.json`
- `COMMERCIAL_MIGRATION_CHANNEL_V1.md`
- `README.txt`

## Operating rule

For future work, XiaoE should resolve all Commercial Voucher tasks against this launch structure before making changes. EVO Voucher remains a reference implementation only; Commercial Voucher must remain independent and white-label.
