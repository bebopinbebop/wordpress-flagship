# wp-mig Guide

`wp-mig` is the planned migration environment for future client rehosting work.

Unlike `wp-lite` and `wp-rds`, this environment is not intended to be deployed yet. It exists as a planning space for the files, variables, scripts, and checklists needed to move an existing WordPress site into AWS.

## Purpose

- Prepare the project for WordPress migration and rehosting workflows.
- Separate migration planning from normal demo deployments.
- Define what information must be collected before importing a client site.
- Give future scripts a clear place to connect Terraform, WP-CLI, backups, and DNS steps.

## Expected Future Workflow

1. Collect source site information.
2. Create a migration plan with `scripts/prepare-migration.sh`.
3. Build an AWS target environment, likely based on the `wp-rds` architecture.
4. Export the current WordPress database and `wp-content` files.
5. Import the database and files into the AWS-hosted WordPress instance.
6. Run WP-CLI search-replace for domain changes.
7. Test pages, media, plugins, forms, and admin login.
8. Cut over DNS after approval.

## Expected Inputs

- Client or project name.
- Current domain.
- Target domain or temporary test URL.
- Current host access method.
- WordPress admin access.
- Database export method.
- `wp-content/uploads` size.
- Active theme and required plugins.
- DNS provider.
- Rollback plan.

## Current Project Support

- `scripts/prepare-migration.sh` creates a local migration checklist.
- `docs/migration-guide.md` explains the migration flow.
- `terraform/environments/wp-mig` reserves a future Terraform workspace.

## Not Included Yet

- Automated database import.
- Automated uploads sync.
- Domain search-replace script.
- DNS cutover automation.
- HTTPS/domain automation.

Do not store client exports, database dumps, uploaded media, paid plugins, or secrets in this repository.
