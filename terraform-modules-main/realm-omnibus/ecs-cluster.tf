module "ecs_cluster" {
  count  = var.create_ecs_cluster ? 1 : 0
  source = "git::git@github.com:ledgerrun/terraform-modules.git?ref=ecs-cluster/v1.0.0"
  # source = "/Users/aduss/ledgerrun/terraform-modules/ecs-cluster"

  name = "${var.realm}-${var.environment}"

  enable_container_insights = var.options_ecs_cluster.enable_container_insights
  fargate_spot_weight       = var.options_ecs_cluster.fargate_spot_weight
  fargate_weight            = var.options_ecs_cluster.fargate_weight
  tags                      = var.options_ecs_cluster.tags
}
