aws_region                = "us-west-2"
cluster_name              = "retail-obs"
kubernetes_version        = "1.34" # check standard vs extended support before deploy — docs/AWS-BILLING-CHECKLIST.md
vpc_cidr                  = "10.1.0.0/16"
workload_vpc_cidr         = "10.0.0.0/16"
enable_single_nat_gateway = true
