#!/usr/bin/env bash

# Shared project path helpers for Bash-first WordPress Flagship scripts.
# Scripts pass their own directory so this works from any current directory.

resolve_project_root() {
  local start_dir="$1"
  local fallback_root="$2"
  local git_root

  git_root="$(git -C "$start_dir" rev-parse --show-toplevel 2>/dev/null || true)"
  if [ -n "$git_root" ]; then
    printf '%s\n' "$git_root"
    return 0
  fi

  (cd "$fallback_root" && pwd)
}

project_path() {
  local relative_path="$1"

  printf '%s/%s\n' "$PROJECT_ROOT" "${relative_path#./}"
}

generated_dir() {
  project_path ".generated"
}

terraform_environment_dir() {
  local environment="$1"

  project_path "terraform/environments/$environment"
}
