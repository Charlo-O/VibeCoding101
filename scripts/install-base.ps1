[CmdletBinding(SupportsShouldProcess)]
param(
    [string]$PythonWingetId = "Python.Python.3.12",
    [switch]$SkipVerify,
    [switch]$DeepVerify
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

function Test-CommandExists {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Name
    )

    return [bool](Get-Command $Name -ErrorAction SilentlyContinue)
}

function Add-PathCandidate {
    param(
        [string]$Candidate
    )

    if ([string]::IsNullOrWhiteSpace($Candidate)) {
        return
    }

    if (-not (Test-Path $Candidate)) {
        return
    }

    $parts = $env:Path -split ";"
    if ($parts -contains $Candidate) {
        return
    }

    $env:Path = "{0};{1}" -f $env:Path.TrimEnd(";"), $Candidate
}

function Refresh-KnownPaths {
    Add-PathCandidate -Candidate "C:\Program Files\Git\cmd"
    Add-PathCandidate -Candidate "C:\Program Files\nodejs"
    Add-PathCandidate -Candidate (Join-Path $env:USERPROFILE ".local\bin")

    $pythonRoot = Join-Path $env:LOCALAPPDATA "Programs\Python"
    if (Test-Path $pythonRoot) {
        $latestPython = Get-ChildItem $pythonRoot -Directory | Sort-Object Name -Descending | Select-Object -First 1
        if ($latestPython) {
            Add-PathCandidate -Candidate $latestPython.FullName
            Add-PathCandidate -Candidate (Join-Path $latestPython.FullName "Scripts")
        }
    }
}

function Install-WingetPackage {
    param(
        [Parameter(Mandatory = $true)]
        [hashtable]$Package
    )

    if (Test-CommandExists -Name $Package.Command) {
        return [pscustomobject]@{
            name   = $Package.Name
            status = "already-installed"
            note   = $Package.Command
        }
    }

    if (-not (Test-CommandExists -Name "winget")) {
        throw "winget is not available. Stop here and guide the user through installing App Installer from the Microsoft Store."
    }

    if (-not $PSCmdlet.ShouldProcess($Package.Name, ("Install via winget id {0}" -f $Package.Id))) {
        return [pscustomobject]@{
            name   = $Package.Name
            status = "whatif"
            note   = $Package.Id
        }
    }

    & winget install --id $Package.Id --exact --source winget --accept-package-agreements --accept-source-agreements
    $exitCode = $LASTEXITCODE
    Refresh-KnownPaths

    if ($exitCode -ne 0) {
        return [pscustomobject]@{
            name   = $Package.Name
            status = "failed"
            note   = "winget exit code $exitCode"
        }
    }

    $visibleNow = Test-CommandExists -Name $Package.Command
    [pscustomobject]@{
        name   = $Package.Name
        status = if ($visibleNow) { "installed" } else { "restart-shell" }
        note   = $Package.Id
    }
}

