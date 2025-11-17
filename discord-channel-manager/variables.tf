variable "multisigs" {
  description = "Map of multisig configurations (can be from multiple chains)"
  type = map(object({
    name     = string
    address  = string
    chain    = string
    chain_id = number
    network  = string
  }))
}

variable "discord_server_id" {
  description = "Discord server ID"
  type        = string
}

variable "discord_category_id" {
  description = "Discord category ID where alert channels will be created"
  type        = string
}

