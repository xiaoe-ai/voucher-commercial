-- Commercial Voucher canonical rebuild baseline
-- Status: REBUILD-ONLY / NOT FOR LIVE APPLY
-- Layer: 001F status semantics alignment
-- Purpose: keep canonical schema consistent with revoke/reporting RPC behavior.

alter table public.vouchers
  drop constraint if exists vouchers_status_check;

alter table public.vouchers
  add constraint vouchers_status_check
  check (status in ('valid','redeemed','expired','cancelled','revoked'));

-- Live currently does not permit `revoked` in this check even though several
-- reporting/engine paths understand revoked vouchers. The canonical rebuild
-- intentionally resolves that internal inconsistency.
