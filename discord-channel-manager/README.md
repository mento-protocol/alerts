# Discord Channel Manager Module

This module creates and manages Discord channels and webhooks for blockchain event monitoring. It's **provider-agnostic** and can be used with QuickNode, Tenderly, or any other blockchain monitoring service.

## Features

- ✅ **Automated Discord Channel Creation** - Creates 2 channels per multisig
- ✅ **Automated Webhook Management** - Creates webhooks via Discord REST API (no manual steps!)
- ✅ **Provider-Agnostic** - Works with any monitoring service
- ✅ **Terraform-Native** - No external scripts or manual configuration
- ✅ **Proper Ordering** - Channels are positioned alphabetically

## What Gets Created

For each multisig in your configuration:

### Discord Channels (2 per multisig)

1. **`#🚨︱multisig-alerts-{name}`** - Critical security events
   - Owner changes
   - Threshold modifications
   - Module/guard changes
   - Configuration updates

2. **`#🔔︱multisig-events-{name}`** - Normal operational events
   - Transaction executions
   - Approvals
   - Incoming funds
   - Module transactions

### Discord Webhooks

- Automatically created for each channel via Discord REST API
- Managed entirely by Terraform
- URLs marked as sensitive outputs

## Usage

```hcl
module "discord_channel_manager" {
  source = "./discord-channel-manager"

  providers = {
    restapi.discord = restapi.discord
  }

  multisigs = {
    "mento-labs" = {
      name    = "Mento Labs Multisig"
      address = "0x655133d8E90F8190ed5c1F0f3710F602800C0150"
    }
    "reserve" = {
      name    = "Reserve Multisig"
      address = "0x87647780180B8f55980C7D3fFeFe08a9B29e9aE1"
    }
  }

  discord_server_id   = "your-server-id"
  discord_category_id = "your-category-id"
}
```

## Inputs

| Name                  | Description                                        | Type                                               | Required |
| --------------------- | -------------------------------------------------- | -------------------------------------------------- | -------- |
| `multisigs`           | Map of multisig configurations                     | `map(object({ name = string, address = string }))` | Yes      |
| `discord_server_id`   | Discord server ID                                  | `string`                                           | Yes      |
| `discord_category_id` | Discord category ID where channels will be created | `string`                                           | Yes      |

## Outputs

| Name                        | Description                                 | Sensitive |
| --------------------------- | ------------------------------------------- | --------- |
| `multisig_discord_channels` | Discord channel names for each multisig     | No        |
| `webhook_urls`              | Webhook URLs for alerts and events channels | Yes       |
| `webhook_info`              | Webhook IDs and channel information         | No        |

## Provider Requirements

### Discord Provider

```hcl
provider "discord" {
  token = var.discord_bot_token
}
```

**Required Bot Permissions:**

- Administrator (or at minimum: Manage Channels, Manage Webhooks)

### REST API Provider (Discord API)

```hcl
provider "restapi" {
  alias = "discord"
  uri   = "https://discord.com/api/v10"
  headers = {
    "Authorization" = "Bot ${var.discord_bot_token}"
    "Content-Type"  = "application/json"
  }
  write_returns_object = true
}
```

## Architecture

```text
Root Module
    ↓ (passes multisigs + Discord config)
Discord Monitoring Module
    ↓
Creates: Channels + Webhooks
    ↓
Output: webhook_urls
    ↓
Used by: QuickNode, Tenderly, or other monitoring services
```

## Security Features

- ✅ **Webhook URL Validation** - Lifecycle postconditions ensure webhook creation succeeds
- ✅ **Sensitive Outputs** - Webhook URLs marked as sensitive
- ✅ **Permission Syncing** - Channels inherit category permissions

## Example: Using with QuickNode

```hcl
module "alert_handler" {
  source = "./onchain-event-handler"

  discord_webhook_mento_labs_alerts = module.discord_channel_manager.webhook_urls["mento-labs"].alerts
  discord_webhook_mento_labs_events = module.discord_channel_manager.webhook_urls["mento-labs"].events
  # ... other config
}
```

## Adding New Multisigs

Simply add to the `multisigs` variable:

```hcl
multisigs = {
  "existing" = { ... },
  "new-multisig" = {
    name    = "Treasury Multisig"
    address = "0xYourAddress..."
  }
}
```

Terraform will automatically create the channels and webhooks.

## Removing Multisigs

Remove from the `multisigs` variable. Terraform will destroy the associated channels and webhooks.

⚠️ **Warning:** This will permanently delete the Discord channels and all message history.

## Troubleshooting

### Webhook Creation Fails

**Error:** `Discord webhook creation failed or returned invalid response`

**Causes:**

- Bot doesn't have required permissions
- Discord server ID or category ID is incorrect
- Discord API rate limiting

**Solution:**

1. Verify bot has Administrator permissions
2. Confirm server/category IDs are correct
3. Check Discord API status: <https://discordstatus.com/>
4. Enable debug mode: `debug_mode = true` in root variables

### Channels Not Appearing

**Cause:** Category permissions issue

**Solution:** Ensure your bot has permissions to create channels in the specified category.

## Best Practices

1. **Category Setup** - Create a dedicated category for monitoring channels
2. **Permission Management** - Use `sync_perms_with_category = true` to inherit permissions
3. **Naming Convention** - Stick to the `{emoji}︱multisig-{type}-{name}` pattern for consistency
4. **Webhook Security** - Never log webhook URLs (they're marked sensitive for a reason!)

## Related Modules

- [`onchain-event-listeners`](../onchain-event-listeners/README.md) - QuickNode webhook configuration
- [`onchain-event-handler`](../onchain-event-handler/README.md) - Processes webhooks and routes to Discord
- [`sentry-alerts`](../sentry-alerts/README.md) - Application error monitoring

## References

- [Discord Developer Portal](https://discord.com/developers/docs)
- [Discord REST API](https://discord.com/developers/docs/resources/webhook)
- [Terraform Discord Provider](https://registry.terraform.io/providers/Lucky3028/discord/latest/docs)
