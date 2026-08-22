#!/usr/bin/env bash

# Read-only source preflight for the first supported migration path:
# wp-lite -> wp-mig. This proves WordPress exists; Apache alone is not enough.

set -Eeuo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
LIB_DIR="$(cd -- "$SCRIPT_DIR/../lib" && pwd)"
# shellcheck source=scripts/lib/project-paths.sh
source "$LIB_DIR/project-paths.sh"
PROJECT_ROOT="$(resolve_project_root "$SCRIPT_DIR" "$SCRIPT_DIR/../..")"
# shellcheck source=scripts/lib/migration-common.sh
source "$(project_path "scripts/lib/migration-common.sh")"

SOURCE_ENV="$MIGRATION_SOURCE_ARCHITECTURE_DEFAULT"
SOURCE_DEPLOYMENT=""
SOURCE_SSH_USER="ubuntu"
SOURCE_SSH_KEY=""
WORDPRESS_PATH="$MIGRATION_WORDPRESS_PATH_DEFAULT"
AWS_PROFILE_NAME="${AWS_PROFILE:-default}"
AWS_REGION="${AWS_REGION:-us-east-1}"

usage() {
  cat <<USAGE
Usage: ./scripts/migration/source-preflight.sh [options]

Options:
  --source-env ENV          Source Terraform environment. Default: wp-lite.
  --source-deployment NAME  Expected source deployment name. Optional safety check.
  --ssh-user USER           Source SSH user. Default: ubuntu.
  --ssh-key PATH            SSH private key used to reach the source EC2 instance.
  --wp-path PATH            WordPress path on source EC2. Default: /var/www/html.
  --profile NAME            AWS CLI profile used for Terraform/AWS context.
  --region REGION           AWS region. Default: AWS_REGION or us-east-1.
  -h, --help                Show this help.

Example:
  ./scripts/migration/source-preflight.sh --source-env wp-lite --ssh-key ~/.ssh/wp-key.pem
USAGE
}

ssh_source() {
  ssh "${SSH_BASE_ARGS[@]}" "$SOURCE_SSH_USER@$SOURCE_HOST" "$@"
}

check_expected_deployment() {
  local resolved_deployment="$1"

  if [ -n "$SOURCE_DEPLOYMENT" ] && [ "$SOURCE_DEPLOYMENT" != "$resolved_deployment" ]; then
    migration_fail "SOURCE_PREFLIGHT" "Expected source deployment '$SOURCE_DEPLOYMENT' but Terraform resolved '$resolved_deployment'"
  fi
}

