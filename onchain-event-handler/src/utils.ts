/**
 * Utility functions for webhook processing
 */

import { createPublicClient, http, recoverAddress } from "viem";
import { celo } from "viem/chains";
import config from "./config";
import { EVENT_SIGNATURES, MULTISIGS, SECURITY_EVENTS } from "./constants";
import type { DiscordEmbedField, QuickNodeDecodedLog } from "./types";

/**
 * Block explorer configuration for Celo network
 */
export const BLOCK_EXPLORER = {
  BASE_URL: "https://celoscan.io",
  tx: (hash: string) => `https://celoscan.io/tx/${hash}`,
  block: (number: string) => `https://celoscan.io/block/${number}`,
  address: (addr: string) => `https://celoscan.io/address/${addr}`,
} as const;

/**
 * Get event name from log topic0
 */
export function getEventName(topic0: string): string | null {
  return EVENT_SIGNATURES[topic0] || null;
}

/**
 * Get multisig key from contract address
 */
export function getMultisigKey(address: string): string | null {
  const normalizedAddress = address.toLowerCase();
  return MULTISIGS[normalizedAddress] || null;
}

/**
 * Determine if event is a security event
 */
export function isSecurityEvent(eventName: string): boolean {
  return SECURITY_EVENTS.includes(
    eventName as (typeof SECURITY_EVENTS)[number],
  );
}

/**
 * Get Discord webhook URL from environment variables
 * All multisigs share the same two webhook URLs
 */
export function getWebhookUrl(
  _multisigKey: string,
  channelType: "alerts" | "events",
): string | null {
  // All multisigs use the same webhook URLs
  const envKey =
    `DISCORD_WEBHOOK_${channelType.toUpperCase()}` as keyof typeof config;

  const webhookUrl = config[envKey];
  if (typeof webhookUrl === "string") {
    return webhookUrl;
  }

  return null;
}

/**
 * Extract signer addresses from Safe transaction signatures
 * Safe signatures can be:
 * - Standard ECDSA signatures (65 bytes: r, s, v) where v is 27 or 28
 * - Contract signatures (v = 0 or 1, followed by 32 bytes address + 32 bytes data = 129 bytes total)
 *
 * Safe contract signature format:
 * - v = 0 or 1 (not 27/28) indicates contract signature
 * - Next 32 bytes: address (right-padded, address in last 20 bytes)
 * - Next 32 bytes: signature data
 *
 * @param signatures - Hex string of concatenated signatures
 * @param txHash - Safe transaction hash (EIP-712 hash) that was signed
 * @returns Array of signer addresses
 */
async function extractSignersFromSignatures(
  signatures: string,
  txHash: string,
): Promise<string[]> {
  const signers: string[] = [];

  try {
    // Remove 0x prefix if present
    const sigBytes = signatures.startsWith("0x")
      ? signatures.slice(2)
      : signatures;

    let i = 0;
    while (i < sigBytes.length) {
      // Check if we have at least 65 bytes (130 hex chars) for a signature
      if (i + 130 > sigBytes.length) break;

      const sigHex = sigBytes.slice(i, i + 130);
      const r = ("0x" + sigHex.slice(0, 64)) as `0x${string}`;
      const s = ("0x" + sigHex.slice(64, 128)) as `0x${string}`;
      const vByte = parseInt(sigHex.slice(128, 130), 16);

      // Check if r contains an address (contract signature variant where address is in r)
      // This happens when r starts with many zeros and contains an address, and s is all zeros
      // This check must come BEFORE the standard contract signature check
      const rHex = sigHex.slice(0, 64);
      const sHex = sigHex.slice(64, 128);
      // Check if r has 24 leading zeros (12 hex chars) followed by an address, and s is all zeros
      if (
        rHex.startsWith("000000000000000000000000") &&
        sHex ===
          "0000000000000000000000000000000000000000000000000000000000000000"
      ) {
        // Extract address from r (last 40 hex chars)
        const address = "0x" + rHex.slice(24);
        if (address !== "0x0000000000000000000000000000000000000000") {
          signers.push(address.toLowerCase());
        }
        // Move to next signature
        i += 130;
        continue;
      }

      // Check if this is a contract signature (v = 0 or 1, not 27/28)
      // Contract signatures are 129 bytes: 65 bytes (r, s, v) + 32 bytes (address) + 32 bytes (data)
      if ((vByte === 0 || vByte === 1) && i + 258 <= sigBytes.length) {
        // Contract signature: extract the address directly
        // Address is in bytes 65-96 (32 bytes), right-padded, address in last 20 bytes
        const addressHex = sigBytes.slice(i + 130, i + 194); // 64 hex chars = 32 bytes
        // Address is in the last 40 hex chars (20 bytes)
        const address = "0x" + addressHex.slice(24); // Extract last 40 chars (20 bytes)
        if (address !== "0x0000000000000000000000000000000000000000") {
          signers.push(address.toLowerCase());
        }
        // Skip the full contract signature: 65 bytes (sig) + 32 bytes (addr) + 32 bytes (data) = 129 bytes = 258 hex chars
        i += 258;
        continue;
      }

      // Standard ECDSA signature recovery (v = 27 or 28)
      if (vByte === 27 || vByte === 28) {
        try {
          // viem's recoverAddress expects v as 0 or 1 (recovery id)
          const v: 0 | 1 = vByte === 27 ? 0 : 1;

          // Construct signature as hex string: r + s + v (v as 0 or 1)
          const signatureHex = (r +
            s.slice(2) +
            v.toString(16).padStart(2, "0")) as `0x${string}`;

          // Safe's txHash is the EIP-712 hash of the transaction
          // Safe signs the EIP-712 hash directly (not with EIP-191 encoding)
          // The signature is over the EIP-712 hash itself
          const recoveredAddress = await recoverAddress({
            hash: txHash as `0x${string}`,
            signature: signatureHex,
          });

          signers.push(recoveredAddress.toLowerCase());
        } catch (error) {
          // If recovery fails, skip this signature
          console.warn(
            `Failed to recover address from signature at offset ${i}:`,
            error,
          );
        }
      } else {
        // Unknown v value, skip this signature
        console.warn(
          `Unknown v value ${vByte} at offset ${i}, skipping signature`,
        );
      }

      // Move to next signature (65 bytes = 130 hex chars)
      i += 130;
    }
  } catch (error) {
    console.warn("Failed to extract signers from signatures:", error);
  }

  return signers;
}

