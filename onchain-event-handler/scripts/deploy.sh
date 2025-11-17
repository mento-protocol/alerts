#!/bin/bash
set -e          # Fail on any error
set -o pipefail # Ensure piped commands propagate exit codes properly
set -u          # Treat unset variables as an error when substituting

# Script to deploy Cloud Function using gcloud directly
# This bypasses Terraform's Cloud Build and deploys directly, which can help debug deployment issues

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MODULE_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
ROOT_DIR="$(cd "${MODULE_DIR}/.." && pwd)"

# Source common utilities
if [[ -f "${ROOT_DIR}/scripts/common.sh" ]]; then
	# shellcheck source=../../scripts/common.sh
	source "${ROOT_DIR}/scripts/common.sh"
else
	# Can't use error() function here since we haven't sourced common.sh yet
	echo "Error: common.sh not found at ${ROOT_DIR}/scripts/common.sh" >&2
	exit 1
fi

# Check requirements first
check_requirements "gcloud" "jq" "terraform"

# Load project variables using existing script
info "Loading project variables..."
if [[ -f "${SCRIPT_DIR}/get-project-vars.sh" ]]; then
	# Source the script to get variables (suppress output unless verbose)
	if [[ ${VERBOSE:-0} -eq 1 ]]; then
		source "${SCRIPT_DIR}/get-project-vars.sh" --verbose
	else
		source "${SCRIPT_DIR}/get-project-vars.sh" >/dev/null 2>&1
	fi
else
	error "get-project-vars.sh not found at ${SCRIPT_DIR}/get-project-vars.sh"
	exit 1
fi

# Verify required variables are set
if [[ -z ${project_id-} ]]; then
	error "project_id not set. Run get-project-vars.sh first."
	exit 1
fi

if [[ -z ${region-} ]]; then
	warn "region not set, using default: europe-west1"
	region="europe-west1"
fi

if [[ -z ${function_name-} ]]; then
	warn "function_name not set, using default: onchain-event-handler"
	function_name="onchain-event-handler"
fi

# Change to module directory
cd "${MODULE_DIR}"

# Ensure safe-abi.json exists (copy from root if needed)
if [[ ! -f "${MODULE_DIR}/safe-abi.json" ]]; then
	if [[ -f "${ROOT_DIR}/safe-abi.json" ]]; then
		info "Copying safe-abi.json from project root..."
		cp "${ROOT_DIR}/safe-abi.json" "${MODULE_DIR}/safe-abi.json"
	else
		error "safe-abi.json not found in project root: ${ROOT_DIR}/safe-abi.json"
		exit 1
	fi
fi

# Note: We don't build locally - Cloud Build will run `npm install` and `npm run build`
# when it detects package.json in the source directory

# Get function configuration from Terraform (if available)
# Try to read from terraform state/outputs
info "Reading function configuration from Terraform..."

# Change to root directory to run terraform commands
cd "${ROOT_DIR}"

