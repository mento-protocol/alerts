######################
# Sentry Variables
######################

variable "sentry_auth_token" {
  description = "Sentry authentication token"
  type        = string
  sensitive   = true
}

######################
# Discord Variables
######################

variable "discord_server_id" {
  description = "Discord server ID"
  type        = string
}

variable "discord_category_id" {
  description = "Discord category ID where alert channels will be created"
  type        = string
}

variable "discord_sentry_role_id" {
  description = "Discord role ID for the Sentry integration (right-click the Sentry role on Discord and copy ID)"
  type        = string
}
