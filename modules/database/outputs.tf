output "db_instance_id" {
  description = "ID of the database instance"
  value       = aws_db_instance.main.id
}

output "db_instance_address" {
  description = "Address of the database instance"
  value       = aws_db_instance.main.address
}

output "db_instance_endpoint" {
  description = "Endpoint of the database instance"
  value       = aws_db_instance.main.endpoint
}

output "db_instance_port" {
  description = "Port of the database instance"
  value       = aws_db_instance.main.port
}

output "db_security_group_id" {
  description = "ID of the database security group"
  value       = aws_security_group.db.id
}

output "db_subnet_group_id" {
  description = "ID of the database subnet group"
  value       = aws_db_subnet_group.main.id
}

output "db_parameter_group_id" {
  description = "ID of the database parameter group"
  value       = aws_db_parameter_group.main.id
}

output "db_instance_name" {
  description = "Name of the database"
  value       = var.db_name
}

output "db_instance_username" {
  description = "Username for the database"
  value       = var.db_username
}

output "db_instance_resource_id" {
  description = "Resource ID of the database instance"
  value       = aws_db_instance.main.resource_id
}

output "db_secret_arn" {
  description = "ARN of the database credentials secret"
  value       = aws_secretsmanager_secret.db.arn
}

output "kms_key_arn" {
  description = "ARN of the KMS key used for encryption"
  value       = var.use_kms_encryption ? aws_kms_key.db[0].arn : null
}