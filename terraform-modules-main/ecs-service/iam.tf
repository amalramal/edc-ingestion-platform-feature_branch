# Task Execution Role (for ECS to pull images and write logs)
resource "aws_iam_role" "execution" {
  name = "${local.service_realm_name}-execution"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ecs-tasks.amazonaws.com"
        }
      }
    ]
  })

  tags = merge(var.tags, {
    Name = "${local.service_realm_name}-execution"
  })
}

resource "aws_iam_role_policy_attachment" "execution" {
  role       = aws_iam_role.execution.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

resource "aws_iam_role_policy_attachment" "execution_additional" {
  for_each   = { for idx, arn in var.task_definition.attach_execution_iam_policies : tostring(idx) => arn }
  role       = aws_iam_role.execution.name
  policy_arn = each.value
}

# Task Role (for the application to access AWS services)
resource "aws_iam_role" "task" {
  name = "${local.service_realm_name}-task"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ecs-tasks.amazonaws.com"
        }
      }
    ]
  })

  tags = merge(var.tags, {
    Name = "${local.service_realm_name}-task"
  })
}

resource "aws_iam_role_policy_attachment" "tasks" {
  for_each   = { for idx, arn in var.task_definition.attach_task_iam_policies : tostring(idx) => arn }
  role       = aws_iam_role.task.name
  policy_arn = each.value
}
