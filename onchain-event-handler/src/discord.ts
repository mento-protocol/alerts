/**
 * Discord message formatting and sending
 */

import axios, { AxiosError } from "axios";
import { DISCORD_COLORS } from "./constants";
import type { DiscordMessage, QuickNodeDecodedLog } from "./types";
import {
  BLOCK_EXPLORER,
  decodeEventData,
  getMultisigChainInfo,
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
  const color = isSecurity ? DISCORD_COLORS.ALERT : DISCORD_COLORS.EVENT;
  const multisigName = getMultisigName(multisigKey);

  // Get chain info and capitalize chain name
  const chainInfo = getMultisigChainInfo(multisigKey);
  const chainDisplay = chainInfo
    ? chainInfo.chain.charAt(0).toUpperCase() + chainInfo.chain.slice(1)
    : "";

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

  // Build title: "Mento Labs Multisig [Celo]"
  const title = chainDisplay
    ? `${multisigName} [${chainDisplay}]`
    : multisigName;

  // Build description: "Event detected on Mento Labs Multisig on Celo"
  const description = chainDisplay
    ? `Event detected on ${multisigName} on ${chainDisplay}`
    : `Event detected on ${multisigName}`;

  // Use current timestamp since block timestamp isn't in decoded log
  return {
    embeds: [
      {
        title,
        description,
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
    const description = embed.description; // Description is now "Event detected on Mento Labs Multisig on Celo"
    const txField = embed.fields.find((f) => f.name === "Transaction Hash");
    const txHash = txField?.value.match(/\[([^\]]+)\]/)?.[1] || "unknown";

    console.info(`Discord message sent: ${description} (tx: ${txHash})`);
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
