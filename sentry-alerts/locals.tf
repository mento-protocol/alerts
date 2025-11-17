locals {
  # Get all projects from Sentry organization
  # This includes both existing projects and any projects we create in this module
  # The data source will automatically discover our managed projects after they're created
  projects = {
    for project in data.sentry_all_projects.all.projects :
    project.slug => project
  }
}

