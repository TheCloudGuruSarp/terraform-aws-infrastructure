# Database Module

# Security Group for RDS
resource "aws_security_group" "db" {
  name        = "${var.environment}-${var.db_name}-sg"
  description = "Security group for ${var.db_name} database"
  vpc_id      = var.vpc_id

  ingress {
    description     = "Database port from web servers"
    from_port       = var.db_port
    to_port         = var.db_port
    protocol        = "tcp"
    security_groups = var.allowed_security_group_ids
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(
    var.tags,
    {
      Name = "${var.environment}-${var.db_name}-sg"
    }
  )
}

# DB Subnet Group
resource "aws_db_subnet_group" "main" {
  name       = "${var.environment}-${var.db_name}-subnet-group"
  subnet_ids = var.subnet_ids

  tags = merge(
    var.tags,
    {
      Name = "${var.environment}-${var.db_name}-subnet-group"
    }
  )
}

# DB Parameter Group
resource "aws_db_parameter_group" "main" {
  name   = "${var.environment}-${var.db_name}-param-group"
  family = var.parameter_group_family

  dynamic "parameter" {
    for_each = var.db_parameters
    content {
      name  = parameter.key
      value = parameter.value
    }
  }

  tags = merge(
    var.tags,
    {
      Name = "${var.environment}-${var.db_name}-param-group"
    }
  )
}

# KMS Key for RDS Encryption
resource "aws_kms_key" "db" {
  count = var.use_kms_encryption ? 1 : 0

  description             = "KMS key for ${var.environment} ${var.db_name} database encryption"
  deletion_window_in_days = 30
  enable_key_rotation     = true

  tags = merge(
    var.tags,
    {
      Name = "${var.environment}-${var.db_name}-kms-key"
    }
  )
}

resource "aws_kms_alias" "db" {
  count = var.use_kms_encryption ? 1 : 0

  name          = "alias/${var.environment}-${var.db_name}-key"
  target_key_id = aws_kms_key.db[0].key_id
}

# Random Password for RDS
resource "random_password" "db" {
  length           = 16
  special          = true
  override_special = "!#$%&*()-_=+[]{}<>:?"
}

# AWS Secrets Manager Secret
resource "aws_secretsmanager_secret" "db" {
  name        = "${var.environment}/${var.db_name}/credentials"
  description = "Credentials for ${var.environment} ${var.db_name} database"
  kms_key_id  = var.use_kms_encryption ? aws_kms_key.db[0].arn : null

  tags = merge(
    var.tags,
    {
      Name = "${var.environment}-${var.db_name}-credentials"
    }
  )
}

resource "aws_secretsmanager_secret_version" "db" {
  secret_id = aws_secretsmanager_secret.db.id
  secret_string = jsonencode({
    username = var.db_username
    password = random_password.db.result
    engine   = var.engine
    host     = aws_db_instance.main.address
    port     = var.db_port
    dbname   = var.db_name
  })
}

# RDS Instance
resource "aws_db_instance" "main" {
  identifier = "${var.environment}-${var.db_name}"

  engine         = var.engine
  engine_version = var.engine_version
  instance_class = var.instance_class

  allocated_storage     = var.allocated_storage
  max_allocated_storage = var.max_allocated_storage
  storage_type          = var.storage_type
  storage_encrypted     = true
  kms_key_id            = var.use_kms_encryption ? aws_kms_key.db[0].arn : null

  db_name  = var.db_name
  username = var.db_username
  password = random_password.db.result
  port     = var.db_port

  vpc_security_group_ids = [aws_security_group.db.id]
  db_subnet_group_name   = aws_db_subnet_group.main.name
  parameter_group_name   = aws_db_parameter_group.main.name

  backup_retention_period = var.backup_retention_period
  backup_window           = var.backup_window
  maintenance_window      = var.maintenance_window

  multi_az               = var.multi_az
  publicly_accessible    = false
  skip_final_snapshot    = var.environment != "prod"
  final_snapshot_identifier = var.environment == "prod" ? "${var.environment}-${var.db_name}-final-snapshot-${formatdate("YYYYMMDDhhmmss", timestamp())}" : null
  deletion_protection       = var.environment == "prod"

  performance_insights_enabled          = var.performance_insights_enabled
  performance_insights_retention_period = var.performance_insights_enabled ? 7 : null
  performance_insights_kms_key_id       = var.performance_insights_enabled && var.use_kms_encryption ? aws_kms_key.db[0].arn : null

  enabled_cloudwatch_logs_exports = var.enabled_cloudwatch_logs_exports
  monitoring_interval             = var.monitoring_interval
  monitoring_role_arn             = var.monitoring_interval > 0 ? aws_iam_role.rds_monitoring[0].arn : null

  apply_immediately = var.apply_immediately

  tags = merge(
    var.tags,
    {
      Name = "${var.environment}-${var.db_name}"
    }
  )

  depends_on = [aws_cloudwatch_log_group.db]
}

# CloudWatch Log Groups for RDS
resource "aws_cloudwatch_log_group" "db" {
  for_each = toset(var.enabled_cloudwatch_logs_exports)

  name              = "/aws/rds/instance/${var.environment}-${var.db_name}/${each.value}"
  retention_in_days = var.log_retention_days

  tags = merge(
    var.tags,
    {
      Name = "/aws/rds/instance/${var.environment}-${var.db_name}/${each.value}"
    }
  )
}

# IAM Role for Enhanced Monitoring
resource "aws_iam_role" "rds_monitoring" {
  count = var.monitoring_interval > 0 ? 1 : 0

  name = "${var.environment}-${var.db_name}-monitoring-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "monitoring.rds.amazonaws.com"
        }
      }
    ]
  })

  tags = merge(
    var.tags,
    {
      Name = "${var.environment}-${var.db_name}-monitoring-role"
    }
  )
}

resource "aws_iam_role_policy_attachment" "rds_monitoring" {
  count = var.monitoring_interval > 0 ? 1 : 0

  role       = aws_iam_role.rds_monitoring[0].name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonRDSEnhancedMonitoringRole"
}