/**
 * Extract event data from decoded log
 * Extracts relevant information from decoded log parameters based on the Safe event type
 * @param eventName - The Safe event name (e.g., "AddedOwner", "ExecutionSuccess")
 * @param log - QuickNode decoded log entry containing decoded event parameters
 * @param txHash - Optional Safe transaction hash for extracting signers
 * @returns Array of Discord embed fields with event parameters
 */
export async function decodeEventData(
  eventName: string,
  log: QuickNodeDecodedLog,
  txHash?: string,
): Promise<DiscordEmbedField[]> {
  const fields: DiscordEmbedField[] = [];

  switch (eventName) {
    case "AddedOwner":
    case "RemovedOwner":
      if (log.owner && typeof log.owner === "string") {
        fields.push({
          name: "Owner",
          value: log.owner,
          inline: false,
        });
      }
      break;

    case "ChangedThreshold":
      if (log.threshold !== undefined) {
        const threshold =
          typeof log.threshold === "string"
            ? parseInt(log.threshold, 10)
            : Number(log.threshold);
        fields.push({
          name: "New Threshold",
          value: threshold.toString(),
          inline: false,
        });
      }
      break;

    case "ChangedFallbackHandler":
      if (log.handler && typeof log.handler === "string") {
        fields.push({
          name: "Fallback Handler",
          value: log.handler,
          inline: false,
        });
      }
      break;

    case "EnabledModule":
    case "DisabledModule":
      if (log.module && typeof log.module === "string") {
        fields.push({
          name: "Module",
          value: log.module,
          inline: false,
        });
      }
      break;

    case "ChangedGuard":
      if (log.guard && typeof log.guard === "string") {
        fields.push({
          name: "Guard",
          value: log.guard,
          inline: false,
        });
      }
      break;

    case "ExecutionSuccess":
    case "ExecutionFailure":
      if (log.payment !== undefined) {
        try {
          const payment =
            typeof log.payment === "string"
              ? BigInt(log.payment)
              : BigInt(Number(log.payment));
          const paymentInCelo = Number(payment) / 1e18;
          if (paymentInCelo > 0) {
            fields.push({
              name: "Payment",
              value: `${paymentInCelo.toFixed(6)} CELO`,
              inline: false,
            });
          }
        } catch {
          // Ignore parsing errors
        }
      }
      break;

    case "ApproveHash":
      if (log.hash && typeof log.hash === "string") {
        fields.push({
          name: "Hash",
          value: log.hash,
          inline: false,
        });
      }
      if (log.owner && typeof log.owner === "string") {
        fields.push({
          name: "Owner",
          value: log.owner,
          inline: false,
        });
      }
      break;

    case "SignMsg":
      if (log.msgHash && typeof log.msgHash === "string") {
        fields.push({
          name: "Message Hash",
          value: log.msgHash,
          inline: false,
        });
      }
      break;

    case "SafeReceived":
      if (log.sender && typeof log.sender === "string") {
        fields.push({
          name: "Sender",
          value: log.sender,
          inline: false,
        });
      }
      if (log.value !== undefined) {
        try {
          const value =
            typeof log.value === "string"
              ? BigInt(log.value)
              : BigInt(Number(log.value));
          const valueInCelo = Number(value) / 1e18;
          fields.push({
            name: "Value",
            value: `${valueInCelo.toFixed(6)} CELO`,
            inline: false,
          });
        } catch {
          // Ignore parsing errors
        }
      }
      break;

    case "SafeMultiSigTransaction":
      // This is a custom event from QuickNode, include relevant fields
      if (log.to && typeof log.to === "string") {
        fields.push({
          name: "To",
          value: `[${log.to}](${BLOCK_EXPLORER.address(log.to)})`,
          inline: false,
        });
      }
      if (log.value && typeof log.value === "string") {
        try {
          const value = BigInt(log.value);
          const valueInCelo = Number(value) / 1e18;
          if (valueInCelo > 0) {
            fields.push({
              name: "Value",
              value: `${valueInCelo.toFixed(6)} CELO`,
              inline: false,
            });
          }
        } catch {
          // Ignore parsing errors
        }
      }
      // Extract signers from signatures if txHash is available
      if (txHash && log.signatures && typeof log.signatures === "string") {
        const signers = await extractSignersFromSignatures(
          log.signatures,
          txHash,
        );
        if (signers.length > 0) {
          const signerLinks = signers
            .map(
              (addr) =>
                `[${addr.slice(0, 6)}...${addr.slice(-4)}](${BLOCK_EXPLORER.address(addr)})`,
            )
            .join(", ");
          fields.push({
            name: "Signers",
            value: signerLinks,
            inline: true,
          });
        }
      }
      // Get executor address (who actually executed the transaction)
      if (log.transactionHash && typeof log.transactionHash === "string") {
        const executor = await getTransactionExecutor(log.transactionHash);
        if (executor) {
          fields.push({
            name: "Executed by",
            value: `[${executor.slice(0, 6)}...${executor.slice(-4)}](${BLOCK_EXPLORER.address(executor)})`,
            inline: true,
          });
        }
      }
      break;
  }

  return fields;
}

