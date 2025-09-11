######################
# Discord Webhooks via REST API Provider
######################
# This creates Discord webhooks using the Discord REST API
# Fully Terraform-native solution - no scripts or manual steps required!
# Note: The restapi.discord provider is configured in the root module

######################
# Create Webhooks for Each Multisig
######################

# Create webhooks for alerts channels
resource "restapi_object" "discord_webhook_alerts" {
  provider = restapi.discord
  for_each = local.multisigs

  path = "/channels/${discord_text_channel.multisig_alerts[each.key].id}/webhooks"

  data = jsonencode({
    name   = "Tenderly Alerts - ${each.value.name}"
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
    name   = "Tenderly Events - ${each.value.name}"
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
  auto_generated_webhook_urls = {
    for key, multisig in local.multisigs : key => {
      alerts = jsondecode(restapi_object.discord_webhook_alerts[key].api_response).url
      events = jsondecode(restapi_object.discord_webhook_events[key].api_response).url
    }
  }
}



######################
# Output Webhook Information
######################

output "discord_webhook_urls" {
  value       = local.auto_generated_webhook_urls
  description = "Auto-generated Discord webhook URLs"
  sensitive   = true
}

output "discord_webhook_info" {
  value = {
    for key, multisig in local.multisigs : key => {
      alerts_webhook_id = restapi_object.discord_webhook_alerts[key].id
      events_webhook_id = restapi_object.discord_webhook_events[key].id
      alerts_channel    = discord_text_channel.multisig_alerts[key].name
      events_channel    = discord_text_channel.multisig_events[key].name
    }
  }
  description = "Discord webhook IDs and channel information"
}
