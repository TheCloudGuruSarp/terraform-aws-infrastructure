#!/bin/bash

# Script to initialize the Terraform backend resources

# Set default environment if not provided
ENV=${1:-dev}

# Validate environment
if [[ "$ENV" != "dev" && "$ENV" != "staging" && "$ENV" != "prod" ]]; then
  echo "Error: Environment must be one of: dev, staging, prod"
  exit 1
fi

echo "Initializing Terraform backend for $ENV environment..."

# Set variables
BUCKET_NAME="terraform-state-bucket-$ENV"
DYNAMODB_TABLE="terraform-locks-$ENV"
REGION="us-west-2"

# Check if bucket exists
if aws s3api head-bucket --bucket "$BUCKET_NAME" 2>/dev/null; then
  echo "Bucket $BUCKET_NAME already exists"
else
  echo "Creating S3 bucket: $BUCKET_NAME"
  aws s3api create-bucket \
    --bucket "$BUCKET_NAME" \
    --region "$REGION" \
    --create-bucket-configuration LocationConstraint="$REGION"

  # Enable versioning
  echo "Enabling versioning on bucket: $BUCKET_NAME"
  aws s3api put-bucket-versioning \
    --bucket "$BUCKET_NAME" \
    --versioning-configuration Status=Enabled

  # Enable encryption
  echo "Enabling encryption on bucket: $BUCKET_NAME"
  aws s3api put-bucket-encryption \
    --bucket "$BUCKET_NAME" \
    --server-side-encryption-configuration '{"Rules": [{"ApplyServerSideEncryptionByDefault": {"SSEAlgorithm": "AES256"}}]}'

  # Block public access
  echo "Blocking public access on bucket: $BUCKET_NAME"
  aws s3api put-public-access-block \
    --bucket "$BUCKET_NAME" \
    --public-access-block-configuration '{"BlockPublicAcls": true, "IgnorePublicAcls": true, "BlockPublicPolicy": true, "RestrictPublicBuckets": true}'
fi

# Check if DynamoDB table exists
if aws dynamodb describe-table --table-name "$DYNAMODB_TABLE" --region "$REGION" 2>/dev/null; then
  echo "DynamoDB table $DYNAMODB_TABLE already exists"
else
  echo "Creating DynamoDB table: $DYNAMODB_TABLE"
  aws dynamodb create-table \
    --table-name "$DYNAMODB_TABLE" \
    --attribute-definitions AttributeName=LockID,AttributeType=S \
    --key-schema AttributeName=LockID,KeyType=HASH \
    --billing-mode PAY_PER_REQUEST \
    --region "$REGION"

  # Wait for table to be created
  echo "Waiting for DynamoDB table to be created..."
  aws dynamodb wait table-exists \
    --table-name "$DYNAMODB_TABLE" \
    --region "$REGION"
fi

echo "Terraform backend initialization complete for $ENV environment!"
echo "S3 Bucket: $BUCKET_NAME"
echo "DynamoDB Table: $DYNAMODB_TABLE"
echo "Region: $REGION"

echo "\nYou can now run 'terraform init' in the $ENV environment directory."
