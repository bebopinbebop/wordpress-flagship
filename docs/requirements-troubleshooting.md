## Requirements and Troubleshooting

The primary supported local workflow is Linux/Bash or WSL2 Ubuntu/Bash. PowerShell can be useful for manual troubleshooting, but the project scripts are designed around Bash.

Required local tools:

- `bash`: runs the project scripts.
- `terraform`: plans, validates, creates, and destroys AWS infrastructure.
- `aws`: authenticates with AWS and supports resource discovery.
- `curl`: waits for WordPress and checks HTTP readiness.
- `ssh`: reaches EC2 instances for diagnostics and migration export.
- `zip` and `unzip`: package and unpack the static demo site.
- `tar` and `gzip`: package migration artifacts.
- `sha256sum`: verifies migration artifact checksums.
- `openssl`: generates local demo passwords.

Migration testing also uses:

- `mysql` or `mariadb` client tools.

Optional development/static-analysis tools:

- `shellcheck`: lint Bash scripts locally; CI runs ShellCheck.
- `jq`: useful for inspecting generated migration manifests.
- `shfmt`: useful for formatting Bash, but not required by CI.
- `tflint`: useful for deeper Terraform linting, but not required by CI yet.

On a fresh Ubuntu/Debian or WSL2 machine, install the local command-line tools with:

```bash
./scripts/install-prereqs.sh
```

Then configure AWS with a CLI profile or AWS SSO:

```bash
aws configure sso
aws sso login --profile your-profile-name
```

Do not paste AWS access keys into project scripts.
