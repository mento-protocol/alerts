# Tenderly Alerts Setup Steps

## ⚠️ Important: Celo Network Limitation

The Tenderly API currently has issues with Celo network contracts. You must add contracts manually before creating alerts.

## Setup Order

### Step 1: Run Terraform for Discord Setup

```bash
terraform apply -target=module.tenderly_alerts.discord_text_channel.multisig_alerts -target=module.tenderly_alerts.discord_text_channel.multisig_events -target=module.tenderly_alerts.restapi_object.discord_webhook_alerts -target=module.tenderly_alerts.restapi_object.discord_webhook_events
```

This creates:

- ✅ Discord channels
- ✅ Discord webhooks

### Step 2: Manually Add Contracts to Tenderly

1. Go to: https://dashboard.tenderly.co/philipThe2nd/project/contracts
2. Click **"Add Contract"**
3. Add **Mento Labs Multisig**:
   - Network: `Celo`
   - Address: `0x655133d8E90F8190ed5c1F0f3710F602800C0150`
   - Name: `Mento Labs Multisig`
4. Add **Reserve Multisig**:
   - Network: `Celo`
   - Address: `0x87647780180B8f55980C7D3fFeFe08a9B29e9aE1`
   - Name: `Reserve Multisig`

### Step 3: Create Alerts

Once contracts are added, run:

```bash
terraform apply -target=module.tenderly_alerts.restapi_object.multisig_alerts
```

## Verification

After setup:

1. Check Discord channels exist in your server
2. Check contracts appear in Tenderly dashboard
3. Check alerts are created in Tenderly Alerts section

## Troubleshooting

If you get 500 errors on alert creation:

- Ensure contracts are added in Tenderly first
- Verify your project slug is correct (`project` in your case)
- Check that the Discord webhooks were created successfully

## Current Status

✅ Discord resources created successfully
❌ Contracts must be added manually (Celo API issue)
⏳ Alerts pending (waiting for manual contract addition)
