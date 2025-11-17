#!/bin/bash
set -euo pipefail

# Script to retrieve and display QuickNode webhook filter function
# Usage: ./scripts/get-webhook-filter.sh

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
TFVARS_FILE="${PROJECT_ROOT}/terraform.tfvars"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Step 1: Read QuickNode API key from terraform.tfvars
echo -e "${GREEN}Step 1: Reading QuickNode API key from terraform.tfvars...${NC}"
if [[ ! -f ${TFVARS_FILE} ]]; then
	echo -e "${RED}Error: terraform.tfvars not found at ${TFVARS_FILE}${NC}" >&2
	exit 1
fi

QUICKNODE_API_KEY=$(grep 'quicknode_api_key' "${TFVARS_FILE}" | sed 's/.*= *"\(.*\)".*/\1/' | head -1)

if [[ -z ${QUICKNODE_API_KEY} ]]; then
	echo -e "${RED}Error: Could not find quicknode_api_key in terraform.tfvars${NC}" >&2
	exit 1
fi

echo -e "${GREEN}✓ Found API key${NC}"

# Step 2: Retrieve all webhooks
echo -e "\n${GREEN}Step 2: Retrieving all webhooks from QuickNode...${NC}"
WEBHOOKS_RESPONSE=$(curl -s -w "\n%{http_code}" \
	-X GET "https://api.quicknode.com/webhooks/rest/v1/webhooks?limit=100&offset=0" \
	-H "accept: application/json" \
	-H "x-api-key: ${QUICKNODE_API_KEY}")

HTTP_CODE=$(echo "${WEBHOOKS_RESPONSE}" | tail -1)
WEBHOOKS_JSON=$(echo "${WEBHOOKS_RESPONSE}" | sed '$d')

if [[ ${HTTP_CODE} != "200" ]]; then
	echo -e "${RED}Error: Failed to retrieve webhooks (HTTP ${HTTP_CODE})${NC}" >&2
	echo "${WEBHOOKS_JSON}" | jq '.' 2>/dev/null || echo "${WEBHOOKS_JSON}"
	exit 1
fi

# Check if jq is available
if ! command -v jq &>/dev/null; then
	echo -e "${YELLOW}Warning: jq not found. Installing jq is recommended for better output.${NC}" >&2
fi

# Step 3: Find webhook matching pattern from main.tf
# Pattern: "safe-multisig-monitor-*" (matches webhooks created by the module)
echo -e "\n${GREEN}Step 3: Finding webhook matching 'safe-multisig-monitor-*' pattern...${NC}"

if command -v jq &>/dev/null; then
	# Extract webhook IDs and names
	WEBHOOK_IDS=$(echo "${WEBHOOKS_JSON}" | jq -r '.data[]? | select(.name | startswith("safe-multisig-monitor-")) | .id' 2>/dev/null || true)
	WEBHOOK_NAMES=$(echo "${WEBHOOKS_JSON}" | jq -r '.data[]? | select(.name | startswith("safe-multisig-monitor-")) | .name' 2>/dev/null || true)
else
	# Fallback: use grep/awk (less reliable)
	echo -e "${YELLOW}Using fallback method (jq not available)${NC}"
	WEBHOOK_IDS=$(echo "${WEBHOOKS_JSON}" | grep -o '"id"[[:space:]]*:[[:space:]]*"[^"]*"' | awk -F'"' '{print $4}' | head -1 || true)
	WEBHOOK_NAMES=$(echo "${WEBHOOKS_JSON}" | grep -o '"name"[[:space:]]*:[[:space:]]*"safe-multisig-monitor-[^"]*"' | awk -F'"' '{print $4}' | head -1 || true)
fi

if [[ -z ${WEBHOOK_IDS} ]] || [[ -z ${WEBHOOK_NAMES} ]]; then
	echo -e "${RED}Error: No webhook found matching pattern 'safe-multisig-monitor-*'${NC}" >&2
	echo -e "${YELLOW}Available webhooks:${NC}"
	if command -v jq &>/dev/null; then
		echo "${WEBHOOKS_JSON}" | jq -r '.data[]? | "  - \(.name) (ID: \(.id))"' 2>/dev/null || echo "${WEBHOOKS_JSON}"
	else
		echo "${WEBHOOKS_JSON}"
	fi
	exit 1
fi

# Handle multiple webhooks (take first match)
WEBHOOK_ID=$(echo "${WEBHOOK_IDS}" | head -1)
WEBHOOK_NAME=$(echo "${WEBHOOK_NAMES}" | head -1)

WEBHOOK_COUNT=$(echo "${WEBHOOK_IDS}" | wc -l)
if [[ ${WEBHOOK_COUNT} -gt 1 ]]; then
	echo -e "${YELLOW}Warning: Multiple webhooks found. Using first match: ${WEBHOOK_NAME}${NC}"
fi

echo -e "${GREEN}✓ Found webhook: ${WEBHOOK_NAME} (ID: ${WEBHOOK_ID})${NC}"

# Step 4: Fetch filter function via webhook details endpoint
echo -e "\n${GREEN}Step 4: Fetching webhook details...${NC}"
WEBHOOK_DETAILS_RESPONSE=$(curl -s -w "\n%{http_code}" \
	-X GET "https://api.quicknode.com/webhooks/rest/v1/webhooks/${WEBHOOK_ID}" \
	-H "accept: application/json" \
	-H "x-api-key: ${QUICKNODE_API_KEY}")

