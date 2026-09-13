import {
  canonicalRequest,
  capabilityForAction,
  hasCapability,
  hmacSha256Hex,
  parseBridgeKeys,
  sha256Hex,
  timestampWithinWindow,
  timingSafeEqualHex,
} from "./security.ts";

function assert(condition: unknown, message: string): asserts condition {
  if (!condition) throw new Error(message);
}

Deno.test("canonical signing roundtrip", async () => {
  const body = JSON.stringify({ action: "read", table: "branches" });
  const hash = await sha256Hex(body);
  const canonical = canonicalRequest("POST", "read", "1789300000", "nonce-1", hash);
  const sig = await hmacSha256Hex("0123456789abcdef0123456789abcdef", canonical);
  assert(sig.length === 64, "expected sha256 hex signature");
  assert(timingSafeEqualHex(sig, sig), "signature should match itself");
  assert(!timingSafeEqualHex(sig, "00".repeat(32)), "modified signature must fail");
});

Deno.test("body tamper changes signature", async () => {
  const secret = "0123456789abcdef0123456789abcdef";
  const h1 = await sha256Hex('{"action":"read"}');
  const h2 = await sha256Hex('{"action":"delete"}');
  const s1 = await hmacSha256Hex(secret, canonicalRequest("POST", "read", "1789300000", "nonce", h1));
  const s2 = await hmacSha256Hex(secret, canonicalRequest("POST", "read", "1789300000", "nonce", h2));
  assert(!timingSafeEqualHex(s1, s2), "body tamper must alter signature");
});

Deno.test("timestamp window rejects expired and future requests", () => {
  const now = 1_789_300_000_000;
  assert(timestampWithinWindow("1789300000", now, 300), "current timestamp should pass");
  assert(!timestampWithinWindow("1789299000", now, 300), "expired timestamp should fail");
  assert(!timestampWithinWindow("1789301000", now, 300), "future timestamp outside skew should fail");
});

Deno.test("capabilities are default deny", () => {
  assert(capabilityForAction("read") === "read", "read mapping");
  assert(capabilityForAction("sql_execute") === "sql", "sql mapping");
  assert(capabilityForAction("unknown_action") === null, "unknown action must deny");
  const cfg = { secret: "x".repeat(32), enabled: true, capabilities: ["read", "write"] };
  assert(hasCapability(cfg, "read"), "read allowed");
  assert(!hasCapability(cfg, "auth_delete_user"), "auth admin denied");
  assert(!hasCapability(cfg, "management_call"), "management denied");
  assert(!hasCapability(cfg, "sql_execute"), "sql denied");
});

Deno.test("key parser ignores malformed and short secrets", () => {
  const keys = parseBridgeKeys(JSON.stringify({
    good: { secret: "a".repeat(32), capabilities: ["read"], enabled: true },
    short: { secret: "tiny", capabilities: ["read"] },
    disabled: { secret: "b".repeat(32), capabilities: ["read"], enabled: false },
  }));
  assert(!!keys.good, "valid key should load");
  assert(!keys.short, "short secret must be rejected");
  assert(!!keys.disabled && keys.disabled.enabled === false, "disabled key should remain explicitly disabled");
});
