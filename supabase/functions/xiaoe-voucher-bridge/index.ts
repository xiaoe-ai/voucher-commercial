import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { loadKeyRingFromEnv, verifySignedBridgeRequest } from "./bridge-security.ts";

const PROJECT_REF = "hukihbcyyqhanaqrizvm";
const SUPABASE_URL = Deno.env.get("SUPABASE_URL") ?? "";
const SERVICE_ROLE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "";
const BRIDGE_TOKEN = Deno.env.get("XIAOE_VOUCHER_COMMERCIAL_BRIDGE_TOKEN") ?? "";
const STATIC_MANAGEMENT_TOKEN = Deno.env.get("XIAOE_VOUCHER_COMMERCIAL_MANAGEMENT_TOKEN") ?? "";
const OAUTH_CLIENT_ID = Deno.env.get("XIAOE_VOUCHER_COMMERCIAL_OAUTH_CLIENT_ID") ?? "";
const OAUTH_CLIENT_SECRET = Deno.env.get("XIAOE_VOUCHER_COMMERCIAL_OAUTH_CLIENT_SECRET") ?? "";
const CALLBACK_URL = `${SUPABASE_URL}/functions/v1/xiaoe-voucher-bridge/oauth/callback`;
const KEY_RING = loadKeyRingFromEnv((name) => Deno.env.get(name));
const LEGACY_READ_ONLY = new Set(["health", "oauth_status", "read"]);

const json = (body: unknown, status = 200) => new Response(JSON.stringify(body), { status, headers: { "content-type": "application/json; charset=utf-8" } });
const html = (body: string, status = 200) => new Response(body, { status, headers: { "content-type": "text/html; charset=utf-8" } });
const allowedOps = new Set(["eq","neq","gt","gte","lt","lte","like","ilike","is","in"]);

