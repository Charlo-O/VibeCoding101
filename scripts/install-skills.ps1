[CmdletBinding(SupportsShouldProcess)]
param(
    [string]$CodexHome = $(if ($env:CODEX_HOME) { $env:CODEX_HOME } else { Join-Path $env:USERPROFILE ".codex" }),
    [switch]$InstallSelf,
    [switch]$ForceSelfUpdate,
    [switch]$SkipVerify,
    [switch]$DeepVerify,
    [string[]]$LocalSkillPaths = @(),
    [string[]]$StarterSkills = @("find-skills", "playwright", "screenshot", "netlify-deploy", "imagegen", "openai-docs")
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

function Get-SkillLocation {
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

    if (Test-Path $userPath) {
        return "user"
    }

    if (Test-Path $systemPath) {
        return "system"
    }

    return "missing"
}

function Get-SkillNameFromPath {
    param(
        [Parameter(Mandatory = $true)]
        [string]$SourcePath
    )

    $skillFile = Join-Path $SourcePath "SKILL.md"
    if (Test-Path $skillFile) {
        $content = Get-Content -Raw $skillFile
        $match = [regex]::Match($content, '(?m)^name:\s*"?([^"\r\n]+)"?\s*$')
        if ($match.Success) {
            return $match.Groups[1].Value.Trim()
        }
    }

    return (Split-Path -Leaf $SourcePath)
}

function Copy-SkillPayload {
    param(
        [Parameter(Mandatory = $true)]
        [string]$SourcePath,

        [Parameter(Mandatory = $true)]
        [string]$DestinationPath
    )

    $payloadItems = @("README.md", "SKILL.md", "agents", "references", "scripts", "assets")
    if (-not (Test-Path $DestinationPath)) {
        New-Item -ItemType Directory -Path $DestinationPath -Force | Out-Null
    }

    foreach ($item in $payloadItems) {
        $sourceItem = Join-Path $SourcePath $item
        if (Test-Path $sourceItem) {
            Copy-Item -Path $sourceItem -Destination $DestinationPath -Recurse -Force
        }
    }
}

function Install-LocalSkillFolder {
    param(
        [Parameter(Mandatory = $true)]
        [string]$SourcePath,

        [Parameter(Mandatory = $true)]
        [string]$DestinationRoot
    )

    $resolvedSource = (Resolve-Path $SourcePath).Path
    $skillName = Get-SkillNameFromPath -SourcePath $resolvedSource
    $destinationPath = Join-Path $DestinationRoot $skillName

    if (Test-Path $destinationPath) {
        if (-not $ForceSelfUpdate) {
            return [pscustomobject]@{
                name   = $skillName
                status = "skipped-existing"
                note   = $destinationPath
            }
        }

        $backupPath = "$destinationPath.bak.$(Get-Date -Format 'yyyyMMdd-HHmmss')"
        if ($PSCmdlet.ShouldProcess($destinationPath, "Backup and replace skill from $resolvedSource")) {
            Copy-Item -Path $destinationPath -Destination $backupPath -Recurse -Force
            Remove-Item -Path $destinationPath -Recurse -Force
            Copy-SkillPayload -SourcePath $resolvedSource -DestinationPath $destinationPath
        }

        return [pscustomobject]@{
            name   = $skillName
            status = "updated"
            note   = $destinationPath
        }
    }

    if ($PSCmdlet.ShouldProcess($destinationPath, "Copy local skill from $resolvedSource")) {
        Copy-SkillPayload -SourcePath $resolvedSource -DestinationPath $destinationPath
    }

    return [pscustomobject]@{
        name   = $skillName
        status = "installed"
        note   = $destinationPath
    }
}

function Invoke-PostInstallCheck {
    param(
        [Parameter(Mandatory = $true)]
        [string]$CodexHome,

        [switch]$DeepVerify
    )

    $verifyScript = Join-Path $PSScriptRoot "verify-setup.ps1"
    if (-not (Test-Path $verifyScript)) {
        Write-Warning "verify-setup.ps1 was not found, so the post-install check was skipped."
        return
    }

    Write-Output "Post-install check"
    $arguments = @("-ExecutionPolicy", "Bypass", "-File", $verifyScript, "-CodexHome", $CodexHome)
    if ($DeepVerify) {
        $arguments += "-Deep"
    }

    & powershell.exe @arguments
    if ($LASTEXITCODE -ne 0) {
        exit $LASTEXITCODE
    }
}

$skillsPath = Join-Path $CodexHome "skills"
$systemSkillsPath = Join-Path $skillsPath ".system"

if (-not (Test-Path $skillsPath)) {
    if ($PSCmdlet.ShouldProcess($skillsPath, "Create user skill directory")) {
        New-Item -ItemType Directory -Path $skillsPath -Force | Out-Null
    }
}

$copyResults = New-Object System.Collections.Generic.List[object]

if ($InstallSelf) {
    $selfRoot = Split-Path -Parent $PSScriptRoot
    if (Test-Path $selfRoot) {
        $copyResults.Add((Install-LocalSkillFolder -SourcePath $selfRoot -DestinationRoot $skillsPath))
    }
}

foreach ($localSkillPath in $LocalSkillPaths) {
    if (-not (Test-Path $localSkillPath)) {
        $copyResults.Add([pscustomobject]@{
            name   = $localSkillPath
            status = "missing-source"
            note   = $localSkillPath
        })
        continue
    }

    $copyResults.Add((Install-LocalSkillFolder -SourcePath $localSkillPath -DestinationRoot $skillsPath))
}

$starterReport = foreach ($skill in $StarterSkills) {
    $location = Get-SkillLocation -Name $skill -UserSkillsPath $skillsPath -SystemSkillsPath $systemSkillsPath
    [pscustomobject]@{
        name     = $skill
        status   = $location
        installed = $location -ne "missing"
    }
}

$missingStarterSkills = @(
    $starterReport |
        Where-Object { -not $_.installed } |
        Select-Object -ExpandProperty name
)
$skillInstallerAvailable = Test-Path (Join-Path $systemSkillsPath "skill-installer")

if ($copyResults.Count -gt 0) {
    Write-Output "Local skill copy results"
    $copyResults | Format-Table -AutoSize | Out-String | Write-Output
}

Write-Output "Starter skill audit"
$starterReport | Format-Table -AutoSize | Out-String | Write-Output

if ($missingStarterSkills.Count -gt 0) {
    Write-Warning ("Missing starter skills: {0}" -f ($missingStarterSkills -join ", "))
    if ($skillInstallerAvailable) {
        Write-Output ("Suggested prompt: Use `$skill-installer to install these skills: {0}" -f ($missingStarterSkills -join ", "))
    }
    else {
        Write-Warning "skill-installer is not available in .system. Install missing skills manually or add skill-installer first."
    }
}

$shouldRunPostInstallCheck = (-not $WhatIfPreference) -and (-not $SkipVerify) -and ($InstallSelf -or $LocalSkillPaths.Count -gt 0)
if ($shouldRunPostInstallCheck) {
    Write-Output ""
    Invoke-PostInstallCheck -CodexHome $CodexHome -DeepVerify:$DeepVerify
}
