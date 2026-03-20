[CmdletBinding(SupportsShouldProcess)]
param(
    [string]$CodexHome = $(if ($env:CODEX_HOME) { $env:CODEX_HOME } else { Join-Path $env:USERPROFILE ".codex" }),
    [string[]]$Profiles = @("context7", "fetch", "shadcn")
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

function Write-Utf8NoBomFile {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Path,

        [Parameter(Mandatory = $true)]
        [string]$Content
    )

    $encoding = New-Object System.Text.UTF8Encoding($false)
    [System.IO.File]::WriteAllText($Path, $Content, $encoding)
}

$profileBlocks = [ordered]@{
    context7 = @'
[mcp_servers.context7]
type = "stdio"
command = "npx"
args = ["-y", "@upstash/context7-mcp"]
'@
    fetch = @'
[mcp_servers.fetch]
type = "stdio"
command = "uvx"
args = ["mcp-server-fetch"]
'@
    shadcn = @'
[mcp_servers.shadcn]
type = "stdio"
command = "npx"
args = ["shadcn-vue@latest", "mcp"]
'@
}

$configPath = Join-Path $CodexHome "config.toml"
$configDir = Split-Path -Parent $configPath
if (-not (Test-Path $configDir)) {
    if ($PSCmdlet.ShouldProcess($configDir, "Create Codex home directory for config")) {
        New-Item -ItemType Directory -Path $configDir -Force | Out-Null
    }
}

$originalText = if (Test-Path $configPath) { Get-Content -Raw $configPath } else { "" }
$updatedText = $originalText

if ($updatedText -notmatch '(?m)^\[mcp_servers\]\s*$') {
    if ([string]::IsNullOrWhiteSpace($updatedText)) {
        $updatedText = "[mcp_servers]`r`n"
    }
    else {
        $updatedText = $updatedText.TrimEnd() + "`r`n`r`n[mcp_servers]`r`n"
    }
}

$addedProfiles = New-Object System.Collections.Generic.List[string]
$skippedProfiles = New-Object System.Collections.Generic.List[string]

foreach ($profile in $Profiles) {
    if (-not $profileBlocks.Contains($profile)) {
        throw "Unsupported MCP profile '$profile'. Supported values: $($profileBlocks.Keys -join ', ')"
    }

    $escapedProfile = [regex]::Escape($profile)
    if ($updatedText -match "(?m)^\[mcp_servers\.$escapedProfile\]\s*$") {
        $skippedProfiles.Add($profile)
        continue
    }

    $updatedText = $updatedText.TrimEnd() + "`r`n`r`n" + $profileBlocks[$profile].Trim() + "`r`n"
    $addedProfiles.Add($profile)
}

if ($addedProfiles.Count -eq 0) {
    Write-Output "No MCP changes were needed."
    if ($skippedProfiles.Count -gt 0) {
        Write-Output ("Already configured: {0}" -f ($skippedProfiles -join ", "))
    }
    exit 0
}

$timestamp = Get-Date -Format "yyyyMMdd-HHmmss"
$backupPath = if (Test-Path $configPath) { "$configPath.bak.$timestamp" } else { $null }

if ($PSCmdlet.ShouldProcess($configPath, ("Backup and append MCP profiles: {0}" -f ($addedProfiles -join ", ")))) {
    if ($backupPath) {
        Copy-Item -Path $configPath -Destination $backupPath -Force
    }

    Write-Utf8NoBomFile -Path $configPath -Content $updatedText
}

Write-Output ("Added MCP profiles: {0}" -f ($addedProfiles -join ", "))
if ($backupPath) {
    Write-Output ("Backup created: {0}" -f $backupPath)
}
if ($skippedProfiles.Count -gt 0) {
    Write-Output ("Already configured: {0}" -f ($skippedProfiles -join ", "))
}
