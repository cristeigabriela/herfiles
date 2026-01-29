# Extending HerFiles

This guide explains how to add new modules to the HerFiles dotfiles management system.

## Architecture Overview

```
HerFiles/
├── HerFiles.psm1                  # Main module (exports Gather-DotFiles, Install-DotFiles)
├── Shared/
│   └── HerFiles.Shared.psm1       # Shared utilities (UI, file ops, prompts, templating)
├── Modules/
│   ├── PowerShell.psm1            # Simple single-file module
│   ├── Starship.psm1              # Module with program detection
│   └── VSCode/
│       ├── VSCode.psm1            # Complex module with submodule
│       └── VSCodeCustomAssets.psm1 # Submodule for asset management
└── EXTENDING.md                   # This file
```

## Module Contract

Every module must export two functions:

1. `Gather-<ModuleName>Files` - Collects configuration from the system
2. `Install-<ModuleName>Files` - Deploys configuration to the system

### Function Signatures

```powershell
function Gather-<ModuleName>Files {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Destination
    )
    # Returns: $true on success, $false on failure
}

function Install-<ModuleName>Files {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Source
    )
    # Returns: $true on success, $false on failure
}
```

## Creating a New Module

### Step 1: Create the Module File

Create a new file in `Modules/` (e.g., `Modules/MyApp.psm1`).

### Step 2: Basic Module Template

```powershell
# ============================================================================
#  HerFiles.MyApp - MyApp Configuration Module
# ============================================================================
#
#  Manages MyApp configuration files.
#
#  Gathered files:
#    - config.json
#    - settings.xml
#
#  Program detection:
#    - Checks for 'myapp' in PATH (optional)
#    - Offers winget installation if missing (optional)
#
# ============================================================================

# Import shared utilities
$sharedPath = Join-Path $PSScriptRoot "..\Shared\HerFiles.Shared.psm1"
Import-Module $sharedPath -Force

# ============================================================================
#  CONFIGURATION
# ============================================================================

$script:MODULE_NAME = "MyApp"
$script:CONFIG_FILENAME = "config.json"
$script:WINGET_ID = "Publisher.MyApp"  # Optional: for auto-installation

function Get-MyAppSourcePath {
    # Return the path where MyApp stores its config
    return Join-Path $env:APPDATA "MyApp\$script:CONFIG_FILENAME"
}

# ============================================================================
#  GATHER
# ============================================================================

function Gather-MyAppFiles {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Destination
    )

    Write-HerHeader -Title $script:MODULE_NAME -Subtitle "Gathering configuration"

    $sourcePath = Get-MyAppSourcePath

    if (-not (Test-Path $sourcePath)) {
        Write-HerWarning "Config not found at: $sourcePath"
        Write-HerInfo "Nothing to gather."
        return $false
    }

    # Ensure destination directory exists
    if (-not (Test-Path $Destination)) {
        New-Item -ItemType Directory -Path $Destination -Force | Out-Null
        Write-HerAction -Action "Created" -Target $Destination
    }

    # Read and process content
    $content = Get-Content -Path $sourcePath -Raw

    # Template home directory paths for portability
    if (Test-HerContainsHomePath -Content $content) {
        Write-HerInfo "Templating home directory paths..."
        $content = ConvertTo-HerTemplatePath -Content $content
    }

    # Write to destination
    $targetPath = Join-Path $Destination $script:CONFIG_FILENAME

    try {
        Set-Content -Path $targetPath -Value $content -NoNewline
        Write-HerAction -Action "Gathered" -Target $script:CONFIG_FILENAME

        Write-Host ""
        Write-HerSuccess "MyApp configuration gathered successfully."
        return $true
    } catch {
        Write-HerError "Failed to gather: $($_.Exception.Message)"
        return $false
    }
}

# ============================================================================
#  INSTALL
# ============================================================================

function Install-MyAppFiles {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Source
    )

    Write-HerHeader -Title $script:MODULE_NAME -Subtitle "Installing configuration"

    # Optional: Check if program is installed
    if (-not (Test-HerProgramInstalled -ProgramName "myapp")) {
        $installed = Install-HerProgramWithWinget `
            -ProgramName "myapp" `
            -WingetId $script:WINGET_ID `
            -Description "MyApp"

        if (-not $installed) {
            Write-HerInfo "Skipping MyApp configuration."
            return $false
        }
    }

    $sourcePath = Join-Path $Source $script:CONFIG_FILENAME

    if (-not (Test-Path $sourcePath)) {
        Write-HerWarning "No gathered config found."
        return $false
    }

    $targetPath = Get-MyAppSourcePath

    # Ensure target directory exists
    $targetDir = Split-Path -Parent $targetPath
    if (-not (Test-Path $targetDir)) {
        New-Item -ItemType Directory -Path $targetDir -Force | Out-Null
    }

    # Read and restore content
    $content = Get-Content -Path $sourcePath -Raw
    $content = ConvertFrom-HerTemplatePath -Content $content

    # Compare and prompt for overwrite
    if (Test-Path $targetPath) {
        $tempPath = [System.IO.Path]::GetTempFileName()
        Set-Content -Path $tempPath -Value $content -NoNewline

        $comparison = Compare-HerFiles `
            -SourcePath $tempPath `
            -TargetPath $targetPath `
            -SourceLabel "Incoming" `
            -TargetLabel "Current"

        Remove-Item $tempPath -Force

        if ($comparison.AreIdentical) {
            Write-HerSkip "Identical: $script:CONFIG_FILENAME"
            return $true
        }

        $confirm = Read-HerConfirm -Question "Overwrite existing config?" -Default $false
        if (-not $confirm) {
            Write-HerSkip "Skipped: $script:CONFIG_FILENAME"
            return $false
        }
    }

    # Install
    try {
        Set-Content -Path $targetPath -Value $content -NoNewline
        Write-HerAction -Action "Installed" -Target $script:CONFIG_FILENAME

        Write-Host ""
        Write-HerSuccess "MyApp configuration installed."
        return $true
    } catch {
        Write-HerError "Failed to install: $($_.Exception.Message)"
        return $false
    }
}

