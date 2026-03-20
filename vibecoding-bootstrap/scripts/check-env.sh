#!/usr/bin/env bash
set -euo pipefail

CODEX_HOME="${CODEX_HOME:-$HOME/.codex}"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --codex-home)
      CODEX_HOME="$2"
      shift 2
      ;;
    *)
      echo "Unknown argument: $1" >&2
      exit 2
      ;;
  esac
done

command_version() {
  local name="$1"
  shift || true

  if ! command -v "$name" >/dev/null 2>&1; then
    return 1
  fi

  local version="available"
  if output=$("$name" "$@" 2>/dev/null | head -n 1); then
    if [[ -n "$output" ]]; then
      version="$output"
    fi
  fi

  printf '%s' "$version"
}

print_tool_status() {
  local name="$1"
  shift || true

  if command -v "$name" >/dev/null 2>&1; then
    local path
    path="$(command -v "$name")"
    local version
    version="$(command_version "$name" "$@" || true)"
    printf '%-12s %-7s %-30s %s\n' "$name" "yes" "${version:-available}" "$path"
  else
    printf '%-12s %-7s %-30s %s\n' "$name" "no" "-" "-"
  fi
}

has_mcp_section() {
  local section="$1"
  local config_path="$2"

  [[ -f "$config_path" ]] && grep -Eq "^\\[mcp_servers\\.${section//./\\.}\\]$" "$config_path"
}

skill_location() {
  local name="$1"
  local user_skills="$2"
  local system_skills="$3"

  if [[ -d "$user_skills/$name" ]]; then
    printf 'user'
  elif [[ -d "$system_skills/$name" ]]; then
    printf 'system'
  else
    printf 'missing'
  fi
}

config_path="$CODEX_HOME/config.toml"
skills_path="$CODEX_HOME/skills"
system_skills_path="$skills_path/.system"

echo "Directories"
printf '%-14s %-7s %s\n' "name" "found" "path"
for entry in "$CODEX_HOME" "$config_path" "$skills_path" "$system_skills_path"; do
  label="unknown"
  case "$entry" in
    "$CODEX_HOME") label="codex-home" ;;
    "$config_path") label="config" ;;
    "$skills_path") label="skills" ;;
    "$system_skills_path") label="system-skills" ;;
  esac

  if [[ -e "$entry" ]]; then
    printf '%-14s %-7s %s\n' "$label" "yes" "$entry"
  else
    printf '%-14s %-7s %s\n' "$label" "no" "$entry"
  fi
done
echo

echo "Tools"
printf '%-12s %-7s %-30s %s\n' "name" "found" "version" "path"
print_tool_status "brew" "--version"
print_tool_status "git" "--version"
print_tool_status "node" "--version"
print_tool_status "npm" "--version"
print_tool_status "npx" "--version"
print_tool_status "corepack" "--version"
print_tool_status "pnpm" "--version"
print_tool_status "python3" "--version"
print_tool_status "uv" "--version"
print_tool_status "uvx" "--version"
echo

echo "MCP servers"
printf '%-12s %-7s\n' "name" "found"
for profile in context7 fetch shadcn; do
  if has_mcp_section "$profile" "$config_path"; then
    printf '%-12s %-7s\n' "$profile" "yes"
  else
    printf '%-12s %-7s\n' "$profile" "no"
  fi
done
echo

echo "Starter skills"
printf '%-16s %-7s %-10s\n' "name" "found" "location"
for skill in find-skills playwright screenshot netlify-deploy imagegen openai-docs; do
  location="$(skill_location "$skill" "$skills_path" "$system_skills_path")"
  if [[ "$location" == "missing" ]]; then
    printf '%-16s %-7s %-10s\n' "$skill" "no" "$location"
  else
    printf '%-16s %-7s %-10s\n' "$skill" "yes" "$location"
  fi
done
