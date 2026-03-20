---
name: vibecoding-bootstrap
description: Bootstrap and repair a beginner-friendly vibecoding environment on Windows or macOS with the core local tools, Codex skill folders, and MCP server configuration. Use when a user is new to vibecoding or Codex and asks to inspect, install, fix, or verify Git, Node.js, pnpm, Python, uv, ~/.codex/config.toml MCP entries, or starter skills on Windows or macOS.
---

# VibeCoding Bootstrap

## Overview

Make a Windows or macOS machine ready for beginner-level vibecoding with the smallest useful toolset: Git, Node.js LTS, corepack/pnpm, Python 3.12+, uv, starter MCP entries, and a starter skill audit.

Choose the script set by platform:

- Windows: use the `.ps1` scripts in PowerShell.
- macOS: use the `.sh` scripts in Bash or zsh.

Prefer the bundled scripts over ad hoc terminal commands. The mutating scripts support dry-run mode and back up `config.toml` before changing MCP settings.

## Workflow

1. Inspect the machine first with `scripts/check-env.ps1`.
2. Install missing base tools with `scripts/install-base.ps1`.
3. Configure missing MCP entries with `scripts/configure-mcp.ps1`.
4. Audit or install local skills with `scripts/install-skills.ps1`.
5. Confirm readiness with `scripts/verify-setup.ps1`.

On macOS, run the matching `.sh` scripts in the same order.

## Quick Start

### Windows

