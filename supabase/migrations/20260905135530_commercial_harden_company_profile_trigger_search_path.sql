-- Commercial Voucher security hardening
-- Keep trigger helper deterministic and immune to role-mutable search_path.

create or replace function public.touch_company_profile_updated_at()
returns trigger
language plpgsql
set search_path to 'public'
as $$
begin
  new.updated_at = now();
  new.updated_by = auth.uid();
  return new;
end;
$$;
