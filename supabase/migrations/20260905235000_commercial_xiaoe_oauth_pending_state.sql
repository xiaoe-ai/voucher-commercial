create table if not exists public.xiaoe_oauth_pending (
  id uuid primary key default gen_random_uuid(),
  state_hash text not null unique,
  verifier_secret_id uuid not null,
  redirect_uri text not null,
  created_at timestamptz not null default now(),
  expires_at timestamptz not null
);

revoke all on table public.xiaoe_oauth_pending from public, anon, authenticated;
grant select, insert, delete on table public.xiaoe_oauth_pending to service_role;

create or replace function public.xiaoe_oauth_create_pending(
  p_state text,
  p_verifier text,
  p_redirect_uri text
) returns jsonb
language plpgsql
security definer
set search_path = public, vault, extensions
as $$
declare
  v_secret_id uuid;
  v_hash text;
begin
  if coalesce(p_state,'')='' or coalesce(p_verifier,'')='' or coalesce(p_redirect_uri,'')='' then
    raise exception 'state, verifier and redirect_uri are required';
  end if;
  v_hash := encode(digest(p_state,'sha256'),'hex');
  delete from public.xiaoe_oauth_pending where expires_at < now();
  select vault.create_secret(p_verifier,null,'XiaoE Commercial OAuth PKCE verifier',null) into v_secret_id;
  insert into public.xiaoe_oauth_pending(state_hash,verifier_secret_id,redirect_uri,expires_at)
  values(v_hash,v_secret_id,p_redirect_uri,now()+interval '10 minutes');
  return jsonb_build_object('ok',true,'expires_at',now()+interval '10 minutes');
end;
$$;

revoke all on function public.xiaoe_oauth_create_pending(text,text,text) from public, anon, authenticated;
grant execute on function public.xiaoe_oauth_create_pending(text,text,text) to service_role;

create or replace function public.xiaoe_oauth_consume_pending(p_state text)
returns jsonb
language plpgsql
security definer
set search_path = public, vault, extensions
as $$
declare
  v_hash text;
  v_row public.xiaoe_oauth_pending%rowtype;
  v_verifier text;
begin
  if coalesce(p_state,'')='' then raise exception 'state is required'; end if;
  v_hash := encode(digest(p_state,'sha256'),'hex');
  select * into v_row from public.xiaoe_oauth_pending where state_hash=v_hash and expires_at>=now() for update;
  if not found then raise exception 'invalid or expired oauth state'; end if;
  select decrypted_secret into v_verifier from vault.decrypted_secrets where id=v_row.verifier_secret_id;
  delete from public.xiaoe_oauth_pending where id=v_row.id;
  return jsonb_build_object('ok',true,'verifier',v_verifier,'redirect_uri',v_row.redirect_uri);
end;
$$;

revoke all on function public.xiaoe_oauth_consume_pending(text) from public, anon, authenticated;
grant execute on function public.xiaoe_oauth_consume_pending(text) to service_role;