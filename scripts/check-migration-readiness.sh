#!/usr/bin/env bash

# Migration preflight worker for wp-mig.
# This script is intentionally read-only: it does not export, import, delete, or
# transfer client data. It verifies that the local workstation, source WordPress
# path, and Terraform target look ready for a later migration step.

set -Eeuo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=scripts/lib/project-paths.sh
source "$SCRIPT_DIR/lib/project-paths.sh"
PROJECT_ROOT="$(resolve_project_root "$SCRIPT_DIR" "$SCRIPT_DIR/..")"
ENV_ROOT="$(project_path "terraform/environments")"

AWS_PROFILE_NAME="${AWS_PROFILE:-default}"
AWS_REGION="us-east-1"
TARGET_ENV="wp-mig"
SOURCE_PATH=""
SOURCE_URL=""
TARGET_SSH=""
SSH_KEY_PATH=""

GREEN="$(printf '\033[32m')"
YELLOW="$(printf '\033[33m')"
RED="$(printf '\033[31m')"
RESET="$(printf '\033[0m')"

usage() {
  cat <<USAGE
Usage: ./scripts/check-migration-readiness.sh [options]

Options:
  --target-env ENV       Terraform target environment. Default: wp-mig.
  --profile NAME         AWS CLI profile. Default: AWS_PROFILE or default.
  --region REGION        AWS region. Default: us-east-1.
  --source-path PATH     Local source WordPress root to inspect.
  --source-url URL       Source WordPress URL for planning/reporting.
  --target-ssh USER@HOST Optional SSH target for reachability checks.
  --ssh-key PATH         Optional SSH private key path for target checks.
  -h, --help             Show this help.

Examples:
  ./scripts/check-migration-readiness.sh --target-env wp-mig --profile my-sso
  ./scripts/check-migration-readiness.sh --source-path /var/www/html --source-url https://example.com
USAGE
}

info() {
  echo "[INFO] $*"
}

ok() {
  echo "${GREEN}[OK]${RESET} $*"
}

warn() {
  echo "${YELLOW}[WARN]${RESET} $*"
}

fail() {
  echo "${RED}[ERROR]${RESET} $*"
  exit 1
}

check_command() {
  local command_name="$1"
  local required="${2:-required}"

  if command -v "$command_name" >/dev/null 2>&1; then
    ok "$command_name is installed"
    return 0
  fi

  if [ "$required" = "optional" ]; then
    warn "$command_name is not installed"
    return 0
  fi

  fail "Required command not found: $command_name"
}

check_one_of() {
  local label="$1"
  shift

  local command_name
  for command_name in "$@"; do
    if command -v "$command_name" >/dev/null 2>&1; then
      ok "$label available through $command_name"
      return 0
    fi
  done

  fail "Missing required tool for $label. Tried: $*"
}

terraform_output_optional() {
  local env_dir="$1"
  local output_name="$2"

  (cd "$env_dir" && terraform output -raw "$output_name" 2>/dev/null) || true
}

check_local_tools() {
  info "Checking local migration tools"
  check_command terraform
  check_command aws
  check_command ssh
  check_command scp
  check_command tar
  check_command gzip
  check_command curl
  check_command rsync optional
  check_command jq optional
  check_command wp optional
  check_one_of "MySQL client" mysql mariadb
  check_one_of "database dump utility" mysqldump mariadb-dump
}

check_aws_auth() {
  info "Checking AWS authentication"

  if ! aws sts get-caller-identity --profile "$AWS_PROFILE_NAME" --region "$AWS_REGION" >/tmp/wp-mig-aws-identity.json 2>/tmp/wp-mig-aws-error.log; then
    cat /tmp/wp-mig-aws-error.log >&2
    fail "AWS profile '$AWS_PROFILE_NAME' is not authenticated. Use AWS SSO or an AWS CLI profile; do not paste access keys into scripts."
  fi

  local account
  local arn
  account="$(aws sts get-caller-identity --profile "$AWS_PROFILE_NAME" --query 'Account' --output text)"
  arn="$(aws sts get-caller-identity --profile "$AWS_PROFILE_NAME" --query 'Arn' --output text)"
  ok "AWS profile is authenticated"
  echo "     Account: $account"
  echo "     ARN: $arn"
}

check_target_environment() {
  local env_dir="$ENV_ROOT/$TARGET_ENV"

  info "Checking Terraform target environment: $TARGET_ENV"

  [ -d "$env_dir" ] || fail "Terraform environment not found: $env_dir"
  [ -f "$env_dir/main.tf" ] || fail "Terraform environment has no main.tf: $env_dir"
  ok "Terraform environment files exist"

  if [ ! -f "$env_dir/terraform.tfstate" ]; then
    warn "No local terraform.tfstate found for $TARGET_ENV. Provision the target before restore/validation."
    return 0
  fi

  local wordpress_url
  local instance_id
  local migration_bucket
  wordpress_url="$(terraform_output_optional "$env_dir" wordpress_url)"
  instance_id="$(terraform_output_optional "$env_dir" instance_id)"
  migration_bucket="$(terraform_output_optional "$env_dir" migration_bucket_name)"

  [ -n "$wordpress_url" ] && ok "Target WordPress URL output found: $wordpress_url" || warn "wordpress_url output not available yet"
  [ -n "$instance_id" ] && ok "Target EC2 instance output found: $instance_id" || warn "instance_id output not available yet"
  [ -n "$migration_bucket" ] && ok "Migration S3 bucket output found: $migration_bucket" || warn "migration_bucket_name output not available yet"
}

