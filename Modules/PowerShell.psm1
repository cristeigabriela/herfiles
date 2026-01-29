# ============================================================================
#  HerFiles.PowerShell - PowerShell Profile Management Module
# ============================================================================
#
#  Manages the user's PowerShell profile configuration file.
#
#  Gathered files:
#    - Microsoft.PowerShell_profile.ps1
#
# ============================================================================

# Import shared utilities
$sharedPath = Join-Path $PSScriptRoot "..\Shared\HerFiles.Shared.psm1"
Import-Module $sharedPath -Force -DisableNameChecking

# ============================================================================
#  CONFIGURATION
# ============================================================================

$script:MODULE_NAME = "PowerShell"
$script:PROFILE_FILENAME = "Microsoft.PowerShell_profile.ps1"

function Get-PowerShellSourcePath {
    # The actual location of the user's PowerShell profile
    return Join-Path $env:USERPROFILE "Documents\WindowsPowerShell\$script:PROFILE_FILENAME"
}

# ============================================================================
#  GATHER
# ============================================================================

function Gather-PowerShellFiles {
    <#
    .SYNOPSIS
        Gather PowerShell profile to the specified destination.

    .PARAMETER Destination
        The folder to gather files into (e.g., HerFiles\PowerShell)
    #>
    param(
        [Parameter(Mandatory = $true)]
        [string]$Destination
    )

    Write-HerHeader -Title $script:MODULE_NAME -Subtitle "Gathering profile"

    $sourcePath = Get-PowerShellSourcePath

    if (-not (Test-Path $sourcePath)) {
        Write-HerWarning "PowerShell profile not found at: $sourcePath"
        Write-HerInfo "Nothing to gather."
        return $false
    }

    # Ensure destination directory exists
    if (-not (Test-Path $Destination)) {
        New-Item -ItemType Directory -Path $Destination -Force | Out-Null
        Write-HerAction -Action "Created" -Target $Destination
    }

    # Read and process the profile content
    $content = Get-Content -Path $sourcePath -Raw

    # Check for hardcoded home paths and template them
    if (Test-HerContainsHomePath -Content $content) {
        Write-HerInfo "Templating home directory paths for portability..."
        $content = ConvertTo-HerTemplatePath -Content $content
    }

    # Write the processed content
    $targetPath = Join-Path $Destination $script:PROFILE_FILENAME

    try {
        Set-Content -Path $targetPath -Value $content -NoNewline
        Write-HerAction -Action "Gathered" -Target $script:PROFILE_FILENAME

        $fileInfo = Get-HerFileInfo -Path $targetPath
        Write-HerDetail -Label "Size:" -Value $fileInfo.SizeFormatted

        Write-Host ""
        Write-HerSuccess "PowerShell profile gathered successfully."
        return $true
    } catch {
        Write-HerError "Failed to gather profile: $($_.Exception.Message)"
        return $false
    }
}

# ============================================================================
#  INSTALL
# ============================================================================

function Install-PowerShellFiles {
    <#
    .SYNOPSIS
        Install PowerShell profile from the specified source.

    .PARAMETER Source
        The folder containing gathered files (e.g., HerFiles\PowerShell)

    .RETURNS
        $true = success, $false = failure, "skipped" = user declined
    #>
    param(
        [Parameter(Mandatory = $true)]
        [string]$Source
    )

    Write-HerHeader -Title $script:MODULE_NAME -Subtitle "Installing profile"

    $sourcePath = Join-Path $Source $script:PROFILE_FILENAME

    if (-not (Test-Path $sourcePath)) {
        Write-HerWarning "No gathered profile found at: $sourcePath"
        Write-HerInfo "Nothing to install."
        return $false
    }

    $targetPath = Get-PowerShellSourcePath

    # Ensure target directory exists
    $targetDir = Split-Path -Parent $targetPath
    if (-not (Test-Path $targetDir)) {
        New-Item -ItemType Directory -Path $targetDir -Force | Out-Null
        Write-HerAction -Action "Created" -Target $targetDir
    }

    # Read the gathered content and restore home paths
    $content = Get-Content -Path $sourcePath -Raw
    $content = ConvertFrom-HerTemplatePath -Content $content

    # Check if target exists and compare
    if (Test-Path $targetPath) {
        # Create a temp file with the processed content for comparison
        $tempPath = [System.IO.Path]::GetTempFileName()
        Set-Content -Path $tempPath -Value $content -NoNewline

        $comparison = Compare-HerFiles -SourcePath $tempPath -TargetPath $targetPath -SourceLabel "Incoming" -TargetLabel "Current"

        Remove-Item $tempPath -Force

        if ($comparison.AreIdentical) {
            Write-HerSkip "Identical: $script:PROFILE_FILENAME"
            return $true
        }

        $confirm = Read-HerConfirm -Question "Overwrite existing profile?" -Default $false
        if (-not $confirm) {
            Write-HerSkip "Skipped: $script:PROFILE_FILENAME"
            return "skipped"
        }
    }

    # Install the profile
    try {
        Set-Content -Path $targetPath -Value $content -NoNewline
        Write-HerAction -Action "Installed" -Target $script:PROFILE_FILENAME

        Write-Host ""
        Write-HerSuccess "PowerShell profile installed successfully."
        Write-HerCommand -Label "Reload:" -Command ". `$PROFILE"
        return $true
    } catch {
        Write-HerError "Failed to install profile: $($_.Exception.Message)"
        return $false
    }
}

# ============================================================================
#  EXPORTS
# ============================================================================

Export-ModuleMember -Function @(
    'Gather-PowerShellFiles'
    'Install-PowerShellFiles'
)
