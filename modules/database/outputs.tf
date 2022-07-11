#output "database_cluster_endpoint" {
#  description = "The cluster endpoint"
#  value       = aws_rds_cluster.primary.endpoint
#}

#output "database_cluster_reader_endpoint" {
#  description = "The cluster reader endpoint"
#  value       = aws_rds_cluster.primary.reader_endpoint
#}

output "database_cluster_arn" {
  description = "The cluster arn"
  value       = aws_rds_cluster.primary.arn
 }