function bridgeLegacyAuth(req: Request) { return !!BRIDGE_TOKEN && (req.headers.get("x-xiaoe-bridge-token") ?? "") === BRIDGE_TOKEN; }
function base64url(bytes: Uint8Array) { let s=""; for (const b of bytes) s += String.fromCharCode(b); return btoa(s).replace(/\+/g,"-").replace(/\//g,"_").replace(/=+$/g,""); }
function randomUrlSafe(n=32) { const a=new Uint8Array(n); crypto.getRandomValues(a); return base64url(a); }
async function sha256url(s:string){ const d=await crypto.subtle.digest("SHA-256",new TextEncoder().encode(s)); return base64url(new Uint8Array(d)); }
function buildFilters(filters: Record<string, unknown> | undefined): string { if (!filters || Object.keys(filters).length===0) return ""; const sp=new URLSearchParams(); for (const [column,raw] of Object.entries(filters)) { let op="eq", value:unknown=raw; if (raw && typeof raw === "object" && !Array.isArray(raw)) { const r=raw as Record<string,unknown>; op=typeof r.op === "string"?r.op:"eq"; value=r.value; } if(!allowedOps.has(op)) throw new Error(`unsupported filter operator: ${op}`); if(op==="in"){ if(!Array.isArray(value)) throw new Error("in filter requires array value"); sp.set(column,`in.(${value.map(String).join(",")})`);} else sp.set(column,`${op}.${String(value)}`);} return sp.toString(); }

async function callJson(url:string, init:RequestInit={}, authMode:"service"|"none"="service") { const headers=new Headers(init.headers??{}); if(authMode==="service"){ headers.set("apikey",SERVICE_ROLE_KEY); headers.set("authorization",`Bearer ${SERVICE_ROLE_KEY}`);} if(!headers.has("content-type")) headers.set("content-type","application/json"); const res=await fetch(url,{...init,headers}); const text=await res.text(); let body:unknown=text; try{ body=text?JSON.parse(text):null;}catch{} return {status:res.status,ok:res.ok,body}; }
async function rest(path:string,init:RequestInit={}){ const headers=new Headers(init.headers??{}); headers.set("accept-profile","public"); headers.set("content-profile","public"); return callJson(`${SUPABASE_URL}${path}`,{...init,headers},"service"); }
async function rpc(fn:string,params:unknown={}){ return rest(`/rest/v1/rpc/${encodeURIComponent(fn)}`,{method:"POST",body:JSON.stringify(params)}); }

async function consumeNonce(keyId:string, nonce:string, seenAtIso:string):Promise<boolean>{
  const out=await rest("/rest/v1/xiaoe_bridge_nonces",{method:"POST",headers:{Prefer:"return=minimal"},body:JSON.stringify({key_id:keyId,nonce,seen_at:seenAtIso})});
  if(out.status===409)return false;
  if(!out.ok)throw new Error(`nonce store failed (${out.status})`);
  return true;
}

async function oauthTokens(){ const out=await rpc("xiaoe_oauth_get_tokens",{}); if(!out.ok) throw new Error(`oauth token read failed: ${JSON.stringify(out.body)}`); return out.body as any; }
async function storeTokens(access_token:string,refresh_token:string,expires_in:number){ const expiresAt=new Date(Date.now()+Math.max(Number(expires_in||3600),60)*1000).toISOString(); const out=await rpc("xiaoe_oauth_store_tokens",{p_access_token:access_token,p_refresh_token:refresh_token,p_expires_at:expiresAt}); if(!out.ok) throw new Error(`oauth token store failed: ${JSON.stringify(out.body)}`); return expiresAt; }
async function exchangeToken(params:Record<string,string>){ if(!OAUTH_CLIENT_ID||!OAUTH_CLIENT_SECRET) throw new Error("oauth client credentials not configured"); const headers=new Headers(); headers.set("content-type","application/x-www-form-urlencoded"); headers.set("accept","application/json"); headers.set("authorization",`Basic ${btoa(`${OAUTH_CLIENT_ID}:${OAUTH_CLIENT_SECRET}`)}`); const res=await fetch("https://api.supabase.com/v1/oauth/token",{method:"POST",headers,body:new URLSearchParams(params)}); const text=await res.text(); let body:any={}; try{body=text?JSON.parse(text):{};}catch{body={raw:text};} if(!res.ok) throw new Error(`oauth token exchange failed (${res.status}): ${JSON.stringify(body)}`); return body; }
async function refreshOAuthToken(current:any){ const body=await exchangeToken({grant_type:"refresh_token",refresh_token:String(current.refresh_token??"")}); const refresh=String(body.refresh_token??current.refresh_token??""); const access=String(body.access_token??""); if(!access||!refresh) throw new Error("oauth refresh returned incomplete tokens"); await storeTokens(access,refresh,Number(body.expires_in??3600)); return access; }
async function managementAccessToken(){ if(STATIC_MANAGEMENT_TOKEN) return STATIC_MANAGEMENT_TOKEN; const t=await oauthTokens(); if(!t?.configured) throw new Error("oauth authorization not completed"); const exp=t.expires_at?Date.parse(String(t.expires_at)):0; if(!t.access_token||!t.refresh_token) throw new Error("oauth tokens incomplete"); if(!exp || exp < Date.now()+120000) return refreshOAuthToken(t); return String(t.access_token); }
function managementPathAllowed(path:string){ const p1=`/v1/projects/${PROJECT_REF}`; const p2=`/v2/projects/${PROJECT_REF}`; return path===p1||path.startsWith(p1+"/")||path.startsWith(p1+"?")||path===p2||path.startsWith(p2+"/")||path.startsWith(p2+"?"); }
async function management(path:string,init:RequestInit={}){ if(!managementPathAllowed(path)) return {status:403,ok:false,body:{error:"management path blocked: Commercial project only"}}; const token=await managementAccessToken(); const headers=new Headers(init.headers??{}); headers.set("authorization",`Bearer ${token}`); if(!headers.has("content-type")) headers.set("content-type","application/json"); const res=await fetch(`https://api.supabase.com${path}`,{...init,headers}); const text=await res.text(); let body:unknown=text; try{body=text?JSON.parse(text):null;}catch{} return {status:res.status,ok:res.ok,body}; }

async function handleOAuthCallback(req:Request){ try{ const u=new URL(req.url); const error=u.searchParams.get("error"); if(error) return html(`<h2>Supabase authorization failed</h2><p>${error}</p>`,400); const code=u.searchParams.get("code")??""; const state=u.searchParams.get("state")??""; if(!code||!state) return html("<h2>Missing OAuth code/state</h2>",400); const pending=await rpc("xiaoe_oauth_consume_pending",{p_state:state}); if(!pending.ok) throw new Error(`state validation failed: ${JSON.stringify(pending.body)}`); const p:any=pending.body; const verifier=String(p.verifier??""); const redirectUri=String(p.redirect_uri??CALLBACK_URL); const body=await exchangeToken({grant_type:"authorization_code",code,redirect_uri:redirectUri,code_verifier:verifier}); const access=String(body.access_token??""); const refresh=String(body.refresh_token??""); if(!access||!refresh) throw new Error("oauth authorization returned incomplete tokens"); const expiresAt=await storeTokens(access,refresh,Number(body.expires_in??3600)); return html(`<html><body style="font-family:sans-serif;padding:40px"><h2>✅ XiaoE Supabase authorization complete</h2><p>Management Plane is connected.</p><p>Token refresh is automatic.</p><p>You may close this window.</p><small>expires_at ${expiresAt}</small></body></html>`); }catch(e){ return html(`<h2>OAuth callback error</h2><pre>${String(e instanceof Error?e.message:e)}</pre>`,400); } }

Deno.serve(async(req:Request)=>{
  const url=new URL(req.url);
  if(url.pathname.endsWith("/oauth/callback")) return handleOAuthCallback(req);
  if(req.method==="OPTIONS") return new Response(null,{status:204});
  if(!SUPABASE_URL||!SERVICE_ROLE_KEY) return json({ok:false,error:"bridge runtime not configured"},500);

  let rawBody=new Uint8Array();
  let input:Record<string,unknown>={};
  if(req.method!=="GET"){
    try{
      rawBody=new Uint8Array(await req.arrayBuffer());
      input=rawBody.length?JSON.parse(new TextDecoder().decode(rawBody)):{};
    }catch{return json({ok:false,error:"invalid json"},400);}
  }
  const action=String(input.action??(req.method==="GET"?"health":""));

  const hasSignedHeaders=!!req.headers.get("x-xiaoe-signature")||!!req.headers.get("x-xiaoe-key-id");
  if(hasSignedHeaders){
    try{
      const verified=await verifySignedBridgeRequest(req,action,rawBody,KEY_RING,{consumeNonce});
      if(!verified.ok)return json({ok:false,error:verified.error},verified.status);
    }catch(e){return json({ok:false,error:e instanceof Error?e.message:String(e)},503);}
  }else{
    if(!bridgeLegacyAuth(req))return json({ok:false,error:"unauthorized"},401);
    if(!LEGACY_READ_ONLY.has(action))return json({ok:false,error:"legacy bridge token is read-only; signed request required"},403);
  }

  try{
    if(action==="health"){ const t=await oauthTokens().catch(()=>({configured:false})); return json({ok:true,bridge:"xiaoe-voucher-bridge",project_ref:PROJECT_REF,profile:"commercial_direct_connector_parity_v3_signed",signed_keys_configured:KEY_RING.size,legacy_mode:"read_only",oauth_client_configured:!!OAUTH_CLIENT_ID&&!!OAUTH_CLIENT_SECRET,oauth_authorized:!!t?.configured,management_plane:STATIC_MANAGEMENT_TOKEN?"static_ready":(t?.configured?"oauth_ready":"oauth_authorization_pending"),actions:["health","oauth_authorize_url","oauth_status","read","insert","update","upsert","delete","rpc","sql_query","sql_execute","auth_list_users","auth_get_user","auth_create_user","auth_update_user","auth_delete_user","storage_list_buckets","storage_create_bucket","storage_update_bucket","storage_delete_bucket","storage_list_objects","storage_delete_objects","management_call"]}); }
    if(action==="oauth_status"){ const t=await oauthTokens(); return json({ok:true,configured:!!t?.configured,expires_at:t?.expires_at??null,client_configured:!!OAUTH_CLIENT_ID&&!!OAUTH_CLIENT_SECRET}); }
    if(action==="oauth_authorize_url"){ if(!OAUTH_CLIENT_ID||!OAUTH_CLIENT_SECRET) return json({ok:false,error:"oauth client credentials not configured"},503); const state=randomUrlSafe(32),verifier=randomUrlSafe(48),challenge=await sha256url(verifier); const p=await rpc("xiaoe_oauth_create_pending",{p_state:state,p_verifier:verifier,p_redirect_uri:CALLBACK_URL}); if(!p.ok) return json({ok:false,error:"unable to create oauth pending state",detail:p.body},p.status); const q=new URLSearchParams({response_type:"code",client_id:OAUTH_CLIENT_ID,redirect_uri:CALLBACK_URL,state,code_challenge:challenge,code_challenge_method:"S256"}); return json({ok:true,authorize_url:`https://api.supabase.com/v1/oauth/authorize?${q.toString()}`,callback_url:CALLBACK_URL}); }
    if(action==="rpc"){ const fn=String(input.function??""); if(!/^[A-Za-z_][A-Za-z0-9_]*$/.test(fn)) return json({ok:false,error:"invalid rpc function"},400); const out=await rpc(fn,input.params??{}); return json({ok:out.ok,action,result:out.body},out.status); }
    if(action==="sql_query"||action==="sql_execute"){ const sql=String(input.sql??"").trim(); if(!sql) return json({ok:false,error:"sql is required"},400); const fn=action==="sql_query"?"xiaoe_admin_query":"xiaoe_admin_execute"; const out=await rpc(fn,{p_sql:sql}); return json({ok:out.ok,action,result:out.body},out.status); }
    if(action.startsWith("auth_")){
      if(action==="auth_list_users"){ const page=Math.max(Number(input.page??1),1),perPage=Math.min(Math.max(Number(input.per_page??50),1),1000); const out=await callJson(`${SUPABASE_URL}/auth/v1/admin/users?page=${page}&per_page=${perPage}`); return json({ok:out.ok,action,result:out.body},out.status); }
      if(action==="auth_create_user"){ const out=await callJson(`${SUPABASE_URL}/auth/v1/admin/users`,{method:"POST",body:JSON.stringify(input.payload??{})}); return json({ok:out.ok,action,result:out.body},out.status); }
      const userId=String(input.user_id??""); if(!/^[0-9a-f-]{36}$/i.test(userId)) return json({ok:false,error:"invalid user_id"},400);
      if(action==="auth_get_user"){ const out=await callJson(`${SUPABASE_URL}/auth/v1/admin/users/${userId}`); return json({ok:out.ok,action,result:out.body},out.status); }
      if(action==="auth_update_user"){ const out=await callJson(`${SUPABASE_URL}/auth/v1/admin/users/${userId}`,{method:"PUT",body:JSON.stringify(input.payload??{})}); return json({ok:out.ok,action,result:out.body},out.status); }
      if(action==="auth_delete_user"){ const out=await callJson(`${SUPABASE_URL}/auth/v1/admin/users/${userId}${Boolean(input.soft_delete)?"?should_soft_delete=true":""}`,{method:"DELETE"}); return json({ok:out.ok,action,result:out.body},out.status); }
    }
    if(action.startsWith("storage_")){
      if(action==="storage_list_buckets"){ const out=await callJson(`${SUPABASE_URL}/storage/v1/bucket`); return json({ok:out.ok,action,result:out.body},out.status); }
      if(action==="storage_create_bucket"){ const out=await callJson(`${SUPABASE_URL}/storage/v1/bucket`,{method:"POST",body:JSON.stringify(input.payload??{})}); return json({ok:out.ok,action,result:out.body},out.status); }
      const bucket=String(input.bucket??""); if(!bucket) return json({ok:false,error:"bucket is required"},400);
      if(action==="storage_update_bucket"){ const out=await callJson(`${SUPABASE_URL}/storage/v1/bucket/${encodeURIComponent(bucket)}`,{method:"PUT",body:JSON.stringify(input.payload??{})}); return json({ok:out.ok,action,result:out.body},out.status); }
      if(action==="storage_delete_bucket"){ const out=await callJson(`${SUPABASE_URL}/storage/v1/bucket/${encodeURIComponent(bucket)}`,{method:"DELETE"}); return json({ok:out.ok,action,result:out.body},out.status); }
      if(action==="storage_list_objects"){ const out=await callJson(`${SUPABASE_URL}/storage/v1/object/list/${encodeURIComponent(bucket)}`,{method:"POST",body:JSON.stringify(input.payload??{prefix:"",limit:100,offset:0})}); return json({ok:out.ok,action,result:out.body},out.status); }
      if(action==="storage_delete_objects"){ const prefixes=Array.isArray(input.prefixes)?input.prefixes.map(String):[]; if(!prefixes.length) return json({ok:false,error:"prefixes are required"},400); const out=await callJson(`${SUPABASE_URL}/storage/v1/object/${encodeURIComponent(bucket)}`,{method:"DELETE",body:JSON.stringify({prefixes})}); return json({ok:out.ok,action,result:out.body},out.status); }
    }
    if(action==="management_call"){ const path=String(input.path??""),method=String(input.method??"GET").toUpperCase(); if(!new Set(["GET","POST","PUT","PATCH","DELETE"]).has(method)) return json({ok:false,error:"unsupported management method"},400); const out=await management(path,{method,body:method==="GET"?undefined:JSON.stringify(input.payload??{})}); return json({ok:out.ok,action,result:out.body},out.status); }

    const table=String(input.table??""); if(!/^[A-Za-z_][A-Za-z0-9_]*$/.test(table)) return json({ok:false,error:"invalid table"},400); const filters=(input.filters??undefined) as Record<string,unknown>|undefined; const fq=buildFilters(filters);
    if(action==="read"){ const select=typeof input.select==="string"?input.select:"*",limit=Math.min(Math.max(Number(input.limit??100),1),1000); const qs=new URLSearchParams({select,limit:String(limit)}); const out=await rest(`/rest/v1/${encodeURIComponent(table)}?${qs.toString()}${fq?`&${fq}`:""}`,{method:"GET"}); return json({ok:out.ok,action,result:out.body},out.status); }
    if(action==="insert"){ const out=await rest(`/rest/v1/${encodeURIComponent(table)}`,{method:"POST",headers:{Prefer:"return=representation"},body:JSON.stringify(input.payload??{})}); return json({ok:out.ok,action,result:out.body},out.status); }
    if(action==="upsert"){ const qs=typeof input.on_conflict==="string"&&input.on_conflict?`?on_conflict=${encodeURIComponent(input.on_conflict)}`:""; const out=await rest(`/rest/v1/${encodeURIComponent(table)}${qs}`,{method:"POST",headers:{Prefer:"resolution=merge-duplicates,return=representation"},body:JSON.stringify(input.payload??{})}); return json({ok:out.ok,action,result:out.body},out.status); }
    if(action==="update"){ if(!fq) return json({ok:false,error:"update requires filters"},400); const out=await rest(`/rest/v1/${encodeURIComponent(table)}?${fq}`,{method:"PATCH",headers:{Prefer:"return=representation"},body:JSON.stringify(input.payload??{})}); return json({ok:out.ok,action,result:out.body},out.status); }
    if(action==="delete"){ if(!fq) return json({ok:false,error:"delete requires filters; full-table delete blocked"},400); const out=await rest(`/rest/v1/${encodeURIComponent(table)}?${fq}`,{method:"DELETE",headers:{Prefer:"return=representation"}}); return json({ok:out.ok,action,result:out.body},out.status); }
    return json({ok:false,error:"unsupported action"},400);
  }catch(e){ return json({ok:false,error:e instanceof Error?e.message:String(e)},400); }
});
