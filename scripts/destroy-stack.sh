#!/usr/bin/env bash

# Safe cleanup helper for WordPress Flagship environments.
# It prefers Terraform destroy so resources are removed in dependency order.
# AWS scans are read-only and help spot tagged resources that may still cost money.

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ENV_ROOT="$ROOT_DIR/terraform/environments"

AWS_PROFILE_NAME="${AWS_PROFILE:-default}"
AWS_REGION="us-east-1"
TARGET_ENVIRONMENT="wp-lite"
AUTO_APPROVE="false"
SCAN_ONLY="false"

usage() {
  cat <<USAGE
Usage: ./scripts/destroy-stack.sh [options]

Options:
  --env ENV          Environment to destroy: wp-lite, wp-rds, wp-mig, or all.
                     Default: wp-lite.
  --profile NAME    AWS CLI profile to use. Default: AWS_PROFILE or default.
  --region REGION   AWS region to scan. Default: us-east-1.
  --yes             Skip confirmation prompts for Terraform destroy.
  --scan-only       Only scan AWS and Terraform state. Do not destroy anything.
  -h, --help        Show this help.

Examples:
  ./scripts/destroy-stack.sh --env wp-lite
  ./scripts/destroy-stack.sh --env wp-rds --profile my-sso
  ./scripts/destroy-stack.sh --env wp-mig --profile my-sso
  ./scripts/destroy-stack.sh --env all
  ./scripts/destroy-stack.sh --scan-only --profile my-sso

wp-rds/wp-mig cleanup:
  Terraform destroys the EC2 instance, RDS database, S3 bucket, IAM role/profile,
  VPC, subnets, route tables, internet gateway, and security groups that are in
  the local Terraform state. The S3 backup bucket is configured for demo cleanup
  with force_destroy so uploaded lab files do not block bucket deletion.
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

validate_environment() {
  local env_name="$1"

  case "$env_name" in
    wp-lite|wp-rds|wp-mig|all) ;;
    *)
      echo "Unknown environment: $env_name"
      echo "Use wp-lite, wp-rds, wp-mig, or all."
      exit 1
      ;;
  esac
}

environments_to_process() {
  if [ "$TARGET_ENVIRONMENT" = "all" ]; then
    echo "wp-lite wp-rds wp-mig"
  else
    echo "$TARGET_ENVIRONMENT"
  fi
}

check_aws_auth() {
  if ! aws sts get-caller-identity --profile "$AWS_PROFILE_NAME" >/dev/null 2>&1; then
    echo "AWS profile '$AWS_PROFILE_NAME' is not authenticated."
    echo "Use AWS SSO or an AWS CLI profile:"
    echo "  aws configure sso"
    echo "  aws sso login --profile $AWS_PROFILE_NAME"
    exit 1
  fi
}

