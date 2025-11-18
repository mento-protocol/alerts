#!/bin/bash
#
# Project Variables Loader and Cache Manager
#
# Purpose:
#   Loads and caches project variables from Terraform configuration and state.
#   This script is typically sourced by other scripts that need project information
#   like project_id, region, function_name, etc.
#
# Usage:
#   # Source to load variables into current shell
#   source scripts/get-project-vars.sh
#
#   # Run directly to see cached values
#   ./scripts/get-project-vars.sh
#
#   # Invalidate cache and reload
#   ./scripts/get-project-vars.sh --invalidate-cache
#
# Requirements:
#   - gcloud CLI installed and authenticated
#   - terraform (for reading state)
#   - variables.tf must exist in project root
#
# What it does:
#   1. Checks for cached values in .project_vars_cache
#   2. If cache exists and valid, loads from cache
#   3. If cache missing or invalid, fetches from Terraform and gcloud
#   4. Caches values for faster subsequent loads
#   5. Sets gcloud default project and quota project
#   6. Updates .env file with project_id
#
# Variables exported:
#   - project_id: GCP project ID
#   - project_name: GCP project name
#   - region: GCP region
#   - service_account_email: Service account email
#   - function_name: Cloud Function name
#   - function_entry_point: Function entry point name

set -euo pipefail

# Determine script and directory paths
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MODULE_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
ROOT_DIR="$(cd "${MODULE_DIR}/.." && pwd)"

set_project_id() {
	printf "Looking up project name in variables.tf..."
	project_name=$(awk '/variable "project_name"/{f=1} f==1&&/default/{print $3; exit}' "${ROOT_DIR}/variables.tf" | tr -d '",')
	printf ' \033[1m%s\033[0m\n' "${project_name}"

	printf "Fetching the project ID..."
	project_id=$(gcloud projects list --filter="name:${project_name}" --format="value(projectId)")

	if [[ -z ${project_id} ]]; then
		printf '\n\033[1;31mError: No project found with name "%s"\033[0m\n' "${project_name}"
		echo "This usually means the GCP project hasn't been created yet."
		echo "Please ensure you've run the terraform apply in the root directory first."
		exit 1
	fi

	printf ' \033[1m%s\033[0m\n' "${project_id}"

	# Set your local default project
	printf "Setting your default project to \033[1m%s\033[0m...\n" "${project_id}"
	{
		output=$(gcloud config set project "${project_id}" 2>&1 >/dev/null)
		status=$?
	}
	if [[ ${status} -ne 0 ]]; then
		printf '\n\033[1;31mError setting gcloud project: %s\033[0m\n' "${output}"
		exit "${status}"
	fi

	# Set the quota project to the governance-watchdog project, some gcloud commands require this to be set
	printf "Setting the quota project to \033[1m%s\033[0m...\n" "${project_id}"
	{
		output=$(gcloud auth application-default set-quota-project "${project_id}" 2>&1 >/dev/null)
		status=$?
	}
	if [[ ${status} -ne 0 ]]; then
		printf '\n\033[1;31mError setting quota project: %s\033[0m\n' "${output}"
		exit "${status}"
	fi

	# Update the project ID in your .env file so your cloud function points to the correct project when running locally
	printf "Updating the project ID in your .env file..."
	# Check if .env file exists
	if [[ ! -f "${MODULE_DIR}/.env" ]]; then
		# If .env doesn't exist, create it with the initial value
		echo "GCP_PROJECT_ID=${project_id}" >"${MODULE_DIR}/.env"
	else
		# If .env exists, perform the sed replacement
		sed -i '' "s/^GCP_PROJECT_ID=.*/GCP_PROJECT_ID=${project_id}/" "${MODULE_DIR}/.env"
	fi
	printf "✅"
}

cache_file="${MODULE_DIR}/.project_vars_cache"

# Function to load values from cache
load_cache() {
	if [[ -f ${cache_file} ]]; then
		# shellcheck disable=SC1090
		source "${cache_file}"
		return 0
	else
		return 1
	fi
}

# Function to write values to cache
write_cache() {
	{
		echo "project_id=${project_id}"
		echo "project_name=${project_name}"
		echo "region=${region}"
		echo "service_account_email=${service_account_email}"
		echo "function_name=${function_name}"
		echo "function_entry_point=${function_entry_point}"
	} >"${cache_file}"
}

