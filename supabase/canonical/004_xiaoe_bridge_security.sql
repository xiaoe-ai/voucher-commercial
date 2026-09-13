-- Commercial Voucher bridge security canonical layer
-- Rebuild source only. Validate on an isolated Commercial target before production apply.

create table if not exists public.xiaoe_bridge_nonces (
  key_id text not null,
  nonce text not null,
  seen_at timestamptz not null default now(),
  primary key (key_id, nonce),
  constraint xiaoe_bridge_nonce_key_id_chk check (key_id ~ '^[A-Za-z0-9._-]{1,64}$'),
  constraint xiaoe_bridge_nonce_value_chk check (nonce ~ '^[A-Za-z0-9._~-]{16,128}$')
);

alter table public.xiaoe_bridge_nonces enable row level security;
revoke all on table public.xiaoe_bridge_nonces from public, anon, authenticated;
grant select, insert, delete on table public.xiaoe_bridge_nonces to service_role;

create index if not exists idx_xiaoe_bridge_nonces_seen_at
  on public.xiaoe_bridge_nonces(seen_at);

-- Verified from live Commercial DB on 2026-09-13.
create or replace function public.xiaoe_admin_query(p_sql text)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_sql text := trim(coalesce(p_sql,''));
  v_result jsonb;
begin
  if v_sql = '' then raise exception 'SQL is required'; end if;
  if v_sql ~ ';\s*\S' then raise exception 'Only one SQL statement is allowed'; end if;
  if lower(v_sql) !~ '^(select|with|show|explain)\s' then raise exception 'Query plane only accepts SELECT/WITH/SHOW/EXPLAIN'; end if;

  begin
    execute 'select coalesce(jsonb_agg(to_jsonb(q)), ''[]''::jsonb) from (' || v_sql || ') q' into v_result;
    insert into public.xiaoe_bridge_audit(action,sql_preview,ok)
      values('sql_query',left(v_sql,500),true);
    return coalesce(v_result,'[]'::jsonb);
  exception when others then
    insert into public.xiaoe_bridge_audit(action,sql_preview,ok,error_text)
      values('sql_query',left(v_sql,500),false,sqlerrm);
    raise;
  end;
end;
$$;

create or replace function public.xiaoe_admin_execute(p_sql text)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_sql text := trim(coalesce(p_sql,''));
  v_count bigint := 0;
begin
  if v_sql = '' then raise exception 'SQL is required'; end if;
  if v_sql ~ ';\s*\S' then raise exception 'Only one SQL statement is allowed'; end if;

  begin
    execute v_sql;
    get diagnostics v_count = row_count;
    insert into public.xiaoe_bridge_audit(action,sql_preview,row_count,ok)
      values('sql_execute',left(v_sql,500),v_count,true);
    return jsonb_build_object('ok',true,'row_count',v_count);
  exception when others then
    insert into public.xiaoe_bridge_audit(action,sql_preview,ok,error_text)
      values('sql_execute',left(v_sql,500),false,sqlerrm);
    raise;
  end;
end;
$$;

revoke all on function public.xiaoe_admin_query(text) from public, anon, authenticated;
revoke all on function public.xiaoe_admin_execute(text) from public, anon, authenticated;
grant execute on function public.xiaoe_admin_query(text) to service_role;
grant execute on function public.xiaoe_admin_execute(text) to service_role;