# Get function configuration values
FUNCTION_NAME="${function_name}"
REGION="${region}"
PROJECT_ID="${project_id}"
SERVICE_ACCOUNT_EMAIL="${service_account_email}"
# Try to get memory, timeout, etc. from terraform state
# Read from the actual resource in state
FUNCTION_RESOURCE=$(terraform show -json 2>/dev/null | jq -r '
  .values.root_module.child_modules[]? |
  select(.address == "module.onchain_event_handler") |
  .resources[]? |
  select(.type == "google_cloudfunctions2_function" and .name == "onchain_event_handler")
' 2>/dev/null || echo "{}")

FUNCTION_CONFIG=$(echo "${FUNCTION_RESOURCE}" | jq -r '.values.service_config[0] // {}' 2>/dev/null || echo "{}")

# Extract values from state or use defaults
if [[ ${FUNCTION_CONFIG} != "{}" && ${FUNCTION_CONFIG} != "null" ]]; then
	MEMORY_MB=$(echo "${FUNCTION_CONFIG}" | jq -r '.available_memory // "256M"' | sed 's/M$//' || echo "256")
	TIMEOUT_SECONDS=$(echo "${FUNCTION_CONFIG}" | jq -r '.timeout_seconds // 60' || echo "60")
	MAX_INSTANCES=$(echo "${FUNCTION_CONFIG}" | jq -r '.max_instance_count // 10' || echo "10")
	MIN_INSTANCES=$(echo "${FUNCTION_CONFIG}" | jq -r '.min_instance_count // 0' || echo "0")
else
	# Use defaults from variables.tf
	warn "Could not read function config from Terraform state, using defaults"
	MEMORY_MB="256"
	TIMEOUT_SECONDS="60"
	MAX_INSTANCES="10"
	MIN_INSTANCES="0"
fi

# Validate and sanitize numeric values to ensure they're valid
# Handle cases where jq might return "null" as a string or empty values
# Ensure TIMEOUT_SECONDS is a valid positive integer
if [[ -z ${TIMEOUT_SECONDS} ]] || [[ ${TIMEOUT_SECONDS} == "null" ]] || [[ ! ${TIMEOUT_SECONDS} =~ ^[0-9]+$ ]]; then
	warn "Invalid TIMEOUT_SECONDS value '${TIMEOUT_SECONDS}', using default: 60"
	TIMEOUT_SECONDS="60"
fi

# Ensure MEMORY_MB is a valid positive integer
if [[ -z ${MEMORY_MB} ]] || [[ ${MEMORY_MB} == "null" ]] || [[ ! ${MEMORY_MB} =~ ^[0-9]+$ ]]; then
	warn "Invalid MEMORY_MB value '${MEMORY_MB}', using default: 256"
	MEMORY_MB="256"
fi

# Ensure MAX_INSTANCES is a valid non-negative integer
if [[ -z ${MAX_INSTANCES} ]] || [[ ${MAX_INSTANCES} == "null" ]] || [[ ! ${MAX_INSTANCES} =~ ^[0-9]+$ ]]; then
	warn "Invalid MAX_INSTANCES value '${MAX_INSTANCES}', using default: 10"
	MAX_INSTANCES="10"
fi

# Ensure MIN_INSTANCES is a valid non-negative integer
if [[ -z ${MIN_INSTANCES} ]] || [[ ${MIN_INSTANCES} == "null" ]] || [[ ! ${MIN_INSTANCES} =~ ^[0-9]+$ ]]; then
	warn "Invalid MIN_INSTANCES value '${MIN_INSTANCES}', using default: 0"
	MIN_INSTANCES="0"
fi

# Get environment variables from terraform state
info "Reading environment variables from Terraform state..."

# Try to read environment variables from terraform state
ENV_VARS_JSON=$(cd "${ROOT_DIR}" && terraform show -json 2>/dev/null | jq -r '
  .values.root_module.child_modules[]? |
  select(.address == "module.onchain_event_handler") |
  .resources[]? |
  select(.type == "google_cloudfunctions2_function" and .name == "onchain_event_handler") |
  .values.service_config[0].environment_variables // {}
' 2>/dev/null || echo "{}")

# Build gcloud deploy command
cd "${MODULE_DIR}"

info "Deploying Cloud Function: ${FUNCTION_NAME}"
info "Project: ${PROJECT_ID}"
info "Region: ${REGION}"
info "Memory: ${MEMORY_MB}MB"
info "Timeout: ${TIMEOUT_SECONDS}s"

# Prepare environment variables
# Write to a YAML file to avoid shell parsing issues with special characters (JSON, commas, colons, etc.)
ENV_VARS_FILE=""
if [[ ${ENV_VARS_JSON} != "{}" && ${ENV_VARS_JSON} != "null" && -n ${ENV_VARS_JSON} ]]; then
	# Create temporary YAML file for environment variables
	# gcloud functions deploy supports --env-vars-file with YAML format
	ENV_VARS_FILE=$(mktemp)
	# Cleanup function for trap
	cleanup_env_file() {
		rm -f "${ENV_VARS_FILE}"
	}
	trap cleanup_env_file EXIT

	# Convert JSON to YAML format
	# Format: KEY: "VALUE" (values quoted to handle special characters)
	# Escape quotes in values and wrap in quotes
	echo "${ENV_VARS_JSON}" | jq -r 'to_entries[] | "\(.key): \(.value | @json)"' >"${ENV_VARS_FILE}" 2>/dev/null

	if [[ -s ${ENV_VARS_FILE} ]]; then
		ENV_VAR_COUNT=$(echo "${ENV_VARS_JSON}" | jq 'length' 2>/dev/null || echo "0")
		info "Found ${ENV_VAR_COUNT} environment variables in Terraform state"
	else
		warn "Could not parse environment variables from Terraform state"
		rm -f "${ENV_VARS_FILE}"
		ENV_VARS_FILE=""
	fi
else
	warn "Could not read environment variables from Terraform state"
	warn "The function may not have the correct environment variables set"
	warn "You may need to set them manually or deploy via Terraform first"
fi

# Secret environment variable
SECRET_NAME="quicknode-signing-secret"
SECRET_VERSION="latest"

# Build the gcloud deploy command as an array to properly handle special characters
# Cloud Build will automatically run `npm install` and `npm run build` when it detects package.json
DEPLOY_CMD_ARGS=(
	"functions" "deploy" "${FUNCTION_NAME}"
	"--gen2"
	"--runtime=nodejs22"
	"--region=${REGION}"
	"--source=${MODULE_DIR}"
	"--service-account=${SERVICE_ACCOUNT_EMAIL}"
	"--entry-point=processQuicknodeWebhook"
	"--trigger-http"
	"--allow-unauthenticated"
	"--memory=${MEMORY_MB}MB"
	"--timeout=${TIMEOUT_SECONDS}s"
	"--max-instances=${MAX_INSTANCES}"
	"--min-instances=${MIN_INSTANCES}"
	"--set-secrets=QUICKNODE_SIGNING_SECRET=${SECRET_NAME}:${SECRET_VERSION}"
)

# Add environment variables if we have them
# Use --env-vars-file to avoid shell parsing issues with special characters
if [[ -n ${ENV_VARS_FILE} && -f ${ENV_VARS_FILE} ]]; then
	DEPLOY_CMD_ARGS+=("--env-vars-file=${ENV_VARS_FILE}")
fi

info "Deployment command:"
echo "gcloud ${DEPLOY_CMD_ARGS[*]}"
echo ""

# Execute deployment
info "Starting deployment..."
if gcloud "${DEPLOY_CMD_ARGS[@]}"; then
	info "Deployment successful!"
	info "Getting function URL..."
	FUNCTION_URL=$(gcloud functions describe "${FUNCTION_NAME}" --gen2 --region="${REGION}" --format="value(serviceConfig.uri)" 2>/dev/null || echo "")
	if [[ -n ${FUNCTION_URL} ]]; then
		info "Function URL: ${FUNCTION_URL}"
	else
		warn "Could not retrieve function URL. You can get it with:"
		warn "  gcloud functions describe ${FUNCTION_NAME} --gen2 --region=${REGION} --format='value(serviceConfig.uri)'"
	fi
else
	error "Deployment failed"
	exit 1
fi
