resource "aws_lb" "prometheus" {
  name               = "prometheus"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.prometheus_lb.id]
  subnets            = var.public_subnet_ids
}

resource "aws_lb_target_group" "prometheus" {
  name        = "prometheus"
  port        = 9090
  target_type = "ip"
  protocol    = "HTTP"
  vpc_id      = var.vpc_id

  health_check {
    interval            = 30
    path                = "/-/healthy"
    timeout             = 5
    healthy_threshold   = 3
    unhealthy_threshold = 3
    matcher             = "200-299"
  }
}

resource "aws_lb_listener" "prometheus" {
  load_balancer_arn = aws_lb.prometheus.arn
  port              = 9090
  protocol          = "HTTP"
  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.prometheus.arn
  }
}

resource "aws_lb_listener" "prometheus_80" {
  load_balancer_arn = aws_lb.prometheus.arn
  port              = 80
  protocol          = "HTTP"
  default_action {
    type             = "redirect"
    redirect {
      port = 9090
      protocol = "HTTP"
      status_code = "HTTP_301"
    }
  }
}
