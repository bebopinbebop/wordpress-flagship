# Resource Tagging Architecture

This project treats AWS resource identity as a hierarchy:

```text
Project -> Architecture -> Deployment -> Resource
```

Example:

```text
wordpress-flagship -> wp-rds -> client-demo -> EC2/RDS/S3/VPC/security groups
```

## Current State

The repository currently uses `project_name` for both AWS names and the `Project` tag inside child modules.

That was useful for early demos, but it mixes two different ideas:

- Repository identity: this resource belongs to `wordpress-flagship`.
- Deployment identity: this resource belongs to one specific stack, such as `wp-rds-client-demo`.

The new model separates those concerns.

## Standard Tags

The proposed baseline tag map is:

```text
Project      = wordpress-flagship
Architecture = wp-lite | wp-rds | wp-mig
Deployment   = <unique deployment identifier>
ManagedBy    = terraform
Purpose      = wordpress-demo
```

These tags support:

- account-wide discovery of all resources from this repository,
- filtering by architecture,
- selecting one specific deployment,
- cleanup verification after `terraform destroy`,
- future cost allocation by project, architecture, or deployment,
- safer troubleshooting and inventory scripts.

## Required Tags

- `Project`: fixed repository-level identity, always `wordpress-flagship`.
- `Architecture`: one of `wp-lite`, `wp-rds`, or `wp-mig`.
- `Deployment`: unique per stack, usually the same value currently used by `project_name`.
- `ManagedBy`: always `terraform` for Terraform-created resources.

## Optional Tags Kept

- `Purpose`: useful for distinguishing demo/training resources from future client or production resources.

## Optional Tags Rejected For Now

- `Environment`: reserved for future traditional stages such as `dev`, `test`, and `prod`.
- `Owner`: not needed yet for a personal portfolio repository.
- `CostCenter`: unnecessary unless this becomes a multi-team or client billing system.
- `Repository`: redundant with `Project = wordpress-flagship` for this repository.
- `GitBranch`: fragile because deployed resources can outlive a branch.
- `Version`: useful later, but not needed before release packaging exists.

## Terraform Implementation Plan

Each Terraform root now defines:

```hcl
locals {
  architecture    = "wp-rds"
  deployment_name = var.deployment_name != "" ? var.deployment_name : var.project_name

  common_tags = {
    Project      = "wordpress-flagship"
    Architecture = local.architecture
    Deployment   = local.deployment_name
    ManagedBy    = "terraform"
    Purpose      = "wordpress-demo"
  }
}
```

`wp-lite`, `wp-rds`, and `wp-mig` now pass `local.common_tags` into the shared modules they use.

Resource-specific tags use one additional convention:

```text
Name
Component = compute | database | network | storage | security | iam
```

`Role` is intentionally not used yet because `Component` plus `Name` gives enough operational value without making the tag model noisy.

## Provider default_tags

AWS provider `default_tags` may be useful later for repository-wide tags.

It is not the safest first step here because existing resources explicitly set `Project = var.project_name`. Explicit resource tags can conflict with provider defaults, and the project needs `Project = wordpress-flagship` going forward.

The safer path is:

1. Define the standard tag model in roots.
2. Pass `common_tags` into modules.
3. Replace old `Project = var.project_name` resource tags with `merge(var.common_tags, ...)`.
4. Consider provider `default_tags` only after explicit tag conflicts are removed.

## Script Discovery Strategy

Terraform outputs should remain preferred for the currently selected deployment.

Tags should be preferred for account-wide discovery, inventories, orphan detection, and cleanup verification.

Future scripts should query by:

```text
Project=wordpress-flagship
Architecture=<wp-lite|wp-rds|wp-mig>
Deployment=<deployment-name>
```

Destructive actions should never run from `Architecture` alone. The minimum safe destructive scope should include `Project`, `Architecture`, and `Deployment`, ideally verified against local Terraform state.

## Existing Resource Compatibility

Adding or changing tags usually results in in-place tag updates for EC2, VPC, subnets, security groups, RDS, and S3.

However, the next module-retagging phase should still be reviewed with:

```bash
terraform plan
```

Watch carefully for:

