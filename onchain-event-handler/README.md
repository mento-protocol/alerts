# Onchain Event Handler Module

Terraform module for deploying the Cloud Function that processes QuickNode webhooks and routes Safe multisig events to Discord.

## Overview

This module:

1. Builds and packages the TypeScript source code
2. Creates a Cloud Storage bucket for the function source
3. Deploys a Cloud Function
4. Configures environment variables for Discord webhooks
5. Sets up IAM permissions for public invocation (by QuickNode Webhooks)

## Prerequisites

- Google Cloud project with billing enabled
- Cloud Functions API enabled
- Cloud Storage API enabled
- Service account with appropriate permissions

## Usage

```hcl
module "onchain_event_handler" {
  source = "./onchain-event-handler"

  project_id = var.gcp_project_id
  region     = var.gcp_region

  quicknode_signing_secret       = var.quicknode_signing_secret
  discord_webhook_mento_labs_alerts  = module.discord_resources.webhook_urls.mento_labs.alerts
  discord_webhook_mento_labs_events  = module.discord_resources.webhook_urls.mento_labs.events
  discord_webhook_reserve_alerts     = module.discord_resources.webhook_urls.reserve.alerts
  discord_webhook_reserve_events     = module.discord_resources.webhook_urls.reserve.events
}
```

## Inputs

| Name                                | Description                               | Type     | Default                   | Required               |
| ----------------------------------- | ----------------------------------------- | -------- | ------------------------- | ---------------------- |
| `project_id`                        | GCP project ID                            | `string` | -                         | yes                    |
| `region`                            | GCP region                                | `string` | `"europe-west1"`          | no                     |
| `function_name`                     | Function name                             | `string` | `"onchain-event-handler"` | no                     |
| `memory_mb`                         | Memory in MB                              | `number` | `256`                     | no                     |
| `timeout_seconds`                   | Timeout in seconds                        | `number` | `60`                      | no                     |
| `max_instances`                     | Max instances                             | `number` | `10`                      | no                     |
| `min_instances`                     | Min instances                             | `number` | `0`                       | no                     |
| `quicknode_signing_secret`          | QuickNode signing secret                  | `string` | -                         | yes (passed from root) |
| `discord_webhook_mento_labs_alerts` | Discord webhook URL for Mento Labs alerts | `string` | -                         | yes                    |
| `discord_webhook_mento_labs_events` | Discord webhook URL for Mento Labs events | `string` | -                         | yes                    |
| `discord_webhook_reserve_alerts`    | Discord webhook URL for Reserve alerts    | `string` | -                         | yes                    |
| `discord_webhook_reserve_events`    | Discord webhook URL for Reserve events    | `string` | -                         | yes                    |

## Outputs

| Name                | Description                             |
| ------------------- | --------------------------------------- |
| `function_url`      | Cloud Function URL for webhook endpoint |
| `function_name`     | Function name                           |
| `function_location` | Function location                       |

## Deployment

### Step 1: Prerequisites Setup

1. **Google Cloud Project Setup**

   ```bash
   # Set your GCP project
   gcloud config set project YOUR_PROJECT_ID

   # Enable required APIs
   gcloud services enable cloudfunctions.googleapis.com
   gcloud services enable cloudbuild.googleapis.com
   gcloud services enable storage.googleapis.com
   ```

2. **Authentication**

   ```bash
   # Authenticate with GCP (if not already done)
   gcloud auth application-default login

   # Or use a service account key
   export GOOGLE_APPLICATION_CREDENTIALS="path/to/service-account-key.json"
   ```

### Step 2: Build the Function

**IMPORTANT**: You must build the TypeScript source before deploying:

```bash
# Navigate to the function directory
cd onchain-event-handler

# Install dependencies
npm install

# Build TypeScript to JavaScript
npm run build

# Verify the dist/ directory was created
ls -la dist/
```

The build process compiles TypeScript files from `src/` into JavaScript in `dist/`. The Terraform module will package only the `dist/` folder (excluding source files, Terraform configs, and node_modules).

### Step 3: Configure Terraform Variables

Ensure your `terraform.tfvars` includes all required variables:

```hcl
# Google Cloud Configuration
gcp_project_id = "your-gcp-project-id"
gcp_region     = "europe-west1"

# QuickNode Configuration
quicknode_api_key        = "your-quicknode-api-key"
quicknode_signing_secret = "your-signing-secret"

# Discord and other variables (see terraform.tfvars.example)
```

### Step 4: Deploy with Terraform

From the repository root directory:

```bash
# Initialize Terraform (downloads providers)
terraform init

# Review what will be created
terraform plan

# Deploy the Cloud Function
terraform apply
```

**What happens during deployment:**

1. Terraform archives the function source (including `dist/` folder)
2. Creates a Cloud Storage bucket for the function source
3. Uploads the archive to Cloud Storage
4. Deploys the Cloud Function (2nd gen) with Node.js 22 runtime
5. Configures environment variables
6. Sets up public IAM permissions for QuickNode webhook access

