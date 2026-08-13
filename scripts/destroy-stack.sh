#!/usr/bin/env bash

# Safe cleanup helper for WordPress Flagship environments.
# It prefers Terraform destroy so resources are removed in dependency order.
# AWS scans are read-only and help spot tagged resources that may still cost money.

set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=scripts/lib/project-paths.sh
source "$SCRIPT_DIR/lib/project-paths.sh"
PROJECT_ROOT="$(resolve_project_root "$SCRIPT_DIR" "$SCRIPT_DIR/..")"
ENV_ROOT="$(project_path "terraform/environments")"
# shellcheck source=scripts/lib/aws-tags.sh
source "$(project_path "scripts/lib/aws-tags.sh")"

AWS_PROFILE_NAME="${AWS_PROFILE:-default}"
AWS_REGION="us-east-1"
TARGET_ENVIRONMENT=""
TARGET_DEPLOYMENT=""
AUTO_APPROVE="false"
SCAN_ONLY="false"
DELETE_SNAPSHOTS="prompt"
DEPLOYMENT_KEYS=()
DEPLOYMENT_ENV_CHOICES=()
DEPLOYMENT_NAME_CHOICES=()
DEPLOYMENT_SOURCE_CHOICES=()
DEPLOYMENT_COUNT_CHOICES=()
DEPLOYMENT_COMPONENT_CHOICES=()

usage() {
  cat <<USAGE
Usage: ./scripts/destroy-stack.sh [options]

Options:
  --env ENV          Environment to destroy: wp-lite, wp-rds, wp-mig, or all.
                     If omitted, the script scans AWS and asks you to choose.
  --deployment NAME  Deployment tag to target when --env is provided.
  --profile NAME    AWS CLI profile to use. Default: AWS_PROFILE or default.
  --region REGION   AWS region to scan. Default: us-east-1.
  --yes             Skip confirmation prompts for Terraform destroy.
  --scan-only       Only scan AWS and Terraform state. Do not destroy anything.
  --delete-snapshots Delete matching manual RDS snapshots after Terraform destroy.
  --keep-snapshots   Leave matching manual RDS snapshots in place.
  -h, --help        Show this help.

Examples:
  ./scripts/destroy-stack.sh
  ./scripts/destroy-stack.sh --env wp-lite --deployment wp-lite-client-demo
  ./scripts/destroy-stack.sh --env wp-rds --profile my-sso
  ./scripts/destroy-stack.sh --env wp-mig --profile my-sso
  ./scripts/destroy-stack.sh --env all
  ./scripts/destroy-stack.sh --scan-only --profile my-sso

wp-rds/wp-mig cleanup:
  Terraform destroys the EC2 instance, RDS database, S3 bucket, IAM role/profile,
  VPC, subnets, route tables, internet gateway, and security groups that are in
  the local Terraform state. The S3 backup bucket is configured for demo cleanup
  with force_destroy so uploaded lab files do not block bucket deletion. Matching
  manual RDS snapshots are shown and can be deleted after confirmation.
USAGE
}

require_command() {
  local command_name="$1"

  if ! command -v "$command_name" >/dev/null 2>&1; then
    echo "Missing required command: $command_name"
    exit 1
  fi
}

read_tfvar() {
  local env_dir="$1"
  local key="$2"
  local tfvars_file="$env_dir/terraform.tfvars"

  if [ -f "$tfvars_file" ]; then
    awk -F '=' -v key="$key" '
      $1 ~ "^[[:space:]]*" key "[[:space:]]*$" {
        value=$2
        gsub(/^[[:space:]]+|[[:space:]]+$/, "", value)
        gsub(/^"|"$/, "", value)
        print value
        exit
      }
    ' "$tfvars_file"
  fi
}

project_name_for_env() {
  local env_name="$1"
  local env_dir="$ENV_ROOT/$env_name"
  local from_tfvars

  from_tfvars="$(read_tfvar "$env_dir" "project_name")"
  if [ -n "$from_tfvars" ]; then
    echo "$from_tfvars"
    return
  fi

  case "$env_name" in
    wp-lite) echo "wordpress-wp-lite" ;;
    wp-rds) echo "wordpress-wp-rds" ;;
    wp-mig) echo "wordpress-wp-mig" ;;
    *) echo "$env_name" ;;
  esac
}

