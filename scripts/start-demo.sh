#!/usr/bin/env bash

# Guided launcher for the WordPress Terraform demo.
# This script chooses a project environment and runs its startup workflow.
# It writes an ignored terraform.tfvars file locally, then runs Terraform.
# It never asks for AWS access keys; use an AWS CLI profile or AWS SSO instead.
# AWS Account has to be signed in locally in the shell.

set -euo pipefail

# Find project root for reference to run commands
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

# Sets terminal text color, with a reset back to original color
GREEN="$(printf '\033[32m')"
RED="$(printf '\033[31m')"
RESET="$(printf '\033[0m')"

# Helper function to set default input or use new input for parameter
prompt_default() {
  local label="$1"
  local default="$2"
  local value

  read -r -p "$label [$default]: " value
  echo "${value:-$default}"
}

# Helper function that hides password inputed for over-the-shoulder protection
prompt_secret() {
  local label="$1"
  local value

  read -r -s -p "$label: " value
  echo >&2
  echo "$value"
}

# Helper function that cleans input to insert into .tfvars files so that special characters don't break runtime
hcl_string() {
  local value="$1"

  value="${value//\\/\\\\}"
  value="${value//\"/\\\"}"
  value="${value//$'\n'/\\n}"
  value="${value//$'\r'/}"
  echo "\"$value\""
}

# Helper function that simplifies naming convetions for internal file reference
slugify() {
  echo "$1" \
    | tr '[:upper:]' '[:lower:]' \
    | sed -E 's/[^a-z0-9]+/-/g; s/^-+//; s/-+$//' \
    | cut -c 1-32
}

# Helper function that checks a command is available on the local machine to continue running the script
require_command() {
  local command_name="$1"

  if ! command -v "$command_name" >/dev/null 2>&1; then
    echo "${RED}[missing]${RESET} Required command not found: $command_name"
    exit 1 # Breaks out of script with an error
  fi

  echo "${GREEN}[ok]${RESET} $command_name is installed"
}

# Checks to make sure all required commands are installed on system before committing to script
run_local_preflight() {
  echo "Running local workstation preflight checks..."

  require_command terraform
  require_command aws
  require_command zip
  require_command curl
  require_command openssl

  echo "${GREEN}[ok]${RESET} Local workstation preflight checks passed"
  echo
}

# After bulding EC2, a curl request pings index.php of the wordpress root to establish whether the EC2 is ready.
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

# Establishes which env the user is trying to make from a set of known envs: wp-lite, wp-rds, and wp-mig.
# Doing so would set what Terraform path would be chosen to build a distinct list of AWS resources
choose_environment() {
  local selected_environment

  echo "Choose a demo path:"
  echo "  wp-lite  - active low-cost EC2 + local MariaDB demo"
  echo "  wp-rds   - active EC2 + private RDS MySQL + S3 backup bucket demo"
  echo "  wp-mig   - reserved for the future WordPress migration workflow"
  echo

  selected_environment="$(prompt_default "Environment: wp-lite, wp-rds, or wp-mig" "wp-lite")"

  case "$selected_environment" in
    wp-lite | wp-rds | wp-mig)
      ENVIRONMENT="$selected_environment"
      ;;
    *)
      echo "Environment must be wp-lite, wp-rds, or wp-mig." >&2
      exit 1
      ;;
  esac
}

# Displays information for placeholder environments that are not active yet.
explain_reserved_environment() {
  local environment="$1"

  echo
  echo "The $environment branch is recognized, but it is not active yet."
  echo "Planned purpose: prepare future WordPress migration and rehosting workflows."
  echo "Current recommendation: run ./scripts/prepare-migration.sh or ./scripts/check-migration-readiness.sh for migration planning."

  echo
  echo "No Terraform was initialized, planned, applied, or destroyed."
}

