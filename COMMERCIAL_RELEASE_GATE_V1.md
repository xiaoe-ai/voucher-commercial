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
- [PENDING] Complete final deep legacy-string audit for non-user-facing technical identifiers and any remaining generated outputs.

## B. Customer onboarding
- [PASS] Customer can set company name and basic company details without source-code edits.
- [PASS] Company profile supports cloud sync with local continuity fallback.
- [PASS] Admin / Partner / Staff install entry pages and launch splash screens are wired to Company Profile so role entry surfaces display the customer company name rather than a fixed Commercial/EVO brand.
- [PENDING] Verify first-customer bootstrap path from blank Commercial database to active Admin account.
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
- [PENDING] Live runtime `read` verification after final schema freeze.

## G. Migration and recovery
- [PASS] Commercial migration channel is manual-only.
- [PASS] Dry-run is mandatory before apply.
- [PASS] Apply requires explicit confirmation.
- [PASS] SQL execution is transactional and Commercial-project locked.
- [PASS] Backup and recovery procedure documented in `COMMERCIAL_BACKUP_RECOVERY_V1.md`, including backup scope, checkpoint triggers, isolated restore order, integrity checks and live-recovery safety rules.
- [PENDING] Run one restore / recovery rehearsal from documented backup into an isolated target.

## H. Public/PWA entry points
- [PASS] Admin portal exists.
- [PASS] Partner portal exists.
- [PASS] Staff portal exists.
- [PASS] Company Setup exists.
- [PASS] Admin / Partner / Staff PWA manifests exist with independent start URLs, standalone mode, icons and home-screen labels.
- [PASS] Admin / Partner / Staff install entry pages are Company Profile aware.
- [PASS] Admin / Partner / Staff launch splash screens are Company Profile aware.
- [PENDING] Verify public GitHub Pages routes load successfully on mobile and desktop.
- [PENDING] Verify actual Admin / Partner / Staff install behavior on target devices.

## Verification evidence added 2026-09-05

- Commercial bridge health log: four consecutive `ok=true`, upstream HTTP 200 checks after bridge token configuration was corrected.
- `manifest-admin.json`, `manifest-partner.json`, `manifest-staff.json` structurally verified.
- `commercial-brand.js` hardens legacy export naming and resolves the filename from the latest local Company Profile at export time, so same-session company-name changes are reflected without page reload.
- `commercial-brand.js` exposes `CommercialVoucherThemes` as the Commercial-neutral compatibility API while existing `EOVoucherThemes` callers remain operational during migration.
- Admin / Partner / Staff install entry pages load `commercial-brand.js` and render Company Profile names.
- Admin / Partner / Staff launch splash screens load `commercial-brand.js` and render Company Profile names.
- `COMMERCIAL_BACKUP_RECOVERY_V1.md` defines the canonical backup and restore procedure without storing secret values.

## Launch decision

Current decision: `PRE-LAUNCH`.

Commercial Voucher already has the correct product architecture and most of the EVO-proven operating surface. Remaining blockers are backend canonicalization/rebuild evidence, Partner outlet cutover, end-to-end account/workflow validation, authorization/RLS verification, public-device verification, final deep legacy audit, live schema migration verification, and one isolated restore rehearsal.

## Release rule

Only change this document to `COMMERCIAL_READY` after all required PENDING items are converted to PASS with actual verification evidence.
