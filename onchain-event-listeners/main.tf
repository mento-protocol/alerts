#############################################
# QuickNode Webhook for Multisig Monitoring #
#############################################
# This module creates a QuickNode webhook that monitors Safe multisig events
# and sends them to the alert handler cloud function

# Delete old webhook before recreation (QuickNode doesn't support PUT updates)
# 
# IMPORTANT: Due to Terraform's execution model, the first apply may fail with 404.
# This happens because Terraform plans the update before the provisioner runs.
# 
# WORKAROUND: If you get a 404 error, run:
#   `terraform state rm 'module.onchain_event_listeners["celo"].restapi_object.multisig_webhook'`
#   `terraform apply`
#
# The provisioner will delete the old webhook and remove it from state,
# so the second apply will succeed by creating a new webhook instead of updating.
resource "null_resource" "pause_webhook_before_update" {
  # Include hash in a way that forces replacement
  # When hash changes, Terraform will replace this resource (destroy old, create new)
  triggers = {
    # Hash changes = resource replacement, not update
    webhook_data_hash = local.webhook_data_hash
    webhook_name      = var.webhook_name
    # Force replacement by including hash as a separate trigger
    replacement_trigger = local.webhook_data_hash
  }

  lifecycle {
    # Force replacement when triggers change (don't update in-place)
    create_before_destroy = false
  }

  # Run before Terraform tries to update the webhook
  # This deletes the old webhook and removes it from state, forcing recreation

  # Provisioner runs when resource is created/updated (when hash changes)
  provisioner "local-exec" {
    command = <<-EOT
      # Get webhook ID from Terraform state - find the exact resource path
      # Match any onchain_event_listeners module instance (supports both old and new names for backward compatibility)
      STATE_PATH=$(terraform state list | grep -E '\.multisig_webhook$' | grep -E '(onchain_event_listeners|multisig_alerts)\[.*\]' | head -1)
      
      if [ -z "$STATE_PATH" ]; then
        echo "Webhook not found in state, skipping delete (first creation)"
        exit 0
      fi
      
      WEBHOOK_ID=$(terraform state show "$STATE_PATH" 2>/dev/null | grep -E '^\s+id\s+=' | awk '{print $3}' | tr -d '"' || echo "")
      
      if [ -n "$WEBHOOK_ID" ] && [ "$WEBHOOK_ID" != "" ]; then
        echo "Pausing and deleting old webhook $WEBHOOK_ID to force recreation..."
        
        # First pause the webhook (required before deletion)
        HTTP_CODE=$(curl -s -o /tmp/webhook_response.json -w "%%{http_code}" -X PUT "https://api.quicknode.com/webhooks/rest/v1/webhooks/$WEBHOOK_ID" \
          -H "x-api-key: ${var.quicknode_api_key}" \
          -H "Content-Type: application/json" \
          -H "accept: application/json" \
          -d '{"status": "paused"}')
        
        if [ "$HTTP_CODE" = "200" ] || [ "$HTTP_CODE" = "204" ]; then
          echo "Webhook paused successfully (HTTP $HTTP_CODE)"
          
          # Now delete the webhook
          DELETE_CODE=$(curl -s -o /tmp/webhook_delete.json -w "%%{http_code}" -X DELETE "https://api.quicknode.com/webhooks/rest/v1/webhooks/$WEBHOOK_ID" \
            -H "x-api-key: ${var.quicknode_api_key}" \
            -H "accept: application/json")
          
          if [ "$DELETE_CODE" = "200" ] || [ "$DELETE_CODE" = "204" ]; then
            echo "Old webhook deleted successfully (HTTP $DELETE_CODE)"
            # Remove from Terraform state so Terraform will create instead of update
            echo "Removing webhook from Terraform state..."
            terraform state rm -lock=false "$STATE_PATH" 2>&1 | head -5
            echo "Webhook removed from state - Terraform will create a new one"
          else
            DELETE_BODY=$(cat /tmp/webhook_delete.json 2>/dev/null || echo "No response body")
            echo "Warning: Failed to delete webhook (HTTP $DELETE_CODE): $DELETE_BODY"
          fi
          rm -f /tmp/webhook_delete.json
        else
          BODY=$(cat /tmp/webhook_response.json 2>/dev/null || echo "No response body")
          echo "Warning: Failed to pause webhook (HTTP $HTTP_CODE): $BODY"
        fi
        rm -f /tmp/webhook_response.json
      else
        echo "Could not extract webhook ID from state, skipping delete"
      fi
    EOT
  }

  # Also run on destroy to pause webhook before deletion
  # Note: Uses QUICKNODE_API_KEY environment variable since destroy provisioners can't reference variables
  # Uses webhook_id from triggers (which references restapi_object.multisig_webhook.id)
  provisioner "local-exec" {
    when    = destroy
    command = <<-EOT
      # Get webhook ID from triggers (set when resource was created)
      # Fallback to reading from state if trigger is not available
      WEBHOOK_ID="${self.triggers.webhook_id}"
      
      if [ -z "$WEBHOOK_ID" ] || [ "$WEBHOOK_ID" = "null" ] || [ "$WEBHOOK_ID" = "" ]; then
        # Fallback: try to get from state (supports both old and new names for backward compatibility)
        STATE_PATH=$(terraform state list | grep -E '\.multisig_webhook$' | grep -E '(onchain_event_listeners|multisig_alerts)\[.*\]' | head -1)
        if [ -n "$STATE_PATH" ]; then
          WEBHOOK_ID=$(terraform state show "$STATE_PATH" 2>/dev/null | grep -E '^\s+id\s+=' | awk '{print $3}' | tr -d '"' || echo "")
        fi
      fi
      
      if [ -n "$WEBHOOK_ID" ] && [ "$WEBHOOK_ID" != "" ] && [ "$WEBHOOK_ID" != "null" ]; then
        echo "Pausing webhook $WEBHOOK_ID before deletion..."
        
        # Use environment variable for API key (must be set before terraform destroy)
        API_KEY="$QUICKNODE_API_KEY"
        if [ -z "$API_KEY" ] || [ "$API_KEY" = "" ]; then
          echo "Warning: QUICKNODE_API_KEY environment variable not set, skipping pause"
          echo "Set QUICKNODE_API_KEY environment variable before running terraform destroy"
          exit 0
        fi
        
        # Pause the webhook (required before deletion)
        HTTP_CODE=$(curl -s -o /tmp/webhook_pause.json -w "%%{http_code}" -X PUT "https://api.quicknode.com/webhooks/rest/v1/webhooks/$WEBHOOK_ID" \
          -H "x-api-key: $API_KEY" \
          -H "Content-Type: application/json" \
          -H "accept: application/json" \
          -d '{"status": "paused"}')
        
        if [ "$HTTP_CODE" = "200" ] || [ "$HTTP_CODE" = "204" ]; then
          echo "Webhook paused successfully before deletion"
        else
          BODY=$(cat /tmp/webhook_pause.json 2>/dev/null || echo "No response body")
          echo "Warning: Failed to pause webhook (HTTP $HTTP_CODE): $BODY"
        fi
        rm -f /tmp/webhook_pause.json
      else
        echo "Could not determine webhook ID, skipping pause (may already be deleted)"
      fi
    EOT
  }
}

