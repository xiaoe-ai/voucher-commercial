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
- [PASS] Canonical authorization matrix verified in isolated PostgreSQL 17: Admin can read all partners; Partner Admin is restricted to its own partner/membership; Staff is restricted to its own branch; unauthorized cross-partner update is rejected by RLS.
- [PENDING] End-to-end Admin login test on current Commercial Supabase.
- [PENDING] End-to-end Partner login and authorization test on current Commercial Supabase.
- [PENDING] End-to-end Staff login and branch-scope authorization test on current Commercial Supabase.

## D. Live security posture
- [PASS] Supabase live Security Advisor reviewed on 2026-09-05 and recorded in `COMMERCIAL_LIVE_SECURITY_AUDIT_2026-09-05.md`.
- [PASS] `touch_company_profile_updated_at()` was hardened with fixed `search_path='public'`; the mutable-search-path warning cleared on the follow-up advisor run.
- [PASS] `voucher_allocation_branches` RLS/no-policy INFO was reviewed and classified as intentional internal-table isolation: live grants exist only for `postgres` and `service_role`, with no `anon` or `authenticated` table grants.
- [PASS] `get_public_voucher(uuid)` anon `SECURITY DEFINER` warning was reviewed and classified as intentional public-token voucher presentation; its output excludes customer phone/IC, auth data, staff/admin records, allocation internals and credentials.
- [PASS] Authenticated `SECURITY DEFINER` warnings were reviewed at function-body level: Admin RPCs enforce admin/voucher-admin checks; Partner RPCs enforce `auth.uid()` plus partner membership/role; Staff verify/redeem/reporting RPCs enforce active staff membership/branch scope; `issue_engine_voucher` delegates to the checked Partner issuance function.
- [ACCEPTED / DEFERRED] Supabase Auth leaked-password protection remains disabled by explicit user decision for this release stage. This is not a current launch blocker. Supabase documents the feature as available on Pro Plan and above. Reference: https://supabase.com/docs/guides/auth/password-security#password-strength-and-leaked-password-protection

## E. Business workflow
- [PENDING] Admin: create Partner -> allocate Voucher Type -> create Staff.
- [PASS] Canonical recovery Partner issue -> Staff verify -> Staff redeem flow passed in isolated PostgreSQL 17 workflow run `33969904174`, including second-redemption rejection.
- [PENDING] Live/current Commercial Partner: issue voucher -> generate customer voucher / QR.
- [PENDING] Live/current Commercial Staff: scan / lookup -> validate -> redeem -> history.
- [PASS] Voucher expiry, suspended-staff rejection, and unissued-allocation revoke behavior passed isolated canonical edge-case workflow run `33970472186`.
- [PASS] Canonical Partner and Staff reporting RPCs passed isolated workflow run `33970472186` after a successful redemption; Partner summary correctly included redeemed and expired counts, Partner recent-voucher listing returned the expected records, and Staff recent-redemption reporting returned the completed redemption.
- [PENDING] Excel export end-to-end verification with customer-derived filename.

## F. Isolation
- [PASS] Commercial routing is locked to `hukihbcyyqhanaqrizvm`.
- [PASS] Cross-project fallback is disabled in canonical Commercial route lock.
- [PASS] EVO Production / Voucher Stage / Daughter are denied Commercial routing targets.
- [PASS] Runtime wrong-target rejection verified: request `35` returned HTTP 409 `commercial_route_lock_violation` when target was not `commercial`; request `36` returned HTTP 409 `commercial_project_lock_violation` when `target=commercial` but project_ref was incorrect. Both requests were rejected before any Commercial DB write.

## G. XiaoE management channel
- [PASS] Commercial Main Channel is the logical Commercial management route.
- [PASS] Runtime mode and migration mode remain credential-separated.
- [PASS] Runtime route uses Commercial bridge target.
- [PASS] Migration route uses manual GitHub workflow / Session Pooler.
- [PASS] Live runtime health verification: Commercial health checks returned `ok=true`, HTTP 200 on four consecutive checks on 2026-09-05 after an earlier bridge-token configuration failure was corrected.
- [PASS] Live source verification: XiaoE Supabase `commercial-invoke-gateway` v1 is ACTIVE and hard-locks `target=commercial` plus `project_ref=hukihbcyyqhanaqrizvm`; `external-supabase-bridge` v12 is ACTIVE and routes Commercial only to `https://hukihbcyyqhanaqrizvm.supabase.co/functions/v1/xiaoe-voucher-bridge` using the dedicated Commercial bridge token header.
- [PASS] Final live runtime `read` verification: XiaoE request id `33` returned HTTP 200 through the locked Commercial invoke path and successfully read `company_profile/default` using the canonical field `company_legal_name`.

