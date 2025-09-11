# How to Get Tenderly Delivery Channel IDs

Since the Tenderly UI doesn't display delivery channel IDs, use the API to retrieve them:

## Method 1: API Request (Recommended)

Run this command to get all your delivery channel IDs:

```bash
curl --request GET \
  --url "https://api.tenderly.co/api/v1/account/me/delivery-channels" \
  --header 'Accept: application/json' \
  --header "X-Access-Key: YOUR_TENDERLY_API_KEY" | python3 -m json.tool
```

This will return a JSON response with all your delivery channels, including:

- `id`: The channel ID you need for Terraform
- `label`: The name you gave the channel in the UI
- `type`: The channel type (discord, email, etc.)
- `information.webhook`: The Discord webhook URL

### Formatted Output

For a cleaner output showing just the IDs and labels:

```bash
curl --request GET \
  --url "https://api.tenderly.co/api/v1/account/me/delivery-channels" \
  --header 'Accept: application/json' \
  --header "X-Access-Key: YOUR_TENDERLY_API_KEY" -s | python3 -c "
import json, sys
data = json.load(sys.stdin)
channels = data.get('delivery_channels', [])
print('=== Tenderly Delivery Channel IDs ===\n')
for channel in channels:
    if channel.get('type') == 'discord':
        print(f\"{channel.get('label', 'Unknown')}:\")
        print(f\"  ID: {channel.get('id', 'No ID')}\n\")
"
```

## Example Output

```
=== Tenderly Delivery Channel IDs ===

Mento Labs Multisig Alerts:
  ID: 3282b127-3dc3-4ad5-84c4-1d8b0ae7d208

Mento Labs Multisig Events:
  ID: a809ae1c-8a62-4d7d-b570-c7b7f31625d3

Reserve Multisig Alerts:
  ID: 9c0915b4-dc6e-472e-b249-d08ad261e7d9

Reserve Multisig Events:
  ID: aff3bc61-f078-4dd3-891e-180851b31fce
```

## Add to Terraform

Once you have the IDs, add them to your `terraform.tfvars`:

```hcl
tenderly_delivery_channels = {
  mento_labs_alerts = "3282b127-3dc3-4ad5-84c4-1d8b0ae7d208"
  mento_labs_events = "a809ae1c-8a62-4d7d-b570-c7b7f31625d3"
  reserve_alerts    = "9c0915b4-dc6e-472e-b249-d08ad261e7d9"
  reserve_events    = "aff3bc61-f078-4dd3-891e-180851b31fce"
}
```

## Troubleshooting

### API Key Location

Find your Tenderly API key at: <https://dashboard.tenderly.co/account/authorization>

### No Channels Returned

If the API returns an empty list:

1. Ensure you've created the delivery channels in the UI first
2. Check that your API key has the correct permissions
3. Try the project-specific endpoint if you have multiple projects

### Alternative: Check Existing Alerts

If you have existing alerts using the channels:

```bash
curl --request GET \
  --url "https://api.tenderly.co/api/v1/account/me/project/YOUR_PROJECT/alerts" \
  --header 'Accept: application/json' \
  --header "X-Access-Key: YOUR_API_KEY" -s | python3 -c "
import json, sys
data = json.load(sys.stdin)
channels = {}
for alert in data.get('alerts', []):
    for dc in alert.get('delivery_channels', []):
        channel_id = dc.get('delivery_channel_id')
        if channel_id:
            channels[channel_id] = alert.get('name', '')
print('Channel IDs found in alerts:')
for id, alert in channels.items():
    print(f'  {id}: {alert}')
"
```
