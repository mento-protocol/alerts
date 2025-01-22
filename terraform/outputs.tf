output "organization" {
  description = "The Sentry organization details"
  value       = data.sentry_organization.main
}

output "team" {
  description = "The Sentry team ID"
  value       = data.sentry_team.main.id
}

output "webhook_urls" {
  description = "Discord channel IDs for each project's alerts"
  value = {
    for project, channel in discord_text_channel.sentry_alerts :
    trimprefix(project, "sentry-") => channel.id
  }
  sensitive = true
}
