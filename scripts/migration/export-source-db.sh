#!/usr/bin/env bash

# First migration export stage for wp-lite -> wp-mig.
# Produces database.sql.gz, manifest.json, and checksums.sha256 only.

set -Eeuo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
LIB_DIR="$(cd -- "$SCRIPT_DIR/../lib" && pwd)"
# shellcheck source=scripts/lib/project-paths.sh
source "$LIB_DIR/project-paths.sh"
PROJECT_ROOT="$(resolve_project_root "$SCRIPT_DIR" "$SCRIPT_DIR/../..")"
# shellcheck source=scripts/lib/migration-common.sh
source "$(project_path "scripts/lib/migration-common.sh")"

SOURCE_ENV="$MIGRATION_SOURCE_ARCHITECTURE_DEFAULT"
TARGET_ENV="$MIGRATION_TARGET_ARCHITECTURE_DEFAULT"
SOURCE_DEPLOYMENT=""
TARGET_DEPLOYMENT=""
MIGRATION_ID=""
SOURCE_SSH_USER="ubuntu"
SOURCE_SSH_KEY=""
WORDPRESS_PATH="$MIGRATION_WORDPRESS_PATH_DEFAULT"
AWS_PROFILE_NAME="${AWS_PROFILE:-default}"
AWS_REGION="${AWS_REGION:-us-east-1}"

usage() {
  cat <<USAGE
Usage: ./scripts/migration/export-source-db.sh [options]

Options:
  --source-env ENV          Source Terraform environment. Default: wp-lite.
  --source-deployment NAME  Expected source deployment name. Optional safety check.
  --target-env ENV          Target Terraform environment for metadata. Default: wp-mig.
  --target-deployment NAME  Target deployment name for manifest/migration ID.
  --migration-id ID         Explicit migration ID. Optional.
  --ssh-user USER           Source SSH user. Default: ubuntu.
  --ssh-key PATH            SSH private key used to reach the source EC2 instance.
  --wp-path PATH            WordPress path on source EC2. Default: /var/www/html.
  --profile NAME            AWS CLI profile. Default: AWS_PROFILE or default.
  --region REGION           AWS region. Default: AWS_REGION or us-east-1.
  -h, --help                Show this help.

Example:
  ./scripts/migration/export-source-db.sh --ssh-key ~/.ssh/wp-key.pem

Output:
  .generated/migrations/<migration-id>/database.sql.gz
  .generated/migrations/<migration-id>/manifest.json
  .generated/migrations/<migration-id>/checksums.sha256
USAGE
}

ssh_source() {
  ssh "${SSH_BASE_ARGS[@]}" "$SOURCE_SSH_USER@$SOURCE_HOST" "$@"
}

run_preflight() {
  local args=(
    --source-env "$SOURCE_ENV"
    --ssh-user "$SOURCE_SSH_USER"
    --wp-path "$WORDPRESS_PATH"
    --profile "$AWS_PROFILE_NAME"
    --region "$AWS_REGION"
  )

  [ -n "$SOURCE_DEPLOYMENT" ] && args+=(--source-deployment "$SOURCE_DEPLOYMENT")
  [ -n "$SOURCE_SSH_KEY" ] && args+=(--ssh-key "$SOURCE_SSH_KEY")

  "$(project_path "scripts/migration/source-preflight.sh")" "${args[@]}"
}

resolve_migration_context() {
  local timestamp

  SOURCE_DEPLOYMENT_RESOLVED="$(migration_resolve_deployment "$SOURCE_ENV")"
  [ -n "$SOURCE_DEPLOYMENT_RESOLVED" ] || migration_fail "MIGRATION_ID" "Could not resolve source deployment"

  if [ -n "$SOURCE_DEPLOYMENT" ] && [ "$SOURCE_DEPLOYMENT" != "$SOURCE_DEPLOYMENT_RESOLVED" ]; then
    migration_fail "MIGRATION_ID" "Expected source deployment '$SOURCE_DEPLOYMENT' but resolved '$SOURCE_DEPLOYMENT_RESOLVED'"
  fi

  TARGET_DEPLOYMENT_RESOLVED="${TARGET_DEPLOYMENT:-}"
  if [ -z "$TARGET_DEPLOYMENT_RESOLVED" ]; then
    TARGET_DEPLOYMENT_RESOLVED="$(migration_resolve_deployment "$TARGET_ENV")"
  fi
  [ -n "$TARGET_DEPLOYMENT_RESOLVED" ] || TARGET_DEPLOYMENT_RESOLVED="$TARGET_ENV-target"

  timestamp="$(migration_timestamp_utc)"
  if [ -z "$MIGRATION_ID" ]; then
    MIGRATION_ID="$(migration_build_id "$SOURCE_DEPLOYMENT_RESOLVED" "$TARGET_DEPLOYMENT_RESOLVED" "$timestamp")"
  fi

  if [[ ! "$MIGRATION_ID" =~ ^[a-z0-9][a-z0-9-]{2,120}$ ]]; then
    migration_fail "MIGRATION_ID" "Migration ID must be lowercase kebab-case and safe for paths/S3 prefixes"
  fi

  ARTIFACT_DIR="$(migration_artifact_dir "$MIGRATION_ID")"
  DATABASE_ARTIFACT="$ARTIFACT_DIR/database.sql.gz"
  MANIFEST_FILE="$ARTIFACT_DIR/manifest.json"
  CHECKSUM_FILE="$ARTIFACT_DIR/checksums.sha256"
}

