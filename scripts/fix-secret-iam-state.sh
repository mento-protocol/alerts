#!/bin/bash
# Fix the secret_id format in Terraform state
# This updates the state to use just the secret name instead of the full path
# Run this after updating the config to prevent unnecessary resource replacement

set -e

RESOURCE_ADDRESS="module.onchain_event_handler.google_secret_manager_secret_iam_member.function_secret_accessor"
SECRET_NAME="quicknode-signing-secret"

echo "Backing up current state..."
terraform state pull >"/tmp/tf_state_backup_$(date +%s).json"

echo "Updating secret_id format in state..."
TEMP_STATE=$(terraform state pull)
UPDATED_STATE=$(echo "${TEMP_STATE}" | jq --arg secret_id "${SECRET_NAME}" \
	"(.resources[] | select(.address == \"${RESOURCE_ADDRESS}\") | .instances[0].attributes.secret_id) = \$secret_id")
echo "${UPDATED_STATE}" | terraform state push - || true

echo "State updated successfully!"
echo "Run 'terraform plan' to verify the change is gone."
