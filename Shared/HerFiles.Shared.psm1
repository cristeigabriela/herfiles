# ============================================================================
#  HerFiles.Shared - Shared Utilities for Dotfiles Management
# ============================================================================

$script:HOME_PLACEHOLDER = '{{HERFILES_HOME}}'
$script:MANAGED_DIR_NAME = '.herfiles'

# ============================================================================
#  UI CONSTANTS
# ============================================================================

# Indentation levels
$script:INDENT_1 = "    "           # 4 spaces - section headers
$script:INDENT_2 = "        "       # 8 spaces - content lines

# Column system - all values align to the same column
$script:COL_LABEL = 36              # Width for labels/filenames (padded)
$script:COL_STATUS_LABEL = 34       # Width for status labels (after "+ " symbol)

# ============================================================================
#  UI UTILITIES
# ============================================================================

function Write-HerBanner {
    <#
    .SYNOPSIS
        Display the main HerFiles banner with mode
    #>
    param(
        [Parameter(Mandatory = $true)]
        [ValidateSet("Gather", "Install")]
        [string]$Mode
    )

    Write-Host ""
    Write-Host "    " -NoNewline
    Write-Host " HERFILES " -ForegroundColor Black -BackgroundColor White -NoNewline

    if ($Mode -eq "Gather") {
        Write-Host " GATHER " -ForegroundColor Black -BackgroundColor Cyan
    } else {
        Write-Host " INSTALL " -ForegroundColor Black -BackgroundColor Cyan
    }
    Write-Host ""
}

function Write-HerDivider {
    <#
    .SYNOPSIS
        Write a subtle divider line spanning terminal width
    #>
    param(
        [switch]$Light
    )

    $color = if ($Light) { [ConsoleColor]::DarkGray } else { [ConsoleColor]::Gray }
    $indentLen = $script:INDENT_1.Length

    try {
        $consoleWidth = [Console]::WindowWidth
        $width = [Math]::Max(40, $consoleWidth - $indentLen - 1)
    } catch {
        $width = 76  # Fallback for non-interactive contexts
    }

    Write-Host "$($script:INDENT_1)$("-" * $width)" -ForegroundColor $color
}

function Write-HerSection {
    <#
    .SYNOPSIS
        Write a section header for a module
    #>
    param(
        [Parameter(Mandatory = $true)]
        [string]$Name
    )

    Write-Host ""
    Write-Host "$($script:INDENT_1)" -NoNewline
    Write-Host " $Name " -ForegroundColor Black -BackgroundColor White
    Write-Host ""
}

function Write-HerRow {
    <#
    .SYNOPSIS
        Write a row with aligned label and value
    #>
    param(
        [Parameter(Mandatory = $true)]
        [string]$Label,

        [Parameter(Mandatory = $true)]
        [string]$Value,

        [Parameter(Mandatory = $false)]
        [ConsoleColor]$ValueColor = [ConsoleColor]::White,

        [Parameter(Mandatory = $false)]
        [string]$Prefix = "",

        [Parameter(Mandatory = $false)]
        [ConsoleColor]$PrefixColor = [ConsoleColor]::Gray
    )

    $prefixLen = if ($Prefix) { $Prefix.Length + 1 } else { 0 }
    $labelWidth = $script:COL_LABEL - $prefixLen
    $paddedLabel = $Label.PadRight($labelWidth)

    Write-Host "$($script:INDENT_2)" -NoNewline
    if ($Prefix) {
        Write-Host "$Prefix " -ForegroundColor $PrefixColor -NoNewline
    }
    Write-Host "$paddedLabel" -ForegroundColor DarkGray -NoNewline
    Write-Host "$Value" -ForegroundColor $ValueColor
}

function Write-HerStatus {
    <#
    .SYNOPSIS
        Write a status row with symbol
    #>
    param(
        [Parameter(Mandatory = $true)]
        [string]$Label,

        [Parameter(Mandatory = $true)]
        [ValidateSet("ok", "skip", "fail", "new", "info")]
        [string]$Status,

        [Parameter(Mandatory = $false)]
        [string]$Detail = ""
    )

    $symbols = @{
        ok   = @{ Symbol = "+"; Color = [ConsoleColor]::Green }
        skip = @{ Symbol = "~"; Color = [ConsoleColor]::DarkGray }
        fail = @{ Symbol = "x"; Color = [ConsoleColor]::Red }
        new  = @{ Symbol = "+"; Color = [ConsoleColor]::Cyan }
        info = @{ Symbol = " "; Color = [ConsoleColor]::Gray }
    }

    $s = $symbols[$Status]
    # Symbol takes 2 chars ("+ "), so label gets remaining width
    $paddedLabel = $Label.PadRight($script:COL_STATUS_LABEL)

    Write-Host "$($script:INDENT_2)" -NoNewline
    Write-Host "$($s.Symbol) " -ForegroundColor $s.Color -NoNewline
    Write-Host "$paddedLabel" -ForegroundColor $s.Color -NoNewline

    if ($Detail) {
        Write-Host "$Detail" -ForegroundColor DarkGray
    } else {
        Write-Host ""
    }
}

