import {
  capabilityForAction,
  hmacHex,
  sha256Hex,
  verifySignedBridgeRequest,
  type BridgeKeyConfig,
} from "./bridge-security.ts";

function assert(cond: unknown, msg = "assertion failed"): asserts cond {
  if (!cond) throw new Error(msg);
}

const enc = new TextEncoder();
const now = 1_800_000_000_000;
const secret = "test-secret-1234567890";
const keyId = "test-read";
const ring = new Map<string, BridgeKeyConfig>([
  [keyId, { secret, enabled: true, capabilities: new Set(["read"]) }],
]);

async function signedRequest(action: string, bodyText: string, nonce: string, timestamp = now) {
  const body = enc.encode(bodyText);
  const bodyHash = await sha256Hex(body);
  const canonical = `POST\n${action}\n${timestamp}\n${nonce}\n${bodyHash}`;
  const sig = await hmacHex(secret, canonical);
  const req = new Request("https://example.test/functions/v1/xiaoe-voucher-bridge", {
    method: "POST",
    headers: {
      "x-xiaoe-key-id": keyId,
      "x-xiaoe-timestamp": String(timestamp),
      "x-xiaoe-nonce": nonce,
      "x-xiaoe-signature": sig,
    },
    body: bodyText,
  });
  return { req, body };
}

Deno.test("valid signed read succeeds", async () => {
  const { req, body } = await signedRequest("read", '{"action":"read"}', "nonce-valid-0001");
  const out = await verifySignedBridgeRequest(req, "read", body, ring, {
    nowMs: () => now,
    consumeNonce: async () => true,
  });
  assert(out.ok === true);
});

Deno.test("tampered body fails signature", async () => {
  const { req } = await signedRequest("read", '{"action":"read"}', "nonce-tamper-0001");
  const out = await verifySignedBridgeRequest(req, "read", enc.encode('{"action":"read","x":1}'), ring, {
    nowMs: () => now,
    consumeNonce: async () => true,
  });
  assert(out.ok === false && out.status === 401);
});

Deno.test("expired timestamp fails", async () => {
  const { req, body } = await signedRequest("read", '{"action":"read"}', "nonce-expired-0001", now - 600_000);
  const out = await verifySignedBridgeRequest(req, "read", body, ring, {
    nowMs: () => now,
    consumeNonce: async () => true,
  });
  assert(out.ok === false && out.error.includes("timestamp"));
});

Deno.test("duplicate nonce fails", async () => {
  const { req, body } = await signedRequest("read", '{"action":"read"}', "nonce-replay-0001");
  const out = await verifySignedBridgeRequest(req, "read", body, ring, {
    nowMs: () => now,
    consumeNonce: async () => false,
  });
  assert(out.ok === false && out.status === 409);
});

Deno.test("read key cannot write", async () => {
  const { req, body } = await signedRequest("insert", '{"action":"insert"}', "nonce-cap-0000001");
  const out = await verifySignedBridgeRequest(req, "insert", body, ring, {
    nowMs: () => now,
    consumeNonce: async () => true,
  });
  assert(out.ok === false && out.status === 403);
});

Deno.test("unknown action is default deny", () => {
  assert(capabilityForAction("dangerous_future_action") === null);
});
