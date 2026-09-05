-- Commercial Voucher: authenticated Partner/Staff users need active branch directory data
-- for claim-location resolution. RLS still blocks inactive rows and all writes.

drop policy if exists branches_authenticated_active_select on public.branches;
create policy branches_authenticated_active_select
on public.branches
for select
to authenticated
using (lower(coalesce(status,'active'))='active');
