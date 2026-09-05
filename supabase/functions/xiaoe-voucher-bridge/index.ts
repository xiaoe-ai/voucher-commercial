import { createClient } from "npm:@supabase/supabase-js@2";

const PROJECT_REF = "hukihbcyyqhanaqrizvm";
const JSON_HEADERS = { "Content-Type": "application/json; charset=utf-8" };
const reply = (status: number, body: unknown) =>
  new Response(JSON.stringify(body), { status, headers: JSON_HEADERS });

const ACTIONS = new Set(["health", "read", "insert", "update", "upsert", "delete", "rpc"]);

function cleanLimit(raw: unknown) {
  const n = Number(raw ?? 50);
  if (!Number.isFinite(n)) return 50;
  return Math.max(1, Math.min(Math.floor(n), 500));
}

function isRecord(value: unknown): value is Record<string, unknown> {
  return !!value && typeof value === "object" && !Array.isArray(value);
}

Deno.serve(async (req: Request) => {
  if (req.method !== "POST") return reply(405, { ok: false, error: "method_not_allowed" });

  const expectedToken =
    Deno.env.get("VOUCHER_COMMERCIAL_BRIDGE_TOKEN")?.trim() ||
    Deno.env.get("XIAOE_VOUCHER_COMMERCIAL_BRIDGE_TOKEN")?.trim() ||
    "";
  const suppliedToken = req.headers.get("x-xiaoe-bridge-token")?.trim() || "";
  if (!expectedToken || !suppliedToken || suppliedToken !== expectedToken) {
    return reply(401, { ok: false, error: "unauthorized_bridge_caller" });
  }

  const baseUrl = Deno.env.get("SUPABASE_URL") || "";
  const serviceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") || "";
  if (!baseUrl || !serviceRoleKey) return reply(500, { ok: false, error: "server_configuration_error" });

  let body: Record<string, unknown>;
  try {
    body = await req.json();
  } catch {
    return reply(400, { ok: false, error: "invalid_json" });
  }

  const requestedProject = String(body.project_ref ?? PROJECT_REF).trim();
  const requestedTarget = String(body.target ?? "commercial").trim().toLowerCase();
  if (requestedTarget !== "commercial") {
    return reply(409, { ok: false, error: "commercial_route_lock_violation", requested_target: requestedTarget });
  }
  if (requestedProject !== PROJECT_REF) {
    return reply(409, { ok: false, error: "commercial_project_lock_violation", requested_project_ref: requestedProject });
  }

  const action = String(body.action ?? "health").trim().toLowerCase();
  if (!ACTIONS.has(action)) return reply(400, { ok: false, error: "unsupported_action", action });

  const admin = createClient(baseUrl, serviceRoleKey, {
    auth: { persistSession: false, autoRefreshToken: false },
  });

  if (action === "health") {
    const { error } = await admin.from("partners").select("id", { count: "exact", head: true });
    if (error) return reply(502, { ok: false, error: "voucher_db_unreachable", code: error.code });
    return reply(200, {
      ok: true,
      bridge: "xiaoe-voucher-bridge",
      project_ref: PROJECT_REF,
      profile: "engineering_super_admin_v1",
      actions: [...ACTIONS],
    });
  }

  if (action === "rpc") {
    const fn = typeof body.function === "string" ? body.function.trim() : "";
    if (!fn) return reply(400, { ok: false, error: "function_required" });
    const args = isRecord(body.args) ? body.args : {};
    const { data, error } = await admin.rpc(fn, args);
    if (error) return reply(400, { ok: false, action, result: { code: error.code, message: error.message, details: error.details, hint: error.hint } });
    return reply(200, { ok: true, action, result: data });
  }

  const table = typeof body.table === "string" ? body.table.trim() : "";
  if (!table || !/^[A-Za-z_][A-Za-z0-9_]*$/.test(table)) return reply(400, { ok: false, error: "valid_table_required" });

  if (action === "read") {
    const columns = typeof body.select === "string" && body.select.trim() ? body.select.trim() : "*";
    let q = admin.from(table).select(columns).limit(cleanLimit(body.limit));
    if (isRecord(body.eq)) {
      for (const [key, value] of Object.entries(body.eq)) q = q.eq(key, value as never);
    }
    if (typeof body.order_by === "string" && body.order_by.trim()) {
      q = q.order(body.order_by.trim(), { ascending: body.ascending !== false });
    }
    const { data, error } = await q;
    if (error) return reply(400, { ok: false, action, result: { code: error.code, message: error.message, details: error.details, hint: error.hint } });
    return reply(200, { ok: true, action, result: data ?? [] });
  }

  if (action === "insert") {
    const row = body.row;
    if (!(isRecord(row) || Array.isArray(row))) return reply(400, { ok: false, error: "row_required" });
    const { data, error } = await admin.from(table).insert(row as never).select();
    if (error) return reply(400, { ok: false, action, result: { code: error.code, message: error.message, details: error.details, hint: error.hint } });
    return reply(200, { ok: true, action, result: data ?? [] });
  }

  if (action === "upsert") {
    const row = body.row;
    if (!(isRecord(row) || Array.isArray(row))) return reply(400, { ok: false, error: "row_required" });
    const onConflict = typeof body.on_conflict === "string" ? body.on_conflict.trim() : undefined;
    const { data, error } = await admin.from(table).upsert(row as never, onConflict ? { onConflict } : undefined).select();
    if (error) return reply(400, { ok: false, action, result: { code: error.code, message: error.message, details: error.details, hint: error.hint } });
    return reply(200, { ok: true, action, result: data ?? [] });
  }

  if (action === "update") {
    const patch = body.patch;
    if (!isRecord(patch)) return reply(400, { ok: false, error: "patch_required" });
    if (!isRecord(body.eq) || Object.keys(body.eq).length === 0) return reply(400, { ok: false, error: "update_filter_required" });
    let q = admin.from(table).update(patch as never);
    for (const [key, value] of Object.entries(body.eq)) q = q.eq(key, value as never);
    const { data, error } = await q.select();
    if (error) return reply(400, { ok: false, action, result: { code: error.code, message: error.message, details: error.details, hint: error.hint } });
    return reply(200, { ok: true, action, result: data ?? [] });
  }

  if (action === "delete") {
    if (!isRecord(body.eq) || Object.keys(body.eq).length === 0) return reply(400, { ok: false, error: "delete_filter_required" });
    let q = admin.from(table).delete();
    for (const [key, value] of Object.entries(body.eq)) q = q.eq(key, value as never);
    const { data, error } = await q.select();
    if (error) return reply(400, { ok: false, action, result: { code: error.code, message: error.message, details: error.details, hint: error.hint } });
    return reply(200, { ok: true, action, result: data ?? [] });
  }

  return reply(400, { ok: false, error: "unsupported_action", action });
});
