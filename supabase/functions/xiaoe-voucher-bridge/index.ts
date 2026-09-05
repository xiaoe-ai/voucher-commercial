import "jsr:@supabase/functions-js/edge-runtime.d.ts";

const PROJECT_REF = "hukihbcyyqhanaqrizvm";
const BRIDGE_SECRET = "XIAOE_VOUCHER_COMMERCIAL_BRIDGE_TOKEN";
const SUPABASE_URL = Deno.env.get("SUPABASE_URL") ?? "";
const SERVICE_ROLE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "";
const BRIDGE_TOKEN = Deno.env.get(BRIDGE_SECRET) ?? "";

const json = (body: unknown, status = 200) => new Response(JSON.stringify(body), {
  status,
  headers: { "content-type": "application/json; charset=utf-8" },
});

function auth(req: Request): boolean {
  const supplied = req.headers.get("x-xiaoe-bridge-token") ?? "";
  return !!BRIDGE_TOKEN && supplied === BRIDGE_TOKEN;
}

const allowedOps = new Set(["eq","neq","gt","gte","lt","lte","like","ilike","is","in"]);

function buildFilters(filters: Record<string, unknown> | undefined): string {
  if (!filters || Object.keys(filters).length === 0) return "";
  const sp = new URLSearchParams();
  for (const [column, raw] of Object.entries(filters)) {
    let op = "eq";
    let value: unknown = raw;
    if (raw && typeof raw === "object" && !Array.isArray(raw)) {
      const r = raw as Record<string, unknown>;
      op = typeof r.op === "string" ? r.op : "eq";
      value = r.value;
    }
    if (!allowedOps.has(op)) throw new Error(`unsupported filter operator: ${op}`);
    if (op === "in") {
      if (!Array.isArray(value)) throw new Error("in filter requires array value");
      sp.set(column, `in.(${value.map(v => String(v)).join(",")})`);
    } else {
      sp.set(column, `${op}.${String(value)}`);
    }
  }
  return sp.toString();
}

async function rest(path: string, init: RequestInit = {}) {
  const headers = new Headers(init.headers ?? {});
  headers.set("apikey", SERVICE_ROLE_KEY);
  headers.set("authorization", `Bearer ${SERVICE_ROLE_KEY}`);
  headers.set("content-type", "application/json");
  headers.set("accept-profile", "public");
  headers.set("content-profile", "public");
  const res = await fetch(`${SUPABASE_URL}${path}`, { ...init, headers });
  const text = await res.text();
  let body: unknown = text;
  try { body = text ? JSON.parse(text) : null; } catch { /* keep text */ }
  return { status: res.status, ok: res.ok, body };
}

Deno.serve(async (req: Request) => {
  if (req.method === "OPTIONS") return new Response(null, { status: 204 });
  if (!auth(req)) return json({ ok: false, error: "unauthorized" }, 401);
  if (!SUPABASE_URL || !SERVICE_ROLE_KEY) return json({ ok: false, error: "bridge runtime not configured" }, 500);

  let input: Record<string, unknown> = {};
  try { input = req.method === "GET" ? {} : await req.json(); } catch { return json({ ok: false, error: "invalid json" }, 400); }

  const action = String(input.action ?? (req.method === "GET" ? "health" : ""));

  try {
    if (action === "health") {
      return json({ ok: true, bridge: "xiaoe-voucher-bridge", project_ref: PROJECT_REF, profile: "engineering_super_admin_v1", actions: ["health","read","insert","update","upsert","delete","rpc"] });
    }

    if (action === "rpc") {
      const fn = String(input.function ?? "");
      if (!/^[A-Za-z_][A-Za-z0-9_]*$/.test(fn)) return json({ ok: false, error: "invalid rpc function" }, 400);
      const out = await rest(`/rest/v1/rpc/${encodeURIComponent(fn)}`, { method: "POST", body: JSON.stringify(input.params ?? {}) });
      return json({ ok: out.ok, action, result: out.body }, out.status);
    }

    const table = String(input.table ?? "");
    if (!/^[A-Za-z_][A-Za-z0-9_]*$/.test(table)) return json({ ok: false, error: "invalid table" }, 400);
    const filters = (input.filters ?? undefined) as Record<string, unknown> | undefined;
    const filterQuery = buildFilters(filters);

    if (action === "read") {
      const select = typeof input.select === "string" ? input.select : "*";
      const limit = Math.min(Math.max(Number(input.limit ?? 100), 1), 1000);
      const qs = new URLSearchParams();
      qs.set("select", select);
      qs.set("limit", String(limit));
      const fq = filterQuery ? `&${filterQuery}` : "";
      const out = await rest(`/rest/v1/${encodeURIComponent(table)}?${qs.toString()}${fq}`, { method: "GET" });
      return json({ ok: out.ok, action, result: out.body }, out.status);
    }

    if (action === "insert") {
      const out = await rest(`/rest/v1/${encodeURIComponent(table)}`, { method: "POST", headers: { Prefer: "return=representation" }, body: JSON.stringify(input.payload ?? {}) });
      return json({ ok: out.ok, action, result: out.body }, out.status);
    }

    if (action === "upsert") {
      const qs = typeof input.on_conflict === "string" && input.on_conflict ? `?on_conflict=${encodeURIComponent(input.on_conflict)}` : "";
      const out = await rest(`/rest/v1/${encodeURIComponent(table)}${qs}`, { method: "POST", headers: { Prefer: "resolution=merge-duplicates,return=representation" }, body: JSON.stringify(input.payload ?? {}) });
      return json({ ok: out.ok, action, result: out.body }, out.status);
    }

    if (action === "update") {
      if (!filterQuery) return json({ ok: false, error: "update requires filters" }, 400);
      const out = await rest(`/rest/v1/${encodeURIComponent(table)}?${filterQuery}`, { method: "PATCH", headers: { Prefer: "return=representation" }, body: JSON.stringify(input.payload ?? {}) });
      return json({ ok: out.ok, action, result: out.body }, out.status);
    }

    if (action === "delete") {
      if (!filterQuery) return json({ ok: false, error: "delete requires filters; full-table delete blocked" }, 400);
      const out = await rest(`/rest/v1/${encodeURIComponent(table)}?${filterQuery}`, { method: "DELETE", headers: { Prefer: "return=representation" } });
      return json({ ok: out.ok, action, result: out.body }, out.status);
    }

    return json({ ok: false, error: "unsupported action" }, 400);
  } catch (e) {
    return json({ ok: false, error: e instanceof Error ? e.message : String(e) }, 400);
  }
});