deployment_name_for_env() {
  local env_name="$1"
  local env_dir="$ENV_ROOT/$env_name"
  local from_tfvars

  from_tfvars="$(read_tfvar "$env_dir" "deployment_name")"
  if [ -n "$from_tfvars" ]; then
    echo "$from_tfvars"
    return
  fi

  project_name_for_env "$env_name"
}

infer_env_from_project() {
  local project_name="$1"

  case "$project_name" in
    *wp-lite*) echo "wp-lite" ;;
    *wp-rds*) echo "wp-rds" ;;
    *wp-mig*) echo "wp-mig" ;;
    *) echo "" ;;
  esac
}

validate_environment() {
  local env_name="$1"

  case "$env_name" in
    "") ;;
    wp-lite|wp-rds|wp-mig|all) ;;
    *)
      echo "Unknown environment: $env_name"
      echo "Use wp-lite, wp-rds, wp-mig, or all."
      exit 1
      ;;
  esac
}

validate_deployment_name() {
  local deployment_name="$1"

  if [ -n "$deployment_name" ] && [[ ! "$deployment_name" =~ ^[a-z0-9][a-z0-9-]{1,62}[a-z0-9]$ ]]; then
    echo "Deployment must be lowercase kebab-case, 3-64 characters."
    exit 1
  fi
}

environments_to_process() {
  if [ "$TARGET_ENVIRONMENT" = "all" ]; then
    echo "wp-lite wp-rds wp-mig"
  else
    echo "$TARGET_ENVIRONMENT"
  fi
}

add_discovered_deployment() {
  local env_name="$1"
  local deployment_name="$2"
  local source="$3"
  local resource_count="${4:-0}"
  local components="${5:-unknown}"
  local existing
  local key

  [ -n "$env_name" ] || return 0
  [ -n "$deployment_name" ] || return 0
  key="$env_name|$deployment_name"

  for existing in "${DEPLOYMENT_KEYS[@]:-}"; do
    if [ "$existing" = "$key" ]; then
      return 0
    fi
  done

  DEPLOYMENT_KEYS+=("$key")
  DEPLOYMENT_ENV_CHOICES+=("$env_name")
  DEPLOYMENT_NAME_CHOICES+=("$deployment_name")
  DEPLOYMENT_SOURCE_CHOICES+=("$source")
  DEPLOYMENT_COUNT_CHOICES+=("$resource_count")
  DEPLOYMENT_COMPONENT_CHOICES+=("$components")
}

discover_local_projects() {
  local env_name
  local deployment_name

  for env_name in wp-lite wp-rds wp-mig; do
    deployment_name="$(deployment_name_for_env "$env_name")"
    if [ -f "$ENV_ROOT/$env_name/terraform.tfstate" ] || [ -f "$ENV_ROOT/$env_name/terraform.tfvars" ]; then
      add_discovered_deployment "$env_name" "$deployment_name" "local Terraform files" "local" "state"
    fi
  done
}

discover_tagged_projects() {
  local env_name
  local deployment_name
  local resource_count
  local components
  local deployments

  deployments="$(aws resourcegroupstaggingapi get-resources \
    --profile "$AWS_PROFILE_NAME" \
    --region "$AWS_REGION" \
    --tag-filters "Key=Project,Values=$WORDPRESS_FLAGSHIP_PROJECT_TAG" \
    --query 'ResourceTagMappingList[].[Tags[?Key==`Architecture`].Value | [0], Tags[?Key==`Deployment`].Value | [0], Tags[?Key==`Component`].Value | [0]]' \
    --output text 2>/dev/null \
    | awk '
      NF >= 2 && $1 != "None" && $2 != "None" {
        key=$1 "|" $2
        count[key]++
        if ($3 != "None" && components[key] !~ "(^|,)" $3 "(,|$)") {
          components[key] = components[key] ? components[key] "," $3 : $3
        }
      }
      END {
        for (key in count) {
          split(key, parts, "|")
          print parts[1] "\t" parts[2] "\t" count[key] "\t" components[key]
        }
      }
    ' || true)"

  while IFS=$'\t' read -r env_name deployment_name resource_count components; do
    [ -n "$env_name" ] || continue
    add_discovered_deployment "$env_name" "$deployment_name" "AWS structured tags" "$resource_count" "${components:-unknown}"
  done <<< "$deployments"
}

