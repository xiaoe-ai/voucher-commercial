create table if not exists public.xiaoe_stability_state (
  project_key text primary key,
  identity_mode text not null default 'project-local',
  expected_project_ref text not null,
  expected_repository text not null,
  route_lock_version text not null,
  bridge_role text not null default 'transport-only',
  cross_project_fallback boolean not null default false,
  same_direction_failure_limit integer not null default 2 check (same_direction_failure_limit between 1 and 5),
  business_flow_protected boolean not null default true,
  last_verified_at timestamptz,
  last_bridge_status text,
  last_bridge_checked_at timestamptz,
  state jsonb not null default '{}'::jsonb,
  updated_at timestamptz not null default now()
);

alter table public.xiaoe_stability_state enable row level security;
revoke all on public.xiaoe_stability_state from anon, authenticated;
grant select, insert, update, delete on public.xiaoe_stability_state to service_role;

insert into public.xiaoe_stability_state (
  project_key,
  identity_mode,
  expected_project_ref,
  expected_repository,
  route_lock_version,
  bridge_role,
  cross_project_fallback,
  same_direction_failure_limit,
  business_flow_protected,
  last_verified_at,
  last_bridge_status,
  last_bridge_checked_at,
  state,
  updated_at
) values (
  'commercial-voucher',
  'project-local',
  'hukihbcyyqhanaqrizvm',
  'xiaoe-ai/voucher-commercial',
  '1.3',
  'transport-only',
  false,
  2,
  true,
  now(),
  'UNKNOWN',
  null,
  '{"identity_survives_bridge_failure":true,"read_before_write":true,"completion_requires_reverify":true,"protected_business_flow":"Admin -> Partner -> Voucher -> Staff verify/redeem"}'::jsonb,
  now()
)
on conflict (project_key) do update set
  identity_mode = excluded.identity_mode,
  expected_project_ref = excluded.expected_project_ref,
  expected_repository = excluded.expected_repository,
  route_lock_version = excluded.route_lock_version,
  bridge_role = excluded.bridge_role,
  cross_project_fallback = excluded.cross_project_fallback,
  same_direction_failure_limit = excluded.same_direction_failure_limit,
  business_flow_protected = excluded.business_flow_protected,
  last_verified_at = excluded.last_verified_at,
  state = excluded.state,
  updated_at = now();
