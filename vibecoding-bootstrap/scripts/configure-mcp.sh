#!/usr/bin/env bash
set -euo pipefail

CODEX_HOME="${CODEX_HOME:-$HOME/.codex}"
DRY_RUN=0
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
