<#
.SYNOPSIS
   Checks the PowerShell Gallery for a newer version of the Maester module and displays a message if a newer version is available.

.DESCRIPTION
    Compares the installed version of the Maester module with the latest version available on the PowerShell Gallery.

    This is useful to let the user know if there are newer versions with updates and bug fixes.

    The function returns $true if a newer version is available, otherwise $false.

.EXAMPLE
    Get-IsNewMaesterVersionAvailable
#>

Function Get-IsNewMaesterVersionAvailable {
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSAvoidUsingWriteHost', '', Justification = 'Colors are beautiful')]
    [CmdletBinding()]
    param()

    try {
        $currentVersion = (Get-Module -Name Maester).Version
        $latestVersion = (Find-Module -Name Maester).Version

        if ($currentVersion -lt $latestVersion) {
            Write-Host "🔥 A newer version of the Maester module is available. Installed version: $currentVersion, Latest version: $latestVersion" -ForegroundColor Yellow
            Write-Host "Run 'Update-Module Maester' to install the latest version." -ForegroundColor Yellow
            return $true
        }
    } catch {}
    return $false
}