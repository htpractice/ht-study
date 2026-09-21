# Observability cluster — Prometheus, Grafana (Helm after bootstrap)
# CI: push to cka-2026-study under kubeadm-on-ec2/** → plan+apply dev+obs (approve obs gate)
# Local: terraform apply -var-file=obs.tfvars

environment   = "obs"
cluster_role  = "obs"
aws_region    = "us-west-2"
master_count  = 1
worker_count  = 3

# Network — non-overlapping with dev (10.110.x), prod (10.200.x), infra (10.100.x)
vpc_cidr        = "10.210.0.0/16"
azs             = ["us-west-2a", "us-west-2b"]
public_subnets  = ["10.210.100.0/24", "10.210.104.0/24"]
private_subnets = ["10.210.1.0/24", "10.210.4.0/24"]

instance_type = "t3.small"
ami           = "ami-02167eae61967e403"

allow_ssh_from_cidr_blocks = ["223.233.85.32/32"]
my_local_IP                = "223.233.85.32/32"
