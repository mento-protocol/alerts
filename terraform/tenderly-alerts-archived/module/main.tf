######################
# Tenderly Alerts for Multiple Multisigs
######################
# Note: Provider configurations are in main.tf

######################
# Multisig Configuration
######################

locals {
  # Use multisigs from variable input
  multisigs = var.multisigs

  celo_network_id = "42220"

  # Safe contract event signatures (keccak256 hashes)
  # These are standard Safe v1.3.0 events - verify against your specific Safe version
  event_signatures = {
    # Critical Security Events (→ alerts channel)
    safe_setup        = "0x141df868a6331af528e38c83b7aa03edc19be66e37ae67f9285bf4f8e3c6a1a8" # SafeSetup
    added_owner       = "0x9465fa0c962cc76958e6373a993326400c1c94f8be2fe3a952adfa7f60b2ea26" # AddedOwner
    removed_owner     = "0xf8d49fc529812e9a7c5c50e69c20f0dccc0db8fa95c98bc58cc9a4f1c1299eaf" # RemovedOwner
    changed_threshold = "0x610f7ff2b304ae8903c3de74c60c6ab1f7d6226b3f52c5161905bb5ad4039c93" # ChangedThreshold
    changed_fallback  = "0x5ac6c46c93519d78e5e78d13553cc846b05b929af8cec273a4da640ef71518b2" # ChangedFallbackHandler
    enabled_module    = "0xecdf3a3effea5783a3c4c2140e677577666428d44ed9d474a0b3a4c9943f8440" # EnabledModule
    disabled_module   = "0xe009cfde5f0e68181a3a13f192effb5e90e7a6a35744c6302aebcf7e6ea6a41e" # DisabledModule
    changed_guard     = "0x1151116914515bc0891ff9047a6cb32cf902546f83066499bcf8ba33d2353fa2" # ChangedGuard

    # Regular Operation Events (→ events channel)
    execution_success         = "0x442e715f626346e8c54381002da614f62bee8d27386535b2521ec8540898556e" # ExecutionSuccess
    execution_failure         = "0x23428b18acfb3ea64b08dc0c1d296ea9c09702c09083ca5272e64d115b687d23" # ExecutionFailure
    approve_hash              = "0xf2a0eb156472d1440255b0d7c1e19cc07115d1051fe605b0dce69acfec884d9c" # ApproveHash
    sign_msg                  = "0xe7f4675038f4f6034dfcbbb24c4dc08e4ebf10eb9d257d3d02c0f38d122ac6e4" # SignMsg
    safe_module_transaction   = "0xb648d3644f584ed1c2232d53c46d87e693586486ad0d1175f8656013110b714e" # SafeModuleTransaction
    execution_from_module     = "0x6bb56a14aadc7530dc9cd8ce06ef9aa3e2fb53d2e6c0a84e08a2982473a19a02" # ExecutionFromModuleSuccess
    safe_received             = "0x3d0ce9bfc3ed7d6862dbb28b2dea94561fe714a1b4d019aa8af39730d1ad7c3d" # SafeReceived
    safe_multisig_transaction = "0x66753e819721f3c7a15c0e713f8dd6b103a123eb3a06a1ad39ab18d3b094ad85" # SafeMultiSigTransaction
  }

  # Event to channel mapping
  alert_channel_events = {
    safe_setup        = local.event_signatures.safe_setup
    added_owner       = local.event_signatures.added_owner
    removed_owner     = local.event_signatures.removed_owner
    changed_threshold = local.event_signatures.changed_threshold
    changed_fallback  = local.event_signatures.changed_fallback
    enabled_module    = local.event_signatures.enabled_module
    disabled_module   = local.event_signatures.disabled_module
    changed_guard     = local.event_signatures.changed_guard
  }

  events_channel_events = {
    execution_success         = local.event_signatures.execution_success
    execution_failure         = local.event_signatures.execution_failure
    approve_hash              = local.event_signatures.approve_hash
    sign_msg                  = local.event_signatures.sign_msg
    safe_module_transaction   = local.event_signatures.safe_module_transaction
    execution_from_module     = local.event_signatures.execution_from_module
    safe_received             = local.event_signatures.safe_received
    safe_multisig_transaction = local.event_signatures.safe_multisig_transaction
  }

  # Flatten the multisig-event combinations for alerts
  security_alerts = flatten([
    for ms_key, ms in local.multisigs : [
      for event_key, event_sig in local.alert_channel_events : {
        key          = "${ms_key}_${event_key}"
        multisig_key = ms_key
        multisig     = ms
        event_key    = event_key
        event_sig    = event_sig
        channel_type = "alerts"
      }
    ]
  ])

  operation_events = flatten([
    for ms_key, ms in local.multisigs : [
      for event_key, event_sig in local.events_channel_events : {
        key          = "${ms_key}_${event_key}"
        multisig_key = ms_key
        multisig     = ms
        event_key    = event_key
        event_sig    = event_sig
        channel_type = "events"
      }
    ]
  ])

  # Combine all alerts for easier resource creation
  all_alerts = concat(local.security_alerts, local.operation_events)
}