discover_snapshot_projects() {
  local snapshot_ids
  local snapshot_id
  local env_name
  local project_name

  snapshot_ids="$(aws rds describe-db-snapshots \
    --profile "$AWS_PROFILE_NAME" \
    --region "$AWS_REGION" \
    --snapshot-type manual \
    --query 'DBSnapshots[].DBSnapshotIdentifier' \
    --output text 2>/dev/null || true)"

  for snapshot_id in $snapshot_ids; do
    env_name="$(infer_env_from_project "$snapshot_id")"
    [ -n "$env_name" ] || continue
    project_name="$snapshot_id"
    project_name="${project_name%%-mysql*}"
    add_discovered_deployment "$env_name" "$project_name" "RDS snapshot name" "snapshot" "database"
  done
}

choose_project_interactively() {
  local index
  local selected
  local max_index

  DEPLOYMENT_KEYS=()
  DEPLOYMENT_ENV_CHOICES=()
  DEPLOYMENT_NAME_CHOICES=()
  DEPLOYMENT_SOURCE_CHOICES=()
  DEPLOYMENT_COUNT_CHOICES=()
  DEPLOYMENT_COMPONENT_CHOICES=()

  echo
  echo "Scanning AWS for live WordPress Flagship deployments..."
  discover_tagged_projects
  discover_snapshot_projects
  discover_local_projects

  if [ "${#DEPLOYMENT_NAME_CHOICES[@]}" -eq 0 ]; then
    echo "No wp-lite, wp-rds, or wp-mig deployments were discovered."
    echo "You can still run with an explicit environment, for example:"
    echo "  ./scripts/destroy-stack.sh --env wp-mig --deployment wp-mig-demo --profile $AWS_PROFILE_NAME --region $AWS_REGION"
    exit 1
  fi

  echo
  echo "Discovered cleanup targets:"
  printf '  %-4s %-8s %-34s %-9s %-24s %s\n' "No." "Arch" "Deployment" "Resources" "Components" "Source"
  for index in "${!DEPLOYMENT_NAME_CHOICES[@]}"; do
    printf '  %-4s %-8s %-34s %-9s %-24s %s\n' \
      "$((index + 1))" \
      "${DEPLOYMENT_ENV_CHOICES[$index]}" \
      "${DEPLOYMENT_NAME_CHOICES[$index]}" \
      "${DEPLOYMENT_COUNT_CHOICES[$index]}" \
      "${DEPLOYMENT_COMPONENT_CHOICES[$index]}" \
      "${DEPLOYMENT_SOURCE_CHOICES[$index]}"
  done
  echo "  all) Destroy all listed deployments that have local Terraform state"
  echo "  q) Cancel"
  echo

  read -r -p "Which project number do you want to destroy? " selected
  case "$selected" in
    q|Q)
      echo "Cleanup cancelled."
      exit 0
      ;;
    all)
      TARGET_ENVIRONMENT="all"
      return
      ;;
  esac

  if ! [[ "$selected" =~ ^[0-9]+$ ]]; then
    echo "Selection must be a number, all, or q."
    exit 1
  fi

  max_index="${#DEPLOYMENT_NAME_CHOICES[@]}"
  if [ "$selected" -lt 1 ] || [ "$selected" -gt "$max_index" ]; then
    echo "Selection out of range."
    exit 1
  fi

  SELECTED_INDEX="$((selected - 1))"
  TARGET_ENVIRONMENT="${DEPLOYMENT_ENV_CHOICES[$SELECTED_INDEX]}"
  TARGET_DEPLOYMENT="${DEPLOYMENT_NAME_CHOICES[$SELECTED_INDEX]}"
}

check_aws_auth() {
  if ! aws_identity_check "$AWS_PROFILE_NAME" "$AWS_REGION"; then
    exit 1
  fi
}

