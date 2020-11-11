# Network Load Balancer DNS Record
resource "aws_route53_record" "apiserver" {
  zone_id = var.dns_zone_id

  name = format("%s.%s.", var.cluster_name, var.dns_zone)
  type = "A"

  # AWS recommends their special "alias" records for NLBs
  alias {
    name                   = aws_lb.nlb.dns_name
    zone_id                = aws_lb.nlb.zone_id
    evaluate_target_health = true
  }
}

# Network Load Balancer for apiservers and ingress
resource "aws_lb" "nlb" {
  name               = "${var.cluster_name}-nlb"
  load_balancer_type = "network"
  internal           = false

  subnets = aws_subnet.public.*.id

  enable_cross_zone_load_balancing = true

  tags = merge(var.default_tags, {
    Name = "${var.cluster_name}-nlb"
  })
}

# Forward TCP apiserver traffic to controllers
resource "aws_lb_listener" "apiserver-https" {
  load_balancer_arn = aws_lb.nlb.arn
  protocol          = "TCP"
  port              = "6443"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.controllers.arn
  }
}

# Forward HTTP ingress traffic to workers
resource "aws_lb_listener" "ingress-http" {
  count             = var.ingress_http_enabled ? 1 : 0
  load_balancer_arn = aws_lb.nlb.arn
  protocol          = "TCP"
  port              = 80

  default_action {
    type             = "forward"
    target_group_arn = module.workers.target_group_http
  }
}

# Forward HTTPS ingress traffic to workers
resource "aws_lb_listener" "ingress-https" {
  count             = var.ingress_https_enabled ? 1 : 0
  load_balancer_arn = aws_lb.nlb.arn
  protocol          = var.ingress_https_certificate_arn ? "TLS" : "TCP"
  port              = 443
  ssl_policy        = var.ingress_https_certificate_arn ? "ELBSecurityPolicy-TLS-1-2-Ext-2018-06" : null
  certificate_arn   = var.ingress_https_certificate_arn

  default_action {
    type             = "forward"
    target_group_arn = var.ingress_https_certificate_arn ? module.workers.target_group_http : module.workers.target_group_https
  }
}

# Target group of controllers
resource "aws_lb_target_group" "controllers" {
  name        = "${var.cluster_name}-controllers"
  vpc_id      = aws_vpc.network.id
  target_type = "instance"

  protocol = "TCP"
  port     = 6443

  # TCP health check for apiserver
  health_check {
    protocol = "TCP"
    port     = 6443

    # NLBs required to use same healthy and unhealthy thresholds
    healthy_threshold   = 3
    unhealthy_threshold = 3

    # Interval between health checks required to be 10 or 30
    interval = 10
  }

  tags = var.default_tags
}

# Attach controller instances to apiserver NLB
resource "aws_lb_target_group_attachment" "controllers" {
  count = var.controller_count

  target_group_arn = aws_lb_target_group.controllers.arn
  target_id        = aws_instance.controllers.*.id[count.index]
  port             = 6443
}

