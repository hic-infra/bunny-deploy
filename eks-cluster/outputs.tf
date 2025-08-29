output "cluster_id" {
  description = "EKS cluster ID."
  value       = module.eks.cluster_id
}

output "cluster_endpoint" {
  description = "Endpoint for EKS control plane."
  value       = module.eks.cluster_endpoint
}

output "cluster_security_group_id" {
  description = "Security group ids attached to the cluster control plane."
  value       = module.eks.cluster_security_group_id
}

output "region" {
  description = "AWS region"
  value       = var.region
}

output "cluster_name" {
  description = "Kubernetes Cluster Name"
  value       = var.cluster_name
}

output "ipv6_public_cidrs" {
  description = "IPv6 public subnet CIDRs"
  value       = module.vpc.public_subnets_ipv6_cidr_blocks
}
output "ipv6_private_cidrs" {
  description = "IPv6 private subnet CIDRs"
  value       = module.vpc.private_subnets_ipv6_cidr_blocks
}

output "rds_endpoint" {
  value = aws_rds_cluster_instance.bunny.endpoint
}

output "rds_password" {
  value     = random_password.rds_password.result
  sensitive = true
}