function Write-HerResult {
    <#
    .SYNOPSIS
        Write final result message
    #>
    param(
        [Parameter(Mandatory = $true)]
        [ValidateSet("success", "partial", "skipped", "error")]
        [string]$Type,

        [Parameter(Mandatory = $true)]
        [string]$Message
    )

    Write-Host ""
    Write-Host "$($script:INDENT_1)" -NoNewline

    switch ($Type) {
        "success" {
            Write-Host " OK " -ForegroundColor Black -BackgroundColor White -NoNewline
            Write-Host " $Message" -ForegroundColor White
        }
        "partial" {
            Write-Host " OK " -ForegroundColor Black -BackgroundColor Yellow -NoNewline
            Write-Host " $Message" -ForegroundColor Yellow
        }
        "skipped" {
            Write-Host " -- " -ForegroundColor White -BackgroundColor DarkGray -NoNewline
            Write-Host " $Message" -ForegroundColor DarkGray
        }
        "error" {
            Write-Host " ERR " -ForegroundColor White -BackgroundColor Red -NoNewline
            Write-Host " $Message" -ForegroundColor Red
        }
    }
}

function Write-HerNote {
    <#
    .SYNOPSIS
        Write an informational note
    #>
    param(
        [Parameter(Mandatory = $true)]
        [string]$Message
    )

    Write-Host "$($script:INDENT_2)$Message" -ForegroundColor DarkGray
}

function Write-HerCommand {
    <#
    .SYNOPSIS
        Write a command in a distinct code-block style
    #>
    param(
        [Parameter(Mandatory = $true)]
        [string]$Command,

        [Parameter(Mandatory = $false)]
        [string]$Label = ""
    )

    if ($Label) {
        Write-Host "$($script:INDENT_2)$Label" -ForegroundColor DarkGray
    }
    Write-Host "$($script:INDENT_2)" -NoNewline
    Write-Host " $Command " -ForegroundColor White -BackgroundColor DarkGray
}

function Write-HerPrompt {
    <#
    .SYNOPSIS
        Write a prompt line (before Read-Host)
    #>
    param(
        [Parameter(Mandatory = $true)]
        [string]$Question,

        [Parameter(Mandatory = $false)]
        [string]$Hint = ""
    )

    Write-Host ""
    Write-Host "$($script:INDENT_2)" -NoNewline
    Write-Host "? " -ForegroundColor Cyan -NoNewline
    Write-Host "$Question " -ForegroundColor Gray -NoNewline
    if ($Hint) {
        Write-Host "$Hint" -ForegroundColor DarkGray -NoNewline
    }
}

# Legacy compatibility wrappers (used by modules)
function Write-HerHeader {
    param([string]$Title, [string]$Subtitle = "")
    Write-HerSection -Name $Title
}

function Write-HerSuccess {
    param([string]$Message)
    Write-HerResult -Type "success" -Message $Message
}

function Write-HerError {
    param([string]$Message)
    Write-HerResult -Type "error" -Message $Message
}

function Write-HerWarning {
    param([string]$Message)
    Write-Host "$($script:INDENT_2)" -NoNewline
    Write-Host "! " -ForegroundColor Yellow -NoNewline
    Write-Host "$Message" -ForegroundColor Yellow
}

function Write-HerInfo {
    param([string]$Message)
    Write-Host "$($script:INDENT_2)$Message" -ForegroundColor Gray
}

function Write-HerDetail {
    param([string]$Label, [string]$Value, [int]$Indent = 2)
    Write-HerRow -Label $Label -Value $Value
}

function Write-HerSkip {
    param([string]$Message)
    Write-HerStatus -Label $Message -Status "skip"
}

function Write-HerAction {
    param([string]$Action, [string]$Target)
    Write-HerStatus -Label $Target -Status "new" -Detail $Action
}

