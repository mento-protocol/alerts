# Mento Alerts

This repository manages our alert rules with Terraform.

## Current Integrations

- Forwarding Sentry issues to project-specific Discord channels.

## Prerequisites

- Terraform >= 1.10.0
- A Discord server with:
  - A category for alert channels
  - The Sentry integration installed and configured
- A Discord Bot token with admin permissions to allow it to CRUD channels on the server
- An active Discord integration in our Sentry organization

## Setup

1. Copy the example tfvars file:

```bash
cp terraform/terraform.tfvars.example terraform/terraform.tfvars
```

1. Configure the required variables in `terraform.tfvars` (follow the instructions in the file's comments)

1. Initialize your Terraform environment:

```bash
cd terraform
terraform init
terraform plan
terraform apply
```

## What Terraform creates

For each Sentry project:

1. A Discord channel named `#sentry-{project-name}`
2. A Sentry alert rule that forwards errors to that channel
3. Proper permissions for the Sentry integration to access the channels
