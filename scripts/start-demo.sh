#!/usr/bin/env bash

# Guided launcher for the WordPress Terraform demo.
# It writes an ignored terraform.tfvars file locally, then runs Terraform.
# It never asks for AWS access keys; use an AWS CLI profile or AWS SSO instead.
# AWS Account has to be signed in locally in the shell.

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
  echo >&2
  echo "$value"
}

hcl_string() {
  local value="$1"

  value="${value//\\/\\\\}"
  value="${value//\"/\\\"}"
  value="${value//$'\n'/\\n}"
  value="${value//$'\r'/}"
  echo "\"$value\""
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

wait_for_wordpress() {
  local url="$1"
  local admin_user="$2"
  local admin_password="$3"
  local max_attempts="${4:-80}"
  local sleep_seconds="${5:-15}"

  url="${url%/}"

  echo "Waiting for EC2 first-boot setup to finish..."
  echo "Do not worry if the browser fails during this step; Apache/PHP/WordPress may still be installing."
  echo "Checking $url/index.php every $sleep_seconds seconds for up to $max_attempts attempts."

  for attempt in $(seq 1 "$max_attempts"); do
    if curl -fsS --connect-timeout 5 --max-time 10 "$url/index.php" >/dev/null 2>&1; then
      echo
      echo "The site is ready. It is a good time to check the EC2 instance in your browser:"
      echo "  WordPress site: $url/"
      echo "  WordPress admin: $url/wp-admin/"
      echo "  Static infrastructure demo: $url/demo/"
      echo
      echo "WordPress admin login:"
      echo "  Username: $admin_user"
      echo "  Password: $admin_password"
      echo
      echo "Demo note: change this password inside WordPress before using the site for anything public."
      return 0
    fi

    printf 'Still waiting for WordPress... attempt %s/%s\r' "$attempt" "$max_attempts"
    sleep "$sleep_seconds"
  done

  echo
  echo "Terraform created the AWS resources, but WordPress did not answer before the wait timeout."
  echo "The instance may still be installing packages, especially on a small EC2 instance."
  echo "Try these URLs again in a few minutes:"
  echo "  $url/"
  echo "  $url/wp-admin/"
  echo "  $url/demo/"
  echo
  echo "For troubleshooting over SSH:"
  echo "  sudo tail -n 120 /var/log/wordpress-bootstrap.log"
  return 1
}

echo "WordPress Flagship Demo Launcher"
echo
echo "This script creates local Terraform variables and deploys a demo site."
echo "Use an AWS CLI profile or AWS SSO. Do not paste AWS access keys here."
echo

require_command terraform
require_command aws
require_command zip
require_command curl

echo "The default flow uses WordPress at / and the static demo site at /demo/."
echo

ENVIRONMENT="$(prompt_default "Environment: dev-lite or dev-rds" "dev-lite")"
if [ "$ENVIRONMENT" != "dev-lite" ] && [ "$ENVIRONMENT" != "dev-rds" ]; then
  echo "Environment must be dev-lite or dev-rds."
  exit 1
fi

SITE_TITLE="$(prompt_default "Website display name" "Cloud WordPress Demo")"
USE_CUSTOM_STATIC_SITE="$(prompt_default "Use a custom static demo folder instead of website/default-site? yes or no" "no")"
if [ "$USE_CUSTOM_STATIC_SITE" = "yes" ]; then
  WEBSITE_SOURCE="$(prompt_default "Custom static website folder path" "$ROOT_DIR/website/default-site")"
else
  WEBSITE_SOURCE="$ROOT_DIR/website/default-site"
fi
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
WP_ADMIN_USER="$(prompt_default "WordPress admin username" "demo_admin")"
WP_ADMIN_EMAIL="$(prompt_default "WordPress admin email" "admin@example.com")"

if command -v openssl >/dev/null 2>&1; then
  GENERATED_DB_PASSWORD="$(openssl rand -base64 24 | tr -d '/+=' | cut -c 1-24)"
  GENERATED_WP_ADMIN_PASSWORD="$(openssl rand -base64 24 | tr -d '/+=' | cut -c 1-24)"
else
  GENERATED_DB_PASSWORD="CHANGE_ME_SET_A_LOCAL_SECRET"
  GENERATED_WP_ADMIN_PASSWORD="CHANGE_ME_SET_A_LOCAL_SECRET"
fi

DB_PASSWORD="$(prompt_secret "Database password for WordPress-to-MySQL connection (leave blank to generate one)")"
DB_PASSWORD="${DB_PASSWORD:-$GENERATED_DB_PASSWORD}"
WP_ADMIN_PASSWORD="$(prompt_secret "WordPress admin password for browser login (leave blank to generate one)")"
WP_ADMIN_PASSWORD="${WP_ADMIN_PASSWORD:-$GENERATED_WP_ADMIN_PASSWORD}"

ENV_DIR="$ROOT_DIR/terraform/environments/$ENVIRONMENT"
TFVARS_FILE="$ENV_DIR/terraform.tfvars"

if [ ! -d "$ENV_DIR" ]; then
  echo "Environment directory does not exist: $ENV_DIR"
  exit 1
fi

if [ ! -d "$WEBSITE_SOURCE" ]; then
  echo "Static website folder does not exist: $WEBSITE_SOURCE"
  exit 1
fi

if [ ! -f "$WEBSITE_SOURCE/index.html" ]; then
  echo "Static website folder must contain an index.html file: $WEBSITE_SOURCE"
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

GENERATED_DIR="$ROOT_DIR/.generated"
SITE_ARCHIVE="$GENERATED_DIR/${ENVIRONMENT}-${PROJECT_SLUG}-site.zip"

mkdir -p "$GENERATED_DIR"
echo
echo "Packaging static website from $WEBSITE_SOURCE"
(
  cd "$WEBSITE_SOURCE"
  zip -qr "$SITE_ARCHIVE" .
)

echo
echo "Writing local Terraform variables to $TFVARS_FILE"
cat > "$TFVARS_FILE" <<VARS
aws_region        = $(hcl_string "$AWS_REGION")
project_name      = $(hcl_string "$PROJECT_NAME")
allowed_ssh_cidr  = $(hcl_string "$ALLOWED_SSH_CIDR")
instance_type     = $(hcl_string "$INSTANCE_TYPE")
key_name          = $(hcl_string "$KEY_NAME")
site_title        = $(hcl_string "$SITE_TITLE")
site_archive_path = $(hcl_string "$SITE_ARCHIVE")
db_name           = $(hcl_string "$DB_NAME")
db_username       = $(hcl_string "$DB_USERNAME")
db_password       = $(hcl_string "$DB_PASSWORD")
wp_admin_user     = $(hcl_string "$WP_ADMIN_USER")
wp_admin_email    = $(hcl_string "$WP_ADMIN_EMAIL")
wp_admin_password = $(hcl_string "$WP_ADMIN_PASSWORD")
VARS

if [ "$ENVIRONMENT" = "dev-rds" ]; then
  BACKUP_BUCKET_NAME="$(prompt_default "Globally unique S3 backup bucket name" "${PROJECT_NAME}-backups-${AWS_REGION}")"
  cat >> "$TFVARS_FILE" <<VARS
backup_bucket_name = $(hcl_string "$BACKUP_BUCKET_NAME")
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
  echo "Apply cancelled. No AWS resources were created."
  echo "Your local terraform.tfvars file was left in place for review."
  echo "Run ./scripts/start-demo.sh again and type yes at the final prompt to create EC2 and related resources."
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
WORDPRESS_URL="$(terraform output -raw wordpress_url 2>/dev/null || true)"
if [ -n "$WORDPRESS_URL" ]; then
  wait_for_wordpress "$WORDPRESS_URL" "$WP_ADMIN_USER" "$WP_ADMIN_PASSWORD" 80 15 || true
else
  echo "Open the wordpress_url output in your browser for WordPress."
  echo "Open wordpress_url/demo/ for the static infrastructure demo."
fi
