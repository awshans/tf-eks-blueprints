
output "configure_kubectl" {
  description = "Configure kubectl: make sure you're logged in with the correct AWS profile and run the following command to update your kubeconfig"
  value       = module.m_eks.configure_kubectl
}


output "vpc_id" {
  description = "VPC ID"
  value       = module.m_network.vpc_id
}

output "private_subnet_ids" {
  description = "private_subnet_ids"
  value       = module.m_network.private_subnets
}

output "database_cluster_arn" {
  description = "database_cluster_arn"
  value       = module.m_database.database_cluster_arn
}