#!/usr/bin/env bash
set -euo pipefail

CODEX_HOME="${CODEX_HOME:-$HOME/.codex}"
DRY_RUN=0
SKIP_VERIFY=0
DEEP_VERIFY=0
PROFILES=("context7" "fetch" "shadcn")

while [[ $# -gt 0 ]]; do
  case "$1" in
    --codex-home)
      CODEX_HOME="$2"
      shift 2
      ;;
    --profile)
      PROFILES=("$2")
      shift 2
      ;;
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

block_for_profile() {
  case "$1" in
    context7)
      cat <<'EOF'
[mcp_servers.context7]
type = "stdio"
command = "npx"
args = ["-y", "@upstash/context7-mcp"]
EOF
      ;;
    fetch)
      cat <<'EOF'
[mcp_servers.fetch]
type = "stdio"
command = "uvx"
args = ["mcp-server-fetch"]
EOF
      ;;
    shadcn)
      cat <<'EOF'
[mcp_servers.shadcn]
type = "stdio"
command = "npx"
args = ["shadcn-vue@latest", "mcp"]
EOF
      ;;
    *)
      echo "Unsupported MCP profile: $1" >&2
      exit 1
      ;;
  esac
}

has_mcp_section() {
  local section="$1"
  local file_path="$2"
  [[ -f "$file_path" ]] && grep -Eq "^\\[mcp_servers\\.${section//./\\.}\\]$" "$file_path"
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

post_config_check() {
  local missing=()
  local runtime_failed=0

  for profile in "${PROFILES[@]}"; do
    if ! has_mcp_section "$profile" "$config_path"; then
      missing+=("$profile")
    fi
  done

  echo
  echo "Post-config check"
  if [[ ${#missing[@]} -gt 0 ]]; then
    echo "Missing MCP profiles: ${missing[*]}" >&2
  fi

  if (( DEEP_VERIFY )); then
    echo "Runtime checks"
    printf '%-12s %-8s %s\n' "name" "status" "details"
    for profile in "${PROFILES[@]}"; do
      case "$profile" in
        context7)
          runtime_check "context7" npx -y @upstash/context7-mcp --help || runtime_failed=1
          ;;
        fetch)
          runtime_check "fetch" uvx mcp-server-fetch --help || runtime_failed=1
          ;;
        shadcn)
          runtime_check "shadcn" npx shadcn-vue@latest mcp --help || runtime_failed=1
          ;;
      esac
    done
  fi

  if [[ ${#missing[@]} -eq 0 && $runtime_failed -eq 0 ]]; then
    echo "MCP ready: True"
    return 0
  fi

  echo "MCP ready: False"
  return 1
}

mkdir -p "$CODEX_HOME"
config_path="$CODEX_HOME/config.toml"
temp_path="$(mktemp)"
trap 'rm -f "$temp_path"' EXIT

if [[ -f "$config_path" ]]; then
  cat "$config_path" > "$temp_path"
  original_exists=1
else
  : > "$temp_path"
  original_exists=0
fi

if ! grep -Eq '^\[mcp_servers\]$' "$temp_path"; then
  if [[ -s "$temp_path" ]]; then
    printf '\n[mcp_servers]\n' >> "$temp_path"
  else
    printf '[mcp_servers]\n' >> "$temp_path"
  fi
fi

added=()
skipped=()

for profile in "${PROFILES[@]}"; do
  if grep -Eq "^\\[mcp_servers\\.${profile//./\\.}\\]$" "$temp_path"; then
    skipped+=("$profile")
    continue
  fi

  printf '\n%s\n' "$(block_for_profile "$profile")" >> "$temp_path"
  added+=("$profile")
done

if [[ ${#added[@]} -eq 0 ]]; then
  echo "No MCP changes were needed."
  if [[ ${#skipped[@]} -gt 0 ]]; then
    echo "Already configured: ${skipped[*]}"
  fi
  rm -f "$temp_path"
  if (( DRY_RUN == 0 && SKIP_VERIFY == 0 )); then
    post_config_check
  fi
  exit 0
fi

backup_path=""
if (( original_exists )); then
  backup_path="${config_path}.bak.$(date +%Y%m%d-%H%M%S)"
fi

if (( DRY_RUN )); then
  echo "What if: would append MCP profiles: ${added[*]}"
  if [[ -n "$backup_path" ]]; then
    echo "What if: would create backup at $backup_path"
  fi
  rm -f "$temp_path"
  exit 0
fi

if [[ -n "$backup_path" ]]; then
  cp "$config_path" "$backup_path"
fi
mv "$temp_path" "$config_path"
trap - EXIT

echo "Added MCP profiles: ${added[*]}"
if [[ -n "$backup_path" ]]; then
  echo "Backup created: $backup_path"
fi
if [[ ${#skipped[@]} -gt 0 ]]; then
  echo "Already configured: ${skipped[*]}"
fi

if (( SKIP_VERIFY == 0 )); then
  post_config_check
fi
