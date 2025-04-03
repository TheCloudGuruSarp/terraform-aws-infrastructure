provider "aws" {
  region = var.region
}

data "aws_caller_identity" "current" {}

locals {
  environment = "prod"
  common_tags = {
    Environment = local.environment
    Project     = var.project_name
    ManagedBy   = "Terraform"
    Owner       = "DevOps Team"
  }
}

# Networking
module "networking" {
  source = "../../modules/networking"

  environment         = local.environment
  vpc_cidr            = var.vpc_cidr
  availability_zones  = var.availability_zones
  public_subnets      = var.public_subnets
  private_subnets     = var.private_subnets
  single_nat_gateway  = false
  enable_flow_logs    = true
  tags                = local.common_tags
}

# Compute
module "compute" {
  source = "../../modules/compute"

  environment         = local.environment
  vpc_id              = module.networking.vpc_id
  public_subnet_ids   = module.networking.public_subnet_ids
  private_subnet_ids  = module.networking.private_subnet_ids
  ami_id              = var.ami_id
  instance_type       = "t3.medium"
  key_name            = var.key_name
  min_size            = 2
  max_size            = 10
  desired_capacity    = 4
  ssh_allowed_cidr_blocks = ["10.0.0.0/8"]
  certificate_arn     = var.certificate_arn
  alb_logs_bucket     = aws_s3_bucket.alb_logs.bucket
  region              = var.region
  account_id          = data.aws_caller_identity.current.account_id
  tags                = local.common_tags
}

# Database
module "database" {
  source = "../../modules/database"

  environment               = local.environment
  vpc_id                    = module.networking.vpc_id
  subnet_ids                = module.networking.private_subnet_ids
  allowed_security_group_ids = [module.compute.web_security_group_id]
  db_name                   = "appdb"
  db_username               = "dbadmin"
  instance_class            = "db.t3.large"
  allocated_storage         = 100
  max_allocated_storage     = 500
  multi_az                  = true
  performance_insights_enabled = true
  monitoring_interval       = 60
  backup_retention_period   = 30
  tags                      = local.common_tags
}

# S3 Bucket for ALB Logs
resource "aws_s3_bucket" "alb_logs" {
  bucket = "${local.environment}-${var.project_name}-alb-logs-${data.aws_caller_identity.current.account_id}"

  tags = merge(
    local.common_tags,
    {
      Name = "${local.environment}-alb-logs"
    }
  )
}

resource "aws_s3_bucket_lifecycle_configuration" "alb_logs" {
  bucket = aws_s3_bucket.alb_logs.id

  rule {
    id     = "log-expiration"
    status = "Enabled"

    expiration {
      days = 365
    }

    transition {
      days          = 30
      storage_class = "STANDARD_IA"
    }

    transition {
      days          = 90
      storage_class = "GLACIER"
    }
  }
}

resource "aws_s3_bucket_policy" "alb_logs" {
  bucket = aws_s3_bucket.alb_logs.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          AWS = "arn:aws:iam::${var.elb_account_id[var.region]}:root"
        }
        Action   = "s3:PutObject"
        Resource = "${aws_s3_bucket.alb_logs.arn}/*"
      },
      {
        Effect = "Allow"
        Principal = {
          Service = "delivery.logs.amazonaws.com"
        }
        Action   = "s3:PutObject"
        Resource = "${aws_s3_bucket.alb_logs.arn}/*"
        Condition = {
          StringEquals = {
            "s3:x-amz-acl" = "bucket-owner-full-control"
          }
        }
      },
      {
        Effect = "Allow"
        Principal = {
          Service = "delivery.logs.amazonaws.com"
        }
        Action   = "s3:GetBucketAcl"
        Resource = aws_s3_bucket.alb_logs.arn
      }
    ]
  })
}

