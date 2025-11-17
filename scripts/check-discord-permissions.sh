#!/bin/bash
# Wrapper script to check Discord permissions using terraform.tfvars
# This script automatically reads configuration from terraform.tfvars

cd "$(dirname "$0")" || exit 1
npm run check-discord-permissions