/**
 * Format transaction hash for display
 */
export function formatTxHash(hash: string): string {
  return `${hash.slice(0, 10)}...`;
}

/**
 * Get the executor address (from) of a transaction
 * @param transactionHash - The transaction hash to look up
 * @returns The executor address, or null if not found/error
 */
async function getTransactionExecutor(
  transactionHash: string,
): Promise<string | null> {
  try {
    // Use public Celo RPC endpoint
    // In production, you might want to use QuickNode's RPC endpoint if available
    const publicClient = createPublicClient({
      chain: celo,
      transport: http("https://forno.celo.org"),
    });

    const tx = await publicClient.getTransaction({
      hash: transactionHash as `0x${string}`,
    });

    return tx.from.toLowerCase();
  } catch (error) {
    console.warn(
      `Failed to fetch transaction executor for ${transactionHash}:`,
      error,
    );
    return null;
  }
}

/**
 * Get multisig display name
 */
export function getMultisigName(multisigKey: string): string {
  const names: Record<string, string> = {
    "mento-labs": "Mento Labs Multisig",
    reserve: "Reserve Multisig",
  };
  return names[multisigKey] || multisigKey;
}

/**
 * Get chain info from multisig config
 */
export function getMultisigChainInfo(multisigKey: string): {
  chain: string;
} | null {
  try {
    const multisigConfigJson = config.MULTISIG_CONFIG;
    const multisigConfig = JSON.parse(multisigConfigJson) as Record<
      string,
      { address: string; name: string; chain: string }
    >;

    const multisigInfo = multisigConfig[multisigKey];
    if (!multisigInfo) {
      return null;
    }

    return {
      chain: multisigInfo.chain,
    };
  } catch {
    return null;
  }
}

/**
 * Build Safe UI URL for a transaction
 * Format: https://app.safe.global/transactions/tx?safe={chain}:{address}&id=multisig_{address}_{txHash}
 */
export function getSafeUiUrl(
  safeAddress: string,
  txHash: string,
  multisigKey: string,
): string {
  const chainInfo = getMultisigChainInfo(multisigKey);

  if (chainInfo) {
    // Use chain:address format for safe parameter
    // Use multisig_{address}_{txHash} format for id parameter
    const normalizedAddress = safeAddress.toLowerCase();
    return `https://app.safe.global/transactions/tx?safe=${chainInfo.chain}:${normalizedAddress}&id=multisig_${normalizedAddress}_${txHash}`;
  }

  // Fallback to simple format if chain info not available
  const normalizedAddress = safeAddress.toLowerCase();
  return `https://app.safe.global/transactions/tx?safe=${normalizedAddress}&id=multisig_${normalizedAddress}_${txHash}`;
}
