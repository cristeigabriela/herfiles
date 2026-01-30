# ============================================================================
#  HerFiles.VSCode.CustomAssets - VSCode Custom CSS/JS Assets Module
# ============================================================================
#
#  Manages custom CSS and JavaScript files referenced in VSCode settings
#  via the vscode_custom_css.imports setting.
#
#  These files typically live in ~/.vscode/ and are loaded by extensions
#  like "Custom CSS and JS Loader" (be5invis.vscode-custom-css).
#
# ============================================================================

# Import shared utilities
$sharedPath = Join-Path $PSScriptRoot "..\..\Shared\HerFiles.Shared.psm1"
Import-Module $sharedPath -Force -DisableNameChecking

# ============================================================================
#  CONFIGURATION
# ============================================================================

$script:MODULE_NAME = "VSCode.Assets"
$script:ASSETS_SUBFOLDER = "CustomAssets"
$script:INSTALL_SUBFOLDER = ".vscode"  # Where assets go under $HOME/.herfiles/

# ============================================================================
#  UTILITIES
# ============================================================================

function Get-VSCodeCustomAssetPaths {
    <#
    .SYNOPSIS
        Extract file:// paths from VSCode settings JSON content
    #>
    param(
        [Parameter(Mandatory = $true)]
        [object]$SettingsObject
    )

    $paths = @()

    # Look for vscode_custom_css.imports array
    if ($SettingsObject.'vscode_custom_css.imports') {
        foreach ($import in $SettingsObject.'vscode_custom_css.imports') {
            if ($import -match '^file:///(.+)$') {
                # Convert file URI to local path
                $localPath = $Matches[1]
                # Handle Windows drive letters (file:///C:/...)
                $localPath = $localPath -replace '/', '\'
                # Decode any URL encoding
                $localPath = [System.Uri]::UnescapeDataString($localPath)
                $paths += $localPath
            }
        }
    }

    return $paths
}

function Convert-FilePathToUri {
    <#
    .SYNOPSIS
        Convert a local file path to a file:// URI
    #>
    param(
        [Parameter(Mandatory = $true)]
        [string]$Path
    )

    # Normalize path separators to forward slashes
    $uriPath = $Path -replace '\\', '/'
    return "file:///$uriPath"
}

function Get-VSCodeAssetInstallPath {
    <#
    .SYNOPSIS
        Get the install path for a custom asset file.
        Assets are installed to $HOME/.herfiles/.vscode/
    #>
    param(
        [Parameter(Mandatory = $true)]
        [string]$FileName
    )

    $managedPath = Get-HerManagedPath -PathStyle "forward"
    return "$managedPath/$script:INSTALL_SUBFOLDER/$FileName"
}

function Get-VSCodeAssetInstallUri {
    <#
    .SYNOPSIS
        Get the file:// URI for an installed custom asset.
    #>
    param(
        [Parameter(Mandatory = $true)]
        [string]$FileName
    )

    $path = Get-VSCodeAssetInstallPath -FileName $FileName
    return "file:///$path"
}

# ============================================================================
#  GATHER
# ============================================================================

function Gather-VSCodeCustomAssets {
    <#
    .SYNOPSIS
        Gather VSCode custom CSS/JS assets to the specified destination.

    .PARAMETER Destination
        The folder to gather files into (e.g., HerFiles\VSCode\CustomAssets)

    .PARAMETER AssetPaths
        Array of file paths to gather (extracted from settings.json)
    #>
    param(
        [Parameter(Mandatory = $true)]
        [string]$Destination,

        [Parameter(Mandatory = $true)]
        [string[]]$AssetPaths
    )

    if ($AssetPaths.Count -eq 0) {
        Write-HerInfo "No custom assets to gather."
        return $true
    }

    Write-HerInfo "Found $($AssetPaths.Count) custom asset(s) to gather..."

    # Ensure destination directory exists
    $assetsDir = Join-Path $Destination $script:ASSETS_SUBFOLDER
    if (-not (Test-Path $assetsDir)) {
        New-Item -ItemType Directory -Path $assetsDir -Force | Out-Null
    }

    $gatheredCount = 0
    $manifestEntries = @()

    foreach ($assetPath in $AssetPaths) {
        $fileName = Split-Path -Leaf $assetPath

        if (-not (Test-Path $assetPath)) {
            Write-HerWarning "Asset not found: $assetPath"
            continue
        }

        # Read and template the content
        $content = Get-Content -Path $assetPath -Raw

        if (Test-HerContainsHomePath -Content $content) {
            $content = ConvertTo-HerTemplatePath -Content $content
        }

        # Write to destination
        $targetPath = Join-Path $assetsDir $fileName

        try {
            Set-Content -Path $targetPath -Value $content -NoNewline
            Write-HerAction -Action "Gathered" -Target $fileName
            $gatheredCount++

            # Track just the filename - install location is deterministic
            $manifestEntries += [PSCustomObject]@{
                FileName = $fileName
            }
        } catch {
            Write-HerError "Failed to gather $fileName`: $($_.Exception.Message)"
        }
    }

    # Write a manifest file to track assets
    if ($manifestEntries.Count -gt 0) {
        $manifestPath = Join-Path $assetsDir "manifest.json"
        $manifestEntries | ConvertTo-Json -Depth 10 | Set-Content -Path $manifestPath
    }

    Write-HerDetail -Label "Assets gathered:" -Value "$gatheredCount/$($AssetPaths.Count)"
    return $gatheredCount -gt 0
}