# Checks for required installs to make the chosen env work
run_wordpress_env_preflight() {
  local environment="$1"
  local aws_identity
  local ssh_confirm

  echo
  echo "Running $environment AWS and project preflight checks..."

  if [ ! -d "$ENV_DIR" ]; then
    echo "Environment directory does not exist: $ENV_DIR"
    exit 1
  fi
  echo "${GREEN}[ok]${RESET} Terraform environment folder found"

  if [ ! -d "$WEBSITE_SOURCE" ]; then
    echo "Static website folder does not exist: $WEBSITE_SOURCE"
    exit 1
  fi

  if [ ! -f "$WEBSITE_SOURCE/index.html" ]; then
    echo "Static website folder must contain an index.html file: $WEBSITE_SOURCE"
    exit 1
  fi
  echo "${GREEN}[ok]${RESET} Static demo website folder found"

  if ! AWS_ACCOUNT_ID="$(aws sts get-caller-identity --profile "$AWS_PROFILE_NAME" --query 'Account' --output text 2>/dev/null)"; then
    echo
    echo "AWS profile '$AWS_PROFILE_NAME' is not authenticated."
    echo "For SSO, run: aws configure sso"
    echo "Then authenticate with: aws sso login --profile $AWS_PROFILE_NAME"
    echo "For standard profiles, run: aws configure --profile $AWS_PROFILE_NAME"
    exit 1
  fi
  aws_identity="$(aws sts get-caller-identity --profile "$AWS_PROFILE_NAME" --query 'Arn' --output text 2>/dev/null)"
  echo "${GREEN}[ok]${RESET} AWS profile is authenticated"
  echo "     Account: $AWS_ACCOUNT_ID"
  echo "     ARN: $aws_identity"

  if [ "$KEY_NAME" = "replace-with-your-key-pair" ]; then
    echo
    echo "Replace the default EC2 key pair placeholder before deploying."
    echo "Create or choose an EC2 key pair in AWS region $AWS_REGION, then rerun this script."
    exit 1
  fi

  if ! aws ec2 describe-key-pairs \
    --profile "$AWS_PROFILE_NAME" \
    --region "$AWS_REGION" \
    --key-names "$KEY_NAME" >/dev/null 2>&1; then
    echo
    echo "EC2 key pair '$KEY_NAME' was not found in region '$AWS_REGION'."
    echo "Key pairs are region-specific, so confirm the AWS region and key pair name match."
    exit 1
  fi
  echo "${GREEN}[ok]${RESET} EC2 key pair exists in $AWS_REGION"

  if [ "$ALLOWED_SSH_CIDR" = "0.0.0.0/0" ]; then
    echo
    echo "Security warning: SSH is open to 0.0.0.0/0."
    echo "For a real demo, prefer your own IP address in CIDR format, such as 203.0.113.10/32."
    echo "${RED}You can leave SSH open to the internet for testing, but you should later change the EC2 security group settings to prevent random login attempts.${RESET}"
    read -r -p "Continue with SSH open to the internet? Type yes to continue: " ssh_confirm
    if [ "$ssh_confirm" != "yes" ]; then
      echo "Preflight cancelled before Terraform ran."
      exit 0
    fi
  fi

  echo "${GREEN}[ok]${RESET} $environment AWS and project preflight checks passed"
}

validate_wp_rds_inputs() {
  if [[ ! "$DB_USERNAME" =~ ^[A-Za-z][A-Za-z0-9]{0,15}$ ]]; then
    echo
    echo "RDS database username must start with a letter, use only letters and numbers, and be 16 characters or fewer."
    echo "Example: wpadmin"
    exit 1
  fi

  if [ "${#DB_PASSWORD}" -lt 8 ] || [ "${#DB_PASSWORD}" -gt 41 ]; then
    echo
    echo "RDS database password must be between 8 and 41 characters."
    exit 1
  fi

  if [[ "$DB_PASSWORD" == *"/"* || "$DB_PASSWORD" == *"\""* || "$DB_PASSWORD" == *"@"* ]]; then
    echo
    echo "RDS database password cannot contain /, double quote, or @ characters."
    exit 1
  fi

  if [[ ! "$BACKUP_BUCKET_NAME" =~ ^[a-z0-9][a-z0-9.-]{1,61}[a-z0-9]$ ]]; then
    echo
    echo "S3 backup bucket names must be 3-63 characters and use lowercase letters, numbers, dots, or hyphens."
    exit 1
  fi
}

