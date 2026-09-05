# Commercial Voucher Release Gate V1

Status: PRE-LAUNCH / GATED
Date: 2026-09-05

This file is the canonical launch checklist for Commercial Voucher. A release is `COMMERCIAL_READY` only when every required item is PASS.

## A. Product identity
- [PASS] Canonical repository is `xiaoe-ai/voucher-commercial`.
- [PASS] Canonical Supabase project ref is `hukihbcyyqhanaqrizvm`.
- [PASS] Product is defined as generic white-label Commercial Voucher.
- [PASS] Company Profile layer exists (`company-setup.html`, `commercial-brand.js`).
- [PASS] User-visible Excel export naming is guarded by the white-label runtime and derives from the latest customer company name rather than EVO/Evolution branding, including company-name changes made during the same browser session.
- [PASS] Final current-runtime legacy audit passed after source neutralization. Historical migrations/workflows remain preserved as evidence and are not treated as active runtime branding.

## B. Customer onboarding
- [PASS] Customer can set company name and basic company details without source-code edits.
- [PASS] Company profile supports cloud sync with local continuity fallback.
- [PASS] Admin / Partner / Staff install entry pages and launch splash screens are wired to Company Profile so role entry surfaces display the customer company name rather than a fixed Commercial/EVO brand.
- [PASS] First-customer Admin bootstrap was verified from the isolated canonical rebuild: bootstrap state starts disabled, a test setup code can enable first-admin creation, the first call creates an active Admin membership and consumes the setup code, and a second bootstrap attempt is rejected.
- [PENDING] Verify logo and brand propagation across Admin / Partner / Staff / voucher presentation on actual runtime/device surfaces.

## C. Authentication and roles
- [PASS] Admin page contains Supabase Auth login and explicit Admin role check.
- [PENDING] End-to-end Admin login test on current Commercial Supabase.
- [PENDING] End-to-end Partner login and authorization test.
- [PENDING] End-to-end Staff login and branch-scope authorization test.
- [PENDING] Confirm RLS / role policies reject cross-role and unauthorized direct writes.

## D. Business workflow
- [PENDING] Admin: create Partner -> allocate Voucher Type -> create Staff.
- [PENDING] Partner: issue voucher -> generate customer voucher / QR.
- [PENDING] Staff: scan / lookup -> validate -> redeem -> history.
- [PENDING] Voucher expiry and revoked/suspended behavior.
- [PENDING] Reporting and Excel export end-to-end verification with customer-derived filename.

## E. Isolation
- [PASS] Commercial routing is locked to `hukihbcyyqhanaqrizvm`.
- [PASS] Cross-project fallback is disabled in canonical Commercial route lock.
- [PASS] EVO Production / Voucher Stage / Daughter are denied Commercial routing targets.
- [PENDING] Runtime negative test: deliberately wrong project target must be rejected.

## F. XiaoE management channel
- [PASS] Commercial Main Channel is the logical Commercial management route.
- [PASS] Runtime mode and migration mode remain credential-separated.
- [PASS] Runtime route uses Commercial bridge target.
- [PASS] Migration route uses manual GitHub workflow / Session Pooler.
- [PASS] Live runtime health verification: Commercial health checks returned `ok=true`, HTTP 200 on four consecutive checks on 2026-09-05 after an earlier bridge-token configuration failure was corrected.
- [PASS] Live source verification: XiaoE Supabase `commercial-invoke-gateway` v1 is ACTIVE and hard-locks `target=commercial` plus `project_ref=hukihbcyyqhanaqrizvm`; `external-supabase-bridge` v12 is ACTIVE and routes Commercial only to `https://hukihbcyyqhanaqrizvm.supabase.co/functions/v1/xiaoe-voucher-bridge` using the dedicated Commercial bridge token header.
- [PASS] Final live runtime `read` verification: XiaoE request id `33` returned HTTP 200 through the locked Commercial invoke path and successfully read `company_profile/default` using the canonical field `company_legal_name`.

