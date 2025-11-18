#####################
# Discord Monitoring Infrastructure
#####################
# This module creates Discord channels and webhooks for blockchain monitoring
# Provider-agnostic setup that can be used with QuickNode, Tenderly, or other services

#####################
# Discord Channels
#####################

# Create shared alerts channel for all multisigs
resource "discord_text_channel" "multisig_alerts" {
  name                     = "🚨︱multisig-alerts"
  server_id                = var.discord_server_id
  category                 = var.discord_category_id
  topic                    = "Critical security events for all multisigs (owner changes, threshold modifications, etc.)"
  sync_perms_with_category = true
  position                 = 1
}

# Create shared events channel for all multisigs
resource "discord_text_channel" "multisig_events" {
  name                     = "🔔︱multisig-events"
  server_id                = var.discord_server_id
  category                 = var.discord_category_id
  topic                    = "Transaction events for all multisigs (executions, approvals, incoming funds, etc.)"
  sync_perms_with_category = true
  position                 = 2
}

#####################
# Discord Webhooks via REST API Provider
#####################
# This creates Discord webhooks using the Discord REST API
# Fully Terraform-native solution - no scripts or manual steps required!

# Create webhook for shared alerts channel
resource "restapi_object" "discord_webhook_alerts" {
  provider = restapi.discord

  # Path for creating webhook (POST)
  path = "/channels/${discord_text_channel.multisig_alerts.id}/webhooks"

  # Paths for reading, updating, and deleting webhook (using webhook ID from state)
  read_path    = "/webhooks/{id}"
  update_path  = "/webhooks/{id}"
  destroy_path = "/webhooks/{id}"

  data = jsonencode({
    name   = "Multisig Alerts"
    avatar = null # Optional: Add a base64 encoded image for the webhook avatar
  })

  id_attribute = "id"

  # Ignore server-side changes to prevent unnecessary updates
  # Discord may add fields like created_at, updated_at, etc. that we don't manage
  ignore_all_server_changes = true

  depends_on = [discord_text_channel.multisig_alerts]

  # trunk-ignore(terrascan): postcondition blocks are valid Terraform 1.2+ syntax
  lifecycle {
    postcondition {
      condition     = self.api_response != null && can(jsondecode(self.api_response).id)
      error_message = "Discord webhook creation for multisig alerts failed or returned invalid response"
    }
  }
}

# Create webhook for shared events channel
resource "restapi_object" "discord_webhook_events" {
  provider = restapi.discord

  # Path for creating webhook (POST)
  path = "/channels/${discord_text_channel.multisig_events.id}/webhooks"

  # Paths for reading, updating, and deleting webhook (using webhook ID from state)
  read_path    = "/webhooks/{id}"
  update_path  = "/webhooks/{id}"
  destroy_path = "/webhooks/{id}"

  data = jsonencode({
    name   = "Multisig Events"
    avatar = null # Optional: Add a base64 encoded image for the webhook avatar
  })

  id_attribute = "id"

  # Ignore server-side changes to prevent unnecessary updates
  # Discord may add fields like created_at, updated_at, etc. that we don't manage
  ignore_all_server_changes = true

  depends_on = [discord_text_channel.multisig_events]

  # trunk-ignore(terrascan): postcondition blocks are valid Terraform 1.2+ syntax
  lifecycle {
    postcondition {
      condition     = self.api_response != null && can(jsondecode(self.api_response).id)
      error_message = "Discord webhook creation for multisig events failed or returned invalid response"
    }
  }
}

