#!/usr/bin/env bash
set -euo pipefail

CODEX_HOME="${CODEX_HOME:-$HOME/.codex}"
INSTALL_SELF=0
FORCE_SELF_UPDATE=0
DRY_RUN=0
SKIP_VERIFY=0
DEEP_VERIFY=0
LOCAL_SKILL_PATHS=()
STARTER_SKILLS=("find-skills" "playwright" "screenshot" "netlify-deploy" "imagegen" "openai-docs")

while [[ $# -gt 0 ]]; do
  case "$1" in
    --codex-home)
      CODEX_HOME="$2"
      shift 2
      ;;
    --install-self)
      INSTALL_SELF=1
      shift
      ;;
    --force-self-update)
      FORCE_SELF_UPDATE=1
      shift
      ;;
    --local-skill-path)
      LOCAL_SKILL_PATHS+=("$2")
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

abs_dir() {
  (
    cd "$1"
    pwd -P
  )
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

skill_name_from_source() {
  local source_path="$1"
  local skill_file="$source_path/SKILL.md"

  if [[ -f "$skill_file" ]]; then
    local parsed_name
    parsed_name="$(awk '/^name:[[:space:]]*/ { sub(/^name:[[:space:]]*/, "", $0); gsub(/"/, "", $0); print; exit }' "$skill_file")"
    if [[ -n "$parsed_name" ]]; then
      printf '%s' "$parsed_name"
      return
    fi
  fi

  basename "$source_path"
}

copy_skill_payload() {
  local source_path="$1"
  local destination_path="$2"
  local payload_items=("README.md" "SKILL.md" "agents" "references" "scripts" "assets")

  mkdir -p "$destination_path"
  for item in "${payload_items[@]}"; do
    if [[ -e "$source_path/$item" ]]; then
      cp -R "$source_path/$item" "$destination_path/"
    fi
  done
}

copy_skill_folder() {
  local source_path="$1"
  local destination_root="$2"
  local skill_name
  skill_name="$(skill_name_from_source "$source_path")"
  local destination_path="$destination_root/$skill_name"

  if [[ -d "$destination_path" ]]; then
    local source_abs
    local destination_abs
    source_abs="$(abs_dir "$source_path")"
    destination_abs="$(abs_dir "$destination_path")"

    if [[ "$source_abs" == "$destination_abs" ]]; then
      printf '%-22s %-18s %s\n' "$skill_name" "already-installed" "$destination_path"
      return
    fi

    if (( ! FORCE_SELF_UPDATE )); then
      printf '%-22s %-18s %s\n' "$skill_name" "skipped-existing" "$destination_path"
      return
    fi

    local backup_path="${destination_path}.bak.$(date +%Y%m%d-%H%M%S)"
    if (( DRY_RUN )); then
      printf '%-22s %-18s %s\n' "$skill_name" "whatif-update" "$destination_path"
      return
    fi

    cp -R "$destination_path" "$backup_path"
    rm -rf "$destination_path"
    copy_skill_payload "$source_path" "$destination_path"
    printf '%-22s %-18s %s\n' "$skill_name" "updated" "$destination_path"
    return
  fi

  if (( DRY_RUN )); then
    printf '%-22s %-18s %s\n' "$skill_name" "whatif-install" "$destination_path"
    return
  fi

  copy_skill_payload "$source_path" "$destination_path"
  printf '%-22s %-18s %s\n' "$skill_name" "installed" "$destination_path"
}

skills_path="$CODEX_HOME/skills"
system_skills_path="$skills_path/.system"

if (( DRY_RUN )); then
  echo "What if: would ensure skill directory exists at $skills_path"
else
  mkdir -p "$skills_path"
fi

echo "Local skill copy results"
printf '%-22s %-18s %s\n' "name" "status" "path"
if (( INSTALL_SELF )); then
  self_root="$(cd "$(dirname "$0")/.." && pwd -P)"
  copy_skill_folder "$self_root" "$skills_path"
fi

for local_skill_path in "${LOCAL_SKILL_PATHS[@]}"; do
  if [[ ! -d "$local_skill_path" ]]; then
    printf '%-22s %-18s %s\n' "$(basename "$local_skill_path")" "missing-source" "$local_skill_path"
    continue
  fi

  copy_skill_folder "$local_skill_path" "$skills_path"
done

echo
echo "Starter skill audit"
printf '%-16s %-10s %-10s\n' "name" "status" "installed"
missing=()
for skill in "${STARTER_SKILLS[@]}"; do
  location="$(skill_location "$skill" "$skills_path" "$system_skills_path")"
  if [[ "$location" == "missing" ]]; then
    printf '%-16s %-10s %-10s\n' "$skill" "$location" "no"
    missing+=("$skill")
  else
    printf '%-16s %-10s %-10s\n' "$skill" "$location" "yes"
  fi
done

if [[ ${#missing[@]} -gt 0 ]]; then
  echo
  echo "Missing starter skills: ${missing[*]}" >&2
  if [[ -d "$system_skills_path/skill-installer" ]]; then
    echo "Suggested prompt: Use \$skill-installer to install these skills: ${missing[*]}"
  else
    echo "skill-installer is not available in .system. Install missing skills manually or add skill-installer first." >&2
  fi
fi

if (( DRY_RUN == 0 && SKIP_VERIFY == 0 )) && (( INSTALL_SELF == 1 || ${#LOCAL_SKILL_PATHS[@]} > 0 )); then
  verify_script="$(cd "$(dirname "$0")" && pwd -P)/verify-setup.sh"
  if [[ -f "$verify_script" ]]; then
    echo
    echo "Post-install check"
    if (( DEEP_VERIFY )); then
      bash "$verify_script" --codex-home "$CODEX_HOME" --deep
    else
      bash "$verify_script" --codex-home "$CODEX_HOME"
    fi
  else
    echo "verify-setup.sh was not found, so the post-install check was skipped." >&2
  fi
fi
