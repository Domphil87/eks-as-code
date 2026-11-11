# Module: network

Creates an EKS-ready VPC: public and private subnets across several
Availability Zones, an internet gateway, NAT gateway(s), route tables, and a
free S3 gateway endpoint.

```text
VPC
├── Public subnet  ×N  ── route table → Internet Gateway
│     tag kubernetes.io/role/elb=1          (internet-facing load balancers)
│     └── NAT gateway + Elastic IP (first AZ only, or one per AZ)
├── Private subnet ×N  ── route table per AZ → NAT gateway
│     tag kubernetes.io/role/internal-elb=1 (internal load balancers; nodes and pods)
├── S3 gateway endpoint on the private route tables
└── Default security group with all rules removed
```

## Resources

| Resource | Count | Purpose |
|---|---|---|
| `aws_vpc.this` | 1 | The network. DNS support and hostnames are on (required by EKS). |
| `aws_default_security_group.this` | 1 | Removes all rules from the VPC's default SG (deny by default) |
| `aws_internet_gateway.this` | 1 | Internet access for public subnets |
| `aws_subnet.public` | 1 per AZ | Load balancers and NAT. No automatic public IPs. |
| `aws_subnet.private` | 1 per AZ | EKS nodes and pods |
| `aws_eip.nat` + `aws_nat_gateway.this` | 1, or 1 per AZ | Outbound-only internet for private subnets |
| `aws_route_table.public` + route + associations | 1 table | `0.0.0.0/0` → IGW |
| `aws_route_table.private` + route + associations | 1 table per AZ | `0.0.0.0/0` → NAT |
| `aws_vpc_endpoint.s3` | 0 or 1 | Keeps S3 and ECR image-layer traffic off the NAT (free) |

Resources use `for_each` keyed by AZ name, so removing an AZ does not
renumber, and therefore recreate, the others.

## Inputs

| Name | Type | Default | Description |
|---|---|---|---|
| `name` | string | (none) | Name prefix for all resources |
| `vpc_cidr` | string | (none) | VPC CIDR, for example `10.10.0.0/16` |
| `azs` | list(string) | (none) | AZ names (2 or more, must support EKS) |
| `public_subnet_cidrs` | list(string) | (none) | One per AZ, same order |
| `private_subnet_cidrs` | list(string) | (none) | One per AZ, same order |
| `single_nat_gateway` | bool | `true` | One shared NAT (cheap) or one per AZ (resilient) |
| `enable_s3_gateway_endpoint` | bool | `true` | Create the S3 gateway endpoint |
| `tags` | map(string) | `{}` | Extra tags. Standard tags come from provider `default_tags`. |

## Outputs

| Name | Description |
|---|---|
| `vpc_id`, `vpc_cidr` | VPC identifiers |
| `azs` | AZs used, in order |
| `public_subnet_ids`, `private_subnet_ids` | Subnet IDs in AZ order |
| `private_route_table_ids` | Private route table IDs in AZ order |
| `nat_public_ips` | Outbound public IPs of the NAT gateway(s) |

## Design notes

- **Why /19 private subnets?** The EKS VPC CNI gives each pod a real VPC IP
  address. Small private subnets run out of IPs before they run out of compute.
- **Single NAT trade-off.** If the NAT's AZ fails, private subnets in every AZ
  lose outbound internet access. This is acceptable for dev. Use
  `single_nat_gateway = false` for staging and production.
- **Kubernetes subnet tags** let the AWS Load Balancer Controller find the
  right subnets automatically. The per-cluster tag
  `kubernetes.io/cluster/<name>` is no longer required for current controller
  versions.

## Checkov skips

| Check | Reason |
|---|---|
| CKV2_AWS_11: VPC Flow Logs | Added with the observability stack (Milestone 4d) |
| CKV2_AWS_19: EIP attached to EC2 | False positive: the EIP is attached to the NAT gateway |
