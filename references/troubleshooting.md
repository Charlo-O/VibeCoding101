# Troubleshooting

## `winget` is missing

The scripts rely on `winget` for trusted Windows package installation. If it is missing:

1. Install or update App Installer from the Microsoft Store.
2. Open a fresh PowerShell window.
3. Re-run `scripts/check-env.ps1`.

Do not replace this with random direct-download URLs unless the user explicitly approves that route.

## `brew` is missing

The macOS scripts rely on Homebrew for trusted package installation. If it is missing:

1. Install Homebrew from the official site: [brew.sh](https://brew.sh/).
2. Open a fresh terminal.
3. Re-run `scripts/check-env.sh`.

Do not replace this with random copy-pasted install scripts from third-party blogs.

## A tool installed but PowerShell still cannot find it

This is usually a PATH refresh problem.

1. Close the current terminal or Codex session.
2. Open a fresh terminal.
3. Re-run `scripts/verify-setup.ps1`.

`scripts/install-base.ps1` tries to patch common PATH entries in the current process, but Windows installers do not always update the running shell cleanly.

## A tool installed but zsh or Bash still cannot find it

This is usually a shell profile or PATH refresh problem.

1. Close the current terminal.
2. Open a fresh terminal.
3. Run `bash ./scripts/check-env.sh`.

If Homebrew was just installed, make sure its shell init line is present in `~/.zprofile` or `~/.bash_profile` as instructed by Homebrew.

## PowerShell blocks the script

Run with:

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\check-env.ps1
```

If the machine is heavily locked down by policy, use a signed script workflow or ask the user to run the commands in an approved shell.

## Homebrew asks for Xcode Command Line Tools

That is normal on a fresh macOS machine. Install the command line tools first, then rerun `scripts/install-base.sh`.

## MCP command exists but deep verification fails

Check these in order:

1. `node`, `npx`, `uv`, and `uvx` are all visible in a fresh shell.
2. Network access is available.
3. The matching `[mcp_servers.<name>]` block exists in `~/.codex/config.toml`.
4. The package registry is not blocked by a proxy or firewall.

If the config looks correct but runtime checks still fail, separate the problem into:

- dependency issue
- PATH issue
- network issue
- remote package outage

## Starter skills are missing

Use the existing `skill-installer` system skill when possible instead of inventing a one-off download workflow. The bundled `scripts/install-skills.ps1` and `scripts/install-skills.sh` scripts audit starter skills and print a suggested next prompt when `skill-installer` is available.