# ============================================================================
#  EXPORTS
# ============================================================================

Export-ModuleMember -Function @(
    'Gather-MyAppFiles'
    'Install-MyAppFiles'
)
```

### Step 3: Register the Module in HerFiles.psm1

Edit `HerFiles.psm1` to add your module:

1. **Import the module:**
```powershell
$script:MyAppModule = Join-Path $modulesPath "MyApp.psm1"
Import-Module $script:MyAppModule -Force
```

2. **Add to ALL_MODULES:**
```powershell
$script:ALL_MODULES = [ordered]@{
    PowerShell = "PowerShell"
    Starship   = "Starship"
    VSCode     = "VSCode"
    MyApp      = "MyApp"  # Add this line
}
```

3. **Add detection logic in Get-GatherableModules:**
```powershell
# MyApp - check if config exists
$myAppPath = Join-Path $env:APPDATA "MyApp\config.json"
if (Test-Path $myAppPath) {
    $available += "MyApp"
}
```

4. **Add switch cases in Gather-DotFiles and Install-DotFiles:**
```powershell
"MyApp" {
    $results[$moduleName] = Gather-MyAppFiles -Destination $moduleFolder
}
```

5. **Update ValidateSet attributes:**
```powershell
[ValidateSet("PowerShell", "Starship", "VSCode", "MyApp")]
```

## Shared Utilities Reference

### UI Functions

| Function | Description | Example |
|----------|-------------|---------|
| `Write-HerHeader` | Section header | `Write-HerHeader -Title "MyApp" -Subtitle "Gathering"` |
| `Write-HerTag` | Styled badge | `Write-HerTag -Tag "OK" -Message "Done"` |
| `Write-HerSuccess` | Success message | `Write-HerSuccess "Completed!"` |
| `Write-HerError` | Error message | `Write-HerError "Failed to read file"` |
| `Write-HerWarning` | Warning message | `Write-HerWarning "File not found"` |
| `Write-HerInfo` | Info message | `Write-HerInfo "Processing..."` |
| `Write-HerDetail` | Label + value | `Write-HerDetail -Label "Size:" -Value "1.2 KB"` |
| `Write-HerSkip` | Skip notification | `Write-HerSkip "Identical: config.json"` |
| `Write-HerAction` | Action taken | `Write-HerAction -Action "Copied" -Target "config.json"` |

### Prompt Functions

| Function | Description | Example |
|----------|-------------|---------|
| `Read-HerConfirm` | Yes/no prompt | `Read-HerConfirm -Question "Overwrite?" -Default $false` |
| `Read-HerChoice` | Multiple choice | `Read-HerChoice -Question "Select:" -Options @("A", "B")` |

### Progress Functions

| Function | Description | Example |
|----------|-------------|---------|
| `Write-HerProgress` | Progress bar | `Write-HerProgress -Activity "Copying" -Current 5 -Total 10` |
| `Complete-HerProgress` | End progress | `Complete-HerProgress` |

### File Functions

| Function | Description |
|----------|-------------|
| `Get-HerFileHash` | Get SHA256 hash of file |
| `Get-HerFileInfo` | Get file metadata (size, dates, hash) |
| `Compare-HerFiles` | Compare two files with visual diff |
| `Copy-HerFile` | Copy with optional overwrite confirmation |

### Path Templating

| Function | Description |
|----------|-------------|
| `ConvertTo-HerTemplatePath` | Replace $HOME with `{{HERFILES_HOME}}` |
| `ConvertFrom-HerTemplatePath` | Restore `{{HERFILES_HOME}}` to actual $HOME |
| `Test-HerContainsHomePath` | Check if content has hardcoded home paths |

### Program Detection

| Function | Description |
|----------|-------------|
| `Test-HerProgramInstalled` | Check if program is in PATH |
| `Install-HerProgramWithWinget` | Prompt and install via winget |

### Admin Utilities

| Function | Description |
|----------|-------------|
| `Test-HerAdminRights` | Check if running as admin |
| `Request-HerAdminRights` | Prompt to restart as admin |

## Advanced: Submodules

For complex modules (like VSCode), you can create submodules:

```
Modules/
└── MyApp/
    ├── MyApp.psm1           # Main module
    └── MyAppPlugins.psm1    # Submodule for plugin management
