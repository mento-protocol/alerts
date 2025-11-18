/**
 * QuickNode webhook signature verification
 *
 * QuickNode signs webhooks using: HMAC-SHA256(secret, nonce + timestamp + payload)
 * Reference: https://www.quicknode.com/guides/quicknode-products/streams/validating-incoming-streams-webhook-messages
 */

import crypto from "crypto";

/**
 * Verify QuickNode webhook signature
 *
 * @param secret - The secret key used for signing (from QuickNode webhook configuration)
 * @param payload - The raw request body as a string
 * @param nonce - The nonce from x-qn-nonce header
 * @param timestamp - The timestamp from x-qn-timestamp header
 * @param givenSignature - The signature from x-qn-signature header
 * @returns true if signature is valid, false otherwise
 */
export function verifyQuickNodeSignature(
  secret: string,
  payload: string,
  nonce: string,
  timestamp: string,
  givenSignature: string,
): boolean {
  if (!secret || !nonce || !timestamp || !givenSignature) {
    return false;
  }

  // Concatenate signature inputs as strings (nonce + timestamp + payload)
  const signatureData = nonce + timestamp + payload;

  // Compute HMAC-SHA256 signature
  const hmac = crypto.createHmac("sha256", secret);
  hmac.update(signatureData);
  const computedSignature = hmac.digest("hex");

  // Use timing-safe comparison to prevent timing attacks
  return crypto.timingSafeEqual(
    hexToBytes(computedSignature),
    hexToBytes(givenSignature),
  );
}

/**
 * Helper to convert hex string to Uint8Array for timing-safe comparison
 *
 * We use this instead of Buffer to avoid type mismatches in newer @types/node versions,
 * which introduce stricter ArrayBufferLike checks that Buffer doesn't fully satisfy
 * (due to SharedArrayBuffer compatibility issues).
 *
 * @param hex - Hex string to convert
 * @returns Uint8Array representation of the hex string
 */
function hexToBytes(hex: string): Uint8Array {
  const bytes = new Uint8Array(hex.length / 2);
  for (let i = 0; i < bytes.length; i++) {
    bytes[i] = parseInt(hex.substring(i * 2, i * 2 + 2), 16);
  }
  return bytes;
}
