#!/usr/bin/env bash

# Local-only readiness helper for future WordPress migration work.
# This script does not call AWS and does not move client data.

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

check_command() {
  local command_name="$1"

  if command -v "$command_name" >/dev/null 2>&1; then
    echo "[ok] $command_name is installed"
  else
    echo "[todo] Install $command_name before migration work"
  fi
}

echo "WordPress Migration Readiness Check"
echo
echo "This is a planning helper only. Do not place client secrets or exports in Git."
echo

check_command terraform
check_command aws
check_command mysql
check_command rsync
check_command zip
check_command unzip

echo
echo "Project folders:"
echo "[ok] Migration guide: $ROOT_DIR/docs/migration-guide.md"
echo "[ok] wp-mig scaffold: $ROOT_DIR/terraform/environments/wp-mig"
echo "[ok] Generated migration plans: $ROOT_DIR/.generated/migrations"
echo
echo "Next planning step:"
echo "  ./scripts/prepare-migration.sh"
