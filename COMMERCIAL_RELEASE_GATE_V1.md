# Commercial Voucher Release Gate V1

Status: PRE-LAUNCH / GATED
Date: 2026-09-05

This file is the canonical launch checklist for Commercial Voucher. A release is `COMMERCIAL_READY` only when every required item is PASS.

## A. Product identity
- [PASS] Canonical repository is `xiaoe-ai/voucher-commercial`.
- [PASS] Canonical Supabase project ref is `hukihbcyyqhanaqrizvm`.
- [PASS] Product is defined as generic white-label Commercial Voucher.
- [PASS] Company Profile layer exists (`company-setup.html`, `commercial-brand.js`).
- [PENDING] Remove all remaining EVO/Evolution legacy strings from deep code paths and generated filenames.

## B. Customer onboarding
- [PASS] Customer can set company name and basic company details without source-code edits.
- [PASS] Company profile supports cloud sync with local continuity fallback.
- [PENDING] Verify first-customer bootstrap path from blank Commercial database to active Admin account.
- [PENDING] Verify logo and brand propagation across Admin / Partner / Staff / voucher presentation.

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
- [PENDING] Reporting and Excel export verification.

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
- [PENDING] Live runtime `health` verification for final release.
- [PENDING] Live runtime `read` verification after final schema freeze.

## G. Migration and recovery
- [PASS] Commercial migration channel is manual-only.
- [PASS] Dry-run is mandatory before apply.
- [PASS] Apply requires explicit confirmation.
- [PASS] SQL execution is transactional and Commercial-project locked.
- [PENDING] Document backup snapshot procedure before first paying customer.
- [PENDING] Run one restore / recovery rehearsal from documented backup.

## H. Public/PWA entry points
- [PASS] Admin portal exists.
- [PASS] Partner portal exists.
- [PASS] Staff portal exists.
- [PASS] Company Setup exists.
- [PENDING] Verify public GitHub Pages routes load successfully on mobile and desktop.
- [PENDING] Verify Admin / Partner / Staff install manifests and home-screen labels.

## Launch decision

Current decision: `PRE-LAUNCH`.

Commercial Voucher already has the correct product architecture and most of the EVO-proven operating surface, but it must not be declared commercially ready until the remaining PENDING end-to-end, security, recovery and legacy-cleanup checks pass.

## Release rule

Only change this document to `COMMERCIAL_READY` after all required PENDING items are converted to PASS with actual verification evidence.
