create table if not exists public.company_profile (
  id text primary key default 'default' check (id = 'default'),
  company_name text not null,
  company_legal_name text,
  registration_no text,
  tagline text,
  phone text,
  website text,
  logo_url text,
  updated_at timestamptz not null default now(),
  updated_by uuid
);

alter table public.company_profile enable row level security;

insert into public.company_profile (id, company_name, tagline)
values ('default', 'Your Company', 'Voucher Platform')
on conflict (id) do nothing;

create policy "company_profile_public_read"
on public.company_profile
for select
to anon, authenticated
using (id = 'default');

create policy "company_profile_admin_insert"
on public.company_profile
for insert
to authenticated
with check (public.is_voucher_admin());

create policy "company_profile_admin_update"
on public.company_profile
for update
to authenticated
using (public.is_voucher_admin())
with check (public.is_voucher_admin());

create or replace function public.touch_company_profile_updated_at()
returns trigger
language plpgsql
as $$
begin
  new.updated_at = now();
  new.updated_by = auth.uid();
  return new;
end;
$$;

drop trigger if exists trg_company_profile_updated_at on public.company_profile;
create trigger trg_company_profile_updated_at
before update on public.company_profile
for each row execute function public.touch_company_profile_updated_at();

grant select on public.company_profile to anon, authenticated;
grant insert, update on public.company_profile to authenticated;
