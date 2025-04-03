#!/bin/bash

# Script to apply Terraform changes

# Set default environment if not provided
ENV=${1:-dev}

# Validate environment
if [[ "$ENV" != "dev" && "$ENV" != "staging" && "$ENV" != "prod" ]]; then
  echo "Error: Environment must be one of: dev, staging, prod"
  exit 1
fi

echo "Applying Terraform changes for $ENV environment..."

# Change to the environment directory
cd "$(dirname "$0")/../environments/$ENV" || {
  echo "Error: Could not change to directory ../environments/$ENV"
  exit 1
}

# Initialize Terraform
echo "Initializing Terraform..."
terraform init || {
  echo "Error: Terraform initialization failed"
  exit 1
}

# Validate Terraform configuration
echo "Validating Terraform configuration..."
terraform validate || {
  echo "Error: Terraform validation failed"
  exit 1
}

# Create a plan
echo "Creating Terraform plan..."
terraform plan -out=tfplan || {
  echo "Error: Terraform plan creation failed"
  exit 1
}

# Ask for confirmation before applying
read -p "Do you want to apply these changes? (y/n): " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
  echo "Terraform apply cancelled"
  exit 0
fi

# Apply the plan
echo "Applying Terraform plan..."
terraform apply tfplan || {
  echo "Error: Terraform apply failed"
  exit 1
}

# Clean up the plan file
rm -f tfplan

echo "Terraform apply completed successfully for $ENV environment!"