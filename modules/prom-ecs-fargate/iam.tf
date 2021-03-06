data "aws_iam_policy_document" "ecs_assume_roll" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["ecs-tasks.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "prometheus_execution" {
  name               = "prometheus-execution"
  assume_role_policy = data.aws_iam_policy_document.ecs_assume_roll.json
}

data "aws_iam_policy_document" "prometheus_data_volume_access" {
  statement {
    principals {
      type        = "AWS"
      identifiers = [aws_iam_role.prometheus_task.arn]
    }

    actions = [
      "elasticfilesystem:ClientMount",
      "elasticfilesystem:ClientWrite",
    ]

    condition {
      test     = "StringEquals"
      variable = "elasticfilesystem:AccessPointArn"
      values   = [aws_efs_access_point.prometheus.arn]
    }

    resources = [aws_efs_file_system.prometheus.arn]
  }
}

data "aws_iam_policy_document" "prometheus_cloudwatch_access" {
  statement {
    actions = [
      "logs:CreateLogStream",
      "logs:PutLogEvents",
    ]

    resources = [aws_cloudwatch_log_group.prometheus.arn]
  }
}

resource "aws_iam_policy" "prometheus_cloudwatch_access" {
  name   = "prometheus-cloudwatch-access"
  policy = data.aws_iam_policy_document.prometheus_cloudwatch_access.json
}

resource "aws_iam_role_policy_attachment" "prometheus_cloudwatch_access" {
  role       = aws_iam_role.prometheus_execution.name
  policy_arn = aws_iam_policy.prometheus_cloudwatch_access.arn
}

resource "aws_iam_role" "prometheus_task" {
  name               = "prometheus-task"
  assume_role_policy = data.aws_iam_policy_document.ecs_assume_roll.json
}

resource "aws_iam_role" "thanos_query_execution" {
  name               = "thanos-query-execution"
  assume_role_policy = data.aws_iam_policy_document.ecs_assume_roll.json
}

resource "aws_iam_role_policy_attachment" "thanos_query_cloudwatch_access" {
  role       = aws_iam_role.thanos_query_execution.name
  policy_arn = aws_iam_policy.prometheus_cloudwatch_access.arn
}

resource "aws_iam_role" "thanos_query_task" {
  name               = "thanos-query-task"
  assume_role_policy = data.aws_iam_policy_document.ecs_assume_roll.json
}
