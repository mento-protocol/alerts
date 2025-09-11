################
# Sentry Setup #
################

# Get organization details
data "sentry_organization" "main" {
  slug = "mento-labs" # Organization slug from URL: https://[slug].sentry.io
}

# Get team details
data "sentry_team" "main" {
  organization = data.sentry_organization.main.id
  slug         = "mento-labs"
}

# Get Discord integration details
data "sentry_organization_integration" "discord" {
  organization = data.sentry_organization.main.id
  provider_key = "discord"

  # Name of your Discord server as it appears in Sentry https://mento-labs.sentry.io/settings/integrations/discord/272567/
  name = "Mento"
}

# Get all projects in the organization
data "sentry_all_projects" "all" {
  organization = data.sentry_organization.main.id
}

locals {
  # Create a map of project slugs to project details  
  # Include managed projects from resources below
  managed_projects = {
    "app-mento-org"        = sentry_project.app_mento_org
    "reserve-mento-org"    = sentry_project.reserve_mento_org
    "governance-mento-org" = sentry_project.governance_mento_org
  }

  # Include any additional projects that exist but aren't managed by Terraform
  all_projects = {
    for project in data.sentry_all_projects.all.projects :
    project.slug => project
  }

  # Use managed projects where they exist, fall back to discovered projects
  projects = merge(local.all_projects, local.managed_projects)
}

################
# Discord Setup #
################

# Grant the Sentry integration access to the Discord category
resource "discord_channel_permission" "sentry_category_access" {
  channel_id   = var.discord_category_id
  overwrite_id = var.discord_sentry_role_id
  type         = "role"
  allow        = 1024 # View Channel permission (1 << 10)
  deny         = 0    # Don't explicitly deny any permissions
}

# Create Discord alert channels for each Sentry project
resource "discord_text_channel" "sentry_alerts" {
  for_each = local.projects

  name                     = "sentry-${each.key}"
  server_id                = var.discord_server_id
  category                 = var.discord_category_id
  topic                    = "Sentry alerts for ${each.key} project"
  sync_perms_with_category = true
  # Position channels alphabetically, starting at 100 to appear after existing channels
  position = 100 + index(sort([for p in local.projects : "sentry-${p.slug}"]), "sentry-${each.key}")
}

###############
# Alert Rules #
###############

# Create alert rules that forward Sentry errors to Discord
resource "sentry_issue_alert" "discord_alerts" {
  for_each = local.projects

  organization = data.sentry_organization.main.id
  project      = each.key
  name         = "${each.key} - Forward to Discord"

  action_match = "any" # Trigger if any condition is met
  filter_match = "any" # Trigger if any filter matches
  frequency    = 5     # Wait at least 5 minutes before re-triggering

  # Optional: Filter for specific error types. If alerts get too noisy, we can add more filters here.
  #   filters_v2 = [{
  #     issue_category = {
  #       value = "Error"
  #     }
  #   }]

  # Forward to Discord with the right context as defined in tags
  actions_v2 = [{
    discord_notify_service = {
      server     = data.sentry_organization_integration.discord.id
      channel_id = discord_text_channel.sentry_alerts[each.key].id
      tags       = ["url", "browser", "device", "os", "environment", "level", "handled"]
    }
  }]
}

###########################
# Sentry Project Creation #
###########################
# (These were in sentry-projects.tf)

resource "sentry_project" "app_mento_org" {
  organization = data.sentry_organization.main.id

  teams = [data.sentry_team.main.id]
  name  = "app.mento.org"
  slug  = "app-mento-org"

  platform = "javascript-nextjs"

  client_security = {
    scrape_javascript = true
  }
}

resource "sentry_project" "reserve_mento_org" {
  organization = data.sentry_organization.main.id

  teams = [data.sentry_team.main.id]
  name  = "reserve.mento.org"
  slug  = "reserve-mento-org"

  platform = "javascript-nextjs"

  client_security = {
    scrape_javascript = true
  }
}

resource "sentry_project" "governance_mento_org" {
  organization = data.sentry_organization.main.id

  teams = [data.sentry_team.main.id]
  name  = "governance.mento.org"
  slug  = "governance-mento-org"

  platform = "javascript-nextjs"

  client_security = {
    scrape_javascript = true
  }
}
