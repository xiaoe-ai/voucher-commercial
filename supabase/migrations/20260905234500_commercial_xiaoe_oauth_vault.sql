create table if not exists public.xiaoe_oauth_token_meta (
  singleton boolean primary key default true check (singleton),
  access_secret_id uuid,
  refresh_secret_id uuid,
  expires_at timestamptz,
  updated_at timestamptz not null default now()
);

revoke all on table public.xiaoe_oauth_token_meta from public, anon, authenticated;
grant select, insert, update on table public.xiaoe_oauth_token_meta to service_role;

create or replace function public.xiaoe_oauth_store_tokens(
  p_access_token text,
  p_refresh_token text,
  p_expires_at timestamptz
) returns jsonb
language plpgsql
security definer
set search_path = public, vault
as $$
declare
  v_access_id uuid;
  v_refresh_id uuid;
  v_meta public.xiaoe_oauth_token_meta%rowtype;
begin
  if coalesce(p_access_token,'')='' or coalesce(p_refresh_token,'')='' then
    raise exception 'access_token and refresh_token are required';
  end if;

  select * into v_meta from public.xiaoe_oauth_token_meta where singleton=true;

  if v_meta.access_secret_id is null then
    select vault.create_secret(p_access_token,'xiaoe_commercial_oauth_access_token','XiaoE Commercial Supabase OAuth access token',null) into v_access_id;
  else
    v_access_id := v_meta.access_secret_id;
    perform vault.update_secret(v_access_id,p_access_token,'xiaoe_commercial_oauth_access_token','XiaoE Commercial Supabase OAuth access token',null);
  end if;

  if v_meta.refresh_secret_id is null then
    select vault.create_secret(p_refresh_token,'xiaoe_commercial_oauth_refresh_token','XiaoE Commercial Supabase OAuth refresh token',null) into v_refresh_id;
  else
    v_refresh_id := v_meta.refresh_secret_id;
    perform vault.update_secret(v_refresh_id,p_refresh_token,'xiaoe_commercial_oauth_refresh_token','XiaoE Commercial Supabase OAuth refresh token',null);
  end if;

  insert into public.xiaoe_oauth_token_meta(singleton,access_secret_id,refresh_secret_id,expires_at,updated_at)
  values(true,v_access_id,v_refresh_id,p_expires_at,now())
  on conflict(singleton) do update set
    access_secret_id=excluded.access_secret_id,
    refresh_secret_id=excluded.refresh_secret_id,
    expires_at=excluded.expires_at,
    updated_at=now();

  insert into public.xiaoe_bridge_audit(action,sql_preview,ok)
  values('oauth_store_tokens','tokens stored in Supabase Vault',true);

  return jsonb_build_object('ok',true,'expires_at',p_expires_at);
end;
$$;

revoke all on function public.xiaoe_oauth_store_tokens(text,text,timestamptz) from public, anon, authenticated;
grant execute on function public.xiaoe_oauth_store_tokens(text,text,timestamptz) to service_role;

create or replace function public.xiaoe_oauth_get_tokens()
returns jsonb
language plpgsql
security definer
set search_path = public, vault
as $$
declare
  v_meta public.xiaoe_oauth_token_meta%rowtype;
  v_access text;
  v_refresh text;
begin
  select * into v_meta from public.xiaoe_oauth_token_meta where singleton=true;
  if not found or v_meta.access_secret_id is null or v_meta.refresh_secret_id is null then
    return jsonb_build_object('configured',false);
  end if;

  select decrypted_secret into v_access from vault.decrypted_secrets where id=v_meta.access_secret_id;
  select decrypted_secret into v_refresh from vault.decrypted_secrets where id=v_meta.refresh_secret_id;

  return jsonb_build_object(
    'configured',true,
    'access_token',v_access,
    'refresh_token',v_refresh,
    'expires_at',v_meta.expires_at
  );
end;
$$;

revoke all on function public.xiaoe_oauth_get_tokens() from public, anon, authenticated;
grant execute on function public.xiaoe_oauth_get_tokens() to service_role;