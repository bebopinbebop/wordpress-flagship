# Placeholder Terraform file for the future dev-mig environment.
#
# This environment is reserved for migration/rehosting workflows. It should not
# create AWS resources until the migration architecture is intentionally designed.
#
# Future direction:
# - Reuse the VPC, security, EC2, RDS, and S3 modules.
# - Add migration-specific inputs for source domain, target domain, and backup paths.
# - Keep client exports, database dumps, uploads, and secrets out of Git.
