import type { EventContext } from "./build-event-context";
import { formatDiscordMessage, sendToDiscord } from "./discord";
import type { ProcessedEvent, QuickNodeWebhookPayload } from "./types";
import { getMultisigKey, getWebhookUrl, isSecurityEvent } from "./utils";

/**
 * Process all events from webhook payload
 * Skips ExecutionSuccess notifications if there's a SafeMultiSigTransaction for the same tx
 *
 * @param logs - Array of decoded log entries from QuickNode webhook
 * @param context - Event context built from first pass
 * @returns Array of successfully processed events
 */
export async function processEvents(
  logs: QuickNodeWebhookPayload["result"],
  context: EventContext,
): Promise<ProcessedEvent[]> {
  const { txHashMap, hasSafeMultiSigTx } = context;
  const results: ProcessedEvent[] = [];

  for (const log of logs) {
    try {
      // Skip ExecutionSuccess if we already have SafeMultiSigTransaction for this tx
      if (
        log.name === "ExecutionSuccess" &&
        hasSafeMultiSigTx.has(log.transactionHash.toLowerCase())
      ) {
        console.info(
          `Skipping ExecutionSuccess notification (SafeMultiSigTransaction already sent for tx ${log.transactionHash})`,
        );
        continue;
      }

      const result = await processEvent(log, txHashMap);
      if (result) {
        results.push(result);
      }
    } catch (error) {
      console.error("Error processing log:", error);
      // Continue processing other logs
    }
  }

  return results;
}

/**
 * Process a single event log and send to Discord
 *
 * @param log - The decoded log entry from QuickNode webhook
 * @param txHashMap - Map of transactionHash -> Safe txHash for linking transactions
 * @returns ProcessedEvent if successful, null if event should be skipped
 */
async function processEvent(
  log: QuickNodeWebhookPayload["result"][0],
  txHashMap: Map<string, string>,
): Promise<ProcessedEvent | null> {
  // 1. Get event name from decoded log
  const eventName = log.name;

  if (!eventName) {
    console.warn(`Log missing event name:`, log);
    return null;
  }

  // 2. Identify multisig
  const multisigAddress = log.address.toLowerCase();
  const multisigKey = getMultisigKey(multisigAddress);

  if (!multisigKey) {
    console.warn(`Unknown multisig address: ${multisigAddress}`);
    return null;
  }

  // 3. Determine channel (alerts vs events)
  const isSecurity = isSecurityEvent(eventName);
  const channelType = isSecurity ? "alerts" : "events";

  // 4. Get webhook URL
  const webhookUrl = getWebhookUrl(multisigKey, channelType);
  if (!webhookUrl) {
    console.error(`No webhook URL for ${multisigKey} ${channelType}`);
    return null;
  }

  // 5. Format Discord message
  const discordMessage = await formatDiscordMessage(
    eventName,
    log,
    multisigKey,
    txHashMap,
  );

  // 6. Send to Discord
  await sendToDiscord(webhookUrl, discordMessage);

  return { multisigKey, eventName, channelType };
}
