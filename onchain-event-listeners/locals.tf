# Load event signatures from shared JSON file (single source of truth)
# This ensures consistency between Terraform and TypeScript code
locals {
  # Generate JavaScript filter function for QuickNode webhook
  # The filter function checks if logs match any of our multisig addresses
  # and any of our event signatures (topic0)
  # Includes error handling to prevent webhook failures
  # Load ABI from shared JSON file at root (single source of truth)
  safe_abi = jsondecode(file("${path.root}/safe-abi.json"))

  # Generate ABI comment block for QuickNode template metadata
  # Format: /*\ntemplate: evmAbiFilter\nabi: [<JSON>]\ncontracts: <addresses>\n*/
  abi_comment = <<-EOT
/*
template: evmAbiFilter
abi: ${jsonencode(local.safe_abi)}
contracts: ${join(", ", [for addr in var.multisig_addresses : lower(addr)])}
*/
EOT

  # Load from template file and inject multisig addresses and ABI from Terraform config
  filter_function_js = templatefile("${path.module}/filter-function.js.tpl", {
    contracts   = var.multisig_addresses
    abi_json    = jsonencode(local.safe_abi)
    abi_comment = local.abi_comment
  })

  # Base64 encode the filter function
  filter_function_base64 = base64encode(local.filter_function_js)

  # Create a hash of the webhook data to detect changes (excluding status)
  # This will trigger the pause resource before updates
  webhook_data_hash = md5(jsonencode({
    name            = var.webhook_name
    network         = var.network
    filter_function = local.filter_function_base64
    destination_url = var.webhook_endpoint_url
    compression     = var.compression
  }))
}

