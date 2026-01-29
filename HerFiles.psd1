@{
    # Module manifest for HerFiles

    # Script module associated with this manifest
    RootModule = 'HerFiles.psm1'

    # Version number
    ModuleVersion = '1.0.0'

    # ID used to uniquely identify this module
    GUID = 'a1b2c3d4-e5f6-7890-abcd-ef1234567890'

    # Author
    Author = 'gabriela'

    # Description
    Description = 'Windows dotfiles management system'

    # Minimum version of PowerShell required
    PowerShellVersion = '5.1'

    # Functions to export - this prevents the "unapproved verb" warning
    FunctionsToExport = @(
        'Gather-DotFiles'
        'Install-DotFiles'
    )

    # Cmdlets to export
    CmdletsToExport = @()

    # Variables to export
    VariablesToExport = @()

    # Aliases to export
    AliasesToExport = @()

    # Private data
    PrivateData = @{
        PSData = @{
            Tags = @('dotfiles', 'windows', 'configuration')
        }
    }
}
