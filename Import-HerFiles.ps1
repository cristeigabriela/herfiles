<#
.SYNOPSIS
    Import HerFiles module cleanly (no warnings).

.DESCRIPTION
    Dot-source this script:  . .\Import-HerFiles.ps1

    Or add to $PROFILE:
        . "C:\Users\gabriela\Documents\HerFiles\Import-HerFiles.ps1"
#>

$modulePath = Join-Path $PSScriptRoot "HerFiles.psd1"
Import-Module $modulePath -Force -DisableNameChecking -Global

Write-Host ""
Write-Host "     " -NoNewline
Write-Host " HERFILES " -ForegroundColor Black -BackgroundColor White -NoNewline
Write-Host " ready" -ForegroundColor DarkGray
Write-Host ""
Write-Host "        Gather-DotFiles" -ForegroundColor White -NoNewline
Write-Host "     collect" -ForegroundColor DarkGray
Write-Host "        Install-DotFiles" -ForegroundColor White -NoNewline
Write-Host "    deploy" -ForegroundColor DarkGray
Write-Host ""