## H. Migration and recovery
- [PASS] Commercial migration channel is manual-only.
- [PASS] Dry-run is mandatory before apply.
- [PASS] Apply requires explicit confirmation.
- [PASS] SQL execution is transactional and Commercial-project locked.
- [PASS] Backup and recovery procedure documented in `COMMERCIAL_BACKUP_RECOVERY_V1.md`, including backup scope, checkpoint triggers, isolated restore order, integrity checks and live-recovery safety rules.
- [PASS] Canonical SQL rebuild completed successfully in an isolated PostgreSQL 17 container, with canonical files applied deterministically, required tables/RPCs present, RLS checks passing, and executable SQL passing Commercial-neutral legacy guards.
- [PASS] Isolated database restore rehearsal completed successfully in workflow run `33966962154`: PostgreSQL 17 logical backup was created, restored into a blank isolated target, canonical grants were reapplied, schema/functions/RLS/business fixture integrity passed, restored Partner/Staff authorization isolation passed, and no legacy customer seed data was present.
- [PASS] All 9 live Commercial Edge Function sources are archived under `supabase/functions/`, with live version / `verify_jwt` / source SHA recorded in `COMMERCIAL_EDGE_FUNCTION_SOURCE_MANIFEST_V1.md`.
- [PASS] Edge source/build rehearsal run `33969245334` passed required source-tree checks, Deno type-check for all 9 functions, Commercial-neutral contamination scan, Commercial bridge binding checks, JWT manifest validation and source-evidence emission without mutating live deployment.
- [PASS] Isolated local Supabase recovery rehearsal run `33969555832` passed canonical-only stack startup, canonical SQL application, archived Edge Function startup, XiaoE bridge health, protected-function JWT enforcement, bootstrap custom-auth surface checks and emitted `PRODUCTION_TOUCHED=false`.
- [PASS] Post-recovery canonical business E2E completed successfully in workflow run `33969904174`: Partner issuance passed, Staff verification passed, Staff redemption passed, a second redemption attempt was rejected, and `PRODUCTION_TOUCHED=false` was emitted. The two earlier runs (`33969706548`, `33969766121`) failed only in the test harness before full business execution; the corrected session-setting handoff resolved those harness defects without changing business logic.
- [PASS] Canonical edge-case E2E run `33970472186` passed expiry enforcement, suspended-staff blocking, unissued-allocation revoke, Partner reporting, Staff reporting, and emitted `PRODUCTION_TOUCHED=false`.

## I. Public/PWA entry points
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
- Runtime isolation requests `35` and `36` returned the expected HTTP 409 route-lock/project-lock rejections and did not reach a business-data write path.
- Isolated canonical rebuild run `33966478168` verified the expanded canonical baseline, including `admin_bootstrap_config` and `service_bootstrap_first_admin`; the first Admin bootstrap test passed, consumed its one-time setup state, and rejected a second bootstrap attempt.
- Isolated authorization workflow run `33966609022` passed Admin / Partner / Staff RLS isolation and cross-partner unauthorized update rejection.
- Isolated database restore workflow run `33966962154` passed backup, blank-target restore, canonical grant reapplication, schema/functions/RLS/data integrity, post-restore authorization isolation and legacy-seed absence.
- Commercial live Edge Function inventory contains 9 active functions; their source is archived in GitHub and version/JWT/source-hash evidence is captured in `COMMERCIAL_EDGE_FUNCTION_SOURCE_MANIFEST_V1.md`.
- Edge source/build rehearsal run `33969245334` passed all source validation steps and recorded `LIVE_DEPLOYMENT_MUTATED=false`.
- Local Supabase recovery rehearsal run `33969555832` passed the full canonical-only local stack and Edge Function smoke checks with `PRODUCTION_TOUCHED=false`.
- Canonical business E2E run `33969904174` passed the complete isolated flow `partner_issue -> staff_verify -> staff_redeem`, including double-redemption protection, after the harness-only defects in runs `33969706548` and `33969766121` were corrected.
- Canonical edge-case E2E run `33970472186` passed `EXPIRY=true`, `SUSPENDED_STAFF=true`, `UNISSUED_REVOKE=true`, `PARTNER_REPORTING=true`, `STAFF_REPORTING=true`, and `PRODUCTION_TOUCHED=false`.
- Live security advisor audit is recorded in `COMMERCIAL_LIVE_SECURITY_AUDIT_2026-09-05.md`; trigger search-path hardening was applied live and the warning cleared on recheck.
- `commercial-brand.js` retains only defensive legacy-detection/scrub behavior where old literals are needed to prevent legacy content from surfacing; it no longer exposes the old theme alias.
- `COMMERCIAL_BACKUP_RECOVERY_V1.md` defines the canonical backup and restore procedure without storing secret values.

## Launch decision

Current decision: `PRE-LAUNCH`.

Commercial Voucher now has a neutralized live schema and frontend runtime, verified Commercial-only routing, a successful runtime read, a verified isolated canonical rebuild and authorization matrix, a successful isolated database backup/restore rehearsal, a complete archived/type-checked Edge Function source set, a successful canonical-only local Supabase recovery rehearsal with Edge Function startup and security checks, a successful isolated Partner issue -> Staff verify -> Staff redeem business E2E, a successful isolated expiry/suspended/revoke/reporting edge-case E2E, and a completed live Supabase security-advisor review with the mutable-search-path warning remediated. Leaked-password protection is explicitly deferred and is not treated as a current blocker. Remaining blockers are real live/current Commercial Admin/Partner/Staff login and workflow verification, Excel export end-to-end verification, and actual-device branding/PWA verification.

Repository metadata note: the GitHub repository description still shows `evolution-optical-voucher`; the connected toolset does not expose repository-description write capability, so this remains a manual metadata cleanup item and does not represent active runtime code.

## Release rule

Only change this document to `COMMERCIAL_READY` after all required PENDING items are converted to PASS with actual verification evidence.