### Step 5: Verify Deployment

After deployment, verify the function is working:

```bash
# Get the function URL from Terraform outputs
terraform output cloud_function_url

# Test the function endpoint (should return an error without proper webhook payload)
curl $(terraform output -raw cloud_function_url)
```

The function URL will be used as the webhook endpoint in the `onchain-event-listeners` module.

### Step 6: Update Function (Redeployment)

When you make changes to the function code:

```bash
# 1. Rebuild the TypeScript
cd onchain-event-handler
npm run build

# 2. Return to root directory
cd ..

# 3. Apply changes (Terraform will detect the new build)
terraform apply
```

Terraform detects changes in the `dist/` folder and automatically creates a new archive with a new hash, triggering a function update.

## Development

### Development Prerequisites

- Node.js 22
- npm or yarn

### Setup

```bash
cd onchain-event-handler
npm install
```

### Build

```bash
npm run build
```

**IMPORTANT**: You must build the TypeScript source before deploying with Terraform.

The build process compiles TypeScript files from `src/` into JavaScript in `dist/`. The Terraform module will package only the `dist/` folder (excluding source files, Terraform configs, and node_modules).

### Local Development

For local development, you'll need to set up environment variables. The function expects several environment variables that are normally provided by Terraform when deployed to GCP.

1. **Generate `.env` file from Terraform:**

   After running `terraform apply` (to create Discord channels and webhooks), generate the `.env` file:

   ```bash
   # From the root directory
   npm run generate:env
   ```

   This will create a `.env` file with all required variables:
   - `MULTISIG_CONFIG`: JSON string with multisig configuration
   - `DISCORD_WEBHOOK_*`: Discord webhook URLs for each multisig and channel type
   - `QUICKNODE_SIGNING_SECRET`: Secret for verifying QuickNode webhook signatures
   - `SUPPORTED_CHAINS`: Comma-separated list of supported chains

2. **Run the function locally:**

   For development (TypeScript):

   ```bash
   npm run dev
   ```

   Or run the compiled version:

   ```bash
   npm run build
   npm start
   ```

   The function will be available at `http://localhost:8080/` by default. You can send HTTP requests to it:

   ```bash
   curl http://localhost:8080/
   ```

   To use a different port, set the `PORT` environment variable (functions-framework reads this automatically):

   ```bash
   PORT=3000 npm start
   # or
   PORT=3000 npm run dev
   ```

**Note:** If you don't set up `.env`, the code will still run but with warnings. The `MULTISIG_CONFIG` and other environment variables are optional in non-production environments, allowing you to test basic functionality without full configuration.

## Architecture

- **Runtime**: Node.js 22
- **Language**: TypeScript (compiled to JavaScript)
- **Trigger**: HTTP/HTTPS
- **Generation**: 2nd gen Cloud Functions
- **Authentication**: Public (allUsers) for QuickNode webhook access
- **Event Processing**: Processes all 16 Safe contract events
- **Routing**: Routes security events to alerts channels, operational events to events channels
- **Error Handling**: Continues processing other events if one fails

## Troubleshooting

### Build Issues

#### Error: `npm: command not found`

- Install Node.js 22: `brew install node@22` (macOS) or use [nvm](https://github.com/nvm-sh/nvm)

#### Error: TypeScript compilation fails

- Check `tsconfig.json` is present
- Verify all dependencies are installed: `npm install`
- Check for TypeScript errors: `npx tsc --noEmit`

### Deployment Issues

#### Error: API not enabled

```bash
gcloud services enable cloudfunctions.googleapis.com cloudbuild.googleapis.com storage.googleapis.com
```

#### Error: Permission denied

- Ensure your GCP account has `roles/cloudfunctions.admin` and `roles/storage.admin`
- Or use a service account with appropriate permissions

#### Error: Function deployment timeout

- Check Cloud Build logs in GCP Console
- Verify the `dist/` folder exists and contains compiled JavaScript
- Ensure the archive size is reasonable (< 50MB recommended)

### Runtime Issues

#### Function returns 401 Unauthorized

- Verify `QUICKNODE_SIGNING_SECRET` environment variable is set correctly
- Check that the webhook signature verification is working

#### Function doesn't receive webhooks

- Verify the function URL is correct in QuickNode webhook configuration
- Check IAM permissions allow `allUsers` to invoke the function
- Review Cloud Function logs: `gcloud functions logs read onchain-event-handler --region=europe-west1`

## Notes

- The function source is archived and uploaded to Cloud Storage
- The archive excludes `node_modules`, `src/`, test files, Terraform files, and git files
- Only the compiled `dist/` folder is included in the deployment package
- The function must be built before Terraform deployment
- Environment variables are passed at deployment time and cannot be changed without redeployment
- Function updates require rebuilding TypeScript and running `terraform apply`
