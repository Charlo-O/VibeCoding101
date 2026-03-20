#!/usr/bin/env bash
set -euo pipefail

DRY_RUN=0
SKIP_VERIFY=0
DEEP_VERIFY=0

while [[ $# -gt 0 ]]; do
  case "$1" in
    --dry-run)
      DRY_RUN=1
      shift
      ;;
    --skip-verify)
      SKIP_VERIFY=1
      shift
      ;;
    --deep-verify)
      DEEP_VERIFY=1
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

runtime_check() {
  local name="$1"
  shift

  if output="$("$@" 2>&1 | head -n 1)"; then
    printf '%-12s %-8s %s\n' "$name" "passed" "${output:-ok}"
  else
    printf '%-12s %-8s %s\n' "$name" "failed" "${output:-command failed}"
    return 1
  fi
}

post_install_check() {
  local missing=()
  local runtime_failed=0
  local required_tools=("git" "node" "npx" "python3" "uv" "uvx")

  for tool in "${required_tools[@]}"; do
    if ! command_exists "$tool"; then
      missing+=("$tool")
    fi
  done

  echo
  echo "Post-install check"
  if [[ ${#missing[@]} -gt 0 ]]; then
    echo "Missing base tools: ${missing[*]}" >&2
  fi

  if (( DEEP_VERIFY )); then
    echo "Runtime checks"
    printf '%-12s %-8s %s\n' "name" "status" "details"
    command_exists git && runtime_check "git" git --version || runtime_failed=1
    command_exists node && runtime_check "node" node --version || runtime_failed=1
    command_exists npx && runtime_check "npx" npx --version || runtime_failed=1
    command_exists python3 && runtime_check "python3" python3 --version || runtime_failed=1
    command_exists uv && runtime_check "uv" uv --version || runtime_failed=1
    command_exists uvx && runtime_check "uvx" uvx --version || runtime_failed=1
  fi

  if [[ ${#missing[@]} -eq 0 && $runtime_failed -eq 0 ]]; then
    echo "Base ready: True"
    return 0
  fi

  echo "Base ready: False"
  return 1
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
  if command_exists pnpm; then
    printf '%-14s %s\n' "pnpm" "already-installed"
  elif command_exists corepack; then
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

if (( DRY_RUN == 0 && SKIP_VERIFY == 0 )); then
  post_install_check
fi