HTTP_CODE=$(echo "${WEBHOOK_DETAILS_RESPONSE}" | tail -1)
WEBHOOK_DETAILS_JSON=$(echo "${WEBHOOK_DETAILS_RESPONSE}" | sed '$d')

if [[ ${HTTP_CODE} != "200" ]]; then
	echo -e "${RED}Error: Failed to retrieve webhook details (HTTP ${HTTP_CODE})${NC}" >&2
	echo "${WEBHOOK_DETAILS_JSON}" | jq '.' 2>/dev/null || echo "${WEBHOOK_DETAILS_JSON}"
	exit 1
fi

# Step 5: Extract and decode filter function
echo -e "\n${GREEN}Step 5: Extracting and decoding filter function...${NC}"

if command -v jq &>/dev/null; then
	FILTER_FUNCTION_B64=$(echo "${WEBHOOK_DETAILS_JSON}" | jq -r '.filter_function // empty' 2>/dev/null || echo "")
else
	# Fallback: extract with grep/sed
	FILTER_FUNCTION_B64=$(echo "${WEBHOOK_DETAILS_JSON}" | grep -o '"filter_function"[[:space:]]*:[[:space:]]*"[^"]*"' | sed -E 's/.*"filter_function"[[:space:]]*:[[:space:]]*"([^"]*)".*/\1/' || echo "")
fi

if [[ -z ${FILTER_FUNCTION_B64} ]]; then
	echo -e "${RED}Error: filter_function not found in webhook details${NC}" >&2
	echo "${WEBHOOK_DETAILS_JSON}" | jq '.' 2>/dev/null || echo "${WEBHOOK_DETAILS_JSON}"
	exit 1
fi

# Decode base64 filter function (try both -d and -D for compatibility)
FILTER_FUNCTION=""
if command -v base64 &>/dev/null; then
	# Try Linux-style first, then macOS-style
	FILTER_FUNCTION=$(echo "${FILTER_FUNCTION_B64}" | base64 -d 2>/dev/null) ||
		FILTER_FUNCTION=$(echo "${FILTER_FUNCTION_B64}" | base64 -D 2>/dev/null) ||
		FILTER_FUNCTION=""
fi

# If decoding failed or base64 not available, use original (may already be decoded)
if [[ -z ${FILTER_FUNCTION} ]]; then
	echo -e "${YELLOW}Warning: Could not decode filter function (may already be decoded or base64 not available)${NC}" >&2
	FILTER_FUNCTION="${FILTER_FUNCTION_B64}"
fi

# Step 6: Save filter function to file and copy to clipboard
echo -e "\n${GREEN}═══════════════════════════════════════════════════════════════${NC}"
echo -e "${GREEN}Filter Function for Webhook: ${WEBHOOK_NAME}${NC}"
echo -e "${GREEN}═══════════════════════════════════════════════════════════════${NC}\n"

# Determine the filter function template file path (in onchain-event-listeners directory)
FILTER_FUNCTION_FILE="${PROJECT_ROOT}/onchain-event-listeners/filter-function.js.tpl"

# Replace hardcoded contracts array with Terraform template syntax
# This allows contracts to be injected from var.multisig_addresses
# Use perl to handle the replacement properly (handles special characters)
FILTER_FUNCTION_TEMPLATE=$(echo "${FILTER_FUNCTION}" | perl -pe 's/const contracts = \[.*?\];/const contracts = \${jsonencode([for addr in contracts : lower(addr)])};/')

# Save filter function template to file
echo "${FILTER_FUNCTION_TEMPLATE}" >"${FILTER_FUNCTION_FILE}"
echo -e "${GREEN}✓ Saved filter function template to: ${FILTER_FUNCTION_FILE}${NC}"
echo -e "${GREEN}  (Contracts will be injected from Terraform config)${NC}"

# Build the Terraform templatefile() format for locals.tf
# shellcheck disable=SC2016
TERRAFORM_OUTPUT='  filter_function_js = templatefile("${path.module}/filter-function.js.tpl", {
    contracts = var.multisig_addresses
  })'

# Print to console
echo -e "\n${YELLOW}# Update your locals.tf with:${NC}\n"
echo "${TERRAFORM_OUTPUT}"

# Copy Terraform code to clipboard
CLIPBOARD_COPIED=false
UNAME_OS=$(uname)
if [[ ${UNAME_OS} == "Darwin" ]]; then
	# macOS
	if echo -n "${TERRAFORM_OUTPUT}" | pbcopy; then
		CLIPBOARD_COPIED=true
	fi
elif command -v xclip &>/dev/null; then
	# Linux with xclip
	if echo -n "${TERRAFORM_OUTPUT}" | xclip -selection clipboard; then
		CLIPBOARD_COPIED=true
	fi
elif command -v xsel &>/dev/null; then
	# Linux with xsel
	if echo -n "${TERRAFORM_OUTPUT}" | xsel --clipboard --input; then
		CLIPBOARD_COPIED=true
	fi
fi

if [[ ${CLIPBOARD_COPIED} == "true" ]]; then
	echo -e "\n${GREEN}✓ Copied Terraform code to clipboard!${NC}"
else
	echo -e "\n${YELLOW}Note: Could not copy to clipboard (install pbcopy on macOS or xclip/xsel on Linux)${NC}"
fi

echo -e "\n${GREEN}═══════════════════════════════════════════════════════════════${NC}"