```text
forces replacement
must be replaced
-/+
```

Do not apply tag changes if Terraform plans to replace RDS, EC2, VPC, or S3 resources unexpectedly.

## Current Phase

Implemented foundation:

- `deployment_name` variable in each Terraform root.
- `local.common_tags` in each Terraform root.
- non-sensitive `architecture`, `deployment_name`, and `common_tags` outputs.
- `start-demo.sh` writes `deployment_name` into local `terraform.tfvars`.
- `start-demo.sh` validates deployment names as lowercase kebab-case.
- `wp-lite` passes `common_tags` into VPC, security, and EC2 modules.
- `wp-lite` applies launch-time tags to the EC2 root EBS volume with `volume_tags`.
- `wp-rds` passes `common_tags` into VPC, security, EC2, RDS, and S3 modules.
- `wp-rds` applies launch-time tags to the EC2 root EBS volume with `volume_tags`.
- `wp-mig` passes `common_tags` into VPC, security, EC2, RDS, and S3 modules.
- `wp-mig` applies launch-time tags to the EC2 root EBS volume with `volume_tags`.
- `scripts/resources.sh` provides read-only AWS tag discovery.

Not implemented yet:

- tag validation against deployed AWS resources.

## Terraform Resource Inventory

| Resource type | Module/location | Currently tagged? | Recommended behavior |
| --- | --- | --- | --- |
| `aws_vpc` | `modules/vpc` | Yes | Structured tags plus `Name`, `Component=network` |
| `aws_internet_gateway` | `modules/vpc` | Yes | Structured tags plus `Name`, `Component=network` |
| `aws_subnet` | `modules/vpc` | Yes | Structured tags plus `Name`, `Component=network`, `Tier` |
| `aws_route_table` | `modules/vpc` | Yes | Structured tags plus `Name`, `Component=network` |
| `aws_route_table_association` | `modules/vpc` | No | Not directly tagged; association is identified through subnet/route table |
| `aws_security_group` | `modules/security` | Yes | Structured tags plus `Name`, `Component=security` |
| `aws_instance` | `modules/ec2` | Yes | Structured tags plus `Name`, `Component=compute`, `Site` |
| EC2 root EBS volume | created by `aws_instance` | Tagged for new launches | Uses `volume_tags` with `Component=storage`; legacy in-place behavior still needs plan review |
| `aws_iam_role` | `modules/ec2` | Yes when S3 access enabled | Structured tags plus `Name`, `Component=iam` |
| `aws_iam_role_policy` | `modules/ec2` | No | Inline IAM policies are not tagged separately in this pattern |
| `aws_iam_instance_profile` | `modules/ec2` | Tagged when S3 access enabled | Structured tags plus `Name`, `Component=iam` |
| `aws_db_subnet_group` | `modules/rds` | Tagged for `wp-rds` and `wp-mig` | Structured tags plus `Name`, `Component=database` |
| `aws_db_instance` | `modules/rds` | Tagged for `wp-rds` and `wp-mig` | Structured tags plus `Name`, `Component=database` |
| `aws_s3_bucket` | `modules/s3` | Tagged for `wp-rds` and `wp-mig` | Structured tags plus `Name`, `Component=storage` |
| S3 public access block | `modules/s3` | No | Tagging is inherited operationally through the bucket |
| S3 versioning | `modules/s3` | No | Tagging is inherited operationally through the bucket |

## wp-lite Plan Review

The reviewed `wp-lite` plan represented a fresh deployment, not a retrofit of existing AWS resources.

Plan summary:

```text
12 to add, 0 to change, 0 to destroy
```

This proves:

- new `wp-lite` resources receive the structured tags,
- `Project` is consistently `wordpress-flagship`,
- `Architecture` is consistently `wp-lite`,
- `Deployment` is the selected deployment value, such as `wp-lite-test`,
- `ManagedBy = terraform` and `Purpose = wordpress-demo` are present,
- resource-specific tags such as `Name`, `Tier`, and `Site` are preserved,
- no destructive or replacement actions appeared in the fresh-deployment plan.

This does not prove that an older, already-created `wp-lite` deployment can be retroactively retagged without replacement. That case requires a separate plan against existing state.

