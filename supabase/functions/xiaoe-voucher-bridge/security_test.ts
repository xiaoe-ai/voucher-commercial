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

Deno.test("signature binds method action nonce and body", async () => {
  const secret = "0123456789abcdef0123456789abcdef";
  const ts = "1789300000";
  const bodyHash = await sha256Hex('{"action":"read","table":"branches"}');
  const base = await hmacSha256Hex(secret, canonicalRequest("POST", "read", ts, "nonce-123", bodyHash));
  const variants = [
    canonicalRequest("GET", "read", ts, "nonce-123", bodyHash),
    canonicalRequest("POST", "delete", ts, "nonce-123", bodyHash),
    canonicalRequest("POST", "read", ts, "nonce-456", bodyHash),
    canonicalRequest("POST", "read", ts, "nonce-123", await sha256Hex('{"action":"read","table":"partners"}')),
  ];
  for (const variant of variants) {
    const sig = await hmacSha256Hex(secret, variant);
    assert(!timingSafeEqualHex(base, sig), "changing a canonical component must invalidate signature");
  }
});

Deno.test("body tamper changes signature", async () => {
  const secret = "0123456789abcdef0123456789abcdef";
  const h1 = await sha256Hex('{"action":"read"}');
  const h2 = await sha256Hex('{"action":"delete"}');
  const s1 = await hmacSha256Hex(secret, canonicalRequest("POST", "read", "1789300000", "nonce", h1));
  const s2 = await hmacSha256Hex(secret, canonicalRequest("POST", "read", "1789300000", "nonce", h2));
  assert(!timingSafeEqualHex(s1, s2), "body tamper must alter signature");
});

Deno.test("timestamp window rejects expired future and malformed requests", () => {
  const now = 1_789_300_000_000;
  assert(timestampWithinWindow("1789300000", now, 300), "current timestamp should pass");
  assert(timestampWithinWindow("1789300000000", now, 300), "current millisecond timestamp should pass");
  assert(!timestampWithinWindow("1789299000", now, 300), "expired timestamp should fail");
  assert(!timestampWithinWindow("1789301000", now, 300), "future timestamp outside skew should fail");
  assert(!timestampWithinWindow("not-a-time", now, 300), "non numeric timestamp must fail");
  assert(!timestampWithinWindow("12345678901", now, 300), "11 digit timestamp must fail");
});

Deno.test("capabilities are default deny and privilege separated", () => {
  assert(capabilityForAction("read") === "read", "read mapping");
  assert(capabilityForAction("insert") === "write", "write mapping");
  assert(capabilityForAction("auth_delete_user") === "auth_admin", "auth admin mapping");
  assert(capabilityForAction("storage_delete_bucket") === "storage_admin", "storage admin mapping");
  assert(capabilityForAction("management_call") === "management", "management mapping");
  assert(capabilityForAction("sql_execute") === "sql", "sql mapping");
  assert(capabilityForAction("unknown_action") === null, "unknown action must deny");

  const readOnly = { secret: "x".repeat(32), enabled: true, capabilities: ["read"] };
  assert(hasCapability(readOnly, "read"), "read key may read");
  assert(!hasCapability(readOnly, "insert"), "read key must not write");
  assert(!hasCapability(readOnly, "auth_delete_user"), "read key must not administer auth");
  assert(!hasCapability(readOnly, "management_call"), "read key must not call management plane");
  assert(!hasCapability(readOnly, "sql_execute"), "read key must not execute SQL");

  const writeOnly = { secret: "y".repeat(32), enabled: true, capabilities: ["write"] };
  assert(hasCapability(writeOnly, "update"), "write key may update");
  assert(!hasCapability(writeOnly, "auth_create_user"), "write key must not become auth admin");
  assert(!hasCapability(writeOnly, "management_call"), "write key must not call management plane");
  assert(!hasCapability(writeOnly, "sql_query"), "write key must not gain SQL capability");
});

Deno.test("disabled keys are denied even when capability is present", () => {
  const disabled = { secret: "z".repeat(32), enabled: false, capabilities: ["read", "write", "sql"] };
  assert(!hasCapability(disabled, "read"), "disabled key must not read");
  assert(!hasCapability(disabled, "update"), "disabled key must not write");
  assert(!hasCapability(disabled, "sql_execute"), "disabled key must not execute SQL");
});

Deno.test("key parser ignores malformed and short secrets", () => {
  const keys = parseBridgeKeys(JSON.stringify({
    good: { secret: "a".repeat(32), capabilities: ["read"], enabled: true },
    short: { secret: "tiny", capabilities: ["read"] },
    disabled: { secret: "b".repeat(32), capabilities: ["read"], enabled: false },
    "bad key id!": { secret: "c".repeat(32), capabilities: ["read"] },
  }));
  assert(!!keys.good, "valid key should load");
  assert(!keys.short, "short secret must be rejected");
  assert(!!keys.disabled && keys.disabled.enabled === false, "disabled key should remain explicitly disabled");
  assert(!keys["bad key id!"], "malformed key id must be ignored");
});
