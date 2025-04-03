# Infrastructure as Code with Terraform

A comprehensive AWS infrastructure setup using Terraform, following best practices for scalable, secure, and maintainable cloud architecture.

## ✨ Developed by Sarper ✨

---

![DevOps Pipeline](https://img.shields.io/badge/DevOps-Pipeline-blue)
![Kubernetes](https://img.shields.io/badge/Kubernetes-Ready-brightgreen)
![Terraform](https://img.shields.io/badge/Infrastructure-Terraform-purple)
![Monitoring](https://img.shields.io/badge/Monitoring-Prometheus-orange)


## Architecture

This project implements a multi-tier AWS architecture with VPC networking, auto-scaling application servers, managed database services, and comprehensive monitoring - all defined as infrastructure as code using Terraform.

## Features

- Multi-environment infrastructure (dev, staging, production)
- Modular design for reusability and maintainability
- Network setup with public and private subnets
- Auto-scaling application infrastructure
- Managed database services
- Monitoring and logging
- Security best practices
- State management with remote backend

## Project Structure

```
├── environments/
│   ├── dev/
│   ├── staging/
│   └── prod/
├── modules/
│   ├── networking/
│   ├── compute/
│   ├── database/
│   ├── security/
│   ├── monitoring/
│   └── storage/
├── scripts/
└── docs/
```

## Prerequisites

- AWS CLI configured with appropriate permissions
- Terraform v1.0.0 or newer
- S3 bucket for Terraform state (optional)
- DynamoDB table for state locking (optional)

## Getting Started

### Initialize the Project

```bash
# Clone the repository
git clone https://github.com/yourusername/terraform-aws-infrastructure.git
cd terraform-aws-infrastructure

# Initialize Terraform
cd environments/dev
terraform init
```

### Deploy Infrastructure

```bash
# Plan the deployment
terraform plan -out=tfplan

# Apply the changes
terraform apply tfplan
```

## Module Documentation

### Networking Module

Creates a VPC with public and private subnets across multiple availability zones, NAT gateways, and route tables.

### Compute Module

Sets up EC2 instances, Auto Scaling Groups, and Load Balancers for application hosting.

### Database Module

Provisions RDS instances or Aurora clusters with appropriate security groups and parameter groups.

### Security Module

Implements IAM roles, security groups, and KMS keys following the principle of least privilege.

### Monitoring Module

Sets up CloudWatch dashboards, alarms, and log groups for comprehensive monitoring.

### Storage Module

Creates S3 buckets, EFS file systems, and other storage resources with appropriate access controls.

## Best Practices

- Use remote state with locking
- Implement a CI/CD pipeline for infrastructure changes
- Use variables and locals for configuration
- Follow a consistent naming convention
- Tag all resources appropriately
- Use modules for reusable components
- Keep sensitive data in AWS Secrets Manager or Parameter Store

## Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

## License

This project is licensed under the MIT License - see the LICENSE file for details.