collect_source_metadata() {
  SOURCE_HOST="$(migration_source_host "$SOURCE_ENV")"
  [ -n "$SOURCE_HOST" ] || migration_fail "SOURCE_EXPORT" "Could not resolve source host"
  SOURCE_URL="$(migration_terraform_output "$SOURCE_ENV" "wordpress_url")"

  migration_ssh_base_args "$SOURCE_SSH_KEY"
  WORDPRESS_VERSION="$(ssh_source "sudo -n -u www-data wp --path='$WORDPRESS_PATH' core version" 2>/dev/null || true)"
  SOURCE_HOME_URL="$(ssh_source "sudo -n -u www-data wp --path='$WORDPRESS_PATH' option get home" 2>/dev/null || true)"
  SOURCE_SITE_URL="$(ssh_source "sudo -n -u www-data wp --path='$WORDPRESS_PATH' option get siteurl" 2>/dev/null || true)"
  PUBLISHED_POSTS="$(ssh_source "sudo -n -u www-data wp --path='$WORDPRESS_PATH' post list --post_status=publish --format=count" 2>/dev/null || true)"

  [ -n "$SOURCE_URL" ] || SOURCE_URL="$SOURCE_HOME_URL"
}

export_database() {
  local tmp_artifact

  mkdir -p "$ARTIFACT_DIR"
  tmp_artifact="$DATABASE_ARTIFACT.tmp"
  rm -f "$tmp_artifact"

  migration_info "Exporting source database to $DATABASE_ARTIFACT"
  if ssh_source "sudo -n -u www-data wp --quiet --path='$WORDPRESS_PATH' db export -" | gzip -c > "$tmp_artifact"; then
    mv "$tmp_artifact" "$DATABASE_ARTIFACT"
  else
    rm -f "$tmp_artifact"
    migration_fail "DATABASE_EXPORT" "wp db export failed over SSH"
  fi

  [ -s "$DATABASE_ARTIFACT" ] || migration_fail "DATABASE_EXPORT" "database.sql.gz was not created or is empty"
  gzip -t "$DATABASE_ARTIFACT" || migration_fail "DATABASE_EXPORT" "database.sql.gz failed gzip validation"

  if ! zgrep -Eiq -m 1 'wordpress|CREATE TABLE|INSERT INTO|-- MySQL dump|-- MariaDB dump' "$DATABASE_ARTIFACT"; then
    migration_fail "DATABASE_EXPORT" "database.sql.gz does not look like a plausible SQL export"
  fi

  DATABASE_SIZE_BYTES="$(wc -c < "$DATABASE_ARTIFACT" | tr -d ' ')"
  migration_ok "Database export created: $DATABASE_ARTIFACT ($DATABASE_SIZE_BYTES bytes)"
}

write_manifest() {
  local created_at

  created_at="$(migration_iso_utc)"
  cat > "$MANIFEST_FILE" <<JSON
{
  "migration_id": "$(migration_json_escape "$MIGRATION_ID")",
  "created_at": "$(migration_json_escape "$created_at")",
  "source_architecture": "$(migration_json_escape "$SOURCE_ENV")",
  "source_deployment": "$(migration_json_escape "$SOURCE_DEPLOYMENT_RESOLVED")",
  "target_architecture": "$(migration_json_escape "$TARGET_ENV")",
  "target_deployment": "$(migration_json_escape "$TARGET_DEPLOYMENT_RESOLVED")",
  "source_url": "$(migration_json_escape "$SOURCE_URL")",
  "source_home_url": "$(migration_json_escape "$SOURCE_HOME_URL")",
  "source_site_url": "$(migration_json_escape "$SOURCE_SITE_URL")",
  "wordpress_version": "$(migration_json_escape "$WORDPRESS_VERSION")",
  "published_posts": "$(migration_json_escape "$PUBLISHED_POSTS")",
  "database_artifact": "database.sql.gz",
  "database_size_bytes": $DATABASE_SIZE_BYTES,
  "wp_content_artifact": null,
  "artifact_stage": "database-export"
}
JSON

  migration_ok "Manifest written: $MANIFEST_FILE"
}

write_checksums() {
  (
    cd "$ARTIFACT_DIR"
    sha256sum database.sql.gz manifest.json > checksums.sha256
  )

  (cd "$ARTIFACT_DIR" && sha256sum -c checksums.sha256 >/dev/null) \
    || migration_fail "ARTIFACT_CHECKSUM" "Checksum verification failed"

  migration_ok "Checksums generated and verified: $CHECKSUM_FILE"
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
    --target-env)
      TARGET_ENV="$2"
      shift 2
      ;;
    --target-deployment)
      TARGET_DEPLOYMENT="$2"
      shift 2
      ;;
    --migration-id)
      MIGRATION_ID="$2"
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
  *) migration_fail "ARGUMENTS" "This first export supports wp-lite sources only" ;;
esac

case "$TARGET_ENV" in
  wp-mig) ;;
  *) migration_fail "ARGUMENTS" "This first export supports wp-mig targets only" ;;
esac

migration_require_command gzip
migration_require_command zgrep
migration_require_command sha256sum
migration_require_command ssh
migration_require_command terraform

run_preflight
resolve_migration_context
collect_source_metadata
export_database
write_manifest
write_checksums

echo
migration_ok "DATABASE_EXPORT completed"
echo "Migration ID: $MIGRATION_ID"
echo "Artifact directory: $ARTIFACT_DIR"