# Function to load & cache values
cache_values() {
	# Ensure we're in the root directory for terraform commands
	cd "${ROOT_DIR}" || exit 1

	printf "Loading and caching project values...\n\n"

	printf " - Project Name:"
	project_name=$(awk '/variable "project_name"/{f=1} f==1&&/default/{print $3; exit}' "${ROOT_DIR}/variables.tf" | tr -d '",')
	printf ' \033[1m%s\033[0m\n' "${project_name}"

	printf " - Region:"
	region=$(awk '/variable "region"/{f=1} f==1&&/default/{print $3; exit}' "${ROOT_DIR}/variables.tf" | tr -d '",')
	printf ' \033[1m%s\033[0m\n' "${region}"

	printf " - Service Account:"
	service_account_email=$(terraform state show "google_service_account.project_sa" 2>/dev/null | grep email | awk '{print $3}' | tr -d '"' || echo "")
	printf ' \033[1m%s\033[0m\n' "${service_account_email}"

	printf " - Function Name:"
	function_name=$(awk '/variable "function_name"/{f=1} f==1&&/default/{print $3; exit}' "${MODULE_DIR}/variables.tf" | tr -d '",')
	printf ' \033[1m%s\033[0m\n' "${function_name}"

	printf " - Function Entry Point:"
	# Function entry point is hardcoded in main.tf, not a variable
	function_entry_point="processQuicknodeWebhook"
	printf ' \033[1m%s\033[0m\n' "${function_entry_point}"

	printf "\nCaching values in"
	printf ' \033[1m%s\033[0m...' "${cache_file}"
	write_cache

	printf "✅\n\n"
}

# Function to invalidate cache
invalidate_cache() {
	# Ensure we're in the root directory for terraform commands
	cd "${ROOT_DIR}" || exit 1

	printf "Clearing local cache file %s..." "${cache_file}"
	rm -f "${cache_file}"
	printf " ✅\n"

	printf "Loading current local gcloud project ID:"
	current_local_project_id=$(gcloud config get project)
	printf ' \033[1m%s\033[0m\n' "${current_local_project_id}"

	printf "Comparing with project ID from terraform state:"
	current_tf_state_project_id=$(terraform state show module.project_factory.google_project.main 2>/dev/null | grep project_id | awk '{print $3}' | tr -d '"' || echo "Not found")
	printf ' \033[1m%s\033[0m\n' "${current_tf_state_project_id}"

	if [[ ${current_local_project_id} != "${current_tf_state_project_id}" ]]; then
		printf '️\n🚨 Your local gcloud is set to the wrong project: \033[1m%s\033[0m 🚨\n' "${current_local_project_id}"
		printf "\nTrying to set the correct project ID...\n\n"
		set_project_id
		printf "\n\n"
	else
		project_id="${current_local_project_id}"
	fi

	cache_values
}

# Main script logic
main() {
	# Check for verbose flag in arguments
	for arg in "$@"; do
		if [[ ${arg} == "--verbose" || ${arg} == "-v" ]]; then
			export VERBOSE=1
		fi
	done

	if [[ ${1-} == "--invalidate-cache" ]]; then
		invalidate_cache
		return 0
	fi

	set +e
	load_cache
	cache_loaded=$?
	set -e

	if [[ ${cache_loaded} -eq 0 ]]; then
		if [[ ${VERBOSE:-0} -eq 1 ]]; then
			printf "Using cached values from %s:\n" "${cache_file}"
			printf " - Project ID: \033[1m%s\033[0m\n" "${project_id}"
			printf " - Project Name: \033[1m%s\033[0m\n" "${project_name}"
			printf " - Region: \033[1m%s\033[0m\n" "${region}"
			printf " - Service Account: \033[1m%s\033[0m\n" "${service_account_email}"
			printf " - Function Name: \033[1m%s\033[0m\n" "${function_name}"
			printf " - Function Entry Point: \033[1m%s\033[0m\n" "${function_entry_point}"
		else
			# Calculate the length for proper box sizing
			env_text="Project ID: ${project_id}"
			text_length=${#env_text}

			# Create box border (minimum 60 chars wide)
			box_width=$((text_length > 60 ? text_length + 4 : 64))
			border=$(printf '%*s' "${box_width}" '' | tr ' ' '-')

			printf "\n"
			printf "+%s+\n" "${border}"
			printf "| \033[1mProject ID:\033[0m %s" "${project_id}"

			# Calculate padding to align closing pipe
			padding=$((box_width - text_length - 1))
			printf "%*s|\n" "${padding}" ""
			printf "+%s+\n" "${border}"
		fi
	else
		printf "⚠️ No cache found. Setting project Id and fetching values...\n\n"
		# Ensure we're in the root directory for terraform commands
		cd "${ROOT_DIR}" || exit 1
		set_project_id
		cache_values
	fi
}

main "$@"
