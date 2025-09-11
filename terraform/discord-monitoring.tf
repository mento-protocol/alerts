######################
# Discord Monitoring Infrastructure
######################
# This file creates Discord channels and webhooks for blockchain monitoring
# Provider-agnostic setup that can be used with QuickNode, Tenderly, or other services

locals {
  # Multisigs configuration (defined in variables.tf)
  multisigs = var.multisigs
}

######################
# Discord Channels
######################

# Create alerts channels for each multisig
resource "discord_text_channel" "multisig_alerts" {
  for_each = local.multisigs

  name                     = "🚨︱multisig-alerts-${each.key}"
  server_id                = var.discord_server_id
  category                 = var.discord_category_id
  topic                    = "Critical security events for ${each.value.name} on Celo"
  sync_perms_with_category = true
  position                 = index(keys(local.multisigs), each.key) * 2 + 1
}

# Create events channels for each multisig
resource "discord_text_channel" "multisig_events" {
  for_each = local.multisigs

  name                     = "🔔︱multisig-events-${each.key}"
  server_id                = var.discord_server_id
  category                 = var.discord_category_id
  topic                    = "Transaction events for ${each.value.name} on Celo"
  sync_perms_with_category = true
  position                 = index(keys(local.multisigs), each.key) * 2 + 2
}

######################
# Discord Webhooks via REST API Provider
######################
# This creates Discord webhooks using the Discord REST API
# Fully Terraform-native solution - no scripts or manual steps required!

# Create webhooks for alerts channels
resource "restapi_object" "discord_webhook_alerts" {
  provider = restapi.discord
  for_each = local.multisigs

  path = "/channels/${discord_text_channel.multisig_alerts[each.key].id}/webhooks"

  data = jsonencode({
    name   = "Monitoring Alerts - ${each.value.name}"
    avatar = null # Optional: Add a base64 encoded image for the webhook avatar
  })

  id_attribute = "id"

  depends_on = [discord_text_channel.multisig_alerts]
}

# Create webhooks for events channels
resource "restapi_object" "discord_webhook_events" {
  provider = restapi.discord
  for_each = local.multisigs

  path = "/channels/${discord_text_channel.multisig_events[each.key].id}/webhooks"

  data = jsonencode({
    name   = "Monitoring Events - ${each.value.name}"
    avatar = null # Optional: Add a base64 encoded image for the webhook avatar
  })

  id_attribute = "id"

  depends_on = [discord_text_channel.multisig_events]
}

######################
# Extract Webhook URLs
######################

locals {
  # Parse the webhook responses to extract URLs
  multisig_webhook_urls = {
    for key, multisig in local.multisigs : key => {
      alerts = jsondecode(restapi_object.discord_webhook_alerts[key].api_response).url
      events = jsondecode(restapi_object.discord_webhook_events[key].api_response).url
    }
  }
}

######################
# Outputs
######################

output "multisig_discord_channels" {
  value = {
    for key, multisig in local.multisigs : key => {
      alerts_channel = discord_text_channel.multisig_alerts[key].name
      events_channel = discord_text_channel.multisig_events[key].name
    }
  }
  description = "Discord channel names for multisig monitoring"
}

output "multisig_webhook_urls" {
  value       = local.multisig_webhook_urls
  description = "Auto-generated Discord webhook URLs for multisig monitoring"
  sensitive   = true
}

output "multisig_webhook_info" {
  value = {
    for key, multisig in local.multisigs : key => {
      alerts_webhook_id = restapi_object.discord_webhook_alerts[key].id
      events_webhook_id = restapi_object.discord_webhook_events[key].id
      alerts_channel    = discord_text_channel.multisig_alerts[key].name
      events_channel    = discord_text_channel.multisig_events[key].name
    }
  }
  description = "Discord webhook IDs and channel information for multisig monitoring"
}
