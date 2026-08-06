# dev-mig Environment Scaffold

`dev-mig` is a future migration-focused environment.

It is intentionally not deployable yet. The purpose of this folder is to reserve a clear Terraform workspace for future WordPress client migration workflows.

## Intended Purpose

- Stage a clean AWS target for importing an existing WordPress site.
- Keep migration-specific variables separate from `dev-lite` and `dev-rds`.
- Support repeatable client rehosting workflows.
- Track migration readiness before any DNS cutover.

## Future Resources

This environment will likely build on the `dev-rds` architecture:

- EC2 WordPress server.
- RDS MySQL database in private subnets.
- S3 bucket for backups and migration artifacts.
- Optional temporary import storage.
- Future HTTPS and domain support when production hardening is added.

## Current Status

Placeholder only. Use `docs/dev-mig-guide.md` and `scripts/prepare-migration.sh` for planning until this environment is implemented.
