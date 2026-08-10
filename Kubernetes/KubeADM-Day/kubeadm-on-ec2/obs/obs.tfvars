# Observability cluster — Prometheus, Grafana, Loki (Helm after bootstrap)
# Apply: terraform apply -var-file=obs.tfvars
# CD: Actions → Kubeadm Terraform Multi-Env → obs → approve

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

allow_ssh_from_cidr_blocks = ["172.225.137.213/32"]
my_local_IP                = "172.225.137.213/32"
