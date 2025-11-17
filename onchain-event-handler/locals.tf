# Compute a hash of the source files to detect actual changes
# This is more reliable than using the zip's SHA256 which includes metadata
# Prepare environment variables dynamically from multisig webhooks
locals {
  # Source file hashing for stable deployments
  source_files = fileset(path.module, "src/**")
  package_files = [
    "${path.module}/package.json",
    "${path.module}/package-lock.json",
    "${path.module}/tsconfig.json",
    "${path.root}/safe-abi.json",
  ]
  # Create a hash of all source files and package files
  source_hash = md5(join("", [
    for f in sort(concat(tolist(local.source_files), local.package_files)) :
    fileexists(f) ? filemd5(f) : ""
  ]))

  # Extract non-sensitive values from multisig_webhooks to avoid provider bug
  # The entire var.multisig_webhooks is marked sensitive, so we extract values first
  multisig_webhooks_nonsensitive = nonsensitive(var.multisig_webhooks)

  # Flatten multisig webhooks into environment variables
  # Format: MULTISIG_{KEY}_ADDRESS, DISCORD_WEBHOOK_{KEY}_ALERTS, etc.
  multisig_env_vars = merge([
    for key, config in local.multisig_webhooks_nonsensitive : {
      "MULTISIG_${upper(replace(key, "-", "_"))}_ADDRESS"       = config.address
      "MULTISIG_${upper(replace(key, "-", "_"))}_NAME"          = config.name
      "MULTISIG_${upper(replace(key, "-", "_"))}_CHAIN"         = config.chain
      "MULTISIG_${upper(replace(key, "-", "_"))}_CHAIN_ID"      = tostring(config.chain_id)
      "DISCORD_WEBHOOK_${upper(replace(key, "-", "_"))}_ALERTS" = config.alerts_webhook
      "DISCORD_WEBHOOK_${upper(replace(key, "-", "_"))}_EVENTS" = config.events_webhook
    }
  ]...)

  # Get list of unique chains for logging
  chains = distinct([for k, v in local.multisig_webhooks_nonsensitive : v.chain])

  # Combine with base environment variables (excluding secret)
  all_env_vars = merge(
    {
      # JSON-encoded multisig config for easy lookup in the function
      MULTISIG_CONFIG = jsonencode(local.multisig_webhooks_nonsensitive)
      # Comma-separated list of supported chains
      SUPPORTED_CHAINS = join(",", local.chains)
    },
    local.multisig_env_vars
  )
}

