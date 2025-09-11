terraform {
  required_providers {
    discord = {
      source  = "Lucky3028/discord"
      version = "2.0.1"
    }
    restapi = {
      source                = "Mastercard/restapi"
      version               = "~> 2.0.1"
      configuration_aliases = [restapi.discord]
    }
  }
}
