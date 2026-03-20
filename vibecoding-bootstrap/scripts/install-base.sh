#!/usr/bin/env bash
set -euo pipefail

DRY_RUN=0

while [[ $# -gt 0 ]]; do
  case "$1" in
    --dry-run)
      DRY_RUN=1
      shift
      ;;
    *)
      echo "Unknown argument: $1" >&2
      exit 2
      ;;
  esac
done

run_cmd() {
  if (( DRY_RUN )); then
    printf 'What if:'
    for arg in "$@"; do
      printf ' %q' "$arg"
    done
    printf '\n'
  else
    "$@"
  fi
}

command_exists() {
  command -v "$1" >/dev/null 2>&1
}

install_formula() {
  local label="$1"
  local formula="$2"
  local command_name="$3"

  if command_exists "$command_name"; then
    printf '%-14s %s\n' "$label" "already-installed"
    return
  fi

  run_cmd brew install "$formula"

  if (( DRY_RUN )); then
    printf '%-14s %s\n' "$label" "whatif"
    return
  fi

  if command_exists "$command_name"; then
    printf '%-14s %s\n' "$label" "installed"
  else
    printf '%-14s %s\n' "$label" "restart-shell"
  fi
}

if ! command -v brew >/dev/null 2>&1; then
  echo "Homebrew is required on macOS before running install-base.sh." >&2
  echo "Install it from https://brew.sh/ and rerun this script." >&2
  exit 1
fi

echo "Base package results"
install_formula "git" "git" "git"
install_formula "node" "node" "node"
install_formula "python3" "python" "python3"
install_formula "uv" "uv" "uv"

echo
echo "pnpm result"
if command_exists node; then
  if command_exists corepack; then
    run_cmd corepack enable
    run_cmd corepack prepare pnpm@latest --activate
    if (( DRY_RUN )); then
      printf '%-14s %s\n' "pnpm" "whatif"
    elif command_exists pnpm; then
      printf '%-14s %s\n' "pnpm" "ready"
    else
      printf '%-14s %s\n' "pnpm" "restart-shell"
    fi
  else
    printf '%-14s %s\n' "pnpm" "restart-shell"
  fi
else
  printf '%-14s %s\n' "pnpm" "skipped"
fi
