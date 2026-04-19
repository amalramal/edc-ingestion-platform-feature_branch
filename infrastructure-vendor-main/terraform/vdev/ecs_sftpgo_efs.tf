#
# Configuration for the EFS Volume SFTPGo uses to store it's configuration
# values in an sqlite database. Can be shared across pods.
#
# ---

resource "aws_efs_file_system" "config" {
  throughput_mode = "elastic"
  encrypted       = true
  tags = {
    "Name" = "${var.environment}-sftpgo-config"
  }
  lifecycle_policy {
    transition_to_ia = "AFTER_30_DAYS"
  }
  lifecycle_policy {
    transition_to_archive = "AFTER_90_DAYS"
  }
}

resource "aws_security_group" "efs_allow_ecs" {
  name        = "${var.environment}-efs_allow_ecs"
  description = "Allow ECS to access EFS volumes on port 2049"
  vpc_id      = module.vpc.vpc_id
}

resource "aws_vpc_security_group_ingress_rule" "efs_allow_ecs" {
  security_group_id = aws_security_group.efs_allow_ecs.id
  cidr_ipv4         = module.vpc.vpc_cidr
  from_port         = 2049
  ip_protocol       = "tcp"
  to_port           = 2049
}

resource "aws_efs_mount_target" "sftpgo" {
  for_each = toset(module.vpc.private_subnet_ids)

  file_system_id  = "fs-${split("fs-", aws_efs_file_system.config.id)[1]}"
  subnet_id       = each.value
  security_groups = [aws_security_group.efs_allow_ecs.id]
}