# QuickNode webhook creation
# API Reference: https://www.quicknode.com/docs/webhooks/rest-api/webhooks/webhooks-rest-create-webhook
resource "restapi_object" "multisig_webhook" {
  provider = restapi.quicknode
  path     = "/webhooks/rest/v1/webhooks"

  # Configure paths for reading and deleting webhooks
  # Note: QuickNode doesn't support updates - we must recreate webhooks for any changes
  read_path    = "/webhooks/rest/v1/webhooks/{id}"
  destroy_path = "/webhooks/rest/v1/webhooks/{id}"

  # CRITICAL: Do NOT set update_path or update_method - this prevents update attempts entirely
  # Any configuration change will trigger replacement via replace_triggered_by lifecycle rule

  data = jsonencode({
    # Append hash to name to force replacement when config changes
    # This ensures Terraform sees it as a different resource requiring recreation
    name            = "${var.webhook_name}-${substr(local.webhook_data_hash, 0, 8)}"
    network         = var.network
    filter_function = local.filter_function_base64
    destination_attributes = {
      url         = var.webhook_endpoint_url
      compression = var.compression
    }
    status = "active"
  })

  id_attribute = "id"

  # Enable debug mode to see API responses
  debug = true

  lifecycle {
    # QuickNode doesn't support updates - force replacement for ANY change
    create_before_destroy = false # Delete old webhook before creating new one

    # Replace when configuration changes (via null_resource trigger)
    replace_triggered_by = [
      null_resource.pause_webhook_before_update
    ]

    # Prevent updates by ignoring server-managed fields that cause drift
    # QuickNode adds these fields in responses but we don't manage them
    ignore_changes = [
      # Ignore the entire data block to prevent drift detection from server-managed fields
      # Real config changes are detected via the hash in the webhook name
      data
    ]
  }

  # Ensure pause/delete happens before Terraform tries to update
  # Also ensure null_resource runs before this is destroyed (for pause on destroy)
  depends_on = [null_resource.pause_webhook_before_update]
}

# Ensure null_resource destroy provisioner runs before restapi_object is destroyed
# This allows the webhook to be paused before deletion
resource "null_resource" "pause_webhook_on_destroy" {
  triggers = {
    webhook_id = restapi_object.multisig_webhook.id
  }

  lifecycle {
    create_before_destroy = false
  }

  # This provisioner will run when the restapi_object is being destroyed
  # It pauses the webhook before the restapi_object destroy provisioner runs
  provisioner "local-exec" {
    when    = destroy
    command = <<-EOT
      # Get webhook ID from triggers
      WEBHOOK_ID="${self.triggers.webhook_id}"
      
      if [ -n "$WEBHOOK_ID" ] && [ "$WEBHOOK_ID" != "" ] && [ "$WEBHOOK_ID" != "null" ]; then
        echo "Pausing webhook $WEBHOOK_ID before deletion..."
        
        # Use environment variable for API key (must be set before terraform destroy)
        API_KEY="$QUICKNODE_API_KEY"
        if [ -z "$API_KEY" ] || [ "$API_KEY" = "" ]; then
          echo "Warning: QUICKNODE_API_KEY environment variable not set, skipping pause"
          echo "Set QUICKNODE_API_KEY environment variable before running terraform destroy"
          exit 0
        fi
        
        # Pause the webhook (required before deletion)
        HTTP_CODE=$(curl -s -o /tmp/webhook_pause.json -w "%%{http_code}" -X PUT "https://api.quicknode.com/webhooks/rest/v1/webhooks/$WEBHOOK_ID" \
          -H "x-api-key: $API_KEY" \
          -H "Content-Type: application/json" \
          -H "accept: application/json" \
          -d '{"status": "paused"}')
        
        if [ "$HTTP_CODE" = "200" ] || [ "$HTTP_CODE" = "204" ]; then
          echo "Webhook paused successfully before deletion"
        else
          BODY=$(cat /tmp/webhook_pause.json 2>/dev/null || echo "No response body")
          echo "Warning: Failed to pause webhook (HTTP $HTTP_CODE): $BODY"
        fi
        rm -f /tmp/webhook_pause.json
      else
        echo "Could not determine webhook ID, skipping pause"
      fi
    EOT
  }
}

