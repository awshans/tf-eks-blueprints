output "vpc_id" {
  description = "The ID of the VPC"
  value       = module.vpc.vpc_id
}
output "private_subnets" {
  description = "List of IDs of private subnets"
  value       = module.vpc.private_subnets
}

output "public_subnets" {
  description = "List of IDs of public subnets"
  value       = module.vpc.public_subnets
}

output "database_security_group_id" {
  description = "security group id for database"
  value       = aws_security_group.database.id
}

output "container_security_group_id" {
  description = "security group id for container"
  value       = aws_security_group.container.id
}