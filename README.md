# Mento Alerts

This repository manages alert rules for monitoring Mento's infrastructure using Terraform.

## 📦 Module Structure

```plain
terraform/
├── main.tf                 # Root configuration and module orchestration
├── variables.tf            # Shared variable definitions
├── outputs.tf              # Aggregated outputs
│
├── sentry-alerts/          # Sentry JS error monitoring
│   ├── main.tf
│   ├── providers.tf
│   ├── variables.tf
│   ├── outputs.tf
│   └── README.md
│
├── discord-monitoring.tf   # Shared Discord infrastructure
├── safe-event-signatures.md # Event signatures reference
└── tenderly-alerts-archived/ # Archived Tenderly integration
    └── README.md             # See archive for full details
```

## Current Integrations

- **Sentry**: Forwards application errors to project-specific Discord channels
- **QuickNode Webhooks**: (Coming soon) For blockchain event monitoring

> **Note on Monitoring Solutions:** We initially implemented Tenderly for blockchain event monitoring
> but switched to QuickNode Webhooks due to Tenderly's alert pricing. The Tenderly integration
> code is preserved in `terraform/tenderly-alerts-archived/` for potential future use.

## Prerequisites

### Discord Setup

1. **Discord Server**: With a category for alerts
2. **Discord Bot**: Bot token with admin permissions

### For Sentry Alerts

1. **Sentry Account**: Organization with projects
2. **Sentry API Token**: From Account Settings > Auth Tokens
3. **Discord Integration**: [Install Sentry's Discord integration](https://docs.sentry.io/organization/integrations/notification-incidents/discord/)

### For Blockchain Monitoring (Coming Soon)

1. **QuickNode Account**: With webhook support
2. **Contracts**: Safe multisigs to monitor

### System Requirements

- Terraform >= 1.10.0

## 🚀 Quick Start

### 1. Configure Variables

```bash
cp terraform/terraform.tfvars.example terraform/terraform.tfvars
# Fill in all values in terraform.tfvars
```

Required variables:

```hcl
# Discord
discord_bot_token      = "your-bot-token"
discord_server_id      = "your-server-id"
discord_category_id    = "your-category-id"

# Sentry
sentry_auth_token      = "your-sentry-token"
discord_sentry_role_id = "your-sentry-role-id"
```

### 2. Initialize & Deploy

```bash
cd terraform
terraform init
terraform plan
terraform apply
```

## 📊 What Gets Created

### Sentry Module (`sentry-alerts/`)

**Purpose**: Monitor application errors

**Creates**:

- Discord channels: `#sentry-{project-name}` for each Sentry project
- Alert rules forwarding errors to Discord
- Proper permissions for Sentry integration

[Full Documentation →](terraform/sentry-alerts/README.md)

### Discord Monitoring Infrastructure

**Purpose**: Shared Discord channels and webhooks for blockchain monitoring

**Creates per multisig**:

- **Discord Channels** (2 per Safe):
  - `#🚨︱multisig-alerts-{name}` - Critical events like owner or threshold changes
  - `#🔔︱multisig-events-{name}` - Normal transaction events
- **Discord Webhooks**: Automated creation via REST API

**Note**: Currently used with QuickNode Webhooks. Archived Tenderly integration available in `tenderly-alerts-archived/`.

## 🔧 Common Operations

### Deploy Individual Modules

```bash
# Deploy only Sentry monitoring
terraform apply -target=module.sentry_alerts

# Deploy Discord infrastructure
terraform apply -target=discord_text_channel.multisig_alerts -target=discord_text_channel.multisig_events -target=restapi_object.discord_webhook_alerts -target=restapi_object.discord_webhook_events
```

### Add New Multisig

Edit `terraform/terraform.tfvars`:

```hcl
multisigs = {
  "existing-name" = { ... },
  "new-multisig" = {
    name    = "New Multisig Name"
    address = "0xYourAddress..."
  }
}
```

Then run:

```bash
terraform apply
```

### View Current State

```bash
# List all resources
terraform state list

# Show outputs
terraform output

# Module-specific outputs
terraform output -module=sentry_alerts
```

### Destroy Resources

```bash
# Destroy specific module
terraform destroy -target=module.sentry_alerts

# Destroy everything
terraform destroy
```

## 📚 Documentation

### Architecture & Design

- [`.cursor/ARCHITECTURE.mdc`](.cursor/ARCHITECTURE.mdc) - System design and module organization

### Module Documentation

- [`terraform/sentry-alerts/README.md`](terraform/sentry-alerts/README.md) - Sentry module details
- [`terraform/tenderly-alerts-archived/README.md`](terraform/tenderly-alerts-archived/README.md) - Archived Tenderly integration
- [`terraform/safe-event-signatures.md`](terraform/safe-event-signatures.md) - Safe contract event reference

### External Documentation

- [Terraform Documentation](https://www.terraform.io/docs)
- [Sentry API Docs](https://docs.sentry.io/api/)
- [Discord Developer Docs](https://discord.com/developers/docs)
- [QuickNode Documentation](https://www.quicknode.com/docs)

## 🏗️ Module Independence

Each module can be:

- Deployed independently
- Tested in isolation
- Destroyed without affecting others
- Modified without impacting other modules

## 🔒 Security

- API keys stored in `terraform.tfvars` (gitignored)
- Sensitive outputs marked appropriately
- State file contains secrets - handle carefully

## 🐛 Debugging

Enable debug mode in `terraform.tfvars`:

```hcl
debug_mode = true
```

This will show REST API requests/responses for troubleshooting.