scan_project_resources() {
  local env_name="$1"
  local deployment_name="$2"
  local tag_filters

  tag_filters=(
    --tag-filters "Key=Project,Values=$WORDPRESS_FLAGSHIP_PROJECT_TAG"
    --tag-filters "Key=Architecture,Values=$env_name"
  )
  if [ -n "$deployment_name" ]; then
    tag_filters+=(--tag-filters "Key=Deployment,Values=$deployment_name")
  fi

  echo
  echo "AWS resources tagged Project=$WORDPRESS_FLAGSHIP_PROJECT_TAG Architecture=$env_name Deployment=${deployment_name:-any} in $AWS_REGION"
  echo

  echo "Structured tag inventory:"
  aws resourcegroupstaggingapi get-resources \
    --profile "$AWS_PROFILE_NAME" \
    --region "$AWS_REGION" \
    "${tag_filters[@]}" \
    --query "ResourceTagMappingList[].{
      ARN: ResourceARN,
      Component: $(tag_value_query Component),
      Name: $(tag_value_query Name)
    }" \
    --output table || true

  echo
  echo "EC2 instances:"
  aws ec2 describe-instances \
    --profile "$AWS_PROFILE_NAME" \
    --region "$AWS_REGION" \
    --filters "Name=tag:Project,Values=$WORDPRESS_FLAGSHIP_PROJECT_TAG" "Name=tag:Architecture,Values=$env_name" "Name=tag:Deployment,Values=$deployment_name" "Name=instance-state-name,Values=pending,running,stopping,stopped" \
    --query 'Reservations[].Instances[].{InstanceId:InstanceId,State:State.Name,Type:InstanceType,PublicIp:PublicIpAddress,Deployment:Tags[?Key==`Deployment`]|[0].Value,Name:Tags[?Key==`Name`]|[0].Value}' \
    --output table || true

  echo
  echo "EBS volumes:"
  aws ec2 describe-volumes \
    --profile "$AWS_PROFILE_NAME" \
    --region "$AWS_REGION" \
    --filters "Name=tag:Project,Values=$WORDPRESS_FLAGSHIP_PROJECT_TAG" "Name=tag:Architecture,Values=$env_name" "Name=tag:Deployment,Values=$deployment_name" \
    --query 'Volumes[].{VolumeId:VolumeId,State:State,SizeGiB:Size,AttachedTo:Attachments[0].InstanceId,Deployment:Tags[?Key==`Deployment`]|[0].Value,Name:Tags[?Key==`Name`]|[0].Value}' \
    --output table || true

  echo
  echo "RDS databases matching deployment name:"
  aws rds describe-db-instances \
    --profile "$AWS_PROFILE_NAME" \
    --region "$AWS_REGION" \
    --query "DBInstances[?contains(DBInstanceIdentifier, '$deployment_name')].{DBInstanceIdentifier:DBInstanceIdentifier,Status:DBInstanceStatus,Engine:Engine,Class:DBInstanceClass}" \
    --output table || true

  echo
  echo "RDS snapshots matching deployment name:"
  aws rds describe-db-snapshots \
    --profile "$AWS_PROFILE_NAME" \
    --region "$AWS_REGION" \
    --query "DBSnapshots[?contains(DBSnapshotIdentifier, '$deployment_name')].{DBSnapshotIdentifier:DBSnapshotIdentifier,Status:Status,Engine:Engine,AllocatedStorageGiB:AllocatedStorage}" \
    --output table || true

  echo
  echo "IAM roles matching deployment name:"
  aws iam list-roles \
    --profile "$AWS_PROFILE_NAME" \
    --query "Roles[?contains(RoleName, '$deployment_name')].{RoleName:RoleName,Arn:Arn}" \
    --output table || true

  echo
  echo "IAM instance profiles matching deployment name:"
  aws iam list-instance-profiles \
    --profile "$AWS_PROFILE_NAME" \
    --query "InstanceProfiles[?contains(InstanceProfileName, '$deployment_name')].{InstanceProfileName:InstanceProfileName,Arn:Arn}" \
    --output table || true
}

