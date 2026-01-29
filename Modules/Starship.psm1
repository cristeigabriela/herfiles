# ============================================================================
#  HerFiles.Starship - Starship Prompt Configuration Module
# ============================================================================
#
#  Manages the Starship cross-shell prompt configuration.
#
#  Gathered files:
#    - starship.toml
#
#  Program detection:
#    - Checks for 'starship' in PATH
#    - Offers winget installation if missing
#
# ============================================================================

# Import shared utilities
$sharedPath = Join-Path $PSScriptRoot "..\Shared\HerFiles.Shared.psm1"
Import-Module $sharedPath -Force -DisableNameChecking

# ============================================================================
#  CONFIGURATION
# ============================================================================

$script:MODULE_NAME = "Starship"
$script:CONFIG_FILENAME = "starship.toml"
$script:WINGET_ID = "Starship.Starship"

function Get-StarshipSourcePath {
    # Default Starship config location
    return Join-Path $env:USERPROFILE ".config\$script:CONFIG_FILENAME"
}

# ============================================================================
#  GATHER
# ============================================================================

function Gather-StarshipFiles {
    <#
    .SYNOPSIS
        Gather Starship configuration to the specified destination.

    .PARAMETER Destination
        The folder to gather files into (e.g., HerFiles\Starship)
    #>
    param(
        [Parameter(Mandatory = $true)]
        [string]$Destination
    )

    Write-HerHeader -Title $script:MODULE_NAME -Subtitle "Gathering configuration"

    $sourcePath = Get-StarshipSourcePath

    if (-not (Test-Path $sourcePath)) {
        Write-HerWarning "Starship config not found at: $sourcePath"
        Write-HerInfo "Nothing to gather."
        return $false
    }

    # Ensure destination directory exists
    if (-not (Test-Path $Destination)) {
        New-Item -ItemType Directory -Path $Destination -Force | Out-Null
        Write-HerAction -Action "Created" -Target $Destination
    }

    # Read and process the config content
    $content = Get-Content -Path $sourcePath -Raw

    # TOML files typically don't have hardcoded paths, but check anyway
    if (Test-HerContainsHomePath -Content $content) {
        Write-HerInfo "Templating home directory paths for portability..."
        $content = ConvertTo-HerTemplatePath -Content $content
    }

    # Write the processed content
    $targetPath = Join-Path $Destination $script:CONFIG_FILENAME

    try {
        Set-Content -Path $targetPath -Value $content -NoNewline
        Write-HerAction -Action "Gathered" -Target $script:CONFIG_FILENAME

        $fileInfo = Get-HerFileInfo -Path $targetPath
        Write-HerDetail -Label "Size:" -Value $fileInfo.SizeFormatted

        Write-Host ""
        Write-HerSuccess "Starship configuration gathered successfully."
        return $true
    } catch {
        Write-HerError "Failed to gather config: $($_.Exception.Message)"
        return $false
    }
}

# ============================================================================
#  INSTALL
# ============================================================================

function Install-StarshipFiles {
    <#
    .SYNOPSIS
        Install Starship configuration from the specified source.

    .PARAMETER Source
        The folder containing gathered files (e.g., HerFiles\Starship)

    .RETURNS
        $true = success, $false = failure, "skipped" = user declined
    #>
    param(
        [Parameter(Mandatory = $true)]
        [string]$Source
    )

    Write-HerHeader -Title $script:MODULE_NAME -Subtitle "Installing configuration"

    # Check if Starship is installed
    if (-not (Test-HerProgramInstalled -ProgramName "starship")) {
        $installed = Install-HerProgramWithWinget -ProgramName "starship" -WingetId $script:WINGET_ID -Description "Starship prompt"

        if (-not $installed) {
            Write-HerInfo "Skipping Starship configuration installation."
            return "skipped"
        }
    } else {
        Write-HerInfo "Starship is installed."
    }

    $sourcePath = Join-Path $Source $script:CONFIG_FILENAME

    if (-not (Test-Path $sourcePath)) {
        Write-HerWarning "No gathered config found at: $sourcePath"
        Write-HerInfo "Nothing to install."
        return $false
    }

    $targetPath = Get-StarshipSourcePath

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
            Write-HerSkip "Identical: $script:CONFIG_FILENAME"
            return $true
        }

        $confirm = Read-HerConfirm -Question "Overwrite existing config?" -Default $false
        if (-not $confirm) {
            Write-HerSkip "Skipped: $script:CONFIG_FILENAME"
            return "skipped"
        }
    }

    # Install the config
    try {
        Set-Content -Path $targetPath -Value $content -NoNewline
        Write-HerAction -Action "Installed" -Target $script:CONFIG_FILENAME

        Write-Host ""
        Write-HerSuccess "Starship configuration installed successfully."
        Write-HerInfo "Restart your shell to see changes."
        return $true
    } catch {
        Write-HerError "Failed to install config: $($_.Exception.Message)"
        return $false
    }
}

# ============================================================================
#  EXPORTS
# ============================================================================

Export-ModuleMember -Function @(
    'Gather-StarshipFiles'
    'Install-StarshipFiles'
)
