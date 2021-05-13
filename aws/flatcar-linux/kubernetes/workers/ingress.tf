# Target groups of instances for use with load balancers

resource "aws_lb_target_group" "workers-http" {
  count       = var.ingress_http_enabled ? 1 : 0
  name        = "${var.name}-workers-http"
  vpc_id      = var.vpc_id
  target_type = "instance"

  protocol = "TCP"
  port     = var.ingress_http_port

  # HTTP health check for ingress
  health_check {
    protocol = "HTTP"
    port     = 10254
    path     = "/healthz"

    # NLBs required to use same healthy and unhealthy thresholds
    healthy_threshold   = 3
    unhealthy_threshold = 3

    # Interval between health checks required to be 10 or 30
    interval = 10
  }

  tags = var.default_tags
}

resource "aws_lb_target_group" "workers-https" {
  count       = var.ingress_https_enabled && !var.ingress_https_ssl_offloading ? 1 : 0
  name        = "${var.name}-workers-https"
  vpc_id      = var.vpc_id
  target_type = "instance"

  protocol = "TCP"
  port     = var.ingress_https_port

  # HTTP health check for ingress
  health_check {
    protocol = "HTTP"
    port     = 10254
    path     = "/healthz"

    # NLBs required to use same healthy and unhealthy thresholds
    healthy_threshold   = 3
    unhealthy_threshold = 3

    # Interval between health checks required to be 10 or 30
    interval = 10
  }

  tags = var.default_tags
}

