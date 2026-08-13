#!/usr/bin/env bash

# Read-only AWS resource discovery for WordPress Flagship tags.
# This script does not delete, modify, terminate, or detach anything.

set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=scripts/lib/project-paths.sh
source "$SCRIPT_DIR/lib/project-paths.sh"
PROJECT_ROOT="$(resolve_project_root "$SCRIPT_DIR" "$SCRIPT_DIR/..")"
# shellcheck source=scripts/lib/aws-tags.sh
source "$(project_path "scripts/lib/aws-tags.sh")"

AWS_PROFILE_NAME="${AWS_PROFILE:-default}"
AWS_REGION="${AWS_REGION:-us-east-1}"
COMMAND="list"
ARCHITECTURE=""
DEPLOYMENT=""

usage() {
  cat <<USAGE
Usage: ./scripts/resources.sh COMMAND [options]

Commands:
  list          List tagged WordPress Flagship resources.
  deployments   List discovered deployments.
  exists        Check whether a deployment already has tagged resources.

Options:
  --architecture NAME   Filter by wp-lite, wp-rds, or wp-mig.
  --deployment NAME     Filter by deployment identifier.
  --profile NAME        AWS CLI profile. Default: AWS_PROFILE or default.
  --region REGION       AWS region. Default: AWS_REGION or us-east-1.
  -h, --help            Show this help.

Examples:
  ./scripts/resources.sh list
  ./scripts/resources.sh list --architecture wp-lite
  ./scripts/resources.sh list --architecture wp-lite --deployment wp-lite-test
  ./scripts/resources.sh deployments --architecture wp-lite
  ./scripts/resources.sh exists --architecture wp-lite --deployment wp-lite-test
USAGE
}

validate_architecture() {
  local architecture="$1"

  case "$architecture" in
    ""|wp-lite|wp-rds|wp-mig) ;;
    *)
      echo "Architecture must be wp-lite, wp-rds, or wp-mig."
      exit 1
      ;;
  esac
}

validate_deployment() {
  local deployment="$1"

  if [ -n "$deployment" ] && [[ ! "$deployment" =~ ^[a-z0-9][a-z0-9-]{1,62}[a-z0-9]$ ]]; then
    echo "Deployment must be lowercase kebab-case, 3-64 characters."
    exit 1
  fi
}

build_tag_filter_array() {
  TAG_FILTERS=()
  while IFS= read -r filter; do
    TAG_FILTERS+=(--tag-filters "$filter")
  done < <(tag_filter_args "$ARCHITECTURE" "$DEPLOYMENT")
}

print_context() {
  echo "Project: $WORDPRESS_FLAGSHIP_PROJECT_TAG"
  echo "AWS profile: $AWS_PROFILE_NAME"
  echo "AWS region: $AWS_REGION"
  [ -n "$ARCHITECTURE" ] && echo "Architecture: $ARCHITECTURE"
  [ -n "$DEPLOYMENT" ] && echo "Deployment: $DEPLOYMENT"
  echo
}

list_resources() {
  build_tag_filter_array
  print_context

  aws resourcegroupstaggingapi get-resources \
    --profile "$AWS_PROFILE_NAME" \
    --region "$AWS_REGION" \
    "${TAG_FILTERS[@]}" \
    --query "ResourceTagMappingList[].{
      Service: ResourceARN,
      Component: $(tag_value_query Component),
      Architecture: $(tag_value_query Architecture),
      Deployment: $(tag_value_query Deployment),
      Name: $(tag_value_query Name)
    }" \
    --output table

  echo
  echo "Note: Resource Groups Tagging API does not show every AWS supporting object."
  echo "Use Terraform outputs/state for the active deployment and tags for account-wide discovery."
}

list_deployments() {
  build_tag_filter_array
  print_context

  aws resourcegroupstaggingapi get-resources \
    --profile "$AWS_PROFILE_NAME" \
    --region "$AWS_REGION" \
    "${TAG_FILTERS[@]}" \
    --query "sort_by(ResourceTagMappingList[].{
      Architecture: $(tag_value_query Architecture),
      Deployment: $(tag_value_query Deployment)
    }, &Deployment)" \
    --output text \
    | awk 'NF == 2 && !seen[$1 "|" $2]++ { printf "%-12s %s\n", $1, $2 }'
}

deployment_exists() {
  if [ -z "$ARCHITECTURE" ] || [ -z "$DEPLOYMENT" ]; then
    echo "exists requires --architecture and --deployment."
    exit 1
  fi

  build_tag_filter_array
  local count
  count="$(aws resourcegroupstaggingapi get-resources \
    --profile "$AWS_PROFILE_NAME" \
    --region "$AWS_REGION" \
    "${TAG_FILTERS[@]}" \
    --query 'length(ResourceTagMappingList)' \
    --output text)"

  if [ "$count" -gt 0 ]; then
    echo "WARN: Deployment already has $count tagged resource(s)."
    echo "Project=$WORDPRESS_FLAGSHIP_PROJECT_TAG Architecture=$ARCHITECTURE Deployment=$DEPLOYMENT"
    return 0
  fi

  echo "OK: No tagged resources found for this deployment identity."
}

if [ "$#" -gt 0 ]; then
  case "$1" in
    list|deployments|exists)
      COMMAND="$1"
      shift
      ;;
  esac
fi

while [ "$#" -gt 0 ]; do
  case "$1" in
    --architecture)
      ARCHITECTURE="$2"
      shift 2
      ;;
    --deployment)
      DEPLOYMENT="$2"
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
      echo "Unknown option: $1"
      usage
      exit 1
      ;;
  esac
done

validate_architecture "$ARCHITECTURE"
validate_deployment "$DEPLOYMENT"
aws_identity_check "$AWS_PROFILE_NAME" "$AWS_REGION"

case "$COMMAND" in
  list) list_resources ;;
  deployments) list_deployments ;;
  exists) deployment_exists ;;
  *)
    echo "Unknown command: $COMMAND"
    usage
    exit 1
    ;;
esac
