resource "aws_ecs_cluster" "prometheus" {
  name               = "prometheus"
  capacity_providers = ["FARGATE"]
}

data "template_file" "prometheus_task_definition" {
  template = file("${path.module}/files/prometheus-task-definition.json")
  vars = {
    data_volume_name = local.data_volume_name
    log_group_name   = aws_cloudwatch_log_group.prometheus.name
    log_group_region = data.aws_region.current.name
    config_base64    = base64encode(file("${path.module}/files/prometheus.yml"))
  }
}

resource "aws_ecs_task_definition" "prometheus" {
  family                   = "prometheus"
  container_definitions    = data.template_file.prometheus_task_definition.rendered
  requires_compatibilities = ["FARGATE"]
  cpu                      = 512
  memory                   = 1024
  network_mode             = "awsvpc"
  volume {
    name = local.data_volume_name
    efs_volume_configuration {
      file_system_id          = aws_efs_file_system.prometheus.id
      transit_encryption      = "ENABLED"
      transit_encryption_port = 2999
      authorization_config {
        access_point_id = aws_efs_access_point.prometheus.id
        iam             = "ENABLED"
      }
    }
  }

  execution_role_arn = aws_iam_role.prometheus_execution.arn
  task_role_arn      = aws_iam_role.prometheus_task.arn
}

resource "aws_ecs_service" "prometheus" {
  name             = "prometheus"
  cluster          = aws_ecs_cluster.prometheus.id
  task_definition  = aws_ecs_task_definition.prometheus.arn
  desired_count    = 1
  launch_type      = "FARGATE"
  platform_version = "1.4.0"

  load_balancer {
    target_group_arn = aws_lb_target_group.prometheus.arn
    container_name   = "prometheus"
    container_port   = 9090
  }

  network_configuration {
    subnets         = var.private_subnet_ids
    security_groups = [aws_security_group.prometheus_service.id]
  }

  lifecycle {
    ignore_changes = [desired_count]
  }

  depends_on = [
    aws_lb_listener.prometheus,
  ]
}
