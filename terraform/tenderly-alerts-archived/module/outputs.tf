output "discord_channels" {
  description = "Created Discord channels for multisig monitoring"
  value = {
    for key, multisig in var.multisigs : key => {
      alerts_channel = discord_text_channel.multisig_alerts[key].name
      events_channel = discord_text_channel.multisig_events[key].name
    }
  }
}

output "contracts_added" {
  description = "Multisig contracts added to Tenderly project"
  value = {
    for key, multisig in var.multisigs : key => {
      name    = multisig.name
      address = multisig.address
      project = var.tenderly_project_slug
    }
  }
}

output "webhook_urls" {
  description = "Auto-generated Discord webhook URLs"
  value       = local.auto_generated_webhook_urls
  sensitive   = true
}

output "webhook_info" {
  description = "Discord webhook IDs and channel information"
  value = {
    for key, multisig in var.multisigs : key => {
      alerts_webhook_id = restapi_object.discord_webhook_alerts[key].id
      events_webhook_id = restapi_object.discord_webhook_events[key].id
      alerts_channel    = discord_text_channel.multisig_alerts[key].name
      events_channel    = discord_text_channel.multisig_events[key].name
    }
  }
}

output "tenderly_alerts_summary" {
  description = "Summary of Tenderly alerts configuration"
  value = {
    total_alerts = length(restapi_object.multisig_alerts)
    multisigs    = length(var.multisigs)
    events_per_multisig = {
      security_events    = length(local.alert_channel_events)
      operational_events = length(local.events_channel_events)
    }
  }
}

output "alert_configuration" {
  description = "Detailed alert configuration for each multisig"
  value = {
    for key, multisig in var.multisigs : key => {
      multisig_name    = multisig.name
      multisig_address = multisig.address
      security_alerts = [
        for event_key, event_sig in local.alert_channel_events : event_key
      ]
      operational_events = [
        for event_key, event_sig in local.events_channel_events : event_key
      ]
    }
  }
}