## G. Migration and recovery
- [PASS] Commercial migration channel is manual-only.
- [PASS] Dry-run is mandatory before apply.
- [PASS] Apply requires explicit confirmation.
- [PASS] SQL execution is transactional and Commercial-project locked.
- [PASS] Backup and recovery procedure documented in `COMMERCIAL_BACKUP_RECOVERY_V1.md`, including backup scope, checkpoint triggers, isolated restore order, integrity checks and live-recovery safety rules.
- [PASS] Canonical SQL rebuild completed successfully in an isolated PostgreSQL 17 container, with canonical files applied deterministically, required tables/RPCs present, RLS checks passing, and executable SQL passing Commercial-neutral legacy guards.
- [PENDING] Run one restore / recovery rehearsal from documented backup into an isolated target.

## H. Public/PWA entry points
- [PASS] Admin portal exists.
- [PASS] Partner portal exists.
- [PASS] Staff portal exists.
- [PASS] Company Setup exists.
- [PASS] Admin / Partner / Staff PWA manifests exist with independent start URLs, standalone mode, icons and home-screen labels.
- [PASS] Admin / Partner / Staff install entry pages are Company Profile aware.
- [PASS] Admin / Partner / Staff launch splash screens are Company Profile aware.
- [PASS] Public GitHub Pages routes for index, Admin, Partner, Staff, Company Setup and Voucher Engine returned HTTP 200 in release evidence run `33963887854`.
- [PENDING] Verify actual Admin / Partner / Staff install behavior on target devices.

## Verification evidence added 2026-09-05

- Commercial bridge health log: four consecutive `ok=true`, upstream HTTP 200 checks after bridge token configuration was corrected.
- Canonical live preflight run `33962616086`: missing tables 0, missing RPC 0, required RLS enabled, legacy/regional findings 0.
- Frontend source neutralization removed legacy runtime identifiers, hardcoded outlet defaults, fixed Malaysia locale assumptions, old EO voucher placeholder/default copy and fixed RM60 display defaults from active runtime pages.
- Release evidence run `33963887854` passed current-runtime legacy audit, defensive legacy guard isolation, canonical frontend identifier checks, public Pages route checks and PWA manifest validation.
- XiaoE live Edge Function inventory rechecked on 2026-09-05: `commercial-invoke-gateway` ACTIVE v1 and `external-supabase-bridge` ACTIVE v12. Their live source confirms Commercial route-lock enforcement and the exact Commercial upstream project endpoint.
- Final runtime read request `33` returned HTTP 200 and read `company_profile/default` through `xiaoe -> commercial-invoke-gateway -> external-supabase-bridge -> Commercial xiaoe-voucher-bridge -> voucher-db`.
- Isolated canonical rebuild run `33966478168` verified the expanded canonical baseline, including `admin_bootstrap_config` and `service_bootstrap_first_admin`; the first Admin bootstrap test passed, consumed its one-time setup state, and rejected a second bootstrap attempt.
- `commercial-brand.js` retains only defensive legacy-detection/scrub behavior where old literals are needed to prevent legacy content from surfacing; it no longer exposes the old theme alias.
- `COMMERCIAL_BACKUP_RECOVERY_V1.md` defines the canonical backup and restore procedure without storing secret values.

## Launch decision

Current decision: `PRE-LAUNCH`.

Commercial Voucher now has a neutralized live schema and frontend runtime, verified Commercial-only runtime routing, a successful final runtime read, and a verified isolated canonical rebuild with one-time first Admin bootstrap behavior. Remaining blockers are end-to-end Admin/Partner/Staff login/workflow and authorization tests, authenticated runtime wrong-target rejection, actual-device branding/PWA verification, and one isolated restore rehearsal.

Repository metadata note: the GitHub repository description still shows `evolution-optical-voucher`; the connected toolset does not expose repository-description write capability, so this remains a manual metadata cleanup item and does not represent active runtime code.

## Release rule

Only change this document to `COMMERCIAL_READY` after all required PENDING items are converted to PASS with actual verification evidence.
