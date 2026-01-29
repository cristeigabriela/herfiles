# ============================================================================
#  HerFiles.VSCode - Visual Studio Code Configuration Module
# ============================================================================
#
#  Manages VSCode user settings, extensions list, and custom assets.
#
#  Gathered files:
#    - settings.json (with file:// paths templated)
#    - extensions.json (parsed to create portable extensions list)
#    - Custom CSS/JS assets (via VSCodeCustomAssets submodule)
#
#  Program detection:
#    - Checks for 'code' in PATH
#    - Offers winget installation if missing
#
#  Special handling:
#    - file:// URIs in settings.json are detected and managed
#    - Home directory paths are templated for portability
#    - Extensions are exported as a list for reinstallation
#
# ============================================================================

# Import shared utilities
$sharedPath = Join-Path $PSScriptRoot "..\..\Shared\HerFiles.Shared.psm1"
Import-Module $sharedPath -Force -DisableNameChecking

# Import custom assets submodule
$assetsModulePath = Join-Path $PSScriptRoot "VSCodeCustomAssets.psm1"
Import-Module $assetsModulePath -Force -DisableNameChecking

# Import fonts submodule
$fontsModulePath = Join-Path $PSScriptRoot "VSCodeFonts.psm1"
Import-Module $fontsModulePath -Force -DisableNameChecking

# ============================================================================
#  CONFIGURATION
# ============================================================================

$script:MODULE_NAME = "VSCode"
$script:SETTINGS_FILENAME = "settings.json"
$script:EXTENSIONS_LIST_FILENAME = "extensions.txt"
$script:EXTENSIONS_JSON_FILENAME = "extensions.json"
$script:WINGET_ID = "Microsoft.VisualStudioCode"

function Get-VSCodeUserDataPath {
    return Join-Path $env:APPDATA "Code\User"
}

function Get-VSCodeExtensionsJsonPath {
    return Join-Path $env:USERPROFILE ".vscode\extensions\extensions.json"
}

# ============================================================================
#  UTILITIES
# ============================================================================

function Remove-JsonComments {
    <#
    .SYNOPSIS
        Remove // and /* */ comments from JSONC content for parsing
    #>
    param(
        [Parameter(Mandatory = $true)]
        [string]$Content
    )

    # Remove single-line comments (// ...)
    # Be careful not to match // inside strings
    $lines = $Content -split "`n"
    $result = @()

    foreach ($line in $lines) {
        # Simple approach: find // that's not inside a string
        # Track if we're inside a string
        $inString = $false
        $escaped = $false
        $commentStart = -1

        for ($i = 0; $i -lt $line.Length; $i++) {
            $char = $line[$i]

            if ($escaped) {
                $escaped = $false
                continue
            }

            if ($char -eq '\') {
                $escaped = $true
                continue
            }

            if ($char -eq '"' -and -not $escaped) {
                $inString = -not $inString
                continue
            }

            if (-not $inString -and $char -eq '/' -and $i + 1 -lt $line.Length -and $line[$i + 1] -eq '/') {
                $commentStart = $i
                break
            }
        }

        if ($commentStart -ge 0) {
            $result += $line.Substring(0, $commentStart).TrimEnd()
        } else {
            $result += $line
        }
    }

    return $result -join "`n"
}

function Get-InstalledExtensionsList {
    <#
    .SYNOPSIS
        Parse extensions.json and return a list of extension identifiers
    #>
    param(
        [Parameter(Mandatory = $true)]
        [string]$ExtensionsJsonPath
    )

    if (-not (Test-Path $ExtensionsJsonPath)) {
        return @()
    }

    try {
        $extensions = Get-Content -Path $ExtensionsJsonPath -Raw | ConvertFrom-Json

        $extensionIds = @()
        foreach ($ext in $extensions) {
            if ($ext.identifier -and $ext.identifier.id) {
                $extensionIds += $ext.identifier.id
            }
        }

        return $extensionIds | Sort-Object -Unique
    } catch {
        Write-HerWarning "Failed to parse extensions.json: $($_.Exception.Message)"
        return @()
    }
}

function Process-SettingsForGather {
    <#
    .SYNOPSIS
        Process settings.json content for gathering (template paths)
    #>
    param(
        [Parameter(Mandatory = $true)]
        [string]$Content
    )

    # Template home directory paths
    $processed = ConvertTo-HerTemplatePath -Content $Content

    return $processed
}

