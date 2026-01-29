# ============================================================================
#  HerFiles - Windows Dotfiles Management System
# ============================================================================

$script:ModuleRoot = $PSScriptRoot

# Import modules
$sharedPath = Join-Path $script:ModuleRoot "Shared\HerFiles.Shared.psm1"
Import-Module $sharedPath -Force -DisableNameChecking

$modulesPath = Join-Path $script:ModuleRoot "Modules"
Import-Module (Join-Path $modulesPath "PowerShell.psm1") -Force -DisableNameChecking
Import-Module (Join-Path $modulesPath "Starship.psm1") -Force -DisableNameChecking
Import-Module (Join-Path $modulesPath "VSCode\VSCode.psm1") -Force -DisableNameChecking

# ============================================================================
#  CONFIGURATION
# ============================================================================

$script:DEFAULT_FOLDER_NAME = "HerFiles"
$script:ALL_MODULES = [ordered]@{
    PowerShell = "PowerShell"
    Starship   = "Starship"
    VSCode     = "VSCode"
}

# ============================================================================
#  MODULE DETECTION
# ============================================================================

function Get-GatherableModules {
    $available = @()

    $profilePath = Join-Path $env:USERPROFILE "Documents\WindowsPowerShell\Microsoft.PowerShell_profile.ps1"
    if (Test-Path $profilePath) { $available += "PowerShell" }

    $starshipPath = Join-Path $env:USERPROFILE ".config\starship.toml"
    if (Test-Path $starshipPath) { $available += "Starship" }

    $vscodeSettingsPath = Join-Path $env:APPDATA "Code\User\settings.json"
    $vscodeExtensionsPath = Join-Path $env:USERPROFILE ".vscode\extensions\extensions.json"
    if ((Test-Path $vscodeSettingsPath) -or (Test-Path $vscodeExtensionsPath)) { $available += "VSCode" }

    return $available
}

function Get-InstallableModules {
    param([Parameter(Mandatory = $true)][string]$SourcePath)

    $available = @()

    foreach ($moduleName in $script:ALL_MODULES.Keys) {
        $moduleFolder = Join-Path $SourcePath $script:ALL_MODULES[$moduleName]
        if (Test-Path $moduleFolder) {
            $hasContent = (Get-ChildItem -Path $moduleFolder -File -Recurse | Measure-Object).Count -gt 0
            if ($hasContent) { $available += $moduleName }
        }
    }

    return $available
}

# ============================================================================
#  GATHER
# ============================================================================

function Gather-DotFiles {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $false)]
        [string]$Destination = (Join-Path (Get-Location) $script:DEFAULT_FOLDER_NAME),

        [Parameter(Mandatory = $false)]
        [ValidateSet("PowerShell", "Starship", "VSCode")]
        [string[]]$Modules = $null
    )

    Write-HerBanner -Mode "Gather"

    # Auto-detect modules
    if ($null -eq $Modules -or $Modules.Count -eq 0) {
        $Modules = Get-GatherableModules
        if ($Modules.Count -eq 0) {
            Write-HerResult -Type "error" -Message "No configurations found"
            return @{}
        }
    }

    # Show config
    Write-HerRow -Label "Destination" -Value $Destination
    Write-HerRow -Label "Modules" -Value ($Modules -join ", ")

    Write-HerDivider -Light

    # Ensure destination exists
    if (-not (Test-Path $Destination)) {
        New-Item -ItemType Directory -Path $Destination -Force | Out-Null
    }

    # Process modules
    $results = @{}
    $successCount = 0

    foreach ($moduleName in $Modules) {
        $moduleFolder = Join-Path $Destination $script:ALL_MODULES[$moduleName]

        switch ($moduleName) {
            "PowerShell" { $results[$moduleName] = Gather-PowerShellFiles -Destination $moduleFolder }
            "Starship" { $results[$moduleName] = Gather-StarshipFiles -Destination $moduleFolder }
            "VSCode" { $results[$moduleName] = Gather-VSCodeFiles -Destination $moduleFolder }
        }

        if ($results[$moduleName] -eq $true) { $successCount++ }
    }

    # Summary
    Write-HerDivider -Light
    Write-HerSection -Name "Summary"

    foreach ($moduleName in $Modules) {
        $result = $results[$moduleName]
        if ($result -eq $true) {
            Write-HerStatus -Label $moduleName -Status "ok"
        }
        else {
            Write-HerStatus -Label $moduleName -Status "fail"
        }
    }

    Write-Host ""
    Write-HerRow -Label "Gathered" -Value "$successCount of $($Modules.Count) modules"
    Write-HerRow -Label "Location" -Value $Destination

    if ($successCount -eq $Modules.Count) {
        Write-HerResult -Type "success" -Message "All dotfiles gathered"
    }
    elseif ($successCount -gt 0) {
        Write-HerResult -Type "partial" -Message "Some modules not gathered"
    }
    else {
        Write-HerResult -Type "error" -Message "No dotfiles gathered"
    }
}

