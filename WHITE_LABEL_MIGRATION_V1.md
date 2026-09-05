# Commercial Voucher White-Label Migration V1

Status: ACTIVE
Updated: 2026-09-05

## Goal
Convert `xiaoe-ai/voucher-commercial` into a generic white-label voucher platform with no Evolution Optical business dependency.

## Preserve
- Generic voucher engine architecture
- Generic themes and seasonal themes
- Voucher template/version/allocation/redemption model
- Admin / Partner / Staff role separation
- Supabase project `hukihbcyyqhanaqrizvm`
- Existing data compatibility where required for safe migration

## Remove or replace
- User-visible `Evolution Optical` / `EVOLUTION OPTICAL`
- Optical-only copy such as spectacle/free-glasses defaults
- Hard-coded Evolution Optical outlets and contact details
- Old public route `evolution-optical-voucher`
- EVO-prefixed examples used as defaults for new Commercial Voucher data
- Brand-specific legal/footer/share metadata

## Theme policy
Generic themes MUST be retained, including Classic, Birthday, Promo, Premium, CNY, Christmas, Raya, Deepavali, Kids, Valentine, Mother's Day, Corporate, Elegant, Minimal and Anniversary.

Theme functionality is not considered EVO residue merely because it originated in an older codebase.

## Compatibility rule
Internal legacy identifiers may temporarily remain only when removing them would break existing records or RPC/function compatibility. They must not be shown to new Commercial Voucher customers and must not be used as defaults for newly created data.

## Company profile
The target source of truth is a customer-owned Company Profile. Company Name is required; legal name, registration number, tagline, phone, website and logo are optional.

All portals and public vouchers should resolve visible brand information from the Company Profile or voucher payload rather than hard-coded vendor text.

## Route lock
Commercial Voucher operations are locked to:
- GitHub: `xiaoe-ai/voucher-commercial`
- Supabase: `hukihbcyyqhanaqrizvm`
- Xiao-E bridge target: `commercial`

No fallback to EVO Voucher Production or Voucher Stage is allowed.
