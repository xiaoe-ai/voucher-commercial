export type BridgeCapability = "read" | "write" | "auth_admin" | "storage_admin" | "management" | "sql";

export type BridgeKeyConfig = {
  secret: string;
  capabilities: Set<BridgeCapability>;
  enabled: boolean;
};

export type BridgeSecurityDeps = {
  nowMs?: () => number;
  consumeNonce: (keyId: string, nonce: string, seenAtIso: string) => Promise<boolean>;
};

const textEncoder = new TextEncoder();

export const ACTION_CAPABILITY: Record<string, BridgeCapability> = {
  health: "read",
  oauth_status: "read",
  oauth_authorize_url: "management",
  read: "read",
  insert: "write",
  update: "write",
  upsert: "write",
  delete: "write",
  rpc: "write",
  sql_query: "sql",
  sql_execute: "sql",
  auth_list_users: "auth_admin",
  auth_get_user: "auth_admin",
  auth_create_user: "auth_admin",
  auth_update_user: "auth_admin",
  auth_delete_user: "auth_admin",
  storage_list_buckets: "storage_admin",
  storage_create_bucket: "storage_admin",
  storage_update_bucket: "storage_admin",
  storage_delete_bucket: "storage_admin",
  storage_list_objects: "storage_admin",
  storage_delete_objects: "storage_admin",
  management_call: "management",
};

export function parseCapabilities(raw: string): Set<BridgeCapability> {
  const allowed = new Set<BridgeCapability>(["read", "write", "auth_admin", "storage_admin", "management", "sql"]);
  return new Set(raw.split(",").map((v) => v.trim()).filter((v): v is BridgeCapability => allowed.has(v as BridgeCapability)));
}

export function loadKeyRingFromEnv(getEnv: (name: string) => string | undefined): Map<string, BridgeKeyConfig> {
  const ring = new Map<string, BridgeKeyConfig>();
  for (let i = 1; i <= 8; i++) {
    const keyId = (getEnv(`XIAOE_BRIDGE_KEY_${i}_ID`) ?? "").trim();
    const secret = getEnv(`XIAOE_BRIDGE_KEY_${i}_SECRET`) ?? "";
    const caps = getEnv(`XIAOE_BRIDGE_KEY_${i}_CAPABILITIES`) ?? "";
    const enabled = (getEnv(`XIAOE_BRIDGE_KEY_${i}_ENABLED`) ?? "true").toLowerCase() !== "false";
    if (keyId && secret) ring.set(keyId, { secret, capabilities: parseCapabilities(caps), enabled });
  }
  return ring;
}

export async function sha256Hex(bytes: Uint8Array): Promise<string> {
  const digest = new Uint8Array(await crypto.subtle.digest("SHA-256", bytes));
  return [...digest].map((b) => b.toString(16).padStart(2, "0")).join("");
}

export async function hmacHex(secret: string, message: string): Promise<string> {
  const key = await crypto.subtle.importKey("raw", textEncoder.encode(secret), { name: "HMAC", hash: "SHA-256" }, false, ["sign"]);
  const sig = new Uint8Array(await crypto.subtle.sign("HMAC", key, textEncoder.encode(message)));
  return [...sig].map((b) => b.toString(16).padStart(2, "0")).join("");
}

export function constantTimeEqualHex(a: string, b: string): boolean {
  if (!/^[0-9a-f]+$/i.test(a) || !/^[0-9a-f]+$/i.test(b) || a.length !== b.length) return false;
  let diff = 0;
  for (let i = 0; i < a.length; i++) diff |= a.charCodeAt(i) ^ b.charCodeAt(i);
  return diff === 0;
}

export function capabilityForAction(action: string): BridgeCapability | null {
  return ACTION_CAPABILITY[action] ?? null;
}

export async function verifySignedBridgeRequest(
  req: Request,
  action: string,
  rawBody: Uint8Array,
  keyRing: Map<string, BridgeKeyConfig>,
  deps: BridgeSecurityDeps,
  replayWindowMs = 5 * 60 * 1000,
): Promise<{ ok: true; keyId: string; capability: BridgeCapability } | { ok: false; status: number; error: string }> {
  const keyId = (req.headers.get("x-xiaoe-key-id") ?? "").trim();
  const tsRaw = (req.headers.get("x-xiaoe-timestamp") ?? "").trim();
  const nonce = (req.headers.get("x-xiaoe-nonce") ?? "").trim();
  const suppliedSig = (req.headers.get("x-xiaoe-signature") ?? "").trim().toLowerCase();
  if (!keyId || !tsRaw || !nonce || !suppliedSig) return { ok: false, status: 401, error: "signed bridge headers required" };
  if (!/^[A-Za-z0-9._-]{1,64}$/.test(keyId)) return { ok: false, status: 401, error: "invalid key id" };
  if (!/^[A-Za-z0-9._~-]{16,128}$/.test(nonce)) return { ok: false, status: 401, error: "invalid nonce" };

  const key = keyRing.get(keyId);
  if (!key || !key.enabled) return { ok: false, status: 401, error: "unknown or disabled key" };

  const timestampMs = Number(tsRaw);
  const nowMs = (deps.nowMs ?? Date.now)();
  if (!Number.isFinite(timestampMs) || Math.abs(nowMs - timestampMs) > replayWindowMs) {
    return { ok: false, status: 401, error: "timestamp outside replay window" };
  }

  const capability = capabilityForAction(action);
  if (!capability) return { ok: false, status: 403, error: "unsupported action" };
  if (!key.capabilities.has(capability)) return { ok: false, status: 403, error: "capability denied" };

  const bodyHash = await sha256Hex(rawBody);
  const canonical = `${req.method.toUpperCase()}\n${action}\n${tsRaw}\n${nonce}\n${bodyHash}`;
  const expectedSig = await hmacHex(key.secret, canonical);
  if (!constantTimeEqualHex(suppliedSig, expectedSig)) return { ok: false, status: 401, error: "invalid signature" };

  const consumed = await deps.consumeNonce(keyId, nonce, new Date(timestampMs).toISOString());
  if (!consumed) return { ok: false, status: 409, error: "replayed nonce" };
  return { ok: true, keyId, capability };
}
