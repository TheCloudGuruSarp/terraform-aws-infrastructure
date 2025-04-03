output "vpc_id" {
  description = "The ID of the VPC"
  value       = module.networking.vpc_id
}

output "public_subnet_ids" {
  description = "List of IDs of public subnets"
  value       = module.networking.public_subnet_ids
}

output "private_subnet_ids" {
  description = "List of IDs of private subnets"
  value       = module.networking.private_subnet_ids
}

output "alb_dns_name" {
  description = "DNS name of the application load balancer"
  value       = module.compute.alb_dns_name
}

output "db_instance_endpoint" {
  description = "Endpoint of the database instance"
  value       = module.database.db_instance_endpoint
}

output "db_secret_arn" {
  description = "ARN of the database credentials secret"
  value       = module.database.db_secret_arn
}

output "alb_logs_bucket" {
  description = "Name of the S3 bucket for ALB logs"
  value       = aws_s3_bucket.alb_logs.bucket
}

output "sns_topic_arn" {
  description = "ARN of the SNS topic for alerts"
  value       = aws_sns_topic.alerts.arn
}