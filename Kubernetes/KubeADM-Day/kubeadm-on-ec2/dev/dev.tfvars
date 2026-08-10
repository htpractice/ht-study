# order-api app cluster — dev
# Apply: terraform apply -var-file=dev.tfvars
# CD: push kubeadm-on-ec2/** on cka-2026-study → GHA plan + apply (dev approval)
# Observability stack: kubeadm-on-ec2/obs/ (cluster_role=obs)

environment   = "dev"
cluster_role  = "app"
aws_region    = "us-west-2"
master_count  = 1
worker_count  = 3

# Network — non-overlapping with infra (10.100.x) and prod (10.200.x)
vpc_cidr        = "10.110.0.0/16"
azs             = ["us-west-2a", "us-west-2b"]
public_subnets  = ["10.110.100.0/24", "10.110.104.0/24"]
private_subnets = ["10.110.1.0/24", "10.110.4.0/24"]

instance_type = "t3.small"
ami           = "ami-02167eae61967e403"

allow_ssh_from_cidr_blocks = ["172.225.137.213/32"]
my_local_IP                = "172.225.137.213/32"