The follow-up fresh `wp-lite` plan after adding EC2 `volume_tags` also showed:

```text
12 to add, 0 to change, 0 to destroy
```

The EC2 root EBS volume receives launch-time tags through `volume_tags`:

```text
Project=wordpress-flagship
Architecture=wp-lite
Deployment=<deployment>
ManagedBy=terraform
Purpose=wordpress-demo
Component=storage
```

## wp-rds Tagging Status

`wp-rds` now uses the same `common_tags` flow as `wp-lite` for:

- VPC, internet gateway, subnets, and route table,
- WordPress and database security groups,
- EC2 WordPress instance,
- EC2 root EBS volume at launch,
- EC2 IAM role and instance profile for S3 access,
- RDS DB subnet group,
- RDS MySQL instance,
- S3 backup bucket.

No RDS engine, identifier, storage, credential, subnet, snapshot, or availability settings were changed as part of tagging propagation.

The reviewed `wp-rds` plan represented a fresh deployment after the AWS account was manually cleaned.

Plan summary:

```text
20 to add, 0 to change, 0 to destroy
```

This proves new `wp-rds` resources receive the structured tags across the network, security, compute, IAM, database, and storage layers. The EC2 root EBS volume also receives launch-time `volume_tags` with `Component=storage`.

The RDS instance currently has `skip_final_snapshot = true`, so this plan does not create or tag a final DB snapshot during destroy. If final snapshots are enabled later, snapshot tagging should be reviewed as a separate lifecycle improvement.

## wp-mig Tagging Status

`wp-mig` now uses the same `common_tags` flow as `wp-rds` for:

- VPC, internet gateway, subnets, and route table,
- WordPress and database security groups,
- EC2 WordPress migration target,
- EC2 root EBS volume at launch,
- EC2 IAM role and instance profile for S3 access,
- RDS DB subnet group,
- RDS MySQL instance,
- S3 migration artifact bucket.

No migration workflow behavior was redesigned as part of this tagging phase. The environment still provisions a clean migration target based on the `wp-rds` architecture.

The RDS instance currently has `skip_final_snapshot = true`, matching `wp-rds`. If final snapshots are enabled later, snapshot tagging and cleanup behavior should be added deliberately.

The reviewed `wp-mig` plan represented a fresh deployment after the AWS account was manually cleaned.

Plan summary:

```text
20 to add, 0 to change, 0 to destroy
```

This proves new `wp-mig` resources receive the structured tags across the network, security, compute, IAM, database, and migration artifact storage layers. The EC2 root EBS volume also receives launch-time `volume_tags` with `Component=storage`.

## Read-Only Discovery

Use `scripts/resources.sh` to discover resources by structured tags.

List everything from this repository:

```bash
./scripts/resources.sh list --profile your-profile-name --region us-east-1
```

List one architecture:

```bash
./scripts/resources.sh list --architecture wp-lite --profile your-profile-name --region us-east-1
```

List one deployment:

```bash
./scripts/resources.sh list --architecture wp-lite --deployment wp-lite-test --profile your-profile-name --region us-east-1
```

List discovered deployments:

```bash
./scripts/resources.sh deployments --architecture wp-lite --profile your-profile-name --region us-east-1
```

Check for deployment identity collision:

```bash
./scripts/resources.sh exists --architecture wp-lite --deployment wp-lite-test --profile your-profile-name --region us-east-1
```

The collision check is read-only. It warns when tagged resources already exist for:

```text
Project=wordpress-flagship
Architecture=<architecture>
Deployment=<deployment>
```

It does not delete, import, modify Terraform state, or overwrite existing infrastructure.

## Discovery Limitations

`scripts/resources.sh` uses AWS Resource Groups Tagging API for broad account-level discovery.

Known limitations:

- Some supporting resources may not appear in Resource Groups Tagging API.
- Route table associations are not independently tagged.
- S3 public access block and S3 versioning are operational settings on the bucket, not separately tagged project resources.
- Terraform outputs/state remain authoritative for the currently selected deployment.
- Tags are for account-wide discovery, grouping, cleanup verification, and orphan detection.
