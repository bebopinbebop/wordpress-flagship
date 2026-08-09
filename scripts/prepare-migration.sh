#!/usr/bin/env bash

# Creates a local migration checklist for a client WordPress rehosting project.
# This script does not download client data or store secrets.

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
OUTPUT_DIR="$ROOT_DIR/.generated/migrations"

prompt_default() {
  local label="$1"
  local default="$2"
  local value

  read -r -p "$label [$default]: " value
  echo "${value:-$default}"
}

slugify() {
  echo "$1" \
    | tr '[:upper:]' '[:lower:]' \
    | sed -E 's/[^a-z0-9]+/-/g; s/^-+//; s/-+$//' \
    | cut -c 1-48
}

echo "WordPress Migration Prep"
echo
echo "This creates a local checklist only. Do not place client secrets or exports in Git."
echo

CLIENT_NAME="$(prompt_default "Client or project name" "sample-client")"
CURRENT_DOMAIN="$(prompt_default "Current domain" "example.com")"
TARGET_ENV="$(prompt_default "Target environment" "wp-rds")"
PROJECT_SLUG="$(slugify "$CLIENT_NAME")"

mkdir -p "$OUTPUT_DIR"
PLAN_FILE="$OUTPUT_DIR/${PROJECT_SLUG:-sample-client}-migration-plan.md"

cat > "$PLAN_FILE" <<PLAN
# WordPress Migration Plan: $CLIENT_NAME

## Source

- Current domain: $CURRENT_DOMAIN
- Current host:
- WordPress version:
- PHP version:
- Database size:
- Uploads size:
- Active theme:
- Critical plugins:
- DNS provider:
- Email provider:

## Target

- Terraform environment: $TARGET_ENV
- AWS region:
- Project name:
- Instance type:
- Database mode:
- Backup plan:

## Pre-Migration Checklist

- [ ] Confirm admin access to current WordPress.
- [ ] Confirm hosting or SFTP/SSH access.
- [ ] Confirm database export access.
- [ ] Confirm DNS access.
- [ ] Confirm plugin licenses.
- [ ] Lower DNS TTL.
- [ ] Create AWS target environment with Terraform.
- [ ] Confirm target WordPress loads.

## Migration Checklist

- [ ] Export database.
- [ ] Copy wp-content/uploads.
- [ ] Copy active theme.
- [ ] Copy required plugins.
- [ ] Import database into target.
- [ ] Update wp-config.php.
- [ ] Run domain search-replace if needed.
- [ ] Flush permalinks.
- [ ] Test homepage and key pages.
- [ ] Test forms, media, login, and admin.

## Cutover Checklist

- [ ] Point DNS to AWS target.
- [ ] Verify HTTP/HTTPS.
- [ ] Verify redirects.
- [ ] Verify admin login.
- [ ] Ask client for approval.
- [ ] Keep old host available during rollback window.

## Rollback

- Old host URL:
- DNS rollback steps:
- Backup location:

PLAN

echo "Created migration checklist:"
echo "$PLAN_FILE"

