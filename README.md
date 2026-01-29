# HerFiles

My dotfiles... and, a bespoke Windows dotfiles manager based on modules meant to be version-controlled. Not meant to be used outside of this context.

## Dotfiles

- [PowerShell](./HerFiles/PowerShell/)
- [Starship](./HerFiles/Starship/)
- [VSCode](./HerFiles/VSCode/)

## How to use

In a PowerShell prompt:
```pwsh
.\Import-HerFiles.ps1

# This will install the `HerFiles` contents by default, installing this repo's dotfiles.
# This will install all the modules by default.
Install-DotFiles
```

- If it has to, you will be prompted to allow the installation of the applications.
- If there's conflicts, you will be prompted to respond to them.

## How to update

In a PowerShell prompt:
```pwsh
# This will, by default, generate a `HerFiles` folder in PWD, generating for all modules.
# Recommended to sync with Git.
Gather-DotFiles
```

then, maybe commit to Git!

## Structure

- **PWD:** usually, here is where you'll put the results from `Gather-DotFiles`. 
- **$HOME\\.herfiles:** the directory where all sorts of stray files go. Updated as an `Install-DotFiles` step.

## Why?

Some of the dotfiles get complicated and need file management.