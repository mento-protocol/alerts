#####################
# Sentry Module Outputs
#####################

output "sentry_discord_channels" {
  description = "Discord channel IDs for Sentry alerts"
  value       = module.sentry_alerts.discord_channels
}

#####################
# Multisig Monitoring Outputs
#####################

output "monitored_multisigs" {
  description = "Details of all monitored multisigs across all chains"
  value = {
    for key, multisig in var.multisigs : key => {
      name     = multisig.name
      address  = multisig.address
      chain    = multisig.chain
      chain_id = multisig.chain_id
      network  = multisig.network
    }
  }
}

output "discord_channels" {
  description = "Created Discord channels for monitoring"
  value       = module.discord_channel_manager.multisig_discord_channels
}

#####################
# GCP Project Outputs
#####################

output "project_id" {
  description = "GCP project ID"
  value       = local.project_id
}

output "project_number" {
  description = "GCP project number"
  value       = module.project_factory.project_number
}

output "project_name" {
  description = "GCP project name"
  value       = module.project_factory.project_name
}

#####################
# Multi-Chain Configuration Outputs
#####################

output "chains_by_network" {
  description = "Mapping of chains to their network identifiers (one network per chain)"
  value = {
    for chain in distinct([for k, v in var.multisigs : v.chain]) :
    chain => distinct([for k, v in var.multisigs : v.network if v.chain == chain])[0]
  }
}

#####################
# QuickNode & Cloud Function Outputs
#####################

# Note: quicknode_webhook_ids is also available in monitoring_summary.quicknode.webhooks_by_chain
# Kept as top-level output for convenience
output "quicknode_webhook_ids" {
  description = "QuickNode webhook dashboard URLs by chain"
  value       = { for chain, module_output in module.onchain_event_listeners : chain => "https://dashboard.quicknode.com/webhooks/${module_output.webhook_id}" }
}

# Note: cloud_function_url is also available in monitoring_summary.cloud_function.url
# Kept as top-level output for convenience
output "cloud_function_url" {
  description = "Cloud Function URL for webhook endpoint (handles all chains)"
  value       = module.onchain_event_handler.function_url
  sensitive   = false
}
