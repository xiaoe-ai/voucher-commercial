export type BridgeKeyConfig = {
  secret: string;
  enabled: boolean;
  capabilities: string[];
};

export type BridgeKeyMap = Record<string, BridgeKeyConfig>;

const enc = new TextEncoder();

export function bytesToHex(bytes: Uint8Array): string {
  return [...bytes].map((b) => b.toString(16).padStart(2, "0")).join("");
}

export async function sha256Hex(input: string): Promise<string> {
  const digest = await crypto.subtle.digest("SHA-256", enc.encode(input));
  return bytesToHex(new Uint8Array(digest));
}

export async function hmacSha256Hex(secret: string, message: string): Promise<string> {
  const key = await crypto.subtle.importKey(
    "raw",
    enc.encode(secret),
    { name: "HMAC", hash: "SHA-256" },
    false,
    ["sign"],
  );
  const signature = await crypto.subtle.sign("HMAC", key, enc.encode(message));
  return bytesToHex(new Uint8Array(signature));
}

export function timingSafeEqualHex(a: string, b: string): boolean {
  const x = a.trim().toLowerCase();
  const y = b.trim().toLowerCase();
  if (!/^[0-9a-f]+$/.test(x) || !/^[0-9a-f]+$/.test(y) || x.length !== y.length) return false;
  let diff = 0;
  for (let i = 0; i < x.length; i++) diff |= x.charCodeAt(i) ^ y.charCodeAt(i);
  return diff === 0;
}

export function parseBridgeKeys(raw: string): BridgeKeyMap {
  if (!raw.trim()) return {};
  const parsed = JSON.parse(raw) as Record<string, unknown>;
  const out: BridgeKeyMap = {};
  for (const [keyId, value] of Object.entries(parsed)) {
    if (!/^[A-Za-z0-9._-]{1,64}$/.test(keyId) || !value || typeof value !== "object") continue;
    const v = value as Record<string, unknown>;
    const secret = typeof v.secret === "string" ? v.secret : "";
    const capabilities = Array.isArray(v.capabilities) ? v.capabilities.map(String) : [];
    const enabled = v.enabled !== false;
    if (secret.length >= 32) out[keyId] = { secret, capabilities, enabled };
  }
  return out;
}

export function capabilityForAction(action: string): string | null {
  if (action === "health" || action === "read" || action === "oauth_status") return "read";
  if (["insert", "update", "upsert", "delete", "rpc", "oauth_authorize_url"].includes(action)) return "write";
  if (action.startsWith("auth_")) return "auth_admin";
  if (action.startsWith("storage_")) return "storage_admin";
  if (action === "management_call") return "management";
  if (action === "sql_query" || action === "sql_execute") return "sql";
  return null;
}

export function hasCapability(config: BridgeKeyConfig, action: string): boolean {
  const required = capabilityForAction(action);
  return !!required && config.enabled && config.capabilities.includes(required);
}

export function canonicalRequest(method: string, action: string, timestamp: string, nonce: string, bodyHash: string): string {
  return `${method.toUpperCase()}\n${action}\n${timestamp}\n${nonce}\n${bodyHash}`;
}

export function timestampWithinWindow(timestamp: string, nowMs: number, windowSeconds = 300): boolean {
  if (!/^\d{10,13}$/.test(timestamp)) return false;
  const n = Number(timestamp);
  if (!Number.isFinite(n)) return false;
  const tsMs = timestamp.length === 10 ? n * 1000 : n;
  return Math.abs(nowMs - tsMs) <= windowSeconds * 1000;
}