```

Import submodules in your main module:

```powershell
$pluginsModulePath = Join-Path $PSScriptRoot "MyAppPlugins.psm1"
Import-Module $pluginsModulePath -Force
```

## Handling Multiple Files

If your module needs to manage multiple files:

```powershell
$script:FILES_TO_GATHER = @(
    @{ Source = "config.json"; Template = $true }
    @{ Source = "settings.xml"; Template = $false }
    @{ Source = "keys.toml"; Template = $true }
)

function Gather-MyAppFiles {
    param([string]$Destination)

    foreach ($file in $script:FILES_TO_GATHER) {
        $sourcePath = Join-Path (Get-MyAppConfigDir) $file.Source
        # ... gather each file
    }
}
```

## Handling file:// URIs

If your app's config references local files via `file://` URIs (like VSCode's custom CSS):

1. Parse the config to extract file paths
2. Gather those files as assets
3. Create a manifest to track original locations
4. On install, restore files and update URIs

See `VSCodeCustomAssets.psm1` for a complete implementation.

## Testing Your Module

1. Test gathering:
```powershell
Import-Module .\HerFiles.psm1 -Force
Gather-DotFiles -Modules @("MyApp") -Destination ".\TestGather"
```

2. Test installing:
```powershell
Install-DotFiles -Modules @("MyApp") -Source ".\TestGather"
```

3. Test auto-detection:
```powershell
# Should include MyApp if config exists
Gather-DotFiles
```

## Style Guidelines

1. **Use shared utilities** - Don't reinvent the wheel
2. **Follow the DRY principle** - Extract common patterns
3. **Consistent messaging** - Use `Write-Her*` functions
4. **Handle errors gracefully** - Always use try/catch
5. **Prompt before overwriting** - Respect user's existing configs
6. **Template paths** - Make configs portable across machines
7. **Document your module** - Add header comments explaining what files are managed