# ============================================================================
#  INSTALL
# ============================================================================

function Install-VSCodeCustomAssets {
    <#
    .SYNOPSIS
        Install VSCode custom CSS/JS assets from the specified source.

    .PARAMETER Source
        The folder containing gathered assets (e.g., HerFiles\VSCode\CustomAssets)
    #>
    param(
        [Parameter(Mandatory = $true)]
        [string]$Source
    )

    $assetsDir = Join-Path $Source $script:ASSETS_SUBFOLDER

    if (-not (Test-Path $assetsDir)) {
        Write-HerInfo "No custom assets to install."
        return @{
            Success = $true
            InstalledPaths = @()
        }
    }

    # Read the manifest
    $manifestPath = Join-Path $assetsDir "manifest.json"
    if (-not (Test-Path $manifestPath)) {
        Write-HerWarning "Asset manifest not found."
        return @{
            Success = $false
            InstalledPaths = @()
        }
    }

    $manifest = Get-Content -Path $manifestPath -Raw | ConvertFrom-Json

    Write-HerInfo "Checking $($manifest.Count) custom asset(s)..."

    $installedPaths = @()
    $installedCount = 0
    $existingCount = 0

    foreach ($entry in $manifest) {
        $sourcePath = Join-Path $assetsDir $entry.FileName

        if (-not (Test-Path $sourcePath)) {
            Write-HerWarning "Asset file missing: $($entry.FileName)"
            continue
        }

        # Determine target path - always install to $HOME/.herfiles/.vscode/
        $managedPath = Get-HerManagedPath
        $targetPath = Join-Path $managedPath $script:INSTALL_SUBFOLDER | Join-Path -ChildPath $entry.FileName

        # Skip if asset already exists on the system
        if (Test-Path $targetPath) {
            Write-HerSkip "Exists: $($entry.FileName)"
            $installedPaths += $targetPath
            $existingCount++
            continue
        }

        # Ensure target directory exists
        $targetDir = Split-Path -Parent $targetPath
        if (-not (Test-Path $targetDir)) {
            New-Item -ItemType Directory -Path $targetDir -Force | Out-Null
        }

        # Read and restore content (any templated paths inside get restored to $HOME)
        $content = Get-Content -Path $sourcePath -Raw
        $content = ConvertFrom-HerTemplatePath -Content $content

        # Install the missing asset
        try {
            Set-Content -Path $targetPath -Value $content -NoNewline
            Write-HerAction -Action "Installed" -Target $entry.FileName
            $installedCount++
            $installedPaths += $targetPath
        } catch {
            Write-HerError "Failed to install $($entry.FileName): $($_.Exception.Message)"
        }
    }

    if ($installedCount -gt 0) {
        Write-HerDetail -Label "Assets installed:" -Value "$installedCount"
    }
    if ($existingCount -gt 0) {
        Write-HerDetail -Label "Already present:" -Value "$existingCount"
    }

    return @{
        Success = $true
        InstalledPaths = $installedPaths
        InstalledCount = $installedCount
        ExistingCount = $existingCount
    }
}

# ============================================================================
#  EXPORTS
# ============================================================================

Export-ModuleMember -Function @(
    'Get-VSCodeCustomAssetPaths'
    'Convert-FilePathToUri'
    'Get-VSCodeAssetInstallPath'
    'Get-VSCodeAssetInstallUri'
    'Gather-VSCodeCustomAssets'
    'Install-VSCodeCustomAssets'
)
