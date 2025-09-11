# Tenderly Delivery Channels Setup

## Overview

Tenderly requires **delivery channels** to be created via the UI before alerts can be created via API/Terraform. This is a one-time manual setup.

## Step-by-Step Setup

### 1. Navigate to Alert Destinations

Go to: <https://dashboard.tenderly.co/philipThe2nd/project/alerts/destinations>

### 2. Create Delivery Channels / Destinations

You need to create one Discord delivery channels for each Discord channel:

#### Mento Labs Multisig - Alerts Channel

1. Click "Add Destination"
2. Select "Discord"
3. Label: `Mento Labs Multisig Alerts`
4. Webhook URL:

   ```plain
   https://discord.com/api/webhooks/1410647540017266832/pexDqGHN9KglCnujBs3T7J5Ue_iyRGC1NvGQ6pF2Z-XUeh385cYwcDzq0BzjJpMcBIO2
   ```

5. Click "Save"
6. **Note**: The ID is not visible in the UI. See [`GET_CHANNEL_IDS.md`](GET_CHANNEL_IDS.md) for instructions on how to retrieve it

#### Mento Labs Multisig - Events Channel

1. Click "Add Destination"
2. Select "Discord"
3. Label: `Mento Labs Multisig Events`
4. Webhook URL:

   ```plain
   https://discord.com/api/webhooks/1410647540579172353/6_3bFfer0FC9zUzBq0T8cJUJalkjvpKdd_ILpK17uNOu6CGt17g5jRf60S0dOo3JcFPe
   ```

5. Click "Save"
6. Copy the generated ID

#### Reserve Multisig - Alerts Channel

1. Click "Add Destination"
2. Select "Discord"
3. Label: `Reserve Multisig Alerts`
4. Webhook URL:

   ```plain
   https://discord.com/api/webhooks/1410647540344295476/CkQe7QjyX65BSRbF8D_iE30qhUB-EAgkh-xv-X0aWOV-X4o6k9HTnDPdIn4i56wfMSn7
   ```

5. Click "Save"
6. Copy the generated ID

#### Reserve Multisig - Events Channel

1. Click "Add Destination"
2. Select "Discord"
3. Label: `Reserve Multisig Events`
4. Webhook URL:

   ```plain
   https://discord.com/api/webhooks/1410647540113870861/xyHEI9adOhoOgtSHxRLmKL4wBEVDh5iV6gVQYipD1jMeywUmfYd9-d0MrbpjyZhfXz4Q
   ```

5. Click "Save"
6. Copy the generated ID

### 3. Configure Terraform

Add the delivery channel IDs to your `terraform.tfvars`:

```hcl
# Tenderly Delivery Channels (created via UI)
tenderly_delivery_channels = {
  mento_labs_alerts = "xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx"  # From step 2.1
  mento_labs_events = "xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx"  # From step 2.2
  reserve_alerts    = "xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx"  # From step 2.3
  reserve_events    = "xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx"  # From step 2.4
}
```

### 4. Deploy Alerts

Once the delivery channels are configured:

```bash
cd terraform
terraform plan
terraform apply
```

This will create:

- 32 Tenderly alerts (16 events × 2 multisigs)
- Each alert will use the appropriate delivery channel based on event type

## Event Routing

### Security Events → Alerts Channel

- SafeSetup
- AddedOwner
- RemovedOwner
- ChangedThreshold
- ChangedFallbackHandler
- EnabledModule
- DisabledModule
- ChangedGuard

### Operational Events → Events Channel

- ExecutionSuccess
- ExecutionFailure
- ApproveHash
- SignMsg
- SafeModuleTransaction
- ExecutionFromModuleSuccess
- SafeReceived
- SafeMultisigTransaction

## Troubleshooting

### Finding Delivery Channel IDs

After creating delivery channels in the UI, you can list them via API:

```bash
curl -H "X-Access-Key: YOUR_API_KEY" \
  https://api.tenderly.co/api/v1/account/me/project/project/delivery-channels
```

### Testing Webhooks

Test a webhook directly:

```bash
curl -X POST "WEBHOOK_URL" \
  -H "Content-Type: application/json" \
  -d '{"content": "Test message from Terraform setup"}'
```

## Notes

- Delivery channels cannot be created via API (returns 404)
- Each delivery channel can be reused for multiple alerts
- Changes to delivery channels in UI won't affect existing alerts
- To update webhook URLs, create new delivery channels and update the IDs in Terraform
