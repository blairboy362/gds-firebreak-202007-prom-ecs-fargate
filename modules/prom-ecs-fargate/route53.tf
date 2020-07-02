resource "aws_route53_record" "prometheus" {
  zone_id = var.zone_id
  name    = "prometheus"
  type    = "A"

  alias {
    name                   = aws_lb.prometheus.dns_name
    zone_id                = aws_lb.prometheus.zone_id
    evaluate_target_health = false
  }
}