# CloudWatch Dashboard
resource "aws_cloudwatch_dashboard" "main" {
  dashboard_name = "${local.environment}-dashboard"

  dashboard_body = jsonencode({
    widgets = [
      {
        type   = "metric"
        x      = 0
        y      = 0
        width  = 12
        height = 6
        properties = {
          metrics = [
            ["AWS/EC2", "CPUUtilization", "AutoScalingGroupName", module.compute.asg_name, { "stat" = "Average" }]
          ]
          view    = "timeSeries"
          stacked = false
          region  = var.region
          title   = "EC2 CPU Utilization"
          period  = 300
        }
      },
      {
        type   = "metric"
        x      = 12
        y      = 0
        width  = 12
        height = 6
        properties = {
          metrics = [
            ["AWS/RDS", "CPUUtilization", "DBInstanceIdentifier", module.database.db_instance_id, { "stat" = "Average" }]
          ]
          view    = "timeSeries"
          stacked = false
          region  = var.region
          title   = "RDS CPU Utilization"
          period  = 300
        }
      },
      {
        type   = "metric"
        x      = 0
        y      = 6
        width  = 12
        height = 6
        properties = {
          metrics = [
            ["AWS/ApplicationELB", "RequestCount", "LoadBalancer", module.compute.alb_id, { "stat" = "Sum" }]
          ]
          view    = "timeSeries"
          stacked = false
          region  = var.region
          title   = "ALB Request Count"
          period  = 300
        }
      },
      {
        type   = "metric"
        x      = 12
        y      = 6
        width  = 12
        height = 6
        properties = {
          metrics = [
            ["AWS/RDS", "DatabaseConnections", "DBInstanceIdentifier", module.database.db_instance_id, { "stat" = "Average" }]
          ]
          view    = "timeSeries"
          stacked = false
          region  = var.region
          title   = "RDS Connections"
          period  = 300
        }
      },
      {
        type   = "metric"
        x      = 0
        y      = 12
        width  = 12
        height = 6
        properties = {
          metrics = [
            ["AWS/ApplicationELB", "HTTPCode_Target_4XX_Count", "LoadBalancer", module.compute.alb_id, { "stat" = "Sum" }],
            ["AWS/ApplicationELB", "HTTPCode_Target_5XX_Count", "LoadBalancer", module.compute.alb_id, { "stat" = "Sum" }]
          ]
          view    = "timeSeries"
          stacked = false
          region  = var.region
          title   = "ALB Error Codes"
          period  = 300
        }
      },
      {
        type   = "metric"
        x      = 12
        y      = 12
        width  = 12
        height = 6
        properties = {
          metrics = [
            ["AWS/RDS", "FreeStorageSpace", "DBInstanceIdentifier", module.database.db_instance_id, { "stat" = "Average" }]
          ]
          view    = "timeSeries"
          stacked = false
          region  = var.region
          title   = "RDS Free Storage Space"
          period  = 300
        }
      }
    ]
  })
}

# CloudWatch Alarms
resource "aws_cloudwatch_metric_alarm" "high_cpu_web" {
  alarm_name          = "${local.environment}-high-cpu-web"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = "CPUUtilization"
  namespace           = "AWS/EC2"
  period              = 300
  statistic           = "Average"
  threshold           = 80
  alarm_description   = "This metric monitors EC2 CPU utilization"
  alarm_actions       = [aws_sns_topic.alerts.arn]
  ok_actions          = [aws_sns_topic.alerts.arn]

  dimensions = {
    AutoScalingGroupName = module.compute.asg_name
  }

  tags = local.common_tags
}

resource "aws_cloudwatch_metric_alarm" "high_cpu_db" {
  alarm_name          = "${local.environment}-high-cpu-db"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = "CPUUtilization"
  namespace           = "AWS/RDS"
  period              = 300
  statistic           = "Average"
  threshold           = 80
  alarm_description   = "This metric monitors RDS CPU utilization"
  alarm_actions       = [aws_sns_topic.alerts.arn]
  ok_actions          = [aws_sns_topic.alerts.arn]

  dimensions = {
    DBInstanceIdentifier = module.database.db_instance_id
  }

  tags = local.common_tags
}

# SNS Topic for Alerts
resource "aws_sns_topic" "alerts" {
  name = "${local.environment}-alerts"

  tags = local.common_tags
}