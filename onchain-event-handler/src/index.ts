import { Request, Response } from "@google-cloud/functions-framework";
import { buildEventContext } from "./build-event-context";
import { processEvents } from "./process-events";
import { validatePayload } from "./validate-payload";
import { validateQuickNodeWebhook } from "./validate-quicknode-webhook";

/**
 * Cloud Function entry point for processing QuickNode webhooks
 */
export const processQuicknodeWebhook = async (
  req: Request,
  res: Response,
): Promise<void> => {
  try {
    // 1. Verify webhook signature (skip in local development)
    const isProduction = process.env.NODE_ENV !== "development";

    if (isProduction) {
      const requestValidation = validateQuickNodeWebhook(req);
      if (!requestValidation.valid) {
        res.status(requestValidation.status).send(requestValidation.message);
        return;
      }
    }

    // 2. Validate payload structure
    const payloadValidation = validatePayload(req);
    if (!payloadValidation.valid) {
      res.status(payloadValidation.status).json(payloadValidation.error);
      return;
    }

    const webhookData = payloadValidation.payload.result;
    console.info(`Processing webhook with ${webhookData.length} logs`);

    // 3. Build context needed for processing
    // We need this context BEFORE processing to correctly skip ExecutionSuccess duplicates
    const context = buildEventContext(webhookData);

    // 4. Process events with complete context
    const results = await processEvents(webhookData, context);

    // 5. Return success
    res.status(200).json({
      processed: results.length,
      total: webhookData.length,
    });
  } catch (error) {
    console.error("Webhook processing error:", error);
    res.status(500).send("Internal Server Error");
  }
};
