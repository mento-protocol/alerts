#!/bin/bash
# Common utilities for shell scripts
# Source this file to use shared functions and variables

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
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
