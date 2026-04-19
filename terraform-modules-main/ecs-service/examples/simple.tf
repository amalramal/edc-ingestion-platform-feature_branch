module "ecs_service" {
  source = "git::git@github.com:ledgerrun/terraform-modules.git?ref=ecs-service/vX.Y.Z"

  environment            = "prod"
  deployment_environment = "prod"
  realm                  = "infra"
  service_name           = "my-service"

  # This module will create the 'infra/prod/my-service' secret in AWS
  # secrets manager, which the user should then go populate with the
  # correct key/values
  secrets_manager_secrets = [
    "POSTGRES_DB",
    "POSTGRES_PASSWORD",
  ]

  container_definition = {
    image       = "postgres"
    image_tag   = "18"
    web_ui_port = 5432
  }
}
