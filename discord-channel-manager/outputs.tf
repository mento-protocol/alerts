#####################
# Discord Channel Outputs
#####################

output "multisig_discord_channels" {
  description = "Discord channel names for multisig monitoring"
  value = {
    for key, multisig in var.multisigs : key => {
      alerts_channel = discord_text_channel.multisig_alerts[key].name
      events_channel = discord_text_channel.multisig_events[key].name
    }
  }
}

#####################
# Webhook URL Outputs
#####################

output "webhook_urls" {
  description = "Auto-generated Discord webhook URLs for multisig monitoring"
  value = {
    for key, multisig in var.multisigs : key => {
      alerts = jsondecode(restapi_object.discord_webhook_alerts[key].api_response).url
      events = jsondecode(restapi_object.discord_webhook_events[key].api_response).url
    }
  }
  sensitive = true
}

#####################
# Webhook Info Outputs
#####################

output "webhook_info" {
  description = "Discord webhook IDs and channel information for multisig monitoring"
  value = {
    for key, multisig in var.multisigs : key => {
      alerts_webhook_id = restapi_object.discord_webhook_alerts[key].id
      events_webhook_id = restapi_object.discord_webhook_events[key].id
      alerts_channel    = discord_text_channel.multisig_alerts[key].name
      events_channel    = discord_text_channel.multisig_events[key].name
    }
  }
}

