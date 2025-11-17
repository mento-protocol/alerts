#!/bin/bash
set -e
set -o pipefail

# Script to send a test payload to the local cloud function
# Usage: ./scripts/test-local.sh

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MODULE_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
ROOT_DIR="$(cd "${MODULE_DIR}/.." && pwd)"

# Source common utilities (required)
if [[ ! -f "${ROOT_DIR}/scripts/common.sh" ]]; then
	echo "Error: common.sh not found at ${ROOT_DIR}/scripts/common.sh" >&2
	exit 1
fi

# shellcheck source=../../scripts/common.sh
source "${ROOT_DIR}/scripts/common.sh"

# Check requirements
check_requirements "curl"

FUNCTION_URL="${FUNCTION_URL:-http://localhost:8080/}"
PAYLOAD_FILE="${SCRIPT_DIR}/test-payload.json"

if [[ ! -f ${PAYLOAD_FILE} ]]; then
	error "Test payload file not found: ${PAYLOAD_FILE}"
	exit 1
fi

info "Sending test payload to ${FUNCTION_URL}..."

curl -s -w "\nHTTP Status: %{http_code}\n" \
	-X POST "${FUNCTION_URL}" \
	-H "Content-Type: application/json" \
	-d "@${PAYLOAD_FILE}"