function Write-HerTag {
    param(
        [string]$Tag,
        [string]$Message = "",
        [ConsoleColor]$TagForeground = [ConsoleColor]::Black,
        [ConsoleColor]$TagBackground = [ConsoleColor]::White,
        [ConsoleColor]$MessageColor = [ConsoleColor]::Gray,
        [switch]$NoNewline
    )
    Write-Host " $Tag " -ForegroundColor $TagForeground -BackgroundColor $TagBackground -NoNewline
    if ($Message) {
        Write-Host " $Message" -ForegroundColor $MessageColor -NoNewline:$NoNewline
    } elseif (-not $NoNewline) {
        Write-Host ""
    }
}

# ============================================================================
#  PROMPT UTILITIES
# ============================================================================

function Read-HerConfirm {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Question,

        [Parameter(Mandatory = $false)]
        [bool]$Default = $true
    )

    $hint = if ($Default) { "(Y/n)" } else { "(y/N)" }
    Write-HerPrompt -Question $Question -Hint $hint
    $response = Read-Host

    if ([string]::IsNullOrWhiteSpace($response)) {
        return $Default
    }

    return $response -match '^[Yy]'
}

function Read-HerChoice {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Question,

        [Parameter(Mandatory = $true)]
        [string[]]$Options,

        [Parameter(Mandatory = $false)]
        [int]$Default = 1
    )

    Write-Host ""
    Write-Host "$($script:INDENT_2)$Question" -ForegroundColor Gray
    Write-Host ""

    for ($i = 0; $i -lt $Options.Count; $i++) {
        $num = $i + 1
        $indicator = if ($num -eq $Default) { "*" } else { " " }
        Write-Host "$($script:INDENT_2)$indicator" -ForegroundColor White -NoNewline
        Write-Host "[$num]" -ForegroundColor Cyan -NoNewline
        Write-Host " $($Options[$i])" -ForegroundColor Gray
    }

    Write-Host ""
    $response = Read-Host "$($script:INDENT_2)Choice (1-$($Options.Count), default: $Default)"

    if ([string]::IsNullOrWhiteSpace($response)) {
        return $Default
    }

    $choice = 0
    if ([int]::TryParse($response, [ref]$choice) -and $choice -ge 1 -and $choice -le $Options.Count) {
        return $choice
    }

    return $Default
}

# ============================================================================
#  PROGRESS UTILITIES
# ============================================================================

function Write-HerProgress {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Activity,

        [Parameter(Mandatory = $true)]
        [int]$Current,

        [Parameter(Mandatory = $true)]
        [int]$Total,

        [Parameter(Mandatory = $false)]
        [string]$Status = ""
    )

    $percent = if ($Total -gt 0) { [math]::Round(($Current / $Total) * 100) } else { 0 }
    $barWidth = 20
    $filled = [math]::Round(($percent / 100) * $barWidth)
    $empty = $barWidth - $filled

    $bar = ("=" * $filled) + ("-" * $empty)

    $statusText = if ($Status) {
        $maxLen = 28
        if ($Status.Length -gt $maxLen) { $Status.Substring(0, $maxLen) + ".." } else { $Status.PadRight(30) }
    } else { "" }

    Write-Host "`r$($script:INDENT_2)[$bar] $($percent.ToString().PadLeft(3))%  $statusText" -NoNewline
}

function Complete-HerProgress {
    Write-Host ""
}

# ============================================================================
#  FILE UTILITIES
# ============================================================================

function Get-HerFileHash {
    param([Parameter(Mandatory = $true)][string]$Path)

    if (-not (Test-Path $Path -PathType Leaf)) {
        return $null
    }

    return (Get-FileHash -Path $Path -Algorithm SHA256).Hash
}

function Get-HerFileInfo {
    param([Parameter(Mandatory = $true)][string]$Path)

    if (-not (Test-Path $Path -PathType Leaf)) {
        return $null
    }

    $file = Get-Item $Path
    return [PSCustomObject]@{
        Path          = $Path
        Name          = $file.Name
        Size          = $file.Length
        SizeFormatted = Format-HerFileSize -Bytes $file.Length
        Created       = $file.CreationTime
        Modified      = $file.LastWriteTime
        Hash          = Get-HerFileHash -Path $Path
    }
}

function Format-HerFileSize {
    param([Parameter(Mandatory = $true)][long]$Bytes)

    if ($Bytes -lt 1KB) { return "$Bytes B" }
    if ($Bytes -lt 1MB) { return "{0:N1} KB" -f ($Bytes / 1KB) }
    if ($Bytes -lt 1GB) { return "{0:N1} MB" -f ($Bytes / 1MB) }
    return "{0:N2} GB" -f ($Bytes / 1GB)
}

