terraform {
  required_providers {
    sentry = {
      source  = "jianyuan/sentry"
      version = "~> 0.14.3"
    }
  }
}

provider "sentry" {
  auth_token = var.sentry_auth_token
}

################
# Organization #
################

data "sentry_organization" "main" {
  # Taken from URL: https://[slug].sentry.io
  slug = "mento-labs"
}

output "organization" {
  value = data.sentry_organization.main
}

########
# Team #
########

data "sentry_team" "main" {
  organization = data.sentry_organization.main.id
  slug         = "mento-labs"
}

output "team" {
  value = sentry_team.main.id
}