# ============================================================================
#  INSTALL
# ============================================================================

function Install-DotFiles {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $false)]
        [string]$Source = (Join-Path (Get-Location) $script:DEFAULT_FOLDER_NAME),

        [Parameter(Mandatory = $false)]
        [ValidateSet("PowerShell", "Starship", "VSCode")]
        [string[]]$Modules = $null
    )

    Write-HerBanner -Mode "Install"

    # Verify source
    if (-not (Test-Path $Source)) {
        Write-HerResult -Type "error" -Message "Source not found: $Source"
        Write-HerNote "Run Gather-DotFiles first"
        return @{}
    }

    # Auto-detect modules
    if ($null -eq $Modules -or $Modules.Count -eq 0) {
        $Modules = Get-InstallableModules -SourcePath $Source
        if ($Modules.Count -eq 0) {
            Write-HerResult -Type "error" -Message "No modules found in source"
            return @{}
        }
    }
    else {
        $requestedModules = $Modules
        $Modules = @()
        foreach ($moduleName in $requestedModules) {
            $moduleFolder = Join-Path $Source $script:ALL_MODULES[$moduleName]
            if (Test-Path $moduleFolder) {
                $Modules += $moduleName
            }
        }
        if ($Modules.Count -eq 0) {
            Write-HerResult -Type "error" -Message "Requested modules not found"
            return @{}
        }
    }

    # Show config
    Write-HerRow -Label "Source" -Value $Source
    Write-HerRow -Label "Modules" -Value ($Modules -join ", ")

    Write-HerDivider -Light

    # Process modules
    $results = @{}
    $successCount = 0
    $skippedCount = 0

    foreach ($moduleName in $Modules) {
        $moduleFolder = Join-Path $Source $script:ALL_MODULES[$moduleName]

        switch ($moduleName) {
            "PowerShell" { $results[$moduleName] = Install-PowerShellFiles -Source $moduleFolder }
            "Starship" { $results[$moduleName] = Install-StarshipFiles -Source $moduleFolder }
            "VSCode" { $results[$moduleName] = Install-VSCodeFiles -Source $moduleFolder }
        }

        $result = $results[$moduleName]
        if ($result -eq $true) { $successCount++ }
        elseif ($result -eq "skipped") { $skippedCount++ }
    }

    # Summary
    Write-HerDivider -Light
    Write-HerSection -Name "Summary"

    foreach ($moduleName in $Modules) {
        $result = $results[$moduleName]
        if ($result -eq $true) {
            Write-HerStatus -Label $moduleName -Status "ok"
        }
        elseif ($result -eq "skipped") {
            Write-HerStatus -Label $moduleName -Status "skip" -Detail "skipped"
        }
        else {
            Write-HerStatus -Label $moduleName -Status "fail" -Detail "failed"
        }
    }

    Write-Host ""
    $failedCount = $Modules.Count - $successCount - $skippedCount
    Write-HerRow -Label "Installed" -Value "$successCount" -ValueColor Green
    if ($skippedCount -gt 0) {
        Write-HerRow -Label "Skipped" -Value "$skippedCount" -ValueColor DarkGray
    }
    if ($failedCount -gt 0) {
        Write-HerRow -Label "Failed" -Value "$failedCount" -ValueColor Red
    }

    if ($successCount -eq $Modules.Count) {
        Write-HerResult -Type "success" -Message "All dotfiles installed"
    }
    elseif ($successCount -gt 0) {
        if ($skippedCount -gt 0 -and $failedCount -eq 0) {
            Write-HerResult -Type "skipped" -Message "Complete (some skipped)"
        }
        else {
            Write-HerResult -Type "partial" -Message "Some modules not installed"
        }
    }
    elseif ($skippedCount -eq $Modules.Count) {
        Write-HerResult -Type "skipped" -Message "All modules skipped"
    }
    else {
        Write-HerResult -Type "error" -Message "No dotfiles installed"
    }

    # Post-install hints
    if ($results["PowerShell"] -eq $true) {
        Write-Host ""
        Write-HerCommand -Label "Reload profile:" -Command ". `$PROFILE"
    }

    Write-Host ""
}

# ============================================================================
#  EXPORTS
# ============================================================================

Export-ModuleMember -Function @(
    'Gather-DotFiles'
    'Install-DotFiles'
)