Run from the skill root:

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\check-env.ps1
powershell -ExecutionPolicy Bypass -File .\scripts\install-base.ps1
powershell -ExecutionPolicy Bypass -File .\scripts\configure-mcp.ps1
powershell -ExecutionPolicy Bypass -File .\scripts\install-skills.ps1 -InstallSelf
powershell -ExecutionPolicy Bypass -File .\scripts\verify-setup.ps1 -Deep
```

Use `-WhatIf` with `install-base.ps1`, `configure-mcp.ps1`, and `install-skills.ps1` when you want a dry run first.

`install-base.ps1`, `configure-mcp.ps1`, and `install-skills.ps1` now run a lightweight post-step check after a real change. Use `-SkipVerify` to skip that check and `-DeepVerify` when you want a stricter runtime pass.

`install-skills.ps1` now runs a lightweight post-install check after a real install or update. Keep `verify-setup.ps1` as the final explicit confirmation step after the full bootstrap flow.

### macOS

Run from the skill root:

```bash
bash ./scripts/check-env.sh
bash ./scripts/install-base.sh --dry-run
bash ./scripts/install-base.sh
bash ./scripts/configure-mcp.sh --dry-run
bash ./scripts/configure-mcp.sh
bash ./scripts/install-skills.sh --install-self --dry-run
bash ./scripts/install-skills.sh --install-self
bash ./scripts/verify-setup.sh --deep
```

Use `--dry-run` with `install-base.sh`, `configure-mcp.sh`, and `install-skills.sh` before making changes.

`install-base.sh`, `configure-mcp.sh`, and `install-skills.sh` now run a lightweight post-step check after a real change. Use `--skip-verify` to skip that check and `--deep-verify` when you want a stricter runtime pass.

`install-skills.sh` now runs a lightweight post-install check after a real install or update. Keep `verify-setup.sh` as the final explicit confirmation step after the full bootstrap flow.

## Script Guide

### `scripts/check-env.ps1`

- Inspect the current Windows machine.
- Report tool availability for `winget`, `git`, `node`, `npm`, `npx`, `corepack`, `pnpm`, `python`, `py`, `uv`, and `uvx`.
- Report whether `~/.codex`, `~/.codex/config.toml`, and `~/.codex/skills` exist.
- Report whether starter MCP entries and starter skills are already present.
- Use `-AsJson` when another script needs structured output.

### `scripts/check-env.sh`

- Inspect the current macOS machine.
- Report tool availability for `brew`, `git`, `node`, `npm`, `npx`, `corepack`, `pnpm`, `python3`, `uv`, and `uvx`.
- Report whether `~/.codex`, `~/.codex/config.toml`, and `~/.codex/skills` exist.
- Report whether starter MCP entries and starter skills are already present.

### `scripts/install-base.ps1`

- Install missing Windows packages with `winget`.
- Target `Git.Git`, `OpenJS.NodeJS.LTS`, `Python.Python.3.12`, and `astral-sh.uv`.
- Refresh common PATH locations in the current shell after installs.
- Enable `corepack` and activate `pnpm` when Node.js is available.
- Run a post-install base tool check after a real run. Use `-SkipVerify` to skip the check and `-DeepVerify` for runtime command checks.
- If a newly installed command still is not visible, stop and tell the user to restart the terminal or Codex, then rerun verification.

### `scripts/install-base.sh`

- Install missing macOS packages with Homebrew.
- Target `git`, `node`, `python`, and `uv`.
- Stop early if Homebrew is missing, then tell the user to install Homebrew first from the official site.
- Enable `corepack` and activate `pnpm` when Node.js is available.
- Run a post-install base tool check after a real run. Use `--skip-verify` to skip the check and `--deep-verify` for runtime command checks.
- Tell the user to open a fresh shell when a newly installed command is not yet visible.

### `scripts/configure-mcp.ps1`

- Ensure `~/.codex/config.toml` exists.
- Back up the current file before any write.
- Ensure `[mcp_servers]` exists.
- Append missing entries for:
  - `context7` via `npx -y @upstash/context7-mcp`
  - `fetch` via `uvx mcp-server-fetch`
  - `shadcn` via `npx shadcn-vue@latest mcp`
- Run a post-config MCP check after a real run. Use `-SkipVerify` to skip the check and `-DeepVerify` for runtime command checks.
- Do not overwrite existing MCP blocks unless the user explicitly asks for cleanup or refactoring.

### `scripts/configure-mcp.sh`

- Do the same MCP setup on macOS with Bash.
- Support `--dry-run`, `--skip-verify`, and `--deep-verify`.
- Append only missing MCP blocks and back up the existing `config.toml` first.
- Run a post-config MCP check after a real run unless `--skip-verify` is used.

### `scripts/install-skills.ps1`

- Ensure `~/.codex/skills` exists.
- Audit the starter skill set: `find-skills`, `playwright`, `screenshot`, `netlify-deploy`, `imagegen`, `openai-docs`.
- Optionally install this skill into `~/.codex/skills` with `-InstallSelf`.
- Optionally copy additional local skill folders into `~/.codex/skills` with `-LocalSkillPaths`.
- Run `verify-setup.ps1` automatically after a real install or update. Use `-SkipVerify` to skip the post-install check and `-DeepVerify` for a deeper one.
- When starter skills are missing, prefer routing further installs through the existing `skill-installer` system skill instead of hardcoding remote sources here.

### `scripts/install-skills.sh`

- Do the same skill audit and local skill copy workflow on macOS with Bash.
- Support `--install-self`, `--force-self-update`, `--local-skill-path`, `--dry-run`, `--skip-verify`, and `--deep-verify`.
- Run `verify-setup.sh` automatically after a real install or update unless `--skip-verify` is used.
- When starter skills are missing, print a suggested next prompt that uses `skill-installer`.

### `scripts/verify-setup.ps1`

- Re-run `check-env.ps1` and fail fast if critical tools are still missing.
- Confirm required MCP entries exist.
- Use `-Deep` to run lightweight runtime checks for `context7`, `fetch`, and `shadcn`.
- Exit non-zero when the machine is not ready.

### `scripts/verify-setup.sh`

- Re-check the macOS environment.
- Fail when critical tools or required MCP entries are still missing.
- Use `--deep` to run lightweight runtime checks for `context7`, `fetch`, and `shadcn`.

## Operating Rules

- Inspect before changing anything.
- Prefer `winget` on Windows and `brew` on macOS over hand-written download links.
- Back up configuration before writing to it.
- Never write API keys or secrets into `config.toml`.
- Keep the MCP setup minimal for beginners. Add more servers only when a real workflow justifies them.
- Treat skill installation separately from MCP installation so failures are easier to isolate.
- If `winget` or `brew` is unavailable, stop and give manual guidance instead of scripting untrusted downloads from arbitrary sources.

## References

- Read `references/packages.md` for the supported package IDs, starter MCP profiles, and recommended starter skills.
- Read `references/troubleshooting.md` when PATH refresh, Homebrew, PowerShell policy, shell profile, or network-related problems appear.
