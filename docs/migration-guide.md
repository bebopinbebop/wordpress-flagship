# WordPress Migration Guide

This project can support client WordPress rehosting work, but migration should be treated as a workflow layered on top of the Terraform platform.

Terraform is excellent for creating the new AWS hosting environment. WordPress migration also needs content, database, media, DNS, SSL, and acceptance checks.

## Recommended Migration Flow

1. Discovery

- Confirm the current host, WordPress version, PHP version, database size, media size, plugins, theme, DNS provider, and email provider.
- Confirm whether the client needs a simple lift-and-shift or a cleanup/update project.
- Confirm the maintenance window and rollback plan.

2. Build Target AWS Environment

- Use `wp-lite` for demos or very small low-cost sites.
- Use `wp-rds` or a production environment for client-like separation of web and database tiers.
- Confirm security groups, backups, and cost expectations before migration.

3. Export Existing WordPress Site

Common approaches:

- Use a trusted migration plugin.
- Export database with `mysqldump`.
- Copy `wp-content/uploads`, active theme, and required plugins.
- Export WordPress content with WP-CLI when appropriate.

4. Import Into AWS WordPress

- Copy files into the new server.
- Import the database.
- Update `wp-config.php`.
- Run search-replace for the domain if needed.
- Flush permalinks.
- Test admin login, pages, media, forms, and plugins.

5. Cutover

- Lower DNS TTL before migration.
- Point DNS to the new AWS endpoint or load balancer.
- Verify HTTPS, redirects, and canonical domain.
- Keep the old host available until the client signs off.

## What Belongs In This Repo

This repo should include:

- Terraform infrastructure.
- Bootstrap scripts.
- Backup and restore examples.
- Migration checklist.
- WP-CLI helper scripts.
- Documentation for repeatable client delivery.

This repo should not store:

- Client database dumps.
- Client uploads.
- Production secrets.
- Private keys.
- Paid plugin files unless licensing allows it.

## Feasibility

The migration idea is feasible and valuable for Upwork. It does not need to be a separate project yet.

The best framing is:

> This repository is a WordPress hosting and migration platform. Terraform builds the AWS target environment, then migration scripts and checklists help move an existing WordPress site into that environment.

If the migration tooling becomes large enough later, it can become its own companion repository.

