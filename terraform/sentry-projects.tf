# Create all sentry projects
resource "sentry_project" "app_mento_org" {
  organization = data.sentry_organization.main.id

  teams = [data.sentry_team.main.id]
  name  = "app.mento.org"
  slug  = "app-mento-org"

  platform = "javascript-nextjs"

  client_security = {
    scrape_javascript = true
  }
}

resource "sentry_project" "reserve_mento_org" {
  organization = data.sentry_organization.main.id

  teams = [data.sentry_team.main.id]
  name  = "reserve.mento.org"
  slug  = "reserve-mento-org"

  platform = "javascript-nextjs"

  client_security = {
    scrape_javascript = true
  }
}
