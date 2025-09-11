######################
# Contract Management in Tenderly
######################
# This file adds the multisig contracts to the Tenderly project
# so they can be monitored by alerts

# Add each multisig contract to Tenderly project
# NOTE: Contracts are already added, skip creation to avoid conflicts
resource "restapi_object" "tenderly_contracts" {
  for_each = {} # Temporarily disabled as contracts already exist

  path = "/account/${var.tenderly_account_id}/project/${var.tenderly_project_slug}/address"

  data = jsonencode({
    network_id   = local.celo_network_id
    address      = lower(each.value.address) # Ensure lowercase
    display_name = each.value.name
  })

  id_attribute = "id"

  # Make sure contracts are added before alerts are created
  lifecycle {
    create_before_destroy = true
  }

  # Continue even if contract already exists
  create_method  = "POST"
  update_method  = "PATCH"
  destroy_method = "DELETE"
}

# Optional: Add contract tags for better organization
resource "restapi_object" "contract_tags" {
  for_each = {} # Disabled since contracts are managed externally

  path = "/account/${var.tenderly_account_id}/project/${var.tenderly_project_slug}/contracts/${each.value.address}/tag"

  data = jsonencode({
    tags = [
      "multisig",
      "safe",
      each.key,
      "automated"
    ]
  })

  id_attribute = "contract_id"

  depends_on = [restapi_object.tenderly_contracts]
}


