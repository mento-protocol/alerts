# Tenderly Alerts Module

This module monitors Safe multisig events on Celo using Tenderly and sends notifications to Discord.

## Purpose

Provides real-time monitoring of critical security events and operational transactions for Safe multisig wallets on the Celo blockchain.

## ⚠️ Important: Manual Setup Required

**Tenderly delivery channels must be created via UI before using this module.**  
See [`../TENDERLY_SETUP.md`](../TENDERLY_SETUP.md) for detailed instructions.

## Resources Created

Per multisig:

- **Tenderly Contract**: Automatically adds contract to your Tenderly project
- **Discord Channels**:
  - `#🚨︱multisig-alerts-{name}` - Security events
  - `#🔔︱multisig-events-{name}` - Operational events
- **Discord Webhooks**: Automatically created via REST API
- **Tenderly Alerts**: 16 different Safe event types

## Configuration

### Required Variables

```hcl
variable "tenderly_api_key" {
  description = "Tenderly API key"
  type        = string
  sensitive   = true
}

variable "tenderly_project_slug" {
  description = "Tenderly project slug"
  type        = string
}

variable "discord_bot_token" {
  description = "Discord bot token"
  type        = string
  sensitive   = true
}

variable "discord_server_id" {
  description = "Discord server ID"
  type        = string
}

variable "multisigs" {
  description = "Multisig configurations"
  type = map(object({
    name    = string
    address = string
  }))
}
```

### Providers Used

- `discord` - Creates Discord channels
- `restapi` - Creates Tenderly alerts
- `restapi.discord` - Creates Discord webhooks

## Monitored Events

### 🚨 Security Events (Critical)

- **SafeSetup** - Multisig initialization
- **AddedOwner** - New owner added
- **RemovedOwner** - Owner removed
- **ChangedThreshold** - Signature threshold changed
- **ChangedFallbackHandler** - Fallback handler modified
- **EnabledModule** - Module enabled
- **DisabledModule** - Module disabled
- **ChangedGuard** - Guard changed

### 🔔 Operational Events (Informational)

- **ExecutionSuccess** - Transaction executed successfully
- **ExecutionFailure** - Transaction execution failed
- **ApproveHash** - Transaction hash approved
- **SignMsg** - Message signed
- **SafeModuleTransaction** - Module transaction executed
- **ExecutionFromModuleSuccess** - Module execution successful
- **SafeReceived** - Funds received
- **SafeMultiSigTransaction** - Multisig transaction created

## How It Works

1. **Tenderly monitors** blockchain for Safe events
2. **Event detected** matching configured signatures
3. **Webhook triggered** to appropriate Discord channel
4. **Notification sent** with event details

## Adding Multisigs

Edit your `terraform.tfvars`:

```hcl
multisigs = {
  "existing-multisig" = { ... },
  "new-multisig" = {
    name    = "New Multisig Name"
    address = "0xYourMultisigAddress"
  }
}
```

Then apply:

```bash
terraform apply -target=module.tenderly_alerts
```

## Event Signatures

See [`safe-event-signatures.md`](safe-event-signatures.md) for:

- Complete list of events
- Keccak256 signatures
- How to generate signatures
- Safe contract references

## Outputs

- `discord_channels` - Created channel names
- `webhook_urls` - Generated webhook URLs (sensitive)
- `webhook_info` - Webhook IDs and details
- `tenderly_alerts_summary` - Alert statistics
- `alert_configuration` - Detailed configuration

## Testing

### Test Specific Event

Send a test transaction to trigger an event:

```bash
# Example: Send 0 CELO to trigger ExecutionSuccess
cast send --rpc-url https://forno.celo.org \
  0x655133d8E90F8190ed5c1F0f3710F602800C0150 \
  --value 0 \
  --private-key $PRIVATE_KEY
```

### Verify Alert

1. Check Tenderly dashboard for alert trigger
2. Check appropriate Discord channel for notification
3. Verify event details in message

## Architecture

```
Celo Blockchain
    ↓
Tenderly Monitoring
    ↓
Alert Triggered
    ↓
Discord Webhook
    ↓
Discord Channel
```

## Troubleshooting

### No Alerts Received

1. Check if contract was successfully added (view in Tenderly dashboard)
2. Verify webhook URLs are correctly generated
3. Ensure Discord bot has channel permissions
4. Verify network ID is correct (42220 for Celo)
5. Confirm transactions are happening on the monitored address

### Wrong Channel

Check event mapping in `main.tf`:

- Security events → alerts channel
- Operational events → events channel

### Alert Spam

Adjust alert conditions in Tenderly dashboard or disable specific events in Terraform.

## Webhook Management

Webhooks are **automatically created** via Terraform. To recreate:

```bash
# Destroy and recreate webhooks
terraform destroy -target=module.tenderly_alerts.restapi_object.discord_webhook_alerts
terraform apply -target=module.tenderly_alerts
```

## Limitations

- One webhook per channel (Discord limitation)
- All events of same type go to same channel
- No filtering by transaction value or sender
- Celo mainnet only (network ID 42220)
