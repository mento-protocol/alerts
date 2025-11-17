/**
 * Google Cloud Function entry point for processing QuickNode webhooks
 */

import { Request, Response } from "@google-cloud/functions-framework";
import { config } from "./config";
import { formatDiscordMessage, sendToDiscord } from "./discord";
import type { ProcessedEvent, QuickNodeWebhookPayload } from "./types";
import {
  getMultisigKey,
  getWebhookUrl,
  isSecurityEvent,
  verifyQuickNodeSignature,
} from "./utils";

/**
 * Process a single log entry and send to Discord
 */
async function processLog(
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

/**
 * Main Cloud Function handler
 */
export const processQuicknodeWebhook = async (
  req: Request,
  res: Response,
): Promise<void> => {
  try {
    // 1. Verify webhook signature (skip in local development)
    const payload = JSON.stringify(req.body);
    const isProduction = process.env.NODE_ENV === "production";

    if (isProduction) {
      const signature = req.headers["x-quicknode-signature"] as
        | string
        | undefined;
      const secret = config.QUICKNODE_SIGNING_SECRET;
      if (!verifyQuickNodeSignature(payload, signature, secret)) {
        console.error("Invalid webhook signature");
        res.status(401).send("Unauthorized");
        return;
      }
    }

    // 2. Parse request body
    const webhookData = req.body as QuickNodeWebhookPayload;

    // Validate payload structure
    if (
      !webhookData ||
      !webhookData.result ||
      !Array.isArray(webhookData.result)
    ) {
      console.error(
        "Invalid webhook payload: missing or invalid result array",
        {
          body: req.body,
        },
      );
      res
        .status(400)
        .json({ error: "Invalid payload: result array is required" });
      return;
    }

    console.info(`Processing webhook with ${webhookData.result.length} logs`);

    // 3. Build a map of transactionHash -> txHash from ExecutionSuccess events
    // This allows SafeMultiSigTransaction events to use the correct Safe txHash
    const txHashMap = new Map<string, string>();
    // Also track which transactions have SafeMultiSigTransaction events
    const hasSafeMultiSigTx = new Set<string>();

    for (const log of webhookData.result) {
      if (
        log.name === "ExecutionSuccess" &&
        log.txHash &&
        typeof log.txHash === "string"
      ) {
        txHashMap.set(log.transactionHash.toLowerCase(), log.txHash);
      }
      if (log.name === "SafeMultiSigTransaction") {
        hasSafeMultiSigTx.add(log.transactionHash.toLowerCase());
      }
    }

    // 4. Process each log
    // Skip ExecutionSuccess notifications if there's a SafeMultiSigTransaction for the same tx
    const results: ProcessedEvent[] = [];
    for (const log of webhookData.result) {
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

        const result = await processLog(log, txHashMap);
        if (result) {
          results.push(result);
        }
      } catch (error) {
        console.error("Error processing log:", error);
        // Continue processing other logs
      }
    }

    // 4. Return success
    res.status(200).json({
      processed: results.length,
      total: webhookData.result.length,
    });
  } catch (error) {
    console.error("Webhook processing error:", error);
    res.status(500).send("Internal Server Error");
  }
};
