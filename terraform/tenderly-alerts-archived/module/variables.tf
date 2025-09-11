######################
# Tenderly Variables
######################

variable "tenderly_api_key" {
  description = "Tenderly API key for authentication"
  type        = string
  sensitive   = true
}

variable "tenderly_project_slug" {
  description = "Tenderly project slug (found in project URL)"
  type        = string
}

variable "tenderly_account_id" {
  description = "Tenderly account ID (use 'me' for current account)"
  type        = string
  default     = "me"
}

######################
# Discord Variables
######################

variable "discord_bot_token" {
  description = "Discord bot token"
  type        = string
  sensitive   = true
}

variable "discord_server_id" {
  description = "Discord server ID"
  type        = string
}

variable "discord_category_id" {
  description = "Discord category ID where alert channels will be created"
  type        = string
}

######################
# Multisig Configuration
######################

variable "multisigs" {
  description = "Map of multisig configurations"
  type = map(object({
    name    = string
    address = string
  }))
  default = {
    "mento-labs" = {
      name    = "Mento Labs Multisig"
      address = "0x655133d8E90F8190ed5c1F0f3710F602800C0150"
    }
    "reserve" = {
      name    = "Reserve Multisig"
      address = "0x87647780180B8f55980C7D3fFeFe08a9B29e9aE1"
    }
  }
}

######################
# Debug Configuration
######################

variable "debug_mode" {
  description = "Enable debug mode for REST API provider"
  type        = bool
  default     = false
}

variable "tenderly_delivery_channels" {
  description = "Tenderly delivery channel IDs (must be created via UI first)"
  type = object({
    mento_labs_alerts = string
    mento_labs_events = string
    reserve_alerts    = string
    reserve_events    = string
  })
  default = {
    mento_labs_alerts = ""
    mento_labs_events = ""
    reserve_alerts    = ""
    reserve_events    = ""
  }
}
