terraform {
  required_version = ">= 1.10.0"
  required_providers {
    sentry = {
      source  = "jianyuan/sentry"
      version = "~> 0.14.5"
    }
    discord = {
      source  = "Lucky3028/discord"
      version = "2.0.1"
    }
    restapi = {
      source  = "Mastercard/restapi"
      version = "~> 2.0.1"
    }
  }
}

#############
# Providers #
#############

provider "sentry" {
  token = var.sentry_auth_token
}

provider "discord" {
  token = var.discord_bot_token
}

# Discord API provider
provider "restapi" {
  alias = "discord"
  uri   = "https://discord.com/api/v10"
  headers = {
    "Authorization" = "Bot ${var.discord_bot_token}"
    "Content-Type"  = "application/json"
  }
  write_returns_object = true
  debug                = var.debug_mode
}

###########
# Modules #
###########

module "sentry_alerts" {
  source = "./sentry-alerts"

  # Sentry configuration
  sentry_auth_token = var.sentry_auth_token

  # Discord configuration
  discord_server_id      = var.discord_server_id
  discord_category_id    = var.discord_category_id
  discord_sentry_role_id = var.discord_sentry_role_id
}
