module "ecs_cluster" {
  source = "git::git@github.com:ledgerrun/terraform-modules.git?ref=ecs-cluster/v1.0.0"

  name = var.environment
}