list_matching_rds_snapshots() {
  local env_name="$1"
  local deployment_name="$2"
  local named_snapshot_ids
  local tagged_snapshot_ids

  named_snapshot_ids="$(aws rds describe-db-snapshots \
    --profile "$AWS_PROFILE_NAME" \
    --region "$AWS_REGION" \
    --snapshot-type manual \
    --query "DBSnapshots[?contains(DBSnapshotIdentifier, '$deployment_name')].DBSnapshotIdentifier" \
    --output text 2>/dev/null || true)"

  tagged_snapshot_ids="$(aws resourcegroupstaggingapi get-resources \
    --profile "$AWS_PROFILE_NAME" \
    --region "$AWS_REGION" \
    --resource-type-filters rds:snapshot \
    --tag-filters "Key=Project,Values=$WORDPRESS_FLAGSHIP_PROJECT_TAG" \
    --tag-filters "Key=Architecture,Values=$env_name" \
    --tag-filters "Key=Deployment,Values=$deployment_name" \
    --query 'ResourceTagMappingList[].ResourceARN' \
    --output text 2>/dev/null | sed 's|.*:snapshot:||' || true)"

  printf '%s\n%s\n' "$named_snapshot_ids" "$tagged_snapshot_ids" | tr '\t' '\n' | sed '/^$/d' | sort -u
}

cleanup_matching_rds_snapshots() {
  local env_name="$1"
  local deployment_name="$2"
  local snapshot_ids
  local snapshot_id
  local confirm

  snapshot_ids="$(list_matching_rds_snapshots "$env_name" "$deployment_name")"
  if [ -z "$snapshot_ids" ]; then
    echo
    echo "No manual RDS snapshots found matching deployment: $deployment_name"
    return
  fi

  echo
  echo "Manual RDS snapshots still matching deployment '$deployment_name':"
  for snapshot_id in $snapshot_ids; do
    echo "  - $snapshot_id"
  done

  if [ "$SCAN_ONLY" = "true" ]; then
    return
  fi

  if [ "$DELETE_SNAPSHOTS" = "false" ]; then
    echo "Leaving matching RDS snapshots in place because --keep-snapshots was used."
    return
  fi

  if [ "$DELETE_SNAPSHOTS" != "true" ]; then
    echo
    echo "RDS snapshots can keep billing for storage after the database is gone."
    read -r -p "Delete these matching manual RDS snapshots? Type delete-snapshots to continue: " confirm
    if [ "$confirm" != "delete-snapshots" ]; then
      echo "Leaving matching RDS snapshots in place."
      return
    fi
  fi

  for snapshot_id in $snapshot_ids; do
    echo "Deleting RDS snapshot: $snapshot_id"
    aws rds delete-db-snapshot \
      --profile "$AWS_PROFILE_NAME" \
      --region "$AWS_REGION" \
      --db-snapshot-identifier "$snapshot_id" >/dev/null
  done
}

explain_destroy_scope() {
  local env_name="$1"

  echo
  echo "Destroy scope for $env_name:"
  if [ "$env_name" = "wp-rds" ] || [ "$env_name" = "wp-mig" ]; then
    echo "- EC2 WordPress instance and attached EBS root volume"
    echo "- Private RDS MySQL database"
    echo "- S3 backup/artifact bucket and demo uploads tracked by Terraform"
    echo "- EC2 IAM role, policy, and instance profile for S3 access"
    echo "- VPC, public/private subnets, route table, internet gateway, and security groups"
  else
    echo "- EC2 WordPress instance and attached EBS root volume"
    echo "- VPC, public/private subnets, route table, internet gateway, and security groups"
  fi
}

show_terraform_state() {
  local env_name="$1"
  local env_dir="$ENV_ROOT/$env_name"

  echo
  echo "Terraform state for $env_name:"
  if [ ! -d "$env_dir" ]; then
    echo "Environment directory missing: $env_dir"
    return
  fi

  if [ ! -f "$env_dir/terraform.tfstate" ]; then
    echo "No local terraform.tfstate found. Nothing to destroy from local state."
    return
  fi

  (cd "$env_dir" && terraform state list) || true
}

