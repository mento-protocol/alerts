#!/usr/bin/env bash

# Script to fix Terraform state when QuickNode webhooks get out of sync
# This happens when webhooks are deleted outside Terraform or when updates fail with 404

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${YELLOW}QuickNode Webhook State Repair Tool${NC}"
echo "======================================"
echo ""

# Check if we're in the terraform directory
if [[ ! -f "main.tf" ]]; then
	echo -e "${RED}Error: main.tf not found. Please run this script from the terraform root directory.${NC}"
	exit 1
fi

# List all on-chain event listener webhook resources in state
echo "Finding webhook resources in Terraform state..."
WEBHOOK_RESOURCES=$(terraform state list | grep -E '(onchain_event_listeners|multisig_alerts)\[.*\]\.restapi_object\.multisig_webhook' || echo "")

if [[ -z ${WEBHOOK_RESOURCES} ]]; then
	echo -e "${YELLOW}No webhook resources found in state.${NC}"
	exit 0
fi

echo "Found the following webhook resources:"
echo "${WEBHOOK_RESOURCES}"
echo ""

# Get QuickNode API key from (in order of priority):
# 1. Environment variable
# 2. terraform.tfvars file
if [[ -z ${QUICKNODE_API_KEY-} ]]; then
	echo "QUICKNODE_API_KEY not set, trying to read from terraform.tfvars..."

	# Try to read from terraform.tfvars
	if [[ -f "terraform.tfvars" ]]; then
		# Extract quicknode_api_key value (handles both "value" and 'value')
		# Using cut for portability across different systems
		QUICKNODE_API_KEY=$(grep '^quicknode_api_key' terraform.tfvars | head -1 | cut -d'"' -f2)

		# If double quotes didn't work, try single quotes
		if [[ -z ${QUICKNODE_API_KEY} ]]; then
			QUICKNODE_API_KEY=$(grep '^quicknode_api_key' terraform.tfvars | head -1 | cut -d"'" -f2)
		fi

		if [[ -n ${QUICKNODE_API_KEY} ]]; then
			echo -e "${GREEN}✓ Found QuickNode API key in terraform.tfvars${NC}"
		fi
	fi
fi

# Check if we have an API key now
if [[ -z ${QUICKNODE_API_KEY-} ]]; then
	echo -e "${RED}Error: QUICKNODE_API_KEY not found.${NC}"
	echo ""
	echo "Please provide your QuickNode API key in one of these ways:"
	echo ""
	echo "Option 1: Export as environment variable"
	echo "  export QUICKNODE_API_KEY='your-api-key-here'"
	echo "  ./scripts/fix-webhook-state.sh"
	echo ""
	echo "Option 2: Add to terraform.tfvars"
	echo '  quicknode_api_key = "your-api-key-here"'
	echo ""
	echo "Get your API key from: https://dashboard.quicknode.com/api-keys"
	exit 1
fi

echo "Checking webhook existence in QuickNode..."
echo ""

MISSING_WEBHOOKS=()

while IFS= read -r resource; do
	if [[ -z ${resource} ]]; then
		continue
	fi

	echo "Checking: ${resource}"

	# Extract webhook ID from state
	WEBHOOK_ID=$(terraform state show "${resource}" 2>/dev/null | grep -E '^\s+id\s+=' | awk '{print $3}' | tr -d '"' || echo "")

	if [[ -z ${WEBHOOK_ID} ]]; then
		echo -e "  ${YELLOW}⚠ Could not extract webhook ID from state${NC}"
		continue
	fi

	echo "  Webhook ID: ${WEBHOOK_ID}"

	# Check if webhook exists in QuickNode
	HTTP_CODE=$(curl -s -o /tmp/webhook_check.json -w "%{http_code}" \
		-H "x-api-key: ${QUICKNODE_API_KEY}" \
		-H "accept: application/json" \
		"https://api.quicknode.com/webhooks/rest/v1/webhooks/${WEBHOOK_ID}")

	if [[ ${HTTP_CODE} == "200" ]]; then
		echo -e "  ${GREEN}✓ Webhook exists in QuickNode${NC}"
	elif [[ ${HTTP_CODE} == "404" ]]; then
		echo -e "  ${RED}✗ Webhook NOT FOUND in QuickNode (404)${NC}"
		MISSING_WEBHOOKS+=("${resource}")
	else
		echo -e "  ${YELLOW}⚠ Unexpected response code: ${HTTP_CODE}${NC}"
		cat /tmp/webhook_check.json 2>/dev/null || true
	fi

	rm -f /tmp/webhook_check.json
	echo ""
done <<<"${WEBHOOK_RESOURCES}"

# If we found missing webhooks, offer to remove them from state
if [[ ${#MISSING_WEBHOOKS[@]} -gt 0 ]]; then
	echo -e "${YELLOW}Found ${#MISSING_WEBHOOKS[@]} webhook(s) in Terraform state that don't exist in QuickNode:${NC}"
	for webhook in "${MISSING_WEBHOOKS[@]}"; do
		echo "  - ${webhook}"
	done
	echo ""

	read -p "Remove these from Terraform state? (y/N) " -n 1 -r
	echo

	if [[ ${REPLY} =~ ^[Yy]$ ]]; then
		for webhook in "${MISSING_WEBHOOKS[@]}"; do
			echo "Removing: ${webhook}"
			terraform state rm -lock=false "${webhook}"
		done
		echo -e "${GREEN}✓ Removed missing webhooks from state${NC}"
		echo ""
		echo "Next steps:"
		echo "  1. Run 'terraform plan' to see what will be created"
		echo "  2. Run 'terraform apply' to recreate the missing webhooks"
	else
		echo "Skipped state cleanup."
		echo ""
		echo "To manually remove a webhook from state, run:"
		echo "  terraform state rm 'module.onchain_event_listeners[\"<network>\"].restapi_object.multisig_webhook'"
	fi
else
	echo -e "${GREEN}✓ All webhooks in Terraform state exist in QuickNode${NC}"
fi
