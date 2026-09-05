# Commercial Edge Function Deployment Manifest V1

Status: CANONICAL / ISOLATED DEPLOYMENT READY
Date: 2026-09-05
Production project ref: `hukihbcyyqhanaqrizvm`

This file defines the deployment settings required to rebuild Commercial Voucher Edge Functions in an isolated Supabase recovery target. It records secret NAMES only, never values.

## Deployment matrix

| Function | verify_jwt | Required runtime env names | Notes |
|---|---|---|---|
| `create-partner` | true | `SUPABASE_URL`, `SUPABASE_ANON_KEY`, `SUPABASE_SERVICE_ROLE_KEY` | Admin-authenticated provisioning path. |
| `create-staff` | true | `SUPABASE_URL`, `SUPABASE_ANON_KEY`, `SUPABASE_SERVICE_ROLE_KEY` | Admin/Manager authenticated provisioning path. |
| `reset-partner-password` | true | `SUPABASE_URL`, `SUPABASE_SERVICE_ROLE_KEY` | Admin-only password reset; does not log secret material. |
| `manage-partner-staff` | true | `SUPABASE_URL`, `SUPABASE_SERVICE_ROLE_KEY` | Partner Admin staff management. |
| `admin-set-partner-staff-limit` | true | `SUPABASE_URL`, `SUPABASE_SERVICE_ROLE_KEY` | Admin-only staff limit mutation. |
| `voucher-engine-admin` | true | `SUPABASE_URL`, `SUPABASE_SERVICE_ROLE_KEY` | Admin voucher template/version/allocation administration. |
| `bootstrap-admin` | false | `SUPABASE_URL`, `SUPABASE_SERVICE_ROLE_KEY` | Custom one-time setup-code protection is implemented in function/RPC logic. |
| `voucher-engine` | true | `SUPABASE_URL`, `SUPABASE_ANON_KEY`, `SUPABASE_SERVICE_ROLE_KEY` | Authenticated Admin voucher engine operations. |
| `xiaoe-voucher-bridge` | false | `SUPABASE_URL`, `SUPABASE_SERVICE_ROLE_KEY`, `XIAOE_VOUCHER_COMMERCIAL_BRIDGE_TOKEN` | Custom dedicated bridge-token authentication. |

## Required isolated deployment order

1. Create or select an isolated Supabase recovery target. Never use Commercial Production for rehearsal.
2. Restore/apply the canonical database baseline and grants.
3. Configure the runtime environment variables/secrets listed above.
4. Deploy functions with the exact `verify_jwt` setting from this manifest.
5. Verify function inventory and status.
6. Run Admin bootstrap in the isolated target.
7. Run Admin -> Partner -> Staff authorization flow.
8. Run voucher issue -> verify -> redeem flow.
9. Verify reporting/history and expiry/revocation behavior.
10. Point a temporary recovery-only XiaoE bridge route at the isolated target and verify health/read.
11. Remove the temporary recovery route and isolated target when no longer needed.

## Safety rules

- Production project ref `hukihbcyyqhanaqrizvm` must not be the rehearsal target.
- Secret values must never be committed to GitHub.
- Do not merge an isolated Supabase branch into Production as part of the rehearsal.
- Two failed deployment/recovery attempts require STOP and diagnosis before another mutation.
- A PASS requires actual isolated deployment plus business-flow verification; source/type-check success alone is not enough.

## Current evidence

- All 9 live Edge Function sources are archived in GitHub.
- Source/build validation workflow run `33969245334` passed.
- Commercial Supabase currently reports no development branches, so isolated Supabase deployment remains pending until an isolated target is available.