function Compare-HerFiles {
    param(
        [Parameter(Mandatory = $true)][string]$SourcePath,
        [Parameter(Mandatory = $true)][string]$TargetPath,
        [string]$SourceLabel = "Source",
        [string]$TargetLabel = "Target"
    )

    $sourceInfo = Get-HerFileInfo -Path $SourcePath
    $targetInfo = Get-HerFileInfo -Path $TargetPath

    if (-not $sourceInfo) {
        Write-HerError "Source file not found: $SourcePath"
        return $null
    }

    if (-not $targetInfo) {
        return [PSCustomObject]@{
            AreIdentical = $false
            IsNewFile    = $true
            Source       = $sourceInfo
            Target       = $null
        }
    }

    $identical = $sourceInfo.Hash -eq $targetInfo.Hash

    if (-not $identical) {
        Write-Host ""
        Write-HerRow -Label "Incoming" -Value $sourceInfo.Modified.ToString('yyyy-MM-dd HH:mm') -ValueColor Cyan
        Write-HerRow -Label "Current" -Value $targetInfo.Modified.ToString('yyyy-MM-dd HH:mm') -ValueColor Magenta
        Write-Host ""
    }

    return [PSCustomObject]@{
        AreIdentical = $identical
        IsNewFile    = $false
        Source       = $sourceInfo
        Target       = $targetInfo
    }
}

function Copy-HerFile {
    param(
        [Parameter(Mandatory = $true)][string]$SourcePath,
        [Parameter(Mandatory = $true)][string]$TargetPath,
        [string]$Description = "",
        [switch]$Force,
        [switch]$ConfirmOverwrite
    )

    $targetDir = Split-Path -Parent $TargetPath
    if (-not (Test-Path $targetDir)) {
        New-Item -ItemType Directory -Path $targetDir -Force | Out-Null
    }

    $targetExists = Test-Path $TargetPath -PathType Leaf

    if ($targetExists -and $ConfirmOverwrite -and -not $Force) {
        $comparison = Compare-HerFiles -SourcePath $SourcePath -TargetPath $TargetPath

        if ($comparison.AreIdentical) {
            Write-HerSkip "Identical: $Description"
            return $true
        }

        $confirm = Read-HerConfirm -Question "Overwrite $($Description)?" -Default $false
        if (-not $confirm) {
            Write-HerSkip "Skipped: $Description"
            return $false
        }
    }

    try {
        Copy-Item -Path $SourcePath -Destination $TargetPath -Force
        Write-HerAction -Action "Copied" -Target $Description
        return $true
    } catch {
        Write-HerError "Failed to copy: $($_.Exception.Message)"
        return $false
    }
}

# ============================================================================
#  PATH TEMPLATING
# ============================================================================

function ConvertTo-HerTemplatePath {
    param([Parameter(Mandatory = $true)][string]$Content)

    $homePath = $env:USERPROFILE
    $homePathForward = $homePath -replace '\\', '/'

    $result = $Content -replace [regex]::Escape($homePath), $script:HOME_PLACEHOLDER
    $result = $result -replace [regex]::Escape($homePathForward), $script:HOME_PLACEHOLDER

    return $result
}

