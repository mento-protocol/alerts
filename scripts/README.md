# Scripts

Utility scripts for managing the Mento Alerts infrastructure.

## QuickNode Webhook State Repair

Automatically detect and fix Terraform state drift for QuickNode webhooks.

### Usage

```bash
# Run directly (reads from terraform.tfvars automatically)
./scripts/fix-webhook-state.sh
```

The script will automatically read your QuickNode API key from `terraform.tfvars` if the environment variable is not set.

**Note:** This script requires network access to query QuickNode's API. If the script can't reach QuickNode, use the manual fix below.

### What it does

The script will:

1. **Find all webhook resources** in Terraform state
2. **Check if each webhook exists** in QuickNode via API
3. **Identify orphaned webhooks** - Resources in state that don't exist in QuickNode
4. **Offer to remove them from state** - Interactive prompt for cleanup
5. **Provide next steps** - Guidance on running `terraform apply` to recreate

### When to use

Run this script when you encounter:

- ❌ `Error: unexpected response code '404'` during `terraform apply`
- ❌ Terraform trying to update webhooks that don't exist
- ❌ Webhooks were deleted manually in QuickNode dashboard
- ❌ Previous `terraform apply` failed and left state inconsistent

### Example output

```bash
QuickNode Webhook State Repair Tool
======================================

Finding webhook resources in Terraform state...
Found the following webhook resources:
module.onchain_event_listeners["celo"].restapi_object.multisig_webhook

Checking webhook existence in QuickNode...

Checking: module.onchain_event_listeners["celo"].restapi_object.multisig_webhook
  Webhook ID: 9e8b54e7-8039-4dd7-92a4-151d200704f2
  ✗ Webhook NOT FOUND in QuickNode (404)

Found 1 webhook(s) in Terraform state that don't exist in QuickNode:
  - module.onchain_event_listeners["celo"].restapi_object.multisig_webhook

Remove these from Terraform state? (y/N) y
Removing: module.onchain_event_listeners["celo"].restapi_object.multisig_webhook
✓ Removed missing webhooks from state

Next steps:
  1. Run 'terraform plan' to see what will be created
  2. Run 'terraform apply' to recreate the missing webhooks
```

### Troubleshooting

#### Error: "QUICKNODE_API_KEY not found"

**Solution:** Provide your API key in one of these ways:

```bash
# Option 1: Add to terraform.tfvars (recommended)
quicknode_api_key = "your-api-key-here"

# Option 2: Export as environment variable
export QUICKNODE_API_KEY='your-api-key-here'
```

Get your API key from: <https://dashboard.quicknode.com/api-keys>

**Priority order:**

1. `QUICKNODE_API_KEY` environment variable
2. `quicknode_api_key` in `terraform.tfvars`

#### Error: "main.tf not found"

**Solution:** Run the script from the terraform root directory:

```bash
cd /path/to/alerts
./scripts/fix-webhook-state.sh
```

#### Script Can't Reach QuickNode API / Network Issues

**Solution:** Use the manual fix:

```bash
# Remove the orphaned webhook from state
terraform state rm -lock=false 'module.onchain_event_listeners["<network>"].restapi_object.multisig_webhook'

# Also remove the helper resources
terraform state rm -lock=false \
  'module.onchain_event_listeners["<network>"].null_resource.pause_webhook_before_update' \
  'module.onchain_event_listeners["<network>"].null_resource.pause_webhook_on_destroy'

# Plan to verify it will create (not update)
terraform plan -lock=false

# Apply to create the new webhook
terraform apply -lock=false
```

Replace `<network>` with your network key (e.g., `celo`, `ethereum`, `base`).

### Related Documentation

- [Webhook State Management Guide](../onchain-event-listeners/WEBHOOK_STATE_MANAGEMENT.md)
- [On-Chain Event Listeners Module](../onchain-event-listeners/README.md)

## Discord Permission Checker

Check Discord bot permissions and identify missing ones.

### Setup

```bash
cd scripts
npm install
```

### Discord Permission Checker Usage

```bash
# Easiest way - automatically reads from terraform.tfvars (including category ID)
tsx check-discord-permissions.ts

# Or with command-line arguments
tsx check-discord-permissions.ts <BOT_TOKEN> <SERVER_ID> [CATEGORY_ID]

# Or with environment variables
export DISCORD_BOT_TOKEN="your-bot-token"
export DISCORD_SERVER_ID="1234567890123456789"
export DISCORD_CATEGORY_ID="1234567890123456789"  # Optional
tsx check-discord-permissions.ts
```

The script will automatically read from `terraform.tfvars` if no arguments or environment variables are provided. Priority order:

1. Command-line arguments
2. Environment variables
3. `terraform.tfvars` file

**Note:** If `discord_category_id` is found in `terraform.tfvars`, the script will also check category-specific permissions.

### What it checks

The script verifies that your Discord bot has the following **server-wide** permissions:

- ✅ **MANAGE_CHANNELS** - Create, edit, and delete channels
- ✅ **MANAGE_WEBHOOKS** - Create, edit, and delete webhooks
- ✅ **VIEW_CHANNEL** - View channels
- ✅ **SEND_MESSAGES** - Send messages (required for webhooks)

If a category ID is provided (from `terraform.tfvars` or as an argument), the script also checks **category-specific** permissions:

- ✅ **View Category** - Bot can view the category
- ✅ **Manage Channels in Category** - Bot can create channels in the category
- ✅ **Channel Creation Test** - Actually tests creating a channel in the category (cleans up automatically)
- ✅ **Category Permission Management** - Bot can manage permissions on the category (needed for Sentry role setup)

If the bot has `ADMINISTRATOR` permission, all server-wide checks pass automatically, but category-specific checks still run to verify category access.

### Output

The script will:

- Verify bot authentication
- Check if the bot is in the server
- List all current server-wide permissions
- Identify missing server-wide permissions
- If category ID is provided:
  - Verify the category exists and is valid
  - Check category-specific permissions
- Test channel creation in the category
- Test category permission management
- Provide step-by-step instructions to fix any issues

### Discord Permission Checker Troubleshooting

#### Error: "Failed to authenticate bot token"

- Verify your bot token is correct
- Check that the token hasn't been revoked

#### Error: "Failed to fetch member info"

- Ensure the bot is invited to the server
- Verify the server ID is correct
- Check that the bot token has access to the server

#### Missing Permissions

- Follow the instructions provided by the script
- The easiest fix is to grant `Administrator` permission via Discord Server Settings → Roles
- Alternatively, use the OAuth2 URL generator in the Discord Developer Portal

#### Category Permission Issues

If you see category-specific permission errors:

1. **Option 1 (Recommended):** Grant permissions directly on the category
   - Right-click the category → Edit Category → Permissions
   - Find your bot's role and enable "View Channel" and "Manage Channels"

2. **Option 2:** Grant server-wide "Manage Channels" permission
   - Server Settings → Roles → Your Bot Role → Enable "Manage Channels"

**Note:** Category-specific permissions are required for:

- Creating channels in the category (multisig alerts, Sentry alerts)
- Managing category permissions (for Sentry role setup)
