variable "webhook_name" {
  description = "Name for the QuickNode webhook"
  type        = string
  default     = "safe-multisig-monitor"
}

variable "network" {
  description = "Blockchain network identifier (e.g., 'celo-mainnet')"
  type        = string
  default     = "celo-mainnet"
}

variable "webhook_endpoint_url" {
  description = "URL of the Cloud Function endpoint that will receive webhooks"
  type        = string

  validation {
    # Allow empty string during planning (when value is computed after apply)
    # Otherwise, must be a valid HTTPS URL
    condition     = var.webhook_endpoint_url == "" || can(regex("^https://", var.webhook_endpoint_url))
    error_message = "Webhook endpoint URL must use HTTPS."
  }
}

variable "multisig_addresses" {
  description = "List of Safe multisig addresses to monitor"
  type        = list(string)

  validation {
    condition = alltrue([
      for addr in var.multisig_addresses :
      can(regex("^0x[a-fA-F0-9]{40}$", addr))
    ])
    error_message = "All addresses must be valid Ethereum addresses (0x followed by 40 hexadecimal characters)."
  }
}

variable "compression" {
  description = "Compression method for webhook payloads ('gzip' or 'none')"
  type        = string
  default     = "none"

  validation {
    condition     = contains(["gzip", "none"], var.compression)
    error_message = "Compression must be either 'gzip' or 'none'."
  }
}

variable "quicknode_api_key" {
  description = "QuickNode API key for pausing webhooks before updates"
  type        = string
  sensitive   = true
}

