#!/usr/bin/env bash

# Installs the local tools needed to run the WordPress Flagship demo scripts.
# This is meant for fresh Ubuntu/Debian machines, including WSL on Windows.
# It does not configure AWS credentials and does not deploy AWS resources.

set -euo pipefail

GREEN="$(printf '\033[32m')"
RED="$(printf '\033[31m')"
YELLOW="$(printf '\033[33m')"
RESET="$(printf '\033[0m')"

require_apt() {
  if ! command -v apt-get >/dev/null 2>&1; then
    echo "${RED}[missing]${RESET} This helper currently supports Ubuntu/Debian systems with apt-get."
    echo "Install these tools manually: terraform, aws, zip, curl, openssl, unzip."
    exit 1
  fi
}

command_exists() {
  command -v "$1" >/dev/null 2>&1
}

print_installed_version() {
  local command_name="$1"
  local version_command="$2"

  if command_exists "$command_name"; then
    echo "${GREEN}[ok]${RESET} $command_name installed: $($version_command 2>/dev/null | head -n 1)"
  else
    echo "${RED}[missing]${RESET} $command_name is still missing"
    return 1
  fi
}

install_base_packages() {
  echo
  echo "Installing base packages..."

  sudo apt-get update
  sudo apt-get install -y \
    ca-certificates \
    curl \
    gnupg \
    lsb-release \
    openssl \
    unzip \
    wget \
    zip
}

install_terraform() {
  local codename

  if command_exists terraform; then
    echo "${GREEN}[ok]${RESET} terraform is already installed"
    return
  fi

  echo
  echo "Installing Terraform from the official HashiCorp apt repository..."

  codename="$(. /etc/os-release && echo "${UBUNTU_CODENAME:-${VERSION_CODENAME:-}}")"
  if [ -z "$codename" ]; then
    echo "${RED}[missing]${RESET} Could not detect Ubuntu/Debian codename for the HashiCorp repository."
    exit 1
  fi

  wget -O- https://apt.releases.hashicorp.com/gpg \
    | sudo gpg --dearmor --yes -o /usr/share/keyrings/hashicorp-archive-keyring.gpg

  echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] https://apt.releases.hashicorp.com $codename main" \
    | sudo tee /etc/apt/sources.list.d/hashicorp.list >/dev/null

  sudo apt-get update
  sudo apt-get install -y terraform
}

install_aws_cli() {
  local arch
  local aws_zip
  local aws_dir

  if command_exists aws; then
    echo "${GREEN}[ok]${RESET} aws is already installed"
    return
  fi

  echo
  echo "Installing AWS CLI v2..."

  case "$(uname -m)" in
    x86_64 | amd64)
      arch="x86_64"
      ;;
    aarch64 | arm64)
      arch="aarch64"
      ;;
    *)
      echo "${RED}[missing]${RESET} Unsupported CPU architecture for automatic AWS CLI install: $(uname -m)"
      echo "Install the AWS CLI manually from AWS documentation."
      exit 1
      ;;
  esac

  aws_zip="/tmp/awscliv2.zip"
  aws_dir="/tmp/aws"

  rm -rf "$aws_zip" "$aws_dir"
  curl -fsSLo "$aws_zip" "https://awscli.amazonaws.com/awscli-exe-linux-${arch}.zip"
  unzip -q "$aws_zip" -d /tmp
  sudo "$aws_dir/install"
}

echo "WordPress Flagship Local Prerequisite Installer"
echo
echo "This installs local CLI tools only. It does not configure AWS credentials or create AWS resources."
echo

require_apt
install_base_packages
install_terraform
install_aws_cli

echo
echo "Verifying installed tools..."
print_installed_version terraform "terraform version"
print_installed_version aws "aws --version"
print_installed_version zip "zip --version"
print_installed_version curl "curl --version"
print_installed_version openssl "openssl version"
echo
echo "${GREEN}[ok]${RESET} Local prerequisites are installed."
echo
echo "Next steps:"
echo "  aws configure sso"
echo "  aws sso login --profile your-profile-name"
echo "  ./scripts/start-demo.sh"
echo
echo "${YELLOW}Note:${RESET} This script does not create your EC2 key pair. Create or choose one in the same AWS region before deploying wp-lite."
