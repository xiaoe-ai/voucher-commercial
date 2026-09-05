import "jsr:@supabase/functions-js/edge-runtime.d.ts";
const SUPABASE_URL = Deno.env.get("SUPABASE_URL") ?? "";
const SERVICE_ROLE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "";
const CLIENT_ID = Deno.env.get("XIAOE_VOUCHER_COMMERCIAL_OAUTH_CLIENT_ID") ?? "";
const CALLBACK = `${SUPABASE_URL}/functions/v1/xiaoe-voucher-bridge/oauth/callback`;
function b64u(bytes:Uint8Array){let s="";for(const b of bytes)s+=String.fromCharCode(b);return btoa(s).replace(/\+/g,"-").replace(/\//g,"_").replace(/=+$/g,"");}
function random(n=32){const a=new Uint8Array(n);crypto.getRandomValues(a);return b64u(a);}
async function sha256u(s:string){const d=await crypto.subtle.digest("SHA-256",new TextEncoder().encode(s));return b64u(new Uint8Array(d));}
async function rpc(fn:string,params:unknown){const r=await fetch(`${SUPABASE_URL}/rest/v1/rpc/${fn}`,{method:"POST",headers:{apikey:SERVICE_ROLE_KEY,authorization:`Bearer ${SERVICE_ROLE_KEY}`,"content-type":"application/json"},body:JSON.stringify(params)});const t=await r.text();let b:any=t;try{b=t?JSON.parse(t):null}catch{};if(!r.ok)throw new Error(JSON.stringify(b));return b;}
Deno.serve(async()=>{try{if(!SUPABASE_URL||!SERVICE_ROLE_KEY||!CLIENT_ID)return new Response("OAuth runtime not configured",{status:503});const state=random(32),verifier=random(48),challenge=await sha256u(verifier);await rpc("xiaoe_oauth_create_pending",{p_state:state,p_verifier:verifier,p_redirect_uri:CALLBACK});const q=new URLSearchParams({response_type:"code",client_id:CLIENT_ID,redirect_uri:CALLBACK,state,code_challenge:challenge,code_challenge_method:"S256"});return Response.redirect(`https://api.supabase.com/v1/oauth/authorize?${q.toString()}`,302);}catch(e){return new Response(`OAuth start failed: ${e instanceof Error?e.message:String(e)}`,{status:500});}});
