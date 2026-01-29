# ============================================================================
#  HerFiles.VSCode.Fonts - VSCode Font Management Module
# ============================================================================
#
#  Gathers and installs fonts referenced in VSCode's editor.fontFamily setting.
#
# ============================================================================

# Import shared utilities
$sharedPath = Join-Path $PSScriptRoot "..\..\Shared\HerFiles.Shared.psm1"
Import-Module $sharedPath -Force -DisableNameChecking

# ============================================================================
#  CONFIGURATION
# ============================================================================

$script:FONTS_SUBFOLDER = "Fonts"

# ============================================================================
#  UTILITIES
# ============================================================================

function Get-InstalledFonts {
    <#
    .SYNOPSIS
        Get all installed fonts from registry (both system and user)
    #>
    $fonts = @{}

    # System fonts (HKLM)
    try {
        $hklmFonts = Get-ItemProperty -Path "HKLM:\Software\Microsoft\Windows NT\CurrentVersion\Fonts" -ErrorAction SilentlyContinue
        if ($hklmFonts) {
            foreach ($prop in $hklmFonts.PSObject.Properties) {
                if ($prop.Name -notlike "PS*") {
                    $fonts[$prop.Name] = @{
                        Path = $prop.Value
                        Source = "System"
                    }
                }
            }
        }
    } catch { }

    # User fonts (HKCU)
    try {
        $hkcuFonts = Get-ItemProperty -Path "HKCU:\Software\Microsoft\Windows NT\CurrentVersion\Fonts" -ErrorAction SilentlyContinue
        if ($hkcuFonts) {
            foreach ($prop in $hkcuFonts.PSObject.Properties) {
                if ($prop.Name -notlike "PS*") {
                    $fonts[$prop.Name] = @{
                        Path = $prop.Value
                        Source = "User"
                    }
                }
            }
        }
    } catch { }

    return $fonts
}

function Find-FontsByFamily {
    <#
    .SYNOPSIS
        Find fonts whose name starts with the given family name (case insensitive)
    #>
    param(
        [Parameter(Mandatory = $true)]
        [string]$FontFamily,

        [Parameter(Mandatory = $true)]
        [hashtable]$InstalledFonts
    )

    $matches = @()

    foreach ($fontEntry in $InstalledFonts.GetEnumerator()) {
        $fontName = $fontEntry.Key
        $fontInfo = $fontEntry.Value

        # Check if font name starts with the family (case insensitive)
        if ($fontName -like "$FontFamily*") {
            $matches += @{
                Name = $fontName
                Path = $fontInfo.Path
                Source = $fontInfo.Source
            }
        }
    }

    return $matches
}

function Get-FontFamiliesFromSettings {
    <#
    .SYNOPSIS
        Extract font families from various VSCode font settings
    #>
    param(
        [Parameter(Mandatory = $true)]
        [object]$SettingsObject
    )

    $fontFamilies = @()

    # Settings that may contain font family names
    $fontSettings = @(
        'editor.fontFamily'
        'custom-ui-style.font.sansSerif'
        'custom-ui-style.font.monospace'
        'terminal.integrated.fontFamily'
    )

    foreach ($setting in $fontSettings) {
        $value = $SettingsObject.$setting
        if (-not $value) { continue }

        # Font settings can be comma-separated lists like "Fira Code, Consolas, monospace"
        # We want the first one (primary font)
        $primaryFont = ($value -split ',')[0].Trim()

        # Remove quotes if present
        $primaryFont = $primaryFont.Trim('"').Trim("'")

        # Skip generic font families
        if ($primaryFont -in @('monospace', 'sans-serif', 'serif', 'cursive', 'fantasy')) {
            continue
        }

        if ($primaryFont -and $primaryFont -notin $fontFamilies) {
            $fontFamilies += $primaryFont
        }
    }

    return $fontFamilies
}

# ============================================================================
#  GATHER
# ============================================================================

