#####################
# Discord Monitoring Infrastructure
#####################
# This module creates Discord channels and webhooks for blockchain monitoring
# Provider-agnostic setup that can be used with QuickNode, Tenderly, or other services

#####################
# Discord Channels
#####################

# Create alerts channels for each multisig
resource "discord_text_channel" "multisig_alerts" {
  for_each = local.multisigs

  name                     = "🚨︱multisig-alerts-${each.key}"
  server_id                = var.discord_server_id
  category                 = var.discord_category_id
  topic                    = "Critical security events for ${each.value.name} on ${title(each.value.chain)}"
  sync_perms_with_category = true
  position                 = index(keys(local.multisigs), each.key) * 2 + 1

  lifecycle {
    precondition {
      condition     = length(each.value.name) > 0
      error_message = "Multisig name cannot be empty for ${each.key}."
    }
  }
}

# Create events channels for each multisig
resource "discord_text_channel" "multisig_events" {
  for_each = local.multisigs

  name                     = "🔔︱multisig-events-${each.key}"
  server_id                = var.discord_server_id
  category                 = var.discord_category_id
  topic                    = "Transaction events for ${each.value.name} on ${title(each.value.chain)}"
  sync_perms_with_category = true
  position                 = index(keys(local.multisigs), each.key) * 2 + 2

  lifecycle {
    precondition {
      condition     = length(each.value.name) > 0
      error_message = "Multisig name cannot be empty for ${each.key}."
    }
  }
}

#####################
# Discord Webhooks via REST API Provider
#####################
# This creates Discord webhooks using the Discord REST API
# Fully Terraform-native solution - no scripts or manual steps required!

# Create webhooks for alerts channels
resource "restapi_object" "discord_webhook_alerts" {
  provider = restapi.discord
  for_each = local.multisigs

  # Path for creating webhook (POST)
  path = "/channels/${discord_text_channel.multisig_alerts[each.key].id}/webhooks"

  # Paths for reading, updating, and deleting webhook (using webhook ID from state)
  read_path    = "/webhooks/{id}"
  update_path  = "/webhooks/{id}"
  destroy_path = "/webhooks/{id}"

  data = jsonencode({
    name   = "Monitoring Alerts - ${each.value.name}"
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
      error_message = "Discord webhook creation for ${each.value.name} alerts failed or returned invalid response"
    }
  }
}

# Create webhooks for events channels
resource "restapi_object" "discord_webhook_events" {
  provider = restapi.discord
  for_each = local.multisigs

  # Path for creating webhook (POST)
  path = "/channels/${discord_text_channel.multisig_events[each.key].id}/webhooks"

  # Paths for reading, updating, and deleting webhook (using webhook ID from state)
  read_path    = "/webhooks/{id}"
  update_path  = "/webhooks/{id}"
  destroy_path = "/webhooks/{id}"

  data = jsonencode({
    name   = "Monitoring Events - ${each.value.name}"
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
      error_message = "Discord webhook creation for ${each.value.name} events failed or returned invalid response"
    }
  }
}