run_source_preflight() {
  local env_dir
  local resolved_deployment
  local instance_id
  local source_url
  local wp_version
  local db_name
  local db_host
  local disk_report

  migration_info "Checking local tools"
  migration_require_command terraform
  migration_require_command aws
  migration_require_command ssh
  migration_require_command awk
  migration_require_command sed
  migration_require_command gzip
  migration_require_command sha256sum

  if aws sts get-caller-identity --profile "$AWS_PROFILE_NAME" --region "$AWS_REGION" >/dev/null 2>&1; then
    migration_ok "AWS profile is authenticated"
  else
    migration_fail "SOURCE_PREFLIGHT" "AWS profile '$AWS_PROFILE_NAME' is not authenticated"
  fi

  env_dir="$(terraform_environment_dir "$SOURCE_ENV")"
  [ -d "$env_dir" ] || migration_fail "SOURCE_PREFLIGHT" "Terraform environment not found: $env_dir"
  [ -f "$env_dir/main.tf" ] || migration_fail "SOURCE_PREFLIGHT" "Terraform environment has no main.tf: $env_dir"
  migration_ok "Source Terraform environment exists: $SOURCE_ENV"

  resolved_deployment="$(migration_resolve_deployment "$SOURCE_ENV")"
  [ -n "$resolved_deployment" ] || migration_fail "SOURCE_PREFLIGHT" "Could not resolve source deployment from Terraform output or tfvars"
  check_expected_deployment "$resolved_deployment"
  migration_ok "Source deployment resolved: $resolved_deployment"

  instance_id="$(migration_terraform_output "$SOURCE_ENV" "instance_id")"
  [ -n "$instance_id" ] || migration_fail "SOURCE_PREFLIGHT" "Could not read source instance_id from Terraform outputs"
  migration_ok "Source EC2 instance output found: $instance_id"

  SOURCE_HOST="$(migration_source_host "$SOURCE_ENV")"
  [ -n "$SOURCE_HOST" ] || migration_fail "SOURCE_PREFLIGHT" "Could not resolve source EC2 public IP/DNS from Terraform outputs"
  migration_ok "Source EC2 host resolved: $SOURCE_HOST"

  source_url="$(migration_terraform_output "$SOURCE_ENV" "wordpress_url")"
  if [ -n "$source_url" ]; then
    migration_ok "Source URL output found: $source_url"
  else
    migration_warn "Source URL output was not found"
  fi

  migration_ssh_base_args "$SOURCE_SSH_KEY"
  migration_info "Checking SSH reachability"
  ssh_source "true" >/dev/null || migration_fail "SOURCE_PREFLIGHT" "SSH failed for $SOURCE_SSH_USER@$SOURCE_HOST"
  migration_ok "SSH connection works"

  migration_info "Checking WordPress-specific files on source"
  ssh_source "test -d '$WORDPRESS_PATH'" || migration_fail "SOURCE_PREFLIGHT" "WordPress path does not exist: $WORDPRESS_PATH"
  ssh_source "test -f '$WORDPRESS_PATH/wp-load.php'" || migration_fail "SOURCE_PREFLIGHT" "wp-load.php missing. Apache may work, but WordPress is not installed at $WORDPRESS_PATH"
  ssh_source "test -d '$WORDPRESS_PATH/wp-admin'" || migration_fail "SOURCE_PREFLIGHT" "wp-admin directory missing at $WORDPRESS_PATH"
  ssh_source "test -d '$WORDPRESS_PATH/wp-content'" || migration_fail "SOURCE_PREFLIGHT" "wp-content directory missing at $WORDPRESS_PATH"
  ssh_source "test -f '$WORDPRESS_PATH/wp-config.php'" || migration_fail "SOURCE_PREFLIGHT" "wp-config.php missing at $WORDPRESS_PATH"
  migration_ok "WordPress file markers exist"

  if ssh_source "test -d '$WORDPRESS_PATH/wp-content/plugins'"; then
    migration_ok "plugins directory exists"
  else
    migration_warn "plugins directory not found"
  fi

  if ssh_source "test -d '$WORDPRESS_PATH/wp-content/themes'"; then
    migration_ok "themes directory exists"
  else
    migration_warn "themes directory not found"
  fi

  if ssh_source "test -d '$WORDPRESS_PATH/wp-content/uploads'"; then
    migration_ok "uploads directory exists"
  else
    migration_warn "uploads directory not found"
  fi

  migration_info "Checking source WordPress and database with WP-CLI"
  ssh_source "command -v wp >/dev/null" || migration_fail "SOURCE_PREFLIGHT" "WP-CLI is not installed on source EC2"
  migration_ok "WP-CLI exists on source"

  if ssh_source "command -v mysql >/dev/null || command -v mariadb >/dev/null" >/dev/null; then
    migration_ok "Source database client exists"
  else
    migration_warn "No mysql/mariadb client found on source; WP-CLI database checks may still work"
  fi

  ssh_source "sudo -n -u www-data wp --path='$WORDPRESS_PATH' core is-installed" >/dev/null \
    || migration_fail "SOURCE_PREFLIGHT" "WP-CLI reports WordPress core is not installed"
  migration_ok "WP-CLI confirms WordPress core is installed"

  ssh_source "sudo -n -u www-data wp --path='$WORDPRESS_PATH' db check" >/dev/null \
    || migration_fail "SOURCE_PREFLIGHT" "WP-CLI database check failed"
  migration_ok "WP-CLI database check passed"

  wp_version="$(ssh_source "sudo -n -u www-data wp --path='$WORDPRESS_PATH' core version" 2>/dev/null || true)"
  if [ -n "$wp_version" ]; then
    migration_ok "WordPress version: $wp_version"
  else
    migration_warn "Could not read WordPress version"
  fi

  db_name="$(ssh_source "sudo -n -u www-data wp --path='$WORDPRESS_PATH' config get DB_NAME" 2>/dev/null || true)"
  db_host="$(ssh_source "sudo -n -u www-data wp --path='$WORDPRESS_PATH' config get DB_HOST" 2>/dev/null || true)"
  if [ -n "$db_name" ]; then
    migration_ok "Source database name detected"
  else
    migration_warn "Could not read source DB_NAME"
  fi

  if [ -n "$db_host" ]; then
    migration_ok "Source database host detected: $db_host"
  else
    migration_warn "Could not read source DB_HOST"
  fi

  migration_info "Checking source disk space"
  disk_report="$(ssh_source "df -Pk /tmp '$WORDPRESS_PATH' | awk 'NR > 1 { print \$6 \":\" \$4 \"KB available\" }'" 2>/dev/null || true)"
  if [ -n "$disk_report" ]; then
    while IFS= read -r disk_line; do
      echo "     $disk_line"
    done <<< "$disk_report"
    migration_ok "Disk space report collected"
  else
    migration_warn "Could not collect disk space report"
  fi

  echo
  migration_ok "SOURCE_PREFLIGHT completed for $SOURCE_ENV/$resolved_deployment"
}

while [ "$#" -gt 0 ]; do
  case "$1" in
    --source-env)
      SOURCE_ENV="$2"
      shift 2
      ;;
    --source-deployment)
      SOURCE_DEPLOYMENT="$2"
      shift 2
      ;;
    --ssh-user)
      SOURCE_SSH_USER="$2"
      shift 2
      ;;
    --ssh-key)
      SOURCE_SSH_KEY="$2"
      shift 2
      ;;
    --wp-path)
      WORDPRESS_PATH="$2"
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
    -h|--help)
      usage
      exit 0
      ;;
    *)
      migration_fail "ARGUMENTS" "Unknown option: $1"
      ;;
  esac
done

case "$SOURCE_ENV" in
  wp-lite) ;;
  *) migration_fail "ARGUMENTS" "This first source preflight supports wp-lite only" ;;
esac

if [ -n "$SOURCE_SSH_KEY" ] && [ ! -f "$SOURCE_SSH_KEY" ]; then
  migration_fail "SOURCE_PREFLIGHT" "SSH key not found: $SOURCE_SSH_KEY"
fi

run_source_preflight