# Setting variables for the user to input, to then call Terraform and build the stack in AWS.
deploy_wordpress_environment() {
  local environment="$1"
  local default_db_username
  local default_backup_bucket_name

  echo "The default flow uses WordPress at / and the static demo site at /demo/."
  if [ "$environment" = "wp-rds" ]; then
    echo "wp-rds also creates a private RDS MySQL database and an S3 bucket reserved for backups."
    echo "${RED}Cost note: wp-rds costs more than wp-lite because RDS runs as a separate managed database.${RESET}"
  fi
  echo

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
  ENV_DIR="$ROOT_DIR/terraform/environments/$environment"
  TFVARS_FILE="$ENV_DIR/terraform.tfvars"

  run_wordpress_env_preflight "$environment"

  PROJECT_SLUG="$(slugify "$SITE_TITLE")"
  if [ -z "$PROJECT_SLUG" ]; then
    PROJECT_SLUG="wordpress-demo"
  fi

  PROJECT_NAME="$(prompt_default "Terraform project/resource name" "${environment}-${PROJECT_SLUG}")"
  DB_NAME="$(prompt_default "WordPress database name" "wordpress")"
  if [ "$environment" = "wp-rds" ]; then
    default_db_username="wpadmin"
  else
    default_db_username="wordpress_user"
  fi
  DB_USERNAME="$(prompt_default "WordPress database username" "$default_db_username")"
  WP_ADMIN_USER="$(prompt_default "WordPress admin username" "demo_admin")"
  WP_ADMIN_EMAIL="$(prompt_default "WordPress admin email" "admin@example.com")"

  if [ "$environment" = "wp-rds" ]; then
    default_backup_bucket_name="${PROJECT_NAME}-backups-${AWS_REGION}-${AWS_ACCOUNT_ID}"
    BACKUP_BUCKET_NAME="$(prompt_default "Globally unique S3 backup bucket name" "$default_backup_bucket_name")"
  fi

  GENERATED_DB_PASSWORD="$(openssl rand -base64 24 | tr -d '/+=' | cut -c 1-24)"
  GENERATED_WP_ADMIN_PASSWORD="$(openssl rand -base64 24 | tr -d '/+=' | cut -c 1-24)"

  DB_PASSWORD="$(prompt_secret "Database password for WordPress-to-MySQL connection (leave blank to generate one)")"
  DB_PASSWORD="${DB_PASSWORD:-$GENERATED_DB_PASSWORD}"
  WP_ADMIN_PASSWORD="$(prompt_secret "WordPress admin password for browser login (leave blank to generate one)")"
  WP_ADMIN_PASSWORD="${WP_ADMIN_PASSWORD:-$GENERATED_WP_ADMIN_PASSWORD}"

  if [ "$environment" = "wp-rds" ]; then
    validate_wp_rds_inputs
  fi

  GENERATED_DIR="$ROOT_DIR/.generated"
  SITE_ARCHIVE="$GENERATED_DIR/${environment}-${PROJECT_SLUG}-site.zip"

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

  if [ "$environment" = "wp-rds" ]; then
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
}

# START OF SCRIPT
cat << 'EOF'
                          ____ __                     __     _      
 _      __ ____          / __// /____ _ ____ _ _____ / /_   (_)____ 
| | /| / // __ \ ______ / /_ / // __ `// __ `// ___// __ \ / // __ \
| |/ |/ // /_/ //_____// __// // /_/ // /_/ /(__  )/ / / // // /_/ /
|__/|__// .___/       /_/  /_/ \__,_/ \__, //____//_/ /_//_// .___/ 
       /_/                           /____/                /_/        
                                         
EOF

echo "WordPress Flagship Demo Launcher"
echo
echo "This script chooses a project environment and runs its startup workflow."
echo "Use an AWS CLI profile or AWS SSO. Do not paste AWS access keys here."
echo

run_local_preflight
choose_environment

case "$ENVIRONMENT" in
  wp-lite | wp-rds)
    deploy_wordpress_environment "$ENVIRONMENT"
    ;;
  wp-mig)
    explain_reserved_environment "$ENVIRONMENT"
    ;;
esac