function Process-SettingsForInstall {
    <#
    .SYNOPSIS
        Process settings.json content for installation (restore paths)
    #>
    param(
        [Parameter(Mandatory = $true)]
        [string]$Content
    )

    # Restore template to managed directory path with forward slashes for file:// URIs
    return ConvertFrom-HerManagedPath -Content $Content -PathStyle "forward"
}

# ============================================================================
#  GATHER
# ============================================================================

function Gather-VSCodeFiles {
    <#
    .SYNOPSIS
        Gather VSCode configuration to the specified destination.

    .PARAMETER Destination
        The folder to gather files into (e.g., HerFiles\VSCode)
    #>
    param(
        [Parameter(Mandatory = $true)]
        [string]$Destination
    )

    Write-HerHeader -Title $script:MODULE_NAME -Subtitle "Gathering configuration"

    # Ensure destination directory exists
    if (-not (Test-Path $Destination)) {
        New-Item -ItemType Directory -Path $Destination -Force | Out-Null
        Write-HerAction -Action "Created" -Target $Destination
    }

    $gatheredCount = 0

    # --- SETTINGS.JSON ---
    Write-HerInfo "Processing settings.json..."

    $settingsPath = Join-Path (Get-VSCodeUserDataPath) $script:SETTINGS_FILENAME
    $settingsTargetPath = Join-Path $Destination $script:SETTINGS_FILENAME

    if (Test-Path $settingsPath) {
        $settingsContent = Get-Content -Path $settingsPath -Raw

        # Parse to extract file:// paths before templating
        # Note: VSCode settings.json can contain comments (JSONC), so strip them first
        $settingsObject = $null
        $assetPaths = @()

        try {
            $jsonContent = Remove-JsonComments -Content $settingsContent
            $settingsObject = $jsonContent | ConvertFrom-Json

            # Get custom asset paths
            $assetPaths = Get-VSCodeCustomAssetPaths -SettingsObject $settingsObject

            if ($assetPaths.Count -gt 0) {
                Write-HerInfo "Detected $($assetPaths.Count) custom asset reference(s) in settings."
            }
        } catch {
            Write-HerWarning "Could not parse settings.json as JSON: $($_.Exception.Message)"
        }

        # Template the settings content
        $processedSettings = Process-SettingsForGather -Content $settingsContent

        Set-Content -Path $settingsTargetPath -Value $processedSettings -NoNewline
        Write-HerAction -Action "Gathered" -Target $script:SETTINGS_FILENAME
        $gatheredCount++

        # Gather custom assets if any
        if ($assetPaths.Count -gt 0) {
            Write-Host ""
            $assetResult = Gather-VSCodeCustomAssets -Destination $Destination -AssetPaths $assetPaths
        }

        # Gather fonts referenced in editor.fontFamily
        if ($settingsObject) {
            Write-Host ""
            Write-HerInfo "Processing fonts..."
            $fontResult = Gather-VSCodeFonts -Destination $Destination -SettingsObject $settingsObject
        }
    } else {
        Write-HerWarning "settings.json not found at: $settingsPath"
    }

    # --- EXTENSIONS ---
    Write-Host ""
    Write-HerInfo "Processing extensions..."

    $extensionsJsonPath = Get-VSCodeExtensionsJsonPath

    if (Test-Path $extensionsJsonPath) {
        $extensionIds = Get-InstalledExtensionsList -ExtensionsJsonPath $extensionsJsonPath

        if ($extensionIds.Count -gt 0) {
            # Save as simple text list (one extension per line)
            $extensionsListPath = Join-Path $Destination $script:EXTENSIONS_LIST_FILENAME
            $extensionIds | Set-Content -Path $extensionsListPath
            Write-HerAction -Action "Gathered" -Target "$($extensionIds.Count) extensions"

            # Also save the raw JSON for reference
            $extensionsJsonTarget = Join-Path $Destination $script:EXTENSIONS_JSON_FILENAME
            $rawContent = Get-Content -Path $extensionsJsonPath -Raw
            Set-Content -Path $extensionsJsonTarget -Value $rawContent
            Write-HerAction -Action "Gathered" -Target $script:EXTENSIONS_JSON_FILENAME

            $gatheredCount++

            # Display extension categories
            $themeExtensions = $extensionIds | Where-Object { $_ -match 'theme|icon' }
            $langExtensions = $extensionIds | Where-Object { $_ -match 'python|rust|go|typescript|csharp|java' }

            Write-HerDetail -Label "Total extensions:" -Value "$($extensionIds.Count)"
            if ($themeExtensions.Count -gt 0) {
                Write-HerDetail -Label "Themes/Icons:" -Value "$($themeExtensions.Count)"
            }
            if ($langExtensions.Count -gt 0) {
                Write-HerDetail -Label "Language support:" -Value "$($langExtensions.Count)"
            }
        } else {
            Write-HerInfo "No extensions found."
        }
    } else {
        Write-HerWarning "extensions.json not found at: $extensionsJsonPath"
    }

    Write-Host ""
    if ($gatheredCount -gt 0) {
        Write-HerSuccess "VSCode configuration gathered successfully."
    } else {
        Write-HerWarning "No VSCode configuration files found to gather."
    }

    return $gatheredCount -gt 0
}