function Get-HerManagedPath {
    <#
    .SYNOPSIS
        Get the path to the HerFiles managed directory ($HOME/.herfiles)
    #>
    param(
        [string]$PathStyle = "native"
    )

    $managedPath = Join-Path $env:USERPROFILE $script:MANAGED_DIR_NAME

    switch ($PathStyle) {
        "forward" { $managedPath = $managedPath -replace '\\', '/' }
        "backward" { $managedPath = $managedPath -replace '/', '\' }
    }

    return $managedPath
}

function Ensure-HerManagedDirectory {
    <#
    .SYNOPSIS
        Ensure the HerFiles managed directory exists
    #>
    param(
        [string]$Subdirectory = ""
    )

    $managedPath = Get-HerManagedPath
    if ($Subdirectory) {
        $managedPath = Join-Path $managedPath $Subdirectory
    }

    if (-not (Test-Path $managedPath)) {
        New-Item -ItemType Directory -Path $managedPath -Force | Out-Null
    }

    return $managedPath
}

function ConvertFrom-HerTemplatePath {
    <#
    .SYNOPSIS
        Replace {{HERFILES_HOME}} with the user's home directory
    #>
    param(
        [Parameter(Mandatory = $true)][string]$Content,
        [string]$PathStyle = "native"
    )

    $homePath = $env:USERPROFILE

    switch ($PathStyle) {
        "forward" { $homePath = $homePath -replace '\\', '/' }
        "backward" { $homePath = $homePath -replace '/', '\' }
    }

    return $Content -replace [regex]::Escape($script:HOME_PLACEHOLDER), $homePath
}

function ConvertFrom-HerManagedPath {
    <#
    .SYNOPSIS
        Replace {{HERFILES_HOME}} with the managed directory path ($HOME/.herfiles)
        Use this for files that HerFiles manages directly (like VSCode custom assets)
    #>
    param(
        [Parameter(Mandatory = $true)][string]$Content,
        [string]$PathStyle = "native"
    )

    $managedPath = Get-HerManagedPath -PathStyle $PathStyle

    return $Content -replace [regex]::Escape($script:HOME_PLACEHOLDER), $managedPath
}

function Test-HerContainsHomePath {
    param([Parameter(Mandatory = $true)][string]$Content)

    $homePath = $env:USERPROFILE
    $homePathForward = $homePath -replace '\\', '/'

    return ($Content -match [regex]::Escape($homePath)) -or ($Content -match [regex]::Escape($homePathForward))
}

# ============================================================================
#  PROGRAM DETECTION
# ============================================================================

function Test-HerProgramInstalled {
    param([Parameter(Mandatory = $true)][string]$ProgramName)

    $cmd = Get-Command $ProgramName -ErrorAction SilentlyContinue
    return $null -ne $cmd
}

function Install-HerProgramWithWinget {
    param(
        [Parameter(Mandatory = $true)][string]$ProgramName,
        [Parameter(Mandatory = $true)][string]$WingetId,
        [string]$Description = ""
    )

    if (-not (Test-HerProgramInstalled -ProgramName "winget")) {
        Write-HerError "winget is not available"
        return $false
    }

    $desc = if ($Description) { $Description } else { $ProgramName }
    Write-HerWarning "$desc is not installed"

    $confirm = Read-HerConfirm -Question "Install via winget?" -Default $true

    if (-not $confirm) {
        Write-HerNote "Skipping $desc configuration"
        return $false
    }

    Write-HerInfo "Installing $desc..."
    Write-Host ""

    try {
        $result = & winget install --id $WingetId --accept-package-agreements --accept-source-agreements 2>&1

        if ($LASTEXITCODE -eq 0) {
            Write-Host ""
            Write-HerResult -Type "success" -Message "$desc installed"
            $env:Path = [System.Environment]::GetEnvironmentVariable("Path", "Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path", "User")
            return $true
        } else {
            Write-Host ""
            Write-HerResult -Type "error" -Message "Installation failed"
            return $false
        }
    } catch {
        Write-HerError "Installation error: $($_.Exception.Message)"
        return $false
    }
}

# ============================================================================
#  ADMIN UTILITIES
# ============================================================================

function Test-HerAdminRights {
    $identity = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = New-Object Security.Principal.WindowsPrincipal($identity)
    return $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

function Request-HerAdminRights {
    param([Parameter(Mandatory = $true)][string]$Operation)

    if (Test-HerAdminRights) {
        return $true
    }

    Write-HerWarning "Operation '$Operation' requires administrator privileges"
    $confirm = Read-HerConfirm -Question "Restart as Administrator?" -Default $true

    if ($confirm) {
        Write-HerNote "Please re-run this command in the new window"
        Start-Process powershell -Verb RunAs
        return $false
    }

    return $false
}

# ============================================================================
#  EXPORTS
# ============================================================================

Export-ModuleMember -Function @(
    # New UI
    'Write-HerBanner'
    'Write-HerDivider'
    'Write-HerSection'
    'Write-HerRow'
    'Write-HerStatus'
    'Write-HerResult'
    'Write-HerNote'
    'Write-HerCommand'
    'Write-HerPrompt'
    # Legacy UI
    'Write-HerTag'
    'Write-HerHeader'
    'Write-HerSuccess'
    'Write-HerError'
    'Write-HerWarning'
    'Write-HerInfo'
    'Write-HerDetail'
    'Write-HerSkip'
    'Write-HerAction'
    # Prompts
    'Read-HerConfirm'
    'Read-HerChoice'
    # Progress
    'Write-HerProgress'
    'Complete-HerProgress'
    # Files
    'Get-HerFileHash'
    'Get-HerFileInfo'
    'Format-HerFileSize'
    'Compare-HerFiles'
    'Copy-HerFile'
    # Templating
    'ConvertTo-HerTemplatePath'
    'ConvertFrom-HerTemplatePath'
    'ConvertFrom-HerManagedPath'
    'Test-HerContainsHomePath'
    # Managed directory
    'Get-HerManagedPath'
    'Ensure-HerManagedDirectory'
    # Programs
    'Test-HerProgramInstalled'
    'Install-HerProgramWithWinget'
    # Admin
    'Test-HerAdminRights'
    'Request-HerAdminRights'
)
