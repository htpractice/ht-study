aws_region                = "us-west-2"
cluster_name              = "retail-workload"
kubernetes_version        = "1.34" # check standard vs extended support before deploy — docs/AWS-BILLING-CHECKLIST.md
vpc_cidr                  = "10.0.0.0/16"
obs_vpc_cidr              = "10.1.0.0/16"
enable_single_nat_gateway = true
