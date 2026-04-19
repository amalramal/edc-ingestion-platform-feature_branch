module "realm_service" {
  source = "git::git@github.com:ledgerrun/terraform-modules.git?ref=realm-service/vX.Y.Z"

  deployment_environment = "prod"
  realm                  = "infra"
  service_name           = "my-service"
}