scan_project_resources() {
  local env_name="$1"
  local project_name="$2"

  echo
  echo "AWS resources tagged Project=$project_name in $AWS_REGION"
  echo

  echo "EC2 instances:"
  aws ec2 describe-instances \
    --profile "$AWS_PROFILE_NAME" \
    --region "$AWS_REGION" \
    --filters "Name=tag:Project,Values=$project_name" "Name=instance-state-name,Values=pending,running,stopping,stopped" \
    --query 'Reservations[].Instances[].{InstanceId:InstanceId,State:State.Name,Type:InstanceType,PublicIp:PublicIpAddress,Name:Tags[?Key==`Name`]|[0].Value}' \
    --output table || true

  echo
  echo "EBS volumes:"
  aws ec2 describe-volumes \
    --profile "$AWS_PROFILE_NAME" \
    --region "$AWS_REGION" \
    --filters "Name=tag:Project,Values=$project_name" \
    --query 'Volumes[].{VolumeId:VolumeId,State:State,SizeGiB:Size,AttachedTo:Attachments[0].InstanceId,Name:Tags[?Key==`Name`]|[0].Value}' \
    --output table || true

  echo
  echo "RDS databases:"
  aws rds describe-db-instances \
    --profile "$AWS_PROFILE_NAME" \
    --region "$AWS_REGION" \
    --query "DBInstances[?contains(DBInstanceIdentifier, '$project_name')].{DBInstanceIdentifier:DBInstanceIdentifier,Status:DBInstanceStatus,Engine:Engine,Class:DBInstanceClass}" \
    --output table || true

  echo
  echo "RDS snapshots matching this project name:"
  aws rds describe-db-snapshots \
    --profile "$AWS_PROFILE_NAME" \
    --region "$AWS_REGION" \
    --query "DBSnapshots[?contains(DBSnapshotIdentifier, '$project_name')].{DBSnapshotIdentifier:DBSnapshotIdentifier,Status:Status,Engine:Engine,AllocatedStorageGiB:AllocatedStorage}" \
    --output table || true

  echo
  echo "NAT gateways:"
  aws ec2 describe-nat-gateways \
    --profile "$AWS_PROFILE_NAME" \
    --region "$AWS_REGION" \
    --filter "Name=tag:Project,Values=$project_name" \
    --query 'NatGateways[].{NatGatewayId:NatGatewayId,State:State,VpcId:VpcId}' \
    --output table || true

  echo
  echo "Load balancers in this region:"
  aws elbv2 describe-load-balancers \
    --profile "$AWS_PROFILE_NAME" \
    --region "$AWS_REGION" \
    --query 'LoadBalancers[].{LoadBalancerArn:LoadBalancerArn,Name:LoadBalancerName,State:State.Code,Type:Type}' \
    --output table >/tmp/wordpress-flagship-lbs.txt 2>/dev/null || true
  cat /tmp/wordpress-flagship-lbs.txt

  echo
  echo "IAM roles matching this project name:"
  aws iam list-roles \
    --profile "$AWS_PROFILE_NAME" \
    --query "Roles[?contains(RoleName, '$project_name')].{RoleName:RoleName,Arn:Arn}" \
    --output table || true

  echo
  echo "IAM instance profiles matching this project name:"
  aws iam list-instance-profiles \
    --profile "$AWS_PROFILE_NAME" \
    --query "InstanceProfiles[?contains(InstanceProfileName, '$project_name')].{InstanceProfileName:InstanceProfileName,Arn:Arn}" \
    --output table || true

  echo
  echo "S3 bucket check:"
  local env_dir="$ENV_ROOT/$env_name"
  local bucket_name
  bucket_name="$(read_tfvar "$env_dir" "backup_bucket_name")"
  if [ -n "$bucket_name" ]; then
    aws s3api get-bucket-location --profile "$AWS_PROFILE_NAME" --bucket "$bucket_name" >/dev/null 2>&1 \
      && echo "Found S3 bucket: $bucket_name" \
      || echo "No accessible S3 bucket found named: $bucket_name"
  else
    echo "No backup_bucket_name found for $env_name."
  fi
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
  local env_dir="$ENV_ROOT/$env_name"
  local project_name

  project_name="$(project_name_for_env "$env_name")"
  show_terraform_state "$env_name"
  scan_project_resources "$env_name" "$project_name"

  if [ "$SCAN_ONLY" = "true" ]; then
    return
  fi

  if [ ! -f "$env_dir/terraform.tfstate" ]; then
    echo
    echo "Skipping Terraform destroy for $env_name because no local terraform.tfstate was found."
    echo "Use the AWS scan above to investigate possible manually-created or orphaned resources."
    return
  fi

  echo
  echo "About to run Terraform destroy for environment: $env_name"
  echo "Project tag/name: $project_name"
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
  scan_project_resources "$env_name" "$project_name"
}

while [ "$#" -gt 0 ]; do
  case "$1" in
    --env)
      TARGET_ENVIRONMENT="$2"
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
require_command terraform
require_command aws
check_aws_auth

echo "WordPress Flagship Cleanup"
echo "Target environment: $TARGET_ENVIRONMENT"
echo "AWS profile: $AWS_PROFILE_NAME"
echo "AWS region: $AWS_REGION"

for env_name in $(environments_to_process); do
  destroy_environment "$env_name"
done

echo
echo "Cleanup script finished."
echo "Run a final scan if you want to verify remaining tagged resources:"
echo "  ./scripts/destroy-stack.sh --scan-only --profile $AWS_PROFILE_NAME --region $AWS_REGION"
