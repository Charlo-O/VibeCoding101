[CmdletBinding()]
param(
    [string]$CodexHome = $(if ($env:CODEX_HOME) { $env:CODEX_HOME } else { Join-Path $env:USERPROFILE ".codex" }),
    [switch]$Deep
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

function Invoke-RuntimeCheck {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Name,

        [Parameter(Mandatory = $true)]
        [string]$Command,

        [Parameter(Mandatory = $true)]
        [string[]]$Arguments
    )

    try {
        $output = & $Command @Arguments 2>&1
        $exitCode = $LASTEXITCODE
        [pscustomobject]@{
            name    = $Name
            status  = if ($exitCode -eq 0) { "passed" } else { "failed" }
            details = (($output | Select-Object -First 1) -as [string])
        }
    }
    catch {
        [pscustomobject]@{
            name    = $Name
            status  = "failed"
            details = $_.Exception.Message
        }
    }
}

$checkScript = Join-Path $PSScriptRoot "check-env.ps1"
if (-not (Test-Path $checkScript)) {
    throw "Missing check-env.ps1 in $PSScriptRoot"
}

$report = & $checkScript -CodexHome $CodexHome -AsJson | ConvertFrom-Json

$criticalTools = @("winget", "git", "node", "npx", "python", "uv", "uvx")
$missingCritical = @(
    $report.tools |
        Where-Object { ($criticalTools -contains $_.name) -and (-not $_.found) } |
        Select-Object -ExpandProperty name
)

$missingMcp = @(
    $report.mcp_servers |
        Where-Object { -not $_.present } |
        Select-Object -ExpandProperty name
)

$runtimeChecks = New-Object System.Collections.Generic.List[object]

if ($Deep) {
    $toolIndex = @{}
    foreach ($tool in $report.tools) {
        $toolIndex[$tool.name] = [bool]$tool.found
    }

    if ($toolIndex["npx"]) {
        $runtimeChecks.Add((Invoke-RuntimeCheck -Name "context7" -Command "npx" -Arguments @("-y", "@upstash/context7-mcp", "--help")))
        $runtimeChecks.Add((Invoke-RuntimeCheck -Name "shadcn" -Command "npx" -Arguments @("shadcn-vue@latest", "mcp", "--help")))
    }

    if ($toolIndex["uvx"]) {
        $runtimeChecks.Add((Invoke-RuntimeCheck -Name "fetch" -Command "uvx" -Arguments @("mcp-server-fetch", "--help")))
    }
}

$ready = ($missingCritical.Count -eq 0) -and ($missingMcp.Count -eq 0)
if ($Deep -and ($runtimeChecks | Where-Object { $_.status -eq "failed" })) {
    $ready = $false
}

Write-Output ("Ready: {0}" -f $ready)
Write-Output ("Codex home: {0}" -f $report.codex_home)

if ($missingCritical.Count -gt 0) {
    Write-Warning ("Missing critical tools: {0}" -f ($missingCritical -join ", "))
}

if ($missingMcp.Count -gt 0) {
    Write-Warning ("Missing MCP profiles: {0}" -f ($missingMcp -join ", "))
}

if ($Deep -and $runtimeChecks.Count -gt 0) {
    Write-Output "Runtime checks"
    $runtimeChecks | Format-Table -AutoSize | Out-String | Write-Output
}

if (-not $ready) {
    exit 1
}
