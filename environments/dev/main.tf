provider "aws" {
  region = var.region
}

data "aws_caller_identity" "current" {}

locals {
  environment = "dev"
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
  single_nat_gateway  = true
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
  instance_type       = "t3.micro"
  key_name            = var.key_name
  min_size            = 1
  max_size            = 3
  desired_capacity    = 1
  ssh_allowed_cidr_blocks = ["10.0.0.0/8"]
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
  instance_class            = "db.t3.small"
  allocated_storage         = 20
  max_allocated_storage     = 100
  multi_az                  = false
  performance_insights_enabled = true
  monitoring_interval       = 60
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
      days = 90
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
      }
    ]
  })
}