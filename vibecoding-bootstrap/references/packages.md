# Packages

## Base Windows Packages

Use these `winget` identifiers in `scripts/install-base.ps1`:

- `Git.Git`
- `OpenJS.NodeJS.LTS`
- `Python.Python.3.12`
- `astral-sh.uv`

## Base macOS Packages

Use these Homebrew formula names in `scripts/install-base.sh`:

- `git`
- `node`
- `python`
- `uv`

The base environment target is:

- `git` for cloning repos and basic version control
- `node` plus `corepack` and `pnpm` for modern JavaScript tooling
- `python` or `python3` for scripts and compatibility with many dev tools
- `uv` and `uvx` for lightweight Python package and MCP execution

## Starter MCP Profiles

`scripts/configure-mcp.ps1` and `scripts/configure-mcp.sh` manage these profiles:

- `context7`: documentation lookup via `npx -y @upstash/context7-mcp`
- `fetch`: HTTP fetching via `uvx mcp-server-fetch`
- `shadcn`: UI component tooling via `npx shadcn-vue@latest mcp`

These are intentionally basic and broadly useful. Add project-specific servers later instead of front-loading them for a beginner.

## Starter Skills

Audit these skills first:

- `find-skills`
- `playwright`
- `screenshot`
- `netlify-deploy`
- `imagegen`
- `openai-docs`

Rationale:

- `find-skills` helps discover missing capabilities before inventing custom workflows.
- `playwright` is the fastest way to validate browser flows and UI issues.
- `screenshot` helps with desktop-level capture when browser tooling is not enough.
- `netlify-deploy` covers a common beginner deployment path for static sites.
- `imagegen` and `openai-docs` are practical for content and OpenAI API onboarding.