function Invoke-BaseRuntimeCheck {
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

function Invoke-BasePostInstallCheck {
    param(
        [switch]$DeepVerify
    )

    $requiredTools = @("git", "node", "npx", "python", "uv", "uvx")
    $missingTools = @($requiredTools | Where-Object { -not (Test-CommandExists -Name $_) })
    $runtimeChecks = New-Object System.Collections.Generic.List[object]

    if ($DeepVerify) {
        $runtimeCommands = @(
            @{ name = "git"; command = "git"; args = @("--version") }
            @{ name = "node"; command = "node"; args = @("--version") }
            @{ name = "npx"; command = "npx"; args = @("--version") }
            @{ name = "python"; command = "python"; args = @("--version") }
            @{ name = "uv"; command = "uv"; args = @("--version") }
            @{ name = "uvx"; command = "uvx"; args = @("--version") }
        )

        foreach ($runtimeCommand in $runtimeCommands) {
            if (Test-CommandExists -Name $runtimeCommand.command) {
                $runtimeChecks.Add((Invoke-BaseRuntimeCheck -Name $runtimeCommand.name -Command $runtimeCommand.command -Arguments $runtimeCommand.args))
            }
        }
    }

    $ready = $missingTools.Count -eq 0
    if ($DeepVerify -and ($runtimeChecks | Where-Object { $_.status -eq "failed" })) {
        $ready = $false
    }

    Write-Output "Post-install check"
    Write-Output ("Base ready: {0}" -f $ready)

    if ($missingTools.Count -gt 0) {
        Write-Warning ("Missing base tools: {0}" -f ($missingTools -join ", "))
    }

    if ($DeepVerify -and $runtimeChecks.Count -gt 0) {
        Write-Output "Runtime checks"
        $runtimeChecks | Format-Table -AutoSize | Out-String | Write-Output
    }

    if (-not $ready) {
        exit 1
    }
}

Refresh-KnownPaths

$packages = @(
    @{ Name = "Git"; Command = "git"; Id = "Git.Git" }
    @{ Name = "Node.js LTS"; Command = "node"; Id = "OpenJS.NodeJS.LTS" }
    @{ Name = "Python 3.12"; Command = "python"; Id = $PythonWingetId }
    @{ Name = "uv"; Command = "uv"; Id = "astral-sh.uv" }
)

$results = foreach ($package in $packages) {
    Install-WingetPackage -Package $package
}

$pnpmStatus = [pscustomobject]@{
    name   = "pnpm"
    status = "skipped"
    note   = "Node.js is not available."
}

Refresh-KnownPaths

if (Test-CommandExists -Name "node") {
    if (Test-CommandExists -Name "pnpm") {
        $pnpmStatus = [pscustomobject]@{
            name   = "pnpm"
            status = "already-installed"
            note   = "pnpm is already available."
        }
    }
    elseif (Test-CommandExists -Name "corepack") {
        if ($PSCmdlet.ShouldProcess("corepack", "Enable corepack and activate pnpm")) {
            & corepack enable
            $enableExit = $LASTEXITCODE
            if ($enableExit -eq 0) {
                & corepack prepare pnpm@latest --activate
                $prepareExit = $LASTEXITCODE
                Refresh-KnownPaths
                $pnpmStatus = [pscustomobject]@{
                    name   = "pnpm"
                    status = if (($prepareExit -eq 0) -and (Test-CommandExists -Name "pnpm")) { "ready" } elseif ($prepareExit -eq 0) { "restart-shell" } else { "failed" }
                    note   = if ($prepareExit -eq 0) { "Activated with corepack." } else { "corepack prepare exit code $prepareExit" }
                }
            }
            else {
                $pnpmStatus = [pscustomobject]@{
                    name   = "pnpm"
                    status = "failed"
                    note   = "corepack enable exit code $enableExit"
                }
            }
        }
        else {
            $pnpmStatus = [pscustomobject]@{
                name   = "pnpm"
                status = "whatif"
                note   = "Would enable corepack and activate pnpm."
            }
        }
    }
    else {
        $pnpmStatus = [pscustomobject]@{
            name   = "pnpm"
            status = "restart-shell"
            note   = "Node.js is installed, but corepack is not visible in the current shell yet."
        }
    }
}

Write-Output "Base package results"
$results | Format-Table -AutoSize | Out-String | Write-Output

Write-Output "pnpm result"
$pnpmStatus | Format-Table -AutoSize | Out-String | Write-Output

$failed = @($results | Where-Object { $_.status -eq "failed" })
if ($failed.Count -gt 0 -or $pnpmStatus.status -eq "failed") {
    exit 1
}

$shouldRunPostInstallCheck = (-not $WhatIfPreference) -and (-not $SkipVerify)
if ($shouldRunPostInstallCheck) {
    Write-Output ""
    Invoke-BasePostInstallCheck -DeepVerify:$DeepVerify
}
