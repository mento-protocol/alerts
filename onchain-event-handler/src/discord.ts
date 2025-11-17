/**
 * Discord message formatting and sending
 */

import axios, { AxiosError } from "axios";
import { DISCORD_COLORS, DISCORD_EMOJIS } from "./constants";
import type { DiscordMessage, QuickNodeDecodedLog } from "./types";
import {
  BLOCK_EXPLORER,
  decodeEventData,
  getMultisigName,
  getSafeUiUrl,
  isSecurityEvent,
} from "./utils";

/**
 * Format a Discord message from a log event
 * @param eventName - The Safe event name (e.g., "AddedOwner", "ExecutionSuccess")
 * @param log - QuickNode decoded log entry containing transaction data
 * @param multisigKey - Multisig identifier key (e.g., "mento-labs")
 * @param txHashMap - Map of transactionHash -> txHash from ExecutionSuccess events
 * @returns Formatted Discord message with embeds
 */
export async function formatDiscordMessage(
  eventName: string,
  log: QuickNodeDecodedLog,
  multisigKey: string,
  txHashMap: Map<string, string>,
): Promise<DiscordMessage> {
  const isSecurity = isSecurityEvent(eventName);
  const emoji = isSecurity ? DISCORD_EMOJIS.ALERT : DISCORD_EMOJIS.EVENT;
  const color = isSecurity ? DISCORD_COLORS.ALERT : DISCORD_COLORS.EVENT;
  const multisigName = getMultisigName(multisigKey);

  // Prefer txHash (Safe transaction hash) if available in the log,
  // otherwise look it up from ExecutionSuccess events via txHashMap,
  // finally fall back to transactionHash (on-chain tx hash)
  const txHashForSafe =
    log.txHash && typeof log.txHash === "string"
      ? log.txHash
      : txHashMap.get(log.transactionHash.toLowerCase()) || log.transactionHash;
  const safeUiUrl = getSafeUiUrl(log.address, txHashForSafe, multisigKey);

  const fields = [
    {
      name: "Transaction Hash",
      value: `[${log.transactionHash}](${BLOCK_EXPLORER.tx(log.transactionHash)})`,
      inline: false,
    },
    {
      name: "Safe UI Link",
      value: `[Open TX in Safe UI](${safeUiUrl})`,
      inline: false,
    },
    ...(await decodeEventData(eventName, log, txHashForSafe)),
  ];

  // Use current timestamp since block timestamp isn't in decoded log
  return {
    embeds: [
      {
        title: `${emoji} ${eventName}`,
        description: `Event detected on ${multisigName} Multisig`,
        color,
        fields,
        timestamp: new Date().toISOString(),
      },
    ],
  };
}

/**
 * Send message to Discord webhook
 * @param webhookUrl - Discord webhook URL to send the message to
 * @param message - Formatted Discord message with embeds
 * @throws {AxiosError} If the webhook request fails
 */
export async function sendToDiscord(
  webhookUrl: string,
  message: DiscordMessage,
): Promise<void> {
  try {
    await axios.post(webhookUrl, message, {
      headers: { "Content-Type": "application/json" },
      timeout: 10000,
    });

    // Extract key info for logging
    const embed = message.embeds[0];
    const eventName = embed.title.replace(/^[🚨🔔]\s+/u, ""); // Remove emoji prefix
    const multisigName = embed.description.replace("Event detected on ", "");
    const txField = embed.fields.find((f) => f.name === "Transaction");
    const txHash = txField?.value.match(/\[([^\]]+)\]/)?.[1] || "unknown";

    console.info(
      `Discord message sent: ${eventName} on ${multisigName} (tx: ${txHash})`,
    );
  } catch (error) {
    const axiosError = error as AxiosError;
    console.error("Discord webhook error:", {
      status: axiosError.response?.status,
      statusText: axiosError.response?.statusText,
      data: axiosError.response?.data,
      message: axiosError.message,
    });
    throw error;
  }
}