destroy_environment() {
  local env_name="$1"
  local deployment_name="${2:-}"
  local env_dir="$ENV_ROOT/$env_name"
  local local_deployment_name

  if [ -z "$deployment_name" ]; then
    deployment_name="$(deployment_name_for_env "$env_name")"
  fi

  show_terraform_state "$env_name"
  scan_project_resources "$env_name" "$deployment_name"

  if [ "$SCAN_ONLY" = "true" ]; then
    return
  fi

  if [ ! -f "$env_dir/terraform.tfstate" ]; then
    echo
    echo "Skipping Terraform destroy for $env_name because no local terraform.tfstate was found."
    echo "Use the AWS scan above to investigate possible manually-created or orphaned resources."
    cleanup_matching_rds_snapshots "$env_name" "$deployment_name"
    return
  fi

  local_deployment_name="$(read_tfvar "$env_dir" "deployment_name")"
  if [ -n "$local_deployment_name" ] && [ "$local_deployment_name" != "$deployment_name" ]; then
    echo
    echo "WARNING: AWS selection and local Terraform tfvars do not match."
    echo "  Selected deployment: $deployment_name"
    echo "  Local tfvars deployment_name: $local_deployment_name"
    echo "Terraform destroy can only destroy resources tracked by the local state in:"
    echo "  $env_dir"
    echo "Cancel now if this is not the intended local state."
  fi

  echo
  echo "About to run Terraform destroy for environment: $env_name"
  echo "Project tag: $WORDPRESS_FLAGSHIP_PROJECT_TAG"
  echo "Architecture: $env_name"
  echo "Deployment: $deployment_name"
  echo "AWS profile: $AWS_PROFILE_NAME"
  echo "AWS region: $AWS_REGION"
  explain_destroy_scope "$env_name"

  if [ "$AUTO_APPROVE" != "true" ]; then
    local confirm
    read -r -p "Type destroy-$env_name to continue: " confirm
    if [ "$confirm" != "destroy-$env_name" ]; then
      echo "Destroy cancelled for $env_name."
      return
    fi
  fi

  echo
  echo "Running terraform destroy for $env_name..."
  (cd "$env_dir" && AWS_PROFILE="$AWS_PROFILE_NAME" terraform destroy -auto-approve)

  echo
  echo "Post-destroy scan for $env_name:"
  scan_project_resources "$env_name" "$deployment_name"
  cleanup_matching_rds_snapshots "$env_name" "$deployment_name"
}

while [ "$#" -gt 0 ]; do
  case "$1" in
    --env)
      TARGET_ENVIRONMENT="$2"
      shift 2
      ;;
    --deployment)
      TARGET_DEPLOYMENT="$2"
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
    --yes)
      AUTO_APPROVE="true"
      shift
      ;;
    --scan-only)
      SCAN_ONLY="true"
      shift
      ;;
    --delete-snapshots)
      DELETE_SNAPSHOTS="true"
      shift
      ;;
    --keep-snapshots)
      DELETE_SNAPSHOTS="false"
      shift
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

validate_environment "$TARGET_ENVIRONMENT"
validate_deployment_name "$TARGET_DEPLOYMENT"
require_command terraform
require_command aws
check_aws_auth

if [ -z "$TARGET_ENVIRONMENT" ]; then
  choose_project_interactively
fi

echo "WordPress Flagship Cleanup"
echo "Target environment: $TARGET_ENVIRONMENT"
if [ -n "$TARGET_DEPLOYMENT" ]; then
  echo "Selected deployment: $TARGET_DEPLOYMENT"
fi
echo "AWS profile: $AWS_PROFILE_NAME"
echo "AWS region: $AWS_REGION"

if [ "$TARGET_ENVIRONMENT" = "all" ]; then
  if [ "${#DEPLOYMENT_NAME_CHOICES[@]}" -eq 0 ]; then
    DEPLOYMENT_KEYS=()
    DEPLOYMENT_ENV_CHOICES=()
    DEPLOYMENT_NAME_CHOICES=()
    DEPLOYMENT_SOURCE_CHOICES=()
    DEPLOYMENT_COUNT_CHOICES=()
    DEPLOYMENT_COMPONENT_CHOICES=()
    discover_tagged_projects
    discover_snapshot_projects
    discover_local_projects
  fi

  for index in "${!DEPLOYMENT_NAME_CHOICES[@]}"; do
    destroy_environment "${DEPLOYMENT_ENV_CHOICES[$index]}" "${DEPLOYMENT_NAME_CHOICES[$index]}"
  done
else
  destroy_environment "$TARGET_ENVIRONMENT" "$TARGET_DEPLOYMENT"
fi

echo
echo "Cleanup script finished."
echo "Run a final scan if you want to verify remaining tagged resources:"
echo "  ./scripts/destroy-stack.sh --scan-only --profile $AWS_PROFILE_NAME --region $AWS_REGION"
