# Dev network settings. No secrets in here, so this file IS committed
# (see the !envs/**/terraform.tfvars exception in .gitignore).

aws_region  = "us-east-1"
project     = "eks-platform-as-code"
environment = "dev"
owner       = "Domphil87"
cost_center = "portfolio"

# 10.10.0.0/16 = 65,536 addresses. Chosen to avoid the default VPC
# (172.31.0.0/16). Staging uses 10.20.0.0/16.
vpc_cidr = "10.10.0.0/16"

# In this account these map to zone IDs use1-az1, use1-az2 and use1-az4.
# Avoid us-east-1e here: it is use1-az3, which does not support EKS.
azs = ["us-east-1a", "us-east-1b", "us-east-1c"]

# Private /19 = 8,190 usable IPs each. Every pod takes a VPC IP (VPC CNI).
private_subnet_cidrs = ["10.10.0.0/19", "10.10.32.0/19", "10.10.64.0/19"]

# Public /24 = 251 usable IPs each. Only load balancers and NAT live here.
public_subnet_cidrs = ["10.10.96.0/24", "10.10.97.0/24", "10.10.98.0/24"]

# 10.10.99.0 - 10.10.255.255 is left free for future subnets.

# Dev: one NAT gateway to save about $72/month vs. one per AZ.
# Trade-off: if us-east-1a has an outage, private subnets lose internet access.
single_nat_gateway = true
