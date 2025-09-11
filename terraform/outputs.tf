######################
# Sentry Module Outputs
######################

output "sentry_organization" {
  description = "The Sentry organization details"
  value       = module.sentry_alerts.sentry_organization
}

output "sentry_team" {
  description = "The Sentry team ID"
  value       = module.sentry_alerts.sentry_team
}

output "sentry_discord_channels" {
  description = "Discord channel IDs for Sentry alerts"
  value       = module.sentry_alerts.discord_channels
}

output "sentry_projects" {
  description = "List of monitored Sentry projects"
  value       = module.sentry_alerts.sentry_projects
}

######################
# Combined Summary
######################

output "monitoring_summary" {
  description = "Overall monitoring configuration summary"
  value = {
    sentry = {
      projects = length(module.sentry_alerts.sentry_projects)
      channels = length(module.sentry_alerts.discord_channels)
    }
    multisigs = {
      count    = length(var.multisigs)
      channels = length(var.multisigs) * 2
    }
  }
}
