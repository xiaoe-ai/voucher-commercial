# Commercial Edge Function Source Manifest V1

Status: CANONICAL EVIDENCE
Date: 2026-09-05
Supabase project ref: `hukihbcyyqhanaqrizvm`
Repository: `xiaoe-ai/voucher-commercial`

This manifest records the directly-read Commercial Supabase live Edge Function inventory used for the GitHub source archive. Hashes are Supabase `ezbr_sha256` values returned by the Management API. Secret values are not recorded.

| Function | Live version | verify_jwt | Live ezbr_sha256 | Canonical path |
|---|---:|---|---|---|
| `create-partner` | 10 | true | `f87509c69a7c281e663f4e0d1d00115b2fe27bfcb218ce785d3bcf7953c499d8` | `supabase/functions/create-partner/index.ts` |
| `create-staff` | 11 | true | `6bf0a9dd44a2f720e8a6829cf0301154071d4013f9f1972992bff715ff163830` | `supabase/functions/create-staff/index.ts` |
| `reset-partner-password` | 7 | true | `61cef5bedd54598d0483e2e569fa54385dd265da85ece368989c68d9f86333ad` | `supabase/functions/reset-partner-password/index.ts` |
| `manage-partner-staff` | 7 | true | `cd6c6f6ae34accbcc25c918fc16cd97966f726bfb62f028c5388b254f1c2f7b7` | `supabase/functions/manage-partner-staff/index.ts` |
| `admin-set-partner-staff-limit` | 6 | true | `b30f8f9184edafbf4fb0a0a5e9290525d8c1ac8e0002b8e1bd983e93e770ede6` | `supabase/functions/admin-set-partner-staff-limit/index.ts` |
| `voucher-engine-admin` | 9 | true | `7a646b8781b1f66d2c884e7484fd30035832100583033ca9736dbc82f053aedb` | `supabase/functions/voucher-engine-admin/index.ts` |
| `bootstrap-admin` | 5 | false | `0c776122e05dcde00c956f775d1a9375af756d7477b201cb4fd1b016d80b00be` | `supabase/functions/bootstrap-admin/index.ts` |
| `voucher-engine` | 5 | true | `21dc2bf1d9c3018aedd574e06bc44fffaff5c980f6e66a9094568663c0e59cd2` | `supabase/functions/voucher-engine/index.ts` |
| `xiaoe-voucher-bridge` | 4 | false | `673fb9ed206455be6e9ded18d9befcf1c3fb5bcaa9b2c0344f66b8540b3946cb` | `supabase/functions/xiaoe-voucher-bridge/index.ts` |

## Recovery rule

A future recovery rehearsal must not assume source parity only because filenames exist. It must:
1. deploy the archived function source into an isolated recovery target,
2. apply the recorded `verify_jwt` mode,
3. configure required environment secret names without committing secret values,
4. run role authorization and business-flow checks,
5. verify XiaoE bridge health/read against the rebuilt target.

The live Commercial project was read only during this source-archive pass; no Edge Function deployment was changed.
