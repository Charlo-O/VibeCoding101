#!/usr/bin/env bash
set -euo pipefail

CODEX_HOME="${CODEX_HOME:-$HOME/.codex}"
DEEP=0

while [[ $# -gt 0 ]]; do
  case "$1" in
    --codex-home)
      CODEX_HOME="$2"
      shift 2
      ;;
    --deep)
      DEEP=1
      shift
      ;;
    *)
      echo "Unknown argument: $1" >&2
      exit 2
      ;;
  esac
done

config_path="$CODEX_HOME/config.toml"
missing_critical=()
missing_mcp=()
runtime_failed=0

has_command() {
  command -v "$1" >/dev/null 2>&1
}

has_mcp_section() {
  local section="$1"
  [[ -f "$config_path" ]] && grep -Eq "^\\[mcp_servers\\.${section//./\\.}\\]$" "$config_path"
}

for command_name in git node npx python3 uv uvx; do
  if ! has_command "$command_name"; then
    missing_critical+=("$command_name")
  fi
done

for profile in context7 fetch shadcn; do
  if ! has_mcp_section "$profile"; then
    missing_mcp+=("$profile")
  fi
done

echo "Codex home: $CODEX_HOME"

if [[ ${#missing_critical[@]} -gt 0 ]]; then
  echo "Missing critical tools: ${missing_critical[*]}" >&2
fi

if [[ ${#missing_mcp[@]} -gt 0 ]]; then
  echo "Missing MCP profiles: ${missing_mcp[*]}" >&2
fi

if (( DEEP )); then
  echo "Runtime checks"
  printf '%-12s %-8s %s\n' "name" "status" "details"

  if has_command npx; then
    if output="$(npx -y @upstash/context7-mcp --help 2>&1 | head -n 1)"; then
      printf '%-12s %-8s %s\n' "context7" "passed" "${output:-ok}"
    else
      printf '%-12s %-8s %s\n' "context7" "failed" "${output:-command failed}"
      runtime_failed=1
    fi

    if output="$(npx shadcn-vue@latest mcp --help 2>&1 | head -n 1)"; then
      printf '%-12s %-8s %s\n' "shadcn" "passed" "${output:-ok}"
    else
      printf '%-12s %-8s %s\n' "shadcn" "failed" "${output:-command failed}"
      runtime_failed=1
    fi
  fi

  if has_command uvx; then
    if output="$(uvx mcp-server-fetch --help 2>&1 | head -n 1)"; then
      printf '%-12s %-8s %s\n' "fetch" "passed" "${output:-ok}"
    else
      printf '%-12s %-8s %s\n' "fetch" "failed" "${output:-command failed}"
      runtime_failed=1
    fi
  fi
fi

if [[ ${#missing_critical[@]} -eq 0 && ${#missing_mcp[@]} -eq 0 && $runtime_failed -eq 0 ]]; then
  echo "Ready: True"
  exit 0
fi

echo "Ready: False"
exit 1