# ============================================================================
#  INSTALL
# ============================================================================

function Install-VSCodeFiles {
    <#
    .SYNOPSIS
        Install VSCode configuration from the specified source.

    .PARAMETER Source
        The folder containing gathered files (e.g., HerFiles\VSCode)

    .RETURNS
        $true = success, $false = failure, "skipped" = user declined
    #>
    param(
        [Parameter(Mandatory = $true)]
        [string]$Source
    )

    Write-HerHeader -Title $script:MODULE_NAME -Subtitle "Installing configuration"

    # Check if VSCode is installed
    if (-not (Test-HerProgramInstalled -ProgramName "code")) {
        $installed = Install-HerProgramWithWinget -ProgramName "code" -WingetId $script:WINGET_ID -Description "Visual Studio Code"

        if (-not $installed) {
            Write-HerInfo "Skipping VSCode configuration installation."
            return "skipped"
        }
    } else {
        Write-HerInfo "Visual Studio Code is installed."
    }

    # Track what was actually installed vs skipped
    $settingsInstalled = $false
    $settingsSkipped = $false
    $newAssetsInstalled = $false
    $newFontsInstalled = $false

    # --- FONTS FIRST ---
    # Install fonts before anything else so they're available
    Write-Host ""
    Write-HerInfo "Processing fonts..."
    $fontResult = Install-VSCodeFonts -Source $Source
    $newFontsInstalled = $fontResult.InstalledCount -gt 0

    # --- CUSTOM ASSETS ---
    # Install custom assets before settings, so paths exist
    Write-Host ""
    $assetResult = Install-VSCodeCustomAssets -Source $Source
    $newAssetsInstalled = $assetResult.InstalledCount -gt 0

    # --- SETTINGS.JSON ---
    Write-Host ""
    Write-HerInfo "Installing settings.json..."

    $settingsSourcePath = Join-Path $Source $script:SETTINGS_FILENAME
    $settingsTargetPath = Join-Path (Get-VSCodeUserDataPath) $script:SETTINGS_FILENAME

    if (Test-Path $settingsSourcePath) {
        # Ensure target directory exists
        $targetDir = Get-VSCodeUserDataPath
        if (-not (Test-Path $targetDir)) {
            New-Item -ItemType Directory -Path $targetDir -Force | Out-Null
            Write-HerAction -Action "Created" -Target $targetDir
        }

        # Read and process settings
        $settingsContent = Get-Content -Path $settingsSourcePath -Raw
        $processedSettings = Process-SettingsForInstall -Content $settingsContent

        # Compare and install
        if (Test-Path $settingsTargetPath) {
            $tempPath = [System.IO.Path]::GetTempFileName()
            Set-Content -Path $tempPath -Value $processedSettings -NoNewline

            $comparison = Compare-HerFiles -SourcePath $tempPath -TargetPath $settingsTargetPath -SourceLabel "Incoming" -TargetLabel "Current"

            Remove-Item $tempPath -Force

            if ($comparison.AreIdentical) {
                Write-HerSkip "Identical: $script:SETTINGS_FILENAME"
                $settingsInstalled = $true  # Identical counts as "installed" (in sync)
            } else {
                $confirm = Read-HerConfirm -Question "Overwrite settings.json?" -Default $false
                if ($confirm) {
                    try {
                        Set-Content -Path $settingsTargetPath -Value $processedSettings -NoNewline
                        Write-HerAction -Action "Installed" -Target $script:SETTINGS_FILENAME
                        $settingsInstalled = $true
                    } catch {
                        Write-HerError "Failed to install settings: $($_.Exception.Message)"
                    }
                } else {
                    Write-HerSkip "Skipped: $script:SETTINGS_FILENAME"
                    $settingsSkipped = $true
                }
            }
        } else {
            # No existing file, just install
            try {
                Set-Content -Path $settingsTargetPath -Value $processedSettings -NoNewline
                Write-HerAction -Action "Installed" -Target $script:SETTINGS_FILENAME
                $settingsInstalled = $true
            } catch {
                Write-HerError "Failed to install settings: $($_.Exception.Message)"
            }
        }
    } else {
        Write-HerWarning "No settings.json found in source."
    }

    # --- EXTENSIONS ---
    # Only offer extension installation if settings were installed (not skipped)
    Write-Host ""

    if ($settingsSkipped) {
        Write-HerInfo "Skipping extensions (settings.json was skipped)."
    } else {
        Write-HerInfo "Processing extensions..."

        $extensionsListPath = Join-Path $Source $script:EXTENSIONS_LIST_FILENAME

        if (Test-Path $extensionsListPath) {
            $wantedExtensions = Get-Content -Path $extensionsListPath

            if ($wantedExtensions.Count -gt 0) {
                # Get currently installed extensions
                $currentExtensionsPath = Get-VSCodeExtensionsJsonPath
                $installedExtensions = @()
                if (Test-Path $currentExtensionsPath) {
                    $installedExtensions = Get-InstalledExtensionsList -ExtensionsJsonPath $currentExtensionsPath
                }

                # Find missing extensions (case-insensitive comparison)
                $installedLower = $installedExtensions | ForEach-Object { $_.ToLower() }
                $missingExtensions = $wantedExtensions | Where-Object { $installedLower -notcontains $_.ToLower() }

                $alreadyInstalled = $wantedExtensions.Count - $missingExtensions.Count

                Write-HerDetail -Label "Extensions in config:" -Value "$($wantedExtensions.Count)"
                if ($alreadyInstalled -gt 0) {
                    Write-HerDetail -Label "Already installed:" -Value "$alreadyInstalled"
                }

                if ($missingExtensions.Count -eq 0) {
                    Write-HerInfo "All extensions are already installed."
                } else {
                    Write-HerDetail -Label "Missing:" -Value "$($missingExtensions.Count)"

                    $confirm = Read-HerConfirm -Question "Install $($missingExtensions.Count) missing extension(s)?" -Default $true

                    if ($confirm) {
                        Write-Host ""

                        $installed = 0
                        $failed = 0

                        foreach ($extId in $missingExtensions) {
                            Write-HerProgress -Activity "Installing extensions" -Current ($installed + $failed + 1) -Total $missingExtensions.Count -Status $extId

                            try {
                                $result = & code --install-extension $extId --force 2>&1

                                if ($LASTEXITCODE -eq 0) {
                                    $installed++
                                } else {
                                    $failed++
                                }
                            } catch {
                                $failed++
                            }
                        }

                        Complete-HerProgress
                        Write-Host ""

                        Write-HerDetail -Label "Installed:" -Value "$installed"
                        if ($failed -gt 0) {
                            Write-HerDetail -Label "Failed:" -Value "$failed"
                        }
                    } else {
                        Write-HerSkip "Skipped extension installation."
                        Write-HerCommand -Label "Install manually:" -Command "Get-Content '$extensionsListPath' | ForEach-Object { code --install-extension `$_ }"
                    }
                }
            }
        } else {
            Write-HerInfo "No extensions list found."
        }
    }

    Write-Host ""

    # Determine final result
    if ($settingsSkipped -and -not $newAssetsInstalled -and -not $newFontsInstalled) {
        Write-HerInfo "VSCode configuration skipped."
        return "skipped"
    }

    Write-HerSuccess "VSCode configuration installed."
    Write-HerInfo "Restart VSCode to apply all changes."

    # Check if custom CSS extension needs activation (only if new assets were installed)
    if ($newAssetsInstalled) {
        Write-Host ""
        Write-HerWarning "Custom CSS/JS assets were installed."
        Write-HerInfo "You may need to:"
        Write-HerInfo "  1. Run VSCode as Administrator"
        Write-HerInfo "  2. Execute 'Custom CSS and JS: Reload' command"
    }

    # Note about fonts if any were installed
    if ($newFontsInstalled) {
        Write-Host ""
        Write-HerInfo "New fonts were installed. You may need to restart applications to use them."
    }

    return $true
}

# ============================================================================
#  EXPORTS
# ============================================================================

Export-ModuleMember -Function @(
    'Gather-VSCodeFiles'
    'Install-VSCodeFiles'
)
