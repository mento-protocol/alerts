# Archived: Tenderly Alerts Integration

This directory contains a complete Terraform module for Tenderly blockchain monitoring that was developed but not deployed due to pricing considerations.

## 📋 Why Archived?

- **Cost**: Tenderly's alert pricing was too expensive for our monitoring needs
- **Alternative**: Switched to QuickNode Webhooks as a more cost-effective solution
- **Status**: Code is fully functional and ready to deploy if needed in the future

## 📁 What's Included

### Module Components (`module/`)

- **`main.tf`**: Core alert definitions for 16 Safe multisig events
- **`contracts.tf`**: Automatic contract registration in Tenderly
- **`webhooks.tf`**: Discord webhook creation (moved to main configuration)
- **`providers.tf`**: Provider requirements
- **`variables.tf`**: Input variables
- **`outputs.tf`**: Module outputs
- **`README.md`**: Module documentation

### Documentation (`docs/`)

- **`TENDERLY_SETUP.md`**: Complete setup guide for Tenderly integration
- **`GET_CHANNEL_IDS.md`**: Instructions for retrieving delivery channel IDs via API
- **`MANUAL_CONTRACT_SETUP.md`**: Manual contract setup guide
- **`README_SETUP_STEPS.md`**: Step-by-step setup instructions

### Configuration Templates (`config-snippets/`)

- **`main.tf.snippet`**: Provider and module configuration
- **`variables.tf.snippet`**: Required variables
- **`outputs.tf.snippet`**: Output definitions

### Example Configuration (`example-configs/`)

- **`terraform.tfvars.example`**: Example variable values

## ✅ Current Status

The module was fully developed and tested:

- ✅ Fully configured and tested
- ✅ Delivery channel IDs obtained and configured
- ✅ Ready to deploy (36 resources would be created)
- ❌ Not deployed due to cost considerations

### What Was Configured

1. **16 Alert Types** per multisig:

   - Security alerts: SafeSetup, AddedOwner, RemovedOwner, ChangedThreshold, ChangedGuard, ChangedFallbackHandler, DisabledModule, EnabledModule
   - Event notifications: ApproveHash, ExecutionFailure, ExecutionSuccess, ExecutionFromModuleSuccess, ExecutionFromModuleFailure, SafeReceived, SafeMultiSigTransaction, SafeModuleTransaction

2. **2 Multisigs Monitored**:

   - Mento Labs Multisig: `0x87647780180B8f55980C7D3ffeFe08a9B29e9aE1`
   - Reserve Multisig: `0x87647780180B8f55980C7D3ffeFe08a9B29e9aE1`

3. **Discord Integration**:
   - 4 Discord channels (alerts + events for each multisig)
   - 4 Discord webhooks automatically created
   - Delivery channels configured with IDs

## 🚀 Quick Reactivation Guide

To re-enable Tenderly monitoring:

### 1. Copy Configuration Snippets

Add to `terraform/main.tf`:

```bash
cat tenderly-alerts-archived/config-snippets/main.tf.snippet >> ../main.tf
```

Add to `terraform/variables.tf`:

```bash
cat tenderly-alerts-archived/config-snippets/variables.tf.snippet >> ../variables.tf
```

Add to `terraform/outputs.tf`:

```bash
cat tenderly-alerts-archived/config-snippets/outputs.tf.snippet >> ../outputs.tf
```

### 2. Update terraform.tfvars

Add your Tenderly configuration:

```hcl
# Copy from example-configs/terraform.tfvars.example
tenderly_api_key      = "your-api-key"
tenderly_account_id   = "me"
tenderly_project_slug = "project"

# Your existing delivery channel IDs (if still valid)
tenderly_delivery_channels = {
  mento_labs_alerts = "3282b127-3dc3-4ad5-84c4-1d8b0ae7d208"
  mento_labs_events = "a809ae1c-8a62-4d7d-b570-c7b7f31625d3"
  reserve_alerts    = "9c0915b4-dc6e-472e-b249-d08ad261e7d9"
  reserve_events    = "aff3bc61-f078-4dd3-891e-180851b31fce"
}
```

### 3. Initialize and Deploy

```bash
terraform init
terraform plan
terraform apply
```

## 📝 Important Notes

1. **Discord Channels**: The Discord channel creation logic has been moved to `terraform/discord-monitoring.tf` and is still active for use with other monitoring providers.

2. **Event Signatures**: The Safe event signatures documentation has been moved to `terraform/safe-event-signatures.md` and is still actively used.

3. **Delivery Channels**: Must be created manually in Tenderly UI before deployment. Use the API to retrieve their IDs:

   ```bash
   curl --request GET \
     --url "https://api.tenderly.co/api/v1/account/me/delivery-channels" \
     --header 'Accept: application/json' \
     --header "X-Access-Key: YOUR_API_KEY"
   ```

4. **State Management**: If you had previously applied any Tenderly resources, you may need to import them or clean up the state file.

## 🔧 Module Features

- **Automatic Contract Registration**: Adds multisig contracts to Tenderly project
- **Event-based Alerts**: Monitors specific Safe contract events
- **Discord Integration**: Routes alerts to appropriate Discord channels
- **Flexible Configuration**: Supports multiple multisigs and custom event sets
- **Provider-agnostic Webhooks**: Discord webhook creation can be reused

## 📊 Resource Summary

Resources that would be created:

- 32 Tenderly alerts (16 events × 2 multisigs)
- 2 Contract registrations in Tenderly
- Total: 34 Tenderly resources + Discord resources (channels/webhooks)

## 🔗 Related Files

- Main configuration: `terraform/main.tf`
- Discord monitoring: `terraform/discord-monitoring.tf`
- Event signatures: `terraform/safe-event-signatures.md`
- Sentry alerts: `terraform/sentry-alerts/`
