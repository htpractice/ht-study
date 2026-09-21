# Security group rules — from retail-store-sample-app/terraform/security.tf

resource "aws_security_group_rule" "internet_to_lb_http" {
  count = var.enable_ingress_nginx ? 1 : 0

  description       = "Allow HTTP traffic from internet to LoadBalancer"
  type              = "ingress"
  from_port         = 80
  to_port           = 80
  protocol          = "tcp"
  cidr_blocks       = ["0.0.0.0/0"]
  security_group_id = module.eks.cluster_security_group_id
}

resource "aws_security_group_rule" "internet_to_lb_https" {
  count = var.enable_ingress_nginx ? 1 : 0

  description       = "Allow HTTPS traffic from internet to LoadBalancer"
  type              = "ingress"
  from_port         = 443
  to_port           = 443
  protocol          = "tcp"
  cidr_blocks       = ["0.0.0.0/0"]
  security_group_id = module.eks.cluster_security_group_id
}

resource "aws_security_group_rule" "health_checks_to_lb" {
  count = var.enable_ingress_nginx ? 1 : 0

  description       = "Allow AWS health checks to LoadBalancer"
  type              = "ingress"
  from_port         = 10254
  to_port           = 10254
  protocol          = "tcp"
  cidr_blocks       = [module.vpc.vpc_cidr_block]
  security_group_id = module.eks.cluster_security_group_id
}

resource "aws_security_group_rule" "nodeport_access" {
  description       = "Allow NodePort access within VPC"
  type              = "ingress"
  from_port         = 30000
  to_port           = 32767
  protocol          = "tcp"
  cidr_blocks       = [module.vpc.vpc_cidr_block]
  security_group_id = module.eks.cluster_security_group_id
}

resource "aws_security_group_rule" "peer_vpc_ingress" {
  count = var.peer_vpc_cidr != "" ? 1 : 0

  description       = "Cross-cluster observability scrape from peer VPC"
  type              = "ingress"
  from_port         = 0
  to_port           = 65535
  protocol          = "tcp"
  cidr_blocks       = [var.peer_vpc_cidr]
  security_group_id = module.eks.node_security_group_id
}
