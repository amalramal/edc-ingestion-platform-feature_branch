module "new_module" {
  source = "git::git@github.com:ledgerrun/terraform-modules.git?ref=ecs-cluster/vX.Y.Z"

  name = "<REALM>-<ENV>"
}
