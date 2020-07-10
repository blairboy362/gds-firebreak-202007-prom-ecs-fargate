resource "aws_security_group" "prometheus_lb" {
  name   = "prometheus-lb"
  vpc_id = var.vpc_id
}

resource "aws_security_group_rule" "all_inbound_9090" {
  type              = "ingress"
  cidr_blocks       = ["0.0.0.0/0"]
  from_port         = 9090
  to_port           = 9090
  protocol          = "tcp"
  security_group_id = aws_security_group.prometheus_lb.id
}

resource "aws_security_group_rule" "all_inbound_80" {
  type              = "ingress"
  cidr_blocks       = ["0.0.0.0/0"]
  from_port         = 80
  to_port           = 80
  protocol          = "tcp"
  security_group_id = aws_security_group.prometheus_lb.id
}

resource "aws_security_group_rule" "lb_outbound_to_thanos_query" {
  type                     = "egress"
  from_port                = 19192
  to_port                  = 19192
  protocol                 = "tcp"
  source_security_group_id = aws_security_group.thanos_query_service.id
  security_group_id        = aws_security_group.prometheus_lb.id
}

resource "aws_security_group" "prometheus_service" {
  name   = "prometheus-service"
  vpc_id = var.vpc_id
}

resource "aws_security_group_rule" "prometheus_inbound_from_thanos_query" {
  type                     = "ingress"
  from_port                = 10901
  to_port                  = 10901
  protocol                 = "tcp"
  source_security_group_id = aws_security_group.thanos_query_service.id
  security_group_id        = aws_security_group.prometheus_service.id
}

resource "aws_security_group_rule" "prometheus_outbound_to_internet" {
  type              = "egress"
  from_port         = 0
  to_port           = 65535
  protocol          = "all"
  cidr_blocks       = ["0.0.0.0/0"]
  security_group_id = aws_security_group.prometheus_service.id
}

resource "aws_security_group" "efs_mount" {
  name   = "prometheus-efs-mount"
  vpc_id = var.vpc_id
}

resource "aws_security_group_rule" "efs_mount_outboud_all" {
  type              = "egress"
  from_port         = 0
  to_port           = 65535
  protocol          = "all"
  cidr_blocks       = ["0.0.0.0/0"]
  security_group_id = aws_security_group.efs_mount.id
}

resource "aws_security_group_rule" "efs_mount_inbound_from_prometheus" {
  type                     = "ingress"
  from_port                = 2049
  to_port                  = 2049
  protocol                 = "tcp"
  source_security_group_id = aws_security_group.prometheus_service.id
  security_group_id        = aws_security_group.efs_mount.id
}

resource "aws_security_group_rule" "efs_mount_encrypted_inbound_from_prometheus" {
  type                     = "ingress"
  from_port                = 2999
  to_port                  = 2999
  protocol                 = "tcp"
  source_security_group_id = aws_security_group.prometheus_service.id
  security_group_id        = aws_security_group.efs_mount.id
}

resource "aws_security_group" "thanos_query_service" {
  name   = "thanos-query-service"
  vpc_id = var.vpc_id
}

resource "aws_security_group_rule" "thanos_query_inbound_from_lb" {
  type                     = "ingress"
  from_port                = 19192
  to_port                  = 19192
  protocol                 = "tcp"
  source_security_group_id = aws_security_group.prometheus_lb.id
  security_group_id        = aws_security_group.thanos_query_service.id
}

resource "aws_security_group_rule" "thanos_query_outbound_to_internet" {
  type              = "egress"
  from_port         = 0
  to_port           = 65535
  protocol          = "all"
  cidr_blocks       = ["0.0.0.0/0"]
  security_group_id = aws_security_group.thanos_query_service.id
}
