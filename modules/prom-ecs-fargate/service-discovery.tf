resource "aws_service_discovery_private_dns_namespace" "prometheus" {
  name = "prometheus.gds.local"
  vpc  = var.vpc_id
}

resource "aws_service_discovery_service" "prometheus" {
  name = "prometheus"

  dns_config {
    namespace_id = aws_service_discovery_private_dns_namespace.prometheus.id

    dns_records {
      ttl  = 10
      type = "A"
    }
  }

  health_check_custom_config {
    failure_threshold = 1
  }
}
