#!/usr/bin/env bash

# Shared read-only tag helpers for WordPress Flagship AWS discovery scripts.
# These helpers never delete or modify AWS resources.

WORDPRESS_FLAGSHIP_PROJECT_TAG="wordpress-flagship"

tag_filter_args() {
  local architecture="${1:-}"
  local deployment="${2:-}"

  printf '%s\n' "Key=Project,Values=$WORDPRESS_FLAGSHIP_PROJECT_TAG"

  if [ -n "$architecture" ]; then
    printf '%s\n' "Key=Architecture,Values=$architecture"
  fi

  if [ -n "$deployment" ]; then
    printf '%s\n' "Key=Deployment,Values=$deployment"
  fi
}

aws_identity_check() {
  local profile_name="$1"
  local region="$2"

  if ! aws sts get-caller-identity --profile "$profile_name" --region "$region" >/dev/null 2>&1; then
    echo "AWS profile '$profile_name' is not authenticated."
    echo "Use AWS SSO or an AWS CLI profile. Do not paste AWS access keys into scripts."
    return 1
  fi
}

tag_value_query() {
  local tag_name="$1"

  printf 'Tags[?Key==`%s`].Value | [0]' "$tag_name"
}
