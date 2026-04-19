# ECS Service Module

This module will install an ECS service onto an existing ECS Cluster (See the ecs-cluster module)

Start by installing the pre-commit hook by running `pre-commit install`.  Then when you to do a commit, the following tools will be run

  - tflint
  - tf-fmt
  - terraform-docs

<!-- BEGIN_TF_DOCS -->
## Examples

### Simple

```hcl
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
```

## Requirements

| Name | Version |
|------|---------|
| terraform | >= 1.0 |
| aws | >= 5.0 |

## Providers

| Name | Version |
|------|---------|
| aws | >= 5.0 |



## Resources

| Name | Type |
|------|------|
| [aws_cloudwatch_log_group.main](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/cloudwatch_log_group) | resource |
| [aws_ecs_service.svc](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/ecs_service) | resource |
| [aws_ecs_task_definition.task](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/ecs_task_definition) | resource |
| [aws_iam_policy.secrets_manager_read](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_policy) | resource |
| [aws_iam_role.execution](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role) | resource |
| [aws_iam_role.task](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role) | resource |
| [aws_iam_role_policy_attachment.execution](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy_attachment) | resource |
| [aws_iam_role_policy_attachment.execution_additional](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy_attachment) | resource |
| [aws_iam_role_policy_attachment.secrets_manager_read_attachment](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy_attachment) | resource |
| [aws_iam_role_policy_attachment.tasks](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy_attachment) | resource |
| [aws_lb.nlb](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/lb) | resource |
| [aws_lb_listener.nlb_tcp](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/lb_listener) | resource |
| [aws_lb_listener.nlb_tls](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/lb_listener) | resource |
| [aws_lb_listener_rule.main](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/lb_listener_rule) | resource |
| [aws_lb_target_group.main](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/lb_target_group) | resource |
| [aws_lb_target_group.nlb](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/lb_target_group) | resource |
| [aws_route53_record.svc](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/route53_record) | resource |
| [aws_secretsmanager_secret.service](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/secretsmanager_secret) | resource |
| [aws_security_group.nlb](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/security_group) | resource |
| [aws_security_group.tasks](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/security_group) | resource |
| [aws_acm_certificate.realm](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/acm_certificate) | data source |
| [aws_caller_identity.current](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/caller_identity) | data source |
| [aws_ecs_cluster.realm](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/ecs_cluster) | data source |
| [aws_lb.alb](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/lb) | data source |
| [aws_lb_listener.https](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/lb_listener) | data source |
| [aws_region.current](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/region) | data source |
| [aws_route53_zone.realm](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/route53_zone) | data source |
| [aws_subnets.private](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/subnets) | data source |
| [aws_subnets.public](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/subnets) | data source |
| [aws_vpc.vpc](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/vpc) | data source |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| container\_definition | Configuration Options for the ECS Container | <pre>object({<br/>    image       = string<br/>    image_tag   = string<br/>    web_ui_port = number<br/><br/>    # Optional<br/>    command       = optional(list(string), null)<br/>    desired_count = optional(number, 1)<br/>    environment_variables = optional(list(object({<br/>      name  = string<br/>      value = any<br/>    })), null)<br/>    essential = optional(bool, true)<br/>    logdriver = optional(string, "awslogs")<br/>    mount_points = optional(list(object({<br/>      sourceVolume  = string<br/>      containerPath = string<br/>      readOnly      = bool<br/>    })), null)<br/>    port_mappings = optional(list(object({<br/>      name          = string<br/>      containerPort = number<br/>      hostPort      = number<br/>      protocol      = string<br/>    })), null)<br/>    user = optional(string, null)<br/>  })</pre> | n/a | yes |
| deployment\_environment | The name of the environment in which to deploy | `string` | n/a | yes |
| realm | The name of the realm | `string` | n/a | yes |
| service\_name | Name of the ECS service | `string` | n/a | yes |
| base\_domain | The base domain of the URL you want to deploy to | `string` | `"ledgerrun.com"` | no |
| environment | n/a | `string` | `"The name of the environment this service is deployed into. Can be 'dev', 'stage', or 'prod'"` | no |
| log\_retention\_days | CloudWatch log retention in days | `number` | `7` | no |
| module\_tags | A list of tags for each resource in this module | `map(string)` | <pre>{<br/>  "managedby": "terraform",<br/>  "tfmodule": "ecs-service"<br/>}</pre> | no |
| nlb\_config | NLB listener configuration. Required when use\_nlb = true. | <pre>object({<br/>    listeners = map(object({<br/>      protocol           = string # "TCP" or "TLS"<br/>      port               = number # NLB/Internet listener port (443 for HTTPS)<br/>      target_port        = number # container port to forward to<br/>      preserve_client_ip = optional(bool, true)<br/>      health_check = optional(object({<br/>        enabled             = optional(bool, true)<br/>        healthy_threshold   = optional(number, 3)<br/>        unhealthy_threshold = optional(number, 3)<br/>        interval            = optional(number, 10)<br/>        protocol            = optional(string, "TCP")<br/>        path                = optional(string, null)<br/>        port                = optional(string, "traffic-port")<br/>        matcher             = optional(string, null)<br/>      }), null)<br/>    }))<br/>  })</pre> | `null` | no |
| secrets\_manager\_secrets | A list of AWS SecretsManager Secrets to include in the container defintion. A secrets manager secret named $realm/$deploy\_env/$service will also be created. | `list(string)` | `[]` | no |
| tags | Additional tags for resources | `map(string)` | `{}` | no |
| task\_definition | Configuration Options for the ECS Task Definition | <pre>object({<br/>    enable_execute_command        = optional(bool, false)<br/>    attach_execution_iam_policies = optional(list(string), [])<br/>    attach_task_iam_policies      = optional(list(string), [])<br/>    network_mode                  = optional(string, "awsvpc")<br/>    force_new_deployment          = optional(bool, true)<br/>    requires_compatibilities      = optional(list(string), ["FARGATE"])<br/>    cpu                           = optional(number, 256)<br/>    memory                        = optional(number, 512)<br/>    fargate_spot_capacity         = optional(number, 100)<br/>    fargate_capacity              = optional(number, 0)<br/>    sg_ingress = optional(list(object({<br/>      from_port       = number<br/>      to_port         = number<br/>      protocol        = optional(string, "tcp")<br/>      security_groups = optional(list(string), [])<br/>      cidr_blocks     = optional(list(string), [])<br/>      description     = string<br/>    })), null)<br/>    efs_volumes = optional(list(object({<br/>      name           = string<br/>      file_system_id = string<br/>      root_directory = string<br/>    })), null)<br/>  })</pre> | `{}` | no |
| use\_alb | Whether to create ALB resources (target group, listener rule, ALB ingress) | `bool` | `true` | no |
| use\_nlb | Whether to create an NLB for this service | `bool` | `false` | no |

## Outputs

| Name | Description |
|------|-------------|
| service\_arn | ARN of the ECS service |
| service\_id | ID of the ECS service |
| service\_name | Name of the ECS service |
<!-- END_TF_DOCS -->
