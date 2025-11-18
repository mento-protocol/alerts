#!/bin/bash
#
# Common Utilities Library
#
# Purpose:
#   Provides shared functions and utilities for all shell scripts in the project.
#   This includes logging functions, color definitions, requirement checks,
#   and helper functions for common operations.
#
# Usage:
#   # Source the file
#   source scripts/common.sh
#
# Functions Provided:
#   - info "message": Print green [INFO] message
#   - warn "message": Print yellow [WARN] message
#   - error "message": Print red [ERROR] message
#   - check_requirements "tool1" "tool2": Check if required tools are installed
#   - get_script_dir: Get absolute path to script's directory
#   - get_project_root: Get absolute path to project root
#   - read_tfvars_value "var_name": Read value from terraform.tfvars
#   - check_terraform_root: Verify script is run from Terraform root directory
#
# Color Variables:
#   - RED, GREEN, YELLOW, BLUE, CYAN, NC (No Color)
#
# Example:
#   source scripts/common.sh
#   check_requirements "gcloud" "terraform"
#   info "Starting deployment..."
#   PROJECT_ROOT=$(get_project_root)

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
export BLUE='\033[0;34m'
export CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Function to print colored output
info() {
	echo -e "${GREEN}[INFO]${NC} $1"
}

warn() {
	echo -e "${YELLOW}[WARN]${NC} $1"
}

error() {
	echo -e "${RED}[ERROR]${NC} $1"
}

# Check for required tools
# Usage: check_requirements "tool1" "tool2" "tool3"
# Example: check_requirements "gcloud" "jq" "terraform"
check_requirements() {
	local missing_tools=()

	# Check each tool passed as argument
	for tool in "$@"; do
		if ! command -v "${tool}" &>/dev/null; then
			missing_tools+=("${tool}")
		fi
	done

	if [[ ${#missing_tools[@]} -gt 0 ]]; then
		error "Missing required tools: ${missing_tools[*]}"
		error "Please install the missing tools and try again"
		exit 1
	fi
}

# Get the directory where the script is located
# Usage: SCRIPT_DIR=$(get_script_dir)
# Returns: Absolute path to the script's directory
get_script_dir() {
	cd "$(dirname "${BASH_SOURCE[1]}")" && pwd
}

# Get the project root directory (assumes scripts are in scripts/ subdirectory)
# Usage: PROJECT_ROOT=$(get_project_root)
# Returns: Absolute path to the project root
get_project_root() {
	local script_dir
	script_dir=$(get_script_dir)
	cd "${script_dir}/.." && pwd
}

# Read a value from terraform.tfvars file
# Usage: read_tfvars_value "variable_name" [default_value]
# Example: API_KEY=$(read_tfvars_value "quicknode_api_key")
read_tfvars_value() {
	local var_name="$1"
	local default_value="${2-}"
	local tfvars_file
	local project_root
	project_root=$(get_project_root)
	tfvars_file="${project_root}/terraform.tfvars"

	if [[ ! -f ${tfvars_file} ]]; then
		echo "${default_value}"
		return
	fi

	# Try double quotes first
	local value
	value=$(grep "^${var_name}" "${tfvars_file}" | head -1 | sed 's/.*= *"\(.*\)".*/\1/' || true)
	value=${value:-""}

	# If empty, try single quotes
	if [[ -z ${value} ]]; then
		value=$(grep "^${var_name}" "${tfvars_file}" | head -1 | sed "s/.*= *'\(.*\)'.*/\1/" || true)
		value=${value:-""}
	fi

	# If still empty, try without quotes (for numbers, booleans)
	if [[ -z ${value} ]]; then
		value=$(grep "^${var_name}" "${tfvars_file}" | head -1 | sed 's/.*= *\(.*\)/\1/' | tr -d '[:space:]' || true)
		value=${value:-""}
	fi

	if [[ -n ${value} ]]; then
		echo "${value}"
	else
		echo "${default_value}"
	fi
}

# Check if we're in a Terraform root directory (has main.tf)
# Usage: check_terraform_root [error_message]
check_terraform_root() {
	local error_msg="${1:-Error: main.tf not found. Please run this script from the terraform root directory.}"
	if [[ ! -f "main.tf" ]]; then
		error "${error_msg}"
		exit 1
	fi
}
