#!/usr/bin/env bash

# Safe diagnostic helper for an existing wp-rds deployment.
# It reads Terraform outputs and AWS metadata, but it does not destroy resources.

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ENV_DIR="$ROOT_DIR/terraform/environments/wp-rds"
AWS_PROFILE_NAME="${AWS_PROFILE:-default}"

echo "Diagnosing wp-rds using AWS profile: $AWS_PROFILE_NAME"
echo

cd "$ENV_DIR"

if [ ! -f terraform.tfstate ]; then
  echo "No terraform.tfstate found in $ENV_DIR."
  echo "Terraform cannot map this folder to an existing deployment without state."
  exit 1
fi

INSTANCE_ID="$(terraform output -raw instance_id 2>/dev/null || true)"
PUBLIC_IP="$(terraform output -raw wordpress_public_ip 2>/dev/null || true)"
WORDPRESS_URL="$(terraform output -raw wordpress_url 2>/dev/null || true)"
DATABASE_ENDPOINT="$(terraform output -raw database_endpoint 2>/dev/null || true)"
BACKUP_BUCKET_NAME="$(terraform output -raw backup_bucket_name 2>/dev/null || true)"

if [ -z "$INSTANCE_ID" ]; then
  INSTANCE_ID="$(terraform state show module.ec2.aws_instance.wordpress 2>/dev/null | awk -F ' = ' '/^    id / { print $2; exit }' | tr -d '"')"
fi

echo "Terraform URL: ${WORDPRESS_URL:-not found}"
echo "Terraform public IP: ${PUBLIC_IP:-not found}"
echo "Terraform instance ID: ${INSTANCE_ID:-not found}"
echo "RDS endpoint: ${DATABASE_ENDPOINT:-not found}"
echo "Backup bucket: ${BACKUP_BUCKET_NAME:-not found}"
echo

if [ -z "$INSTANCE_ID" ]; then
  echo "Could not find an EC2 instance ID in Terraform outputs or state."
  exit 1
fi

echo "AWS EC2 status:"
aws ec2 describe-instances \
  --profile "$AWS_PROFILE_NAME" \
  --instance-ids "$INSTANCE_ID" \
  --query 'Reservations[0].Instances[0].{State:State.Name,PublicIp:PublicIpAddress,PublicDns:PublicDnsName,SubnetId:SubnetId,VpcId:VpcId,SecurityGroups:SecurityGroups[*].GroupId}' \
  --output table

echo
echo "Instance system status:"
aws ec2 describe-instance-status \
  --profile "$AWS_PROFILE_NAME" \
  --instance-ids "$INSTANCE_ID" \
  --include-all-instances \
  --output table

if [ -n "$DATABASE_ENDPOINT" ]; then
  echo
  echo "RDS status:"
  aws rds describe-db-instances \
    --profile "$AWS_PROFILE_NAME" \
    --query "DBInstances[?Endpoint.Address=='$DATABASE_ENDPOINT'].{DBInstanceIdentifier:DBInstanceIdentifier,Status:DBInstanceStatus,Engine:Engine,Class:DBInstanceClass,StorageEncrypted:StorageEncrypted,PubliclyAccessible:PubliclyAccessible}" \
    --output table || true
fi

if [ -n "$BACKUP_BUCKET_NAME" ]; then
  echo
  echo "S3 backup bucket status:"
  aws s3api get-bucket-location \
    --profile "$AWS_PROFILE_NAME" \
    --bucket "$BACKUP_BUCKET_NAME" \
    --output table || true
fi

echo
echo "HTTP check from this machine:"
if [ -n "$WORDPRESS_URL" ]; then
  curl -I --connect-timeout 5 "$WORDPRESS_URL" || true
else
  curl -I --connect-timeout 5 "http://$PUBLIC_IP" || true
fi

echo
echo "If HTTP fails but the instance is running, SSH in and check:"
echo "  sudo tail -n 120 /var/log/wordpress-bootstrap.log"
echo "  sudo systemctl status apache2 --no-pager"