######################
# Discord Channels
######################

# Create alerts channels for each multisig
resource "discord_text_channel" "multisig_alerts" {
  for_each = local.multisigs

  name                     = "🚨︱multisig-alerts-${each.key}"
  server_id                = var.discord_server_id
  category                 = var.discord_category_id
  topic                    = "Critical security events for ${each.value.name} on Celo"
  sync_perms_with_category = true
  position                 = index(keys(local.multisigs), each.key) * 2 + 1
}

# Create events channels for each multisig
resource "discord_text_channel" "multisig_events" {
  for_each = local.multisigs

  name                     = "🔔︱multisig-events-${each.key}"
  server_id                = var.discord_server_id
  category                 = var.discord_category_id
  topic                    = "Transaction events for ${each.value.name} on Celo"
  sync_perms_with_category = true
  position                 = index(keys(local.multisigs), each.key) * 2 + 2
}

######################
# Webhook URLs
######################

# Discord webhooks are created automatically via discord-webhooks-restapi.tf
# The webhook URLs are extracted from API responses and used for Tenderly notifications

locals {
  # Parse webhook URLs from auto-generated webhooks
  # Webhooks are created automatically via discord-webhooks-restapi.tf
  webhook_urls = {
    for key, multisig in local.multisigs : key => {
      alerts = try(jsondecode(restapi_object.discord_webhook_alerts[key].api_response).url, "")
      events = try(jsondecode(restapi_object.discord_webhook_events[key].api_response).url, "")
    }
  }
}

######################
# Tenderly Alerts
######################

# Create Tenderly alerts using existing delivery channels
# NOTE: Delivery channels must be created manually via Tenderly UI first because the API does not support creating them
# Get the channel IDs from: https://dashboard.tenderly.co/philipThe2nd/project/alerts/destinations
resource "restapi_object" "multisig_alerts" {
  # Only create alerts if delivery channels are configured
  for_each = var.tenderly_delivery_channels.mento_labs_alerts != "" ? { for alert in local.all_alerts : alert.key => alert } : {}

  path = "/account/${var.tenderly_account_id}/project/${var.tenderly_project_slug}/alert"

  data = jsonencode({
    name = format(
      "%s %s [Celo] — %s",
      each.value.channel_type == "alerts" ? "🚨" : "🔔",
      each.value.multisig.name,
      upper(replace(each.value.event_key, "_", " "))
    )
    description = format(
      "%s for %s event on %s",
      each.value.channel_type == "alerts" ? "Security alert" : "Event notification",
      each.value.event_key,
      each.value.multisig.name
    )
    enabled = true
    color   = each.value.channel_type == "alerts" ? "#ff4757" : "#5f27cd"
    expressions = [
      {
        type = "contract_address"
        expression = {
          address = lower(each.value.multisig.address)
        }
      },
      {
        type = "network"
        expression = {
          network_id = local.celo_network_id
        }
      },
      {
        type = "emitted_log"
        expression = {
          address  = lower(each.value.multisig.address)
          event_id = each.value.event_sig
        }
      }
    ]
    delivery_channels = [
      {
        enabled = true
        id = lookup({
          "mento-labs" = {
            "alerts" = var.tenderly_delivery_channels.mento_labs_alerts
            "events" = var.tenderly_delivery_channels.mento_labs_events
          }
          "reserve" = {
            "alerts" = var.tenderly_delivery_channels.reserve_alerts
            "events" = var.tenderly_delivery_channels.reserve_events
          }
        }[each.value.multisig_key], each.value.channel_type, "")
      }
    ]
  })

  id_attribute = "id"

  # Ensure contracts are added first
  depends_on = [
    restapi_object.tenderly_contracts
  ]
}


