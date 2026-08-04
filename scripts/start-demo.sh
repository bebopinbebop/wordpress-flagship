#!/usr/bin/env bash

# Guided launcher for the WordPress Terraform demo.
# It writes an ignored terraform.tfvars file locally, then runs Terraform.
# It never asks for AWS access keys; use an AWS CLI profile or AWS SSO instead.

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

prompt_default() {
  local label="$1"
  local default="$2"
  local value

  read -r -p "$label [$default]: " value
  echo "${value:-$default}"
}

prompt_secret() {
  local label="$1"
  local value

  read -r -s -p "$label: " value
  echo
  echo "$value"
}

slugify() {
  echo "$1" \
    | tr '[:upper:]' '[:lower:]' \
    | sed -E 's/[^a-z0-9]+/-/g; s/^-+//; s/-+$//' \
    | cut -c 1-32
}

require_command() {
  local command_name="$1"

  if ! command -v "$command_name" >/dev/null 2>&1; then
    echo "Missing required command: $command_name"
    exit 1
  fi
}

echo "WordPress Flagship Demo Launcher"
echo
echo "This script creates local Terraform variables and deploys a demo site."
echo "Use an AWS CLI profile or AWS SSO. Do not paste AWS access keys here."
echo

require_command terraform
require_command aws

ENVIRONMENT="$(prompt_default "Environment: dev-lite or dev-rds" "dev-lite")"
if [ "$ENVIRONMENT" != "dev-lite" ] && [ "$ENVIRONMENT" != "dev-rds" ]; then
  echo "Environment must be dev-lite or dev-rds."
  exit 1
fi

SITE_TITLE="$(prompt_default "Website display name" "Cloud WordPress Demo")"
AWS_PROFILE_NAME="$(prompt_default "AWS CLI profile name" "default")"
AWS_REGION="$(prompt_default "AWS region" "us-east-1")"
KEY_NAME="$(prompt_default "Existing EC2 key pair name" "replace-with-your-key-pair")"
ALLOWED_SSH_CIDR="$(prompt_default "SSH allowed CIDR" "0.0.0.0/0")"
INSTANCE_TYPE="$(prompt_default "EC2 instance type" "t3.micro")"

PROJECT_SLUG="$(slugify "$SITE_TITLE")"
if [ -z "$PROJECT_SLUG" ]; then
  PROJECT_SLUG="wordpress-demo"
fi

PROJECT_NAME="$(prompt_default "Terraform project/resource name" "wp-${ENVIRONMENT}-${PROJECT_SLUG}")"
DB_NAME="$(prompt_default "WordPress database name" "wordpress")"
DB_USERNAME="$(prompt_default "WordPress database username" "wordpress_user")"

if command -v openssl >/dev/null 2>&1; then
  GENERATED_DB_PASSWORD="$(openssl rand -base64 24 | tr -d '/+=' | cut -c 1-24)"
else
  GENERATED_DB_PASSWORD="CHANGE_ME_SET_A_LOCAL_SECRET"
fi

DB_PASSWORD="$(prompt_secret "Database password (leave blank to generate one)")"
DB_PASSWORD="${DB_PASSWORD:-$GENERATED_DB_PASSWORD}"

ENV_DIR="$ROOT_DIR/terraform/environments/$ENVIRONMENT"
TFVARS_FILE="$ENV_DIR/terraform.tfvars"

if [ ! -d "$ENV_DIR" ]; then
  echo "Environment directory does not exist: $ENV_DIR"
  exit 1
fi

if ! aws sts get-caller-identity --profile "$AWS_PROFILE_NAME" >/dev/null 2>&1; then
  echo
  echo "AWS profile '$AWS_PROFILE_NAME' is not authenticated."
  echo "For SSO, run: aws configure sso"
  echo "Then authenticate with: aws sso login --profile $AWS_PROFILE_NAME"
  echo "For standard profiles, run: aws configure --profile $AWS_PROFILE_NAME"
  exit 1
fi

echo
echo "Writing local Terraform variables to $TFVARS_FILE"
cat > "$TFVARS_FILE" <<VARS
aws_region       = "$AWS_REGION"
project_name     = "$PROJECT_NAME"
allowed_ssh_cidr = "$ALLOWED_SSH_CIDR"
instance_type    = "$INSTANCE_TYPE"
key_name         = "$KEY_NAME"
site_title       = "$SITE_TITLE"
db_name          = "$DB_NAME"
db_username      = "$DB_USERNAME"
db_password      = "$DB_PASSWORD"
VARS

if [ "$ENVIRONMENT" = "dev-rds" ]; then
  BACKUP_BUCKET_NAME="$(prompt_default "Globally unique S3 backup bucket name" "${PROJECT_NAME}-backups-${AWS_REGION}")"
  cat >> "$TFVARS_FILE" <<VARS
backup_bucket_name = "$BACKUP_BUCKET_NAME"
VARS
fi

echo
echo "Initializing Terraform..."
cd "$ENV_DIR"
AWS_PROFILE="$AWS_PROFILE_NAME" terraform init

echo
echo "Planning Terraform changes..."
AWS_PROFILE="$AWS_PROFILE_NAME" terraform plan

echo
read -r -p "Apply these changes and create AWS resources? Type yes to continue: " CONFIRM
if [ "$CONFIRM" != "yes" ]; then
  echo "Apply cancelled. Your local terraform.tfvars file was left in place for review."
  exit 0
fi

echo
echo "Applying Terraform..."
AWS_PROFILE="$AWS_PROFILE_NAME" terraform apply -auto-approve

echo
echo "Demo deployment complete."
echo
terraform output
echo
echo "Open the wordpress_url output in your browser."
echo "The instance may need a few minutes to finish installing packages after Terraform completes."

