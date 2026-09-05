# Commercial Live Security Audit — 2026-09-05

Project ref: `hukihbcyyqhanaqrizvm`
Status: REVIEWED / NO NEW AUTHORIZATION BREAK FOUND

## Scope

Read-only audit of current Commercial Supabase security-advisor findings plus one low-risk trigger hardening migration.

## Findings

### 1. `touch_company_profile_updated_at` mutable search_path

Supabase Advisor reported `function_search_path_mutable`.

Action taken:
- Hardened function with `SET search_path TO 'public'`.
- Applied to Commercial live Supabase.
- Canonical migration: `supabase/migrations/20260905135530_commercial_harden_company_profile_trigger_search_path.sql`.
- Follow-up advisor run no longer reports this warning.

### 2. `voucher_allocation_branches` — RLS enabled, no policies

Classification: INTENTIONAL INTERNAL TABLE.

Observed live grants:
- `postgres`: table privileges
- `service_role`: table privileges
- no `anon` grant
- no `authenticated` grant

RLS is enabled and no policies exist. For this table that is an additional deny boundary, not an exposed-user authorization gap.

### 3. `get_public_voucher(uuid)` callable by anon as SECURITY DEFINER

Classification: INTENTIONAL PUBLIC VOUCHER SURFACE.

The function is keyed by `public_token` UUID and returns only public voucher presentation data:
- voucher code/type
- customer name
- partner name
- expiry/status/issued time
- greeting/theme/terms
- active branch name/address/phone

It does not return customer phone, IC, staff/admin records, allocation internals, auth data, or service credentials.

This is intentionally callable by anon so a customer can open a public voucher link without signing in.

### 4. Authenticated SECURITY DEFINER warnings

Supabase Advisor reports many RPCs as executable by `authenticated`.

A live function-body audit confirmed the important categories have internal authorization logic:
- Admin RPCs: admin-role and/or voucher-admin membership checks.
- Partner RPCs: `auth.uid()` plus partner membership / partner-role checks.
- Staff verify/redeem/reporting RPCs: `auth.uid()` plus active staff membership / branch scope checks.
- `issue_engine_voucher` is a thin wrapper around `create_partner_multi_voucher_controlled`, which performs the Partner authorization checks.

These warnings are therefore treated as API-surface review notices, not proof of unrestricted privilege escalation.

### 5. Leaked Password Protection Disabled

Classification: OPEN PLATFORM SECURITY WARNING.

Supabase Auth leaked-password protection is currently disabled according to Security Advisor. This requires an Auth platform setting change and was not modified by the connected database tooling in this audit.

Reference:
https://supabase.com/docs/guides/auth/password-security#password-strength-and-leaked-password-protection

## Conclusion

No new live authorization-break vulnerability was identified in this audit.

Remaining launch-security action:
- enable or explicitly accept the risk of Supabase Auth leaked-password protection being disabled.

Remaining launch-functional evidence still required:
- real Admin login E2E
- real Partner login E2E
- real Staff login E2E
- live business workflow verification on current Commercial runtime
- actual-device branding/PWA checks
