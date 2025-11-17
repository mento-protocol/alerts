/**
 * Constants for event signatures, multisig addresses, and configuration
 * Event signatures are extracted from the Safe contract ABI (single source of truth)
 * Multisig addresses are loaded from environment variables
 */

import keccak from "keccak";
import safeAbi from "../safe-abi.json";
import { config } from "./config";
import type {
  EventName,
  EventSignature,
  MultisigAddress,
  MultisigKey,
} from "./types";

/**
 * Security event names that should be routed to the alerts channel
 */
const SECURITY_EVENT_NAMES = new Set([
  "SafeSetup",
  "AddedOwner",
  "RemovedOwner",
  "ChangedThreshold",
  "ChangedFallbackHandler",
  "EnabledModule",
  "DisabledModule",
  "ChangedGuard",
]);

/**
 * Compute keccak256 hash of a string (for event signatures)
 */
function keccak256(input: string): string {
  const hash = keccak("keccak256").update(input).digest("hex");
  return `0x${hash}`;
}

/**
 * Extract event signatures from ABI and compute their hashes
 */
function extractEventSignatures() {
  const eventSignatures: Record<EventSignature, EventName> = {} as Record<
    EventSignature,
    EventName
  >;
  const securityEvents: EventName[] = [];

  for (const item of safeAbi) {
    if (item.type === "event" && item.name) {
      const eventName = item.name;
      const inputs = item.inputs || [];

      // Build signature string: EventName(type1,type2,...)
      const paramTypes = inputs
        .map((input: { type?: string }) => input?.type)
        .filter(
          (type: string | undefined): type is string =>
            typeof type === "string",
        );
      const signatureStr = `${eventName}(${paramTypes.join(",")})`;

      // Compute keccak256 hash
      const signatureHash = keccak256(signatureStr) as EventSignature;

      // Store mapping
      eventSignatures[signatureHash] = eventName;

      // Categorize
      if (SECURITY_EVENT_NAMES.has(eventName)) {
        securityEvents.push(eventName);
      }
    }
  }

  return { eventSignatures, securityEvents };
}

const { eventSignatures, securityEvents } = extractEventSignatures();

/**
 * Mapping of event signatures (topic0) to event names
 * Extracted from Safe contract ABI to ensure consistency
 */
export const EVENT_SIGNATURES: Record<EventSignature, EventName> =
  eventSignatures;

/**
 * Security events that should be routed to the alerts channel
 */
export const SECURITY_EVENTS: EventName[] = securityEvents;

/**
 * Mapping of multisig addresses to their keys
 * Loaded from MULTISIG_CONFIG JSON environment variable passed by Terraform
 */
export const MULTISIGS: Record<MultisigAddress, MultisigKey> = (() => {
  const multisigs: Record<MultisigAddress, MultisigKey> = {};

  // Load multisig config from JSON environment variable
  const multisigConfigJson = config.MULTISIG_CONFIG;

  try {
    const multisigConfig = JSON.parse(multisigConfigJson) as Record<
      string,
      { address: string; name: string; chain: string; chain_id: number }
    >;

    // Build mapping: address -> key (the key from the config map)
    for (const [key, multisigConfigItem] of Object.entries(multisigConfig)) {
      const normalizedAddress = multisigConfigItem.address.toLowerCase();
      multisigs[normalizedAddress] = key;
    }
  } catch (error) {
    throw new Error(
      `Failed to parse MULTISIG_CONFIG: ${error instanceof Error ? error.message : String(error)}`,
    );
  }

  // Validate that we have at least one multisig configured
  if (Object.keys(multisigs).length === 0) {
    // In local development, allow empty config
    if (process.env.NODE_ENV !== "production") {
      console.warn(
        "No multisig addresses configured. Using empty config for local development.",
      );
      return multisigs;
    }
    throw new Error(
      "No multisig addresses configured. Check MULTISIG_CONFIG environment variable.",
    );
  }

  return multisigs;
})();

/**
 * Color codes for Discord embeds
 */
export const DISCORD_COLORS = {
  ALERT: 0xff4757, // Red for security events
  EVENT: 0x5f27cd, // Purple for operational events
} as const;

/**
 * Emojis for Discord messages
 */
export const DISCORD_EMOJIS = {
  ALERT: "🚨",
  EVENT: "🔔",
} as const;
