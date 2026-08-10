# order-api app cluster — prod
# Apply: terraform apply -var-file=prod.tfvars
# Observability stack: kubeadm-on-ec2/obs/ (Prometheus, Grafana via Helm)

environment   = "prod"
cluster_role  = "app"
aws_region    = "us-west-2"
master_count  = 1
worker_count  = 3

# Network
vpc_cidr        = "10.200.0.0/16"
azs             = ["us-west-2a", "us-west-2b"]
public_subnets  = ["10.200.100.0/24", "10.200.104.0/24"]
private_subnets = ["10.200.1.0/24", "10.200.4.0/24"]

instance_type = "t3.small"
ami           = "ami-02167eae61967e403"

allow_ssh_from_cidr_blocks = ["172.225.137.213/32"]
my_local_IP                = "172.225.137.213/32"