check_source_wordpress() {
  if [ -z "$SOURCE_PATH" ]; then
    warn "No --source-path provided. Skipping source WordPress filesystem and WP-CLI checks."
    return 0
  fi

  info "Checking source WordPress path: $SOURCE_PATH"
  [ -d "$SOURCE_PATH" ] || fail "Source path does not exist: $SOURCE_PATH"
  [ -f "$SOURCE_PATH/wp-config.php" ] || fail "Source path does not contain wp-config.php"
  [ -d "$SOURCE_PATH/wp-content" ] || fail "Source path does not contain wp-content"
  [ -d "$SOURCE_PATH/wp-content/uploads" ] && ok "wp-content/uploads exists" || warn "wp-content/uploads was not found"
  [ -d "$SOURCE_PATH/wp-content/themes" ] && ok "wp-content/themes exists" || warn "wp-content/themes was not found"
  [ -d "$SOURCE_PATH/wp-content/plugins" ] && ok "wp-content/plugins exists" || warn "wp-content/plugins was not found"

  if command -v wp >/dev/null 2>&1; then
    if wp --path="$SOURCE_PATH" core is-installed >/dev/null 2>&1; then
      ok "WP-CLI can read the source WordPress installation"
    else
      warn "WP-CLI could not confirm WordPress core is installed at the source path"
    fi

    if wp --path="$SOURCE_PATH" db check >/dev/null 2>&1; then
      ok "WP-CLI verified source database authentication"
    else
      warn "WP-CLI database check failed. Confirm source database credentials before export."
    fi
  else
    warn "WP-CLI is not installed locally, so source database authentication was not checked"
  fi
}

check_source_url() {
  if [ -z "$SOURCE_URL" ]; then
    warn "No --source-url provided. Skipping HTTP source check."
    return 0
  fi

  info "Checking source URL: $SOURCE_URL"
  if curl -fsS --connect-timeout 5 --max-time 15 "$SOURCE_URL" >/dev/null; then
    ok "Source URL responded successfully"
  else
    warn "Source URL did not respond successfully. This may be expected for private or staging sources."
  fi
}

check_target_ssh() {
  if [ -z "$TARGET_SSH" ]; then
    warn "No --target-ssh provided. Skipping SSH reachability check."
    return 0
  fi

  local ssh_args=(-o BatchMode=yes -o ConnectTimeout=8)
  if [ -n "$SSH_KEY_PATH" ]; then
    [ -f "$SSH_KEY_PATH" ] || fail "SSH key path does not exist: $SSH_KEY_PATH"
    ssh_args+=(-i "$SSH_KEY_PATH")
    ok "SSH key exists"
  fi

  info "Checking SSH reachability: $TARGET_SSH"
  if ssh "${ssh_args[@]}" "$TARGET_SSH" "command -v wp >/dev/null && wp --info >/dev/null" >/dev/null 2>&1; then
    ok "Target SSH works and WP-CLI is available on the target"
  else
    warn "Target SSH/WP-CLI check failed. Confirm key, security group, username, and instance bootstrap status."
  fi
}

while [ "$#" -gt 0 ]; do
  case "$1" in
    --target-env)
      TARGET_ENV="$2"
      shift 2
      ;;
    --profile)
      AWS_PROFILE_NAME="$2"
      shift 2
      ;;
    --region)
      AWS_REGION="$2"
      shift 2
      ;;
    --source-path)
      SOURCE_PATH="$2"
      shift 2
      ;;
    --source-url)
      SOURCE_URL="$2"
      shift 2
      ;;
    --target-ssh)
      TARGET_SSH="$2"
      shift 2
      ;;
    --ssh-key)
      SSH_KEY_PATH="$2"
      shift 2
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      fail "Unknown option: $1"
      ;;
  esac
done

case "$TARGET_ENV" in
  wp-lite|wp-rds|wp-mig) ;;
  *) fail "Unsupported target environment: $TARGET_ENV" ;;
esac

echo "WordPress Migration Readiness Check"
echo
echo "This is a read-only preflight. It does not move client data and does not print secrets."
echo

check_local_tools
echo
check_aws_auth
echo
check_target_environment
echo
check_source_wordpress
echo
check_source_url
echo
check_target_ssh
echo
ok "Migration readiness checks completed"
