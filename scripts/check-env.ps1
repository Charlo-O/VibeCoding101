[CmdletBinding()]
param(
    [string]$CodexHome = $(if ($env:CODEX_HOME) { $env:CODEX_HOME } else { Join-Path $env:USERPROFILE ".codex" }),
    [switch]$AsJson
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

function Get-CommandVersion {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Name,

        [string[]]$Args = @("--version")
    )

    if (-not (Get-Command $Name -ErrorAction SilentlyContinue)) {
        return $null
    }

    try {
        $output = & $Name @Args 2>$null
        if ($LASTEXITCODE -ne 0) {
            return "available"
        }

        $firstLine = $output | Select-Object -First 1
        if ($null -eq $firstLine) {
            return "available"
        }

        return $firstLine.ToString().Trim()
    }
    catch {
        return "available"
    }
}

function Get-ToolStatus {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Name,

        [string[]]$VersionArgs = @("--version")
    )

    $command = Get-Command $Name -ErrorAction SilentlyContinue
    [pscustomobject]@{
        name    = $Name
        found   = [bool]$command
        version = if ($command) { Get-CommandVersion -Name $Name -Args $VersionArgs } else { $null }
        path    = if ($command) { $command.Source } else { $null }
    }
}

function Test-TomlSection {
    param(
        [string]$ConfigText,
        [Parameter(Mandatory = $true)]
        [string]$SectionName
    )

    $escapedSection = [regex]::Escape($SectionName)
    return [bool]($ConfigText -match "(?m)^\[mcp_servers\.$escapedSection\]\s*$")
}

function Get-SkillStatus {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Name,

        [Parameter(Mandatory = $true)]
        [string]$UserSkillsPath,

        [Parameter(Mandatory = $true)]
        [string]$SystemSkillsPath
    )

    $userPath = Join-Path $UserSkillsPath $Name
    $systemPath = Join-Path $SystemSkillsPath $Name
    $location = if (Test-Path $userPath) {
        "user"
    }
    elseif (Test-Path $systemPath) {
        "system"
    }
    else {
        "missing"
    }

    [pscustomobject]@{
        name     = $Name
        present  = $location -ne "missing"
        location = $location
    }
}

$configPath = Join-Path $CodexHome "config.toml"
$skillsPath = Join-Path $CodexHome "skills"
$systemSkillsPath = Join-Path $skillsPath ".system"
$configText = if (Test-Path $configPath) { Get-Content -Raw $configPath } else { "" }

$directories = @(
    [pscustomobject]@{ name = "codex-home"; path = $CodexHome; present = Test-Path $CodexHome },
    [pscustomobject]@{ name = "config"; path = $configPath; present = Test-Path $configPath },
    [pscustomobject]@{ name = "skills"; path = $skillsPath; present = Test-Path $skillsPath },
    [pscustomobject]@{ name = "system-skills"; path = $systemSkillsPath; present = Test-Path $systemSkillsPath }
)

$tools = @(
    Get-ToolStatus -Name "winget"
    Get-ToolStatus -Name "git"
    Get-ToolStatus -Name "node"
    Get-ToolStatus -Name "npm"
    Get-ToolStatus -Name "npx"
    Get-ToolStatus -Name "corepack"
    Get-ToolStatus -Name "pnpm"
    Get-ToolStatus -Name "python"
    Get-ToolStatus -Name "py"
    Get-ToolStatus -Name "uv"
    Get-ToolStatus -Name "uvx"
)

$mcpServers = @(
    [pscustomobject]@{ name = "context7"; present = Test-TomlSection -ConfigText $configText -SectionName "context7" }
    [pscustomobject]@{ name = "fetch"; present = Test-TomlSection -ConfigText $configText -SectionName "fetch" }
    [pscustomobject]@{ name = "shadcn"; present = Test-TomlSection -ConfigText $configText -SectionName "shadcn" }
)

$starterSkills = @(
    Get-SkillStatus -Name "find-skills" -UserSkillsPath $skillsPath -SystemSkillsPath $systemSkillsPath
    Get-SkillStatus -Name "playwright" -UserSkillsPath $skillsPath -SystemSkillsPath $systemSkillsPath
    Get-SkillStatus -Name "screenshot" -UserSkillsPath $skillsPath -SystemSkillsPath $systemSkillsPath
    Get-SkillStatus -Name "netlify-deploy" -UserSkillsPath $skillsPath -SystemSkillsPath $systemSkillsPath
    Get-SkillStatus -Name "imagegen" -UserSkillsPath $skillsPath -SystemSkillsPath $systemSkillsPath
    Get-SkillStatus -Name "openai-docs" -UserSkillsPath $skillsPath -SystemSkillsPath $systemSkillsPath
)

$report = [ordered]@{
    timestamp      = (Get-Date).ToString("s")
    codex_home     = $CodexHome
    directories    = $directories
    tools          = $tools
    mcp_servers    = $mcpServers
    starter_skills = $starterSkills
}

if ($AsJson) {
    $report | ConvertTo-Json -Depth 6
    exit 0
}

Write-Output "Directories"
$directories | Format-Table -AutoSize | Out-String | Write-Output

Write-Output "Tools"
$tools | Format-Table -AutoSize | Out-String | Write-Output

Write-Output "MCP servers"
$mcpServers | Format-Table -AutoSize | Out-String | Write-Output

Write-Output "Starter skills"
$starterSkills | Format-Table -AutoSize | Out-String | Write-Output

$criticalTools = @("winget", "git", "node", "npx", "python", "uv", "uvx")
$missingCritical = @(
    $tools |
        Where-Object { ($criticalTools -contains $_.name) -and (-not $_.found) } |
        Select-Object -ExpandProperty name
)

if ($missingCritical.Count -gt 0) {
    Write-Warning ("Missing critical tools: {0}" -f ($missingCritical -join ", "))
}

$missingMcp = @(
    $mcpServers |
        Where-Object { -not $_.present } |
        Select-Object -ExpandProperty name
)
if ($missingMcp.Count -gt 0) {
    Write-Warning ("Missing MCP profiles: {0}" -f ($missingMcp -join ", "))
}
