#!/usr/bin/env bash

# Shared helpers for the first WordPress migration workflow.
# The initial supported source path is wp-lite -> wp-mig.

# shellcheck disable=SC2034
MIGRATION_SOURCE_ARCHITECTURE_DEFAULT="wp-lite"
# shellcheck disable=SC2034
MIGRATION_TARGET_ARCHITECTURE_DEFAULT="wp-mig"
# shellcheck disable=SC2034
MIGRATION_WORDPRESS_PATH_DEFAULT="/var/www/html"

MIGRATION_GREEN="$(printf '\033[32m')"
MIGRATION_YELLOW="$(printf '\033[33m')"
MIGRATION_RED="$(printf '\033[31m')"
MIGRATION_BLUE="$(printf '\033[34m')"
MIGRATION_RESET="$(printf '\033[0m')"

migration_ok() {
  echo "${MIGRATION_GREEN}[OK]${MIGRATION_RESET} $*"
}

migration_warn() {
  echo "${MIGRATION_YELLOW}[WARN]${MIGRATION_RESET} $*"
}

migration_fail() {
  local stage="$1"
  shift

  echo "${MIGRATION_RED}[ERROR]${MIGRATION_RESET} $stage: $*" >&2
  exit 1
}

migration_info() {
  echo "${MIGRATION_BLUE}[INFO]${MIGRATION_RESET} $*"
}

migration_require_command() {
  local command_name="$1"

  if ! command -v "$command_name" >/dev/null 2>&1; then
    migration_fail "LOCAL_TOOLS" "Required command not found: $command_name"
  fi

  migration_ok "$command_name is installed"
}

migration_slugify() {
  echo "$1" \
    | tr '[:upper:]' '[:lower:]' \
    | sed -E 's/[^a-z0-9]+/-/g; s/^-+//; s/-+$//' \
    | cut -c 1-48
}

migration_timestamp_utc() {
  date -u +"%Y%m%dT%H%M%SZ"
}

migration_iso_utc() {
  date -u +"%Y-%m-%dT%H:%M:%SZ"
}

migration_terraform_output() {
  local env_name="$1"
  local output_name="$2"
  local env_dir

  env_dir="$(terraform_environment_dir "$env_name")"
  (cd "$env_dir" && terraform output -raw "$output_name" 2>/dev/null) || true
}

migration_resolve_deployment() {
  local env_name="$1"
  local deployment

  deployment="$(migration_terraform_output "$env_name" "deployment_name")"
  if [ -n "$deployment" ]; then
    echo "$deployment"
    return
  fi

  deployment="$(grep -E '^[[:space:]]*deployment_name[[:space:]]*=' "$(terraform_environment_dir "$env_name")/terraform.tfvars" 2>/dev/null \
    | head -n 1 \
    | awk -F '=' '{ value=$2; gsub(/^[[:space:]]+|[[:space:]]+$/, "", value); gsub(/^"|"$/, "", value); print value }')"
  if [ -n "$deployment" ]; then
    echo "$deployment"
    return
  fi

  grep -E '^[[:space:]]*project_name[[:space:]]*=' "$(terraform_environment_dir "$env_name")/terraform.tfvars" 2>/dev/null \
    | head -n 1 \
    | awk -F '=' '{ value=$2; gsub(/^[[:space:]]+|[[:space:]]+$/, "", value); gsub(/^"|"$/, "", value); print value }'
}

migration_build_id() {
  local source_deployment="$1"
  local target_deployment="$2"
  local timestamp="$3"
  local source_slug
  local target_slug

  source_slug="$(migration_slugify "$source_deployment")"
  target_slug="$(migration_slugify "$target_deployment")"
  echo "${source_slug:-source}-to-${target_slug:-target}-${timestamp}"
}

migration_artifact_dir() {
  local migration_id="$1"

  project_path ".generated/migrations/$migration_id"
}

migration_json_escape() {
  local value="$1"

  value="${value//\\/\\\\}"
  value="${value//\"/\\\"}"
  value="${value//$'\n'/\\n}"
  value="${value//$'\r'/}"
  printf '%s' "$value"
}

migration_ssh_base_args() {
  local ssh_key_path="$1"

  SSH_BASE_ARGS=(-o BatchMode=yes -o StrictHostKeyChecking=accept-new -o ConnectTimeout=10)
  if [ -n "$ssh_key_path" ]; then
    SSH_BASE_ARGS+=(-i "$ssh_key_path")
  fi
}

migration_source_host() {
  local source_env="$1"
  local host

  host="$(migration_terraform_output "$source_env" "wordpress_public_ip")"
  if [ -n "$host" ]; then
    echo "$host"
    return
  fi

  migration_terraform_output "$source_env" "wordpress_url" | sed -E 's#^https?://##; s#/.*$##'
}