function Gather-VSCodeFonts {
    <#
    .SYNOPSIS
        Gather fonts referenced in VSCode font settings
    #>
    param(
        [Parameter(Mandatory = $true)]
        [string]$Destination,

        [Parameter(Mandatory = $true)]
        [object]$SettingsObject
    )

    $fontFamilies = Get-FontFamiliesFromSettings -SettingsObject $SettingsObject
    if ($fontFamilies.Count -eq 0) {
        return @{
            Success = $true
            GatheredCount = 0
        }
    }

    Write-HerInfo "Looking for fonts: $($fontFamilies -join ', ')"

    # Get all installed fonts
    $installedFonts = Get-InstalledFonts

    # Find matching fonts for all families
    $matchingFonts = @()
    foreach ($fontFamily in $fontFamilies) {
        $matches = Find-FontsByFamily -FontFamily $fontFamily -InstalledFonts $installedFonts
        foreach ($match in $matches) {
            # Avoid duplicates (same font file)
            if ($matchingFonts.Path -notcontains $match.Path) {
                $matchingFonts += $match
            }
        }
    }

    if ($matchingFonts.Count -eq 0) {
        Write-HerInfo "No matching fonts found in registry."
        return @{
            Success = $true
            GatheredCount = 0
        }
    }

    Write-HerInfo "Found $($matchingFonts.Count) matching font file(s)."

    # Ensure destination directory exists
    $fontsDir = Join-Path $Destination $script:FONTS_SUBFOLDER
    if (-not (Test-Path $fontsDir)) {
        New-Item -ItemType Directory -Path $fontsDir -Force | Out-Null
    }

    $gatheredCount = 0
    $manifestEntries = @()

    foreach ($font in $matchingFonts) {
        $fontPath = $font.Path

        # If path is relative (system fonts), prepend Windows\Fonts
        if (-not [System.IO.Path]::IsPathRooted($fontPath)) {
            $fontPath = Join-Path $env:WINDIR "Fonts\$fontPath"
        }

        if (-not (Test-Path $fontPath)) {
            Write-HerWarning "Font file not found: $fontPath"
            continue
        }

        $fileName = Split-Path -Leaf $fontPath

        try {
            $targetPath = Join-Path $fontsDir $fileName
            Copy-Item -Path $fontPath -Destination $targetPath -Force
            Write-HerAction -Action "Gathered" -Target $fileName
            $gatheredCount++

            $manifestEntries += [PSCustomObject]@{
                FileName = $fileName
                FontName = $font.Name
                Source = $font.Source
            }
        } catch {
            Write-HerWarning "Failed to copy font $fileName`: $($_.Exception.Message)"
        }
    }

    # Write manifest
    if ($manifestEntries.Count -gt 0) {
        $manifestPath = Join-Path $fontsDir "manifest.json"
        $manifestEntries | ConvertTo-Json -Depth 10 | Set-Content -Path $manifestPath
    }

    return @{
        Success = $true
        GatheredCount = $gatheredCount
    }
}

# ============================================================================
#  INSTALL
# ============================================================================

function Test-FontInstalled {
    <#
    .SYNOPSIS
        Check if a font is already installed
    #>
    param(
        [Parameter(Mandatory = $true)]
        [string]$FontName
    )

    $installedFonts = Get-InstalledFonts
    return $installedFonts.ContainsKey($FontName)
}

function Install-VSCodeFonts {
    <#
    .SYNOPSIS
        Install gathered fonts that are not already installed
    #>
    param(
        [Parameter(Mandatory = $true)]
        [string]$Source
    )

    $fontsDir = Join-Path $Source $script:FONTS_SUBFOLDER

    if (-not (Test-Path $fontsDir)) {
        return @{
            Success = $true
            InstalledCount = 0
        }
    }

    $manifestPath = Join-Path $fontsDir "manifest.json"
    if (-not (Test-Path $manifestPath)) {
        return @{
            Success = $true
            InstalledCount = 0
        }
    }

    $manifest = Get-Content -Path $manifestPath -Raw | ConvertFrom-Json

    Write-HerInfo "Checking $($manifest.Count) font(s)..."

    $installedCount = 0
    $existingCount = 0

    foreach ($entry in $manifest) {
        # Check if font is already installed
        if (Test-FontInstalled -FontName $entry.FontName) {
            Write-HerSkip "Installed: $($entry.FontName)"
            $existingCount++
            continue
        }

        $sourcePath = Join-Path $fontsDir $entry.FileName

        if (-not (Test-Path $sourcePath)) {
            Write-HerWarning "Font file missing: $($entry.FileName)"
            continue
        }

        # Install to user fonts directory
        $userFontsDir = Join-Path $env:LOCALAPPDATA "Microsoft\Windows\Fonts"
        if (-not (Test-Path $userFontsDir)) {
            New-Item -ItemType Directory -Path $userFontsDir -Force | Out-Null
        }

        $targetPath = Join-Path $userFontsDir $entry.FileName

        try {
            # Copy font file
            Copy-Item -Path $sourcePath -Destination $targetPath -Force

            # Register font in HKCU registry
            $regPath = "HKCU:\Software\Microsoft\Windows NT\CurrentVersion\Fonts"
            Set-ItemProperty -Path $regPath -Name $entry.FontName -Value $targetPath

            Write-HerAction -Action "Installed" -Target $entry.FontName
            $installedCount++
        } catch {
            Write-HerWarning "Failed to install $($entry.FontName): $($_.Exception.Message)"
        }
    }

    if ($existingCount -gt 0) {
        Write-HerDetail -Label "Already installed:" -Value "$existingCount"
    }

    return @{
        Success = $true
        InstalledCount = $installedCount
        ExistingCount = $existingCount
    }
}

# ============================================================================
#  EXPORTS
# ============================================================================

Export-ModuleMember -Function @(
    'Get-FontFamiliesFromSettings'
    'Gather-VSCodeFonts'
    'Install-VSCodeFonts'
)
