[CmdletBinding(SupportsShouldProcess)]
param(
    [string]$CodexHome = $(if ($env:CODEX_HOME) { $env:CODEX_HOME } else { Join-Path $env:USERPROFILE ".codex" }),
    [switch]$InstallSelf,
    [switch]$ForceSelfUpdate,
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

function Install-LocalSkillFolder {
    param(
        [Parameter(Mandatory = $true)]
        [string]$SourcePath,

        [Parameter(Mandatory = $true)]
        [string]$DestinationRoot
    )

    $resolvedSource = (Resolve-Path $SourcePath).Path
    $skillName = Split-Path -Leaf $resolvedSource
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
            Copy-Item -Path $resolvedSource -Destination $destinationPath -Recurse -Force
        }

        return [pscustomobject]@{
            name   = $skillName
            status = "updated"
            note   = $destinationPath
        }
    }

    if ($PSCmdlet.ShouldProcess($destinationPath, "Copy local skill from $resolvedSource")) {
        Copy-Item -Path $resolvedSource -Destination $destinationPath -Recurse -Force
    }

    return [pscustomobject]@{
        name   = $skillName
        status = "installed"
        note   = $destinationPath
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
