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

function Get-IsNewMaesterVersionAvailable {
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSAvoidUsingWriteHost', '', Justification = 'Colors are beautiful')]
    [OutputType([bool])]
    [CmdletBinding()]
    param()

    try {
        $currentVersion = ((Get-Module -Name Maester).Version | Select-Object -Last 1).ToString()
        $latestVersion = (Find-Module -Name Maester).Version

        if ($currentVersion -lt $latestVersion) {
            Write-Host "🔥 FYI: A newer version of Maester is available! Run the commands below to update to the latest version."
            Write-Host "💥 Installed version: $currentVersion → Latest version: $latestVersion" -ForegroundColor DarkGray
            Write-Host "✨ Update-Module Maester" -NoNewline -ForegroundColor Green
            Write-Host " → Install the latest version of Maester." -ForegroundColor Yellow
            Write-Host "💫 Update-MaesterTests" -NoNewline -ForegroundColor Green
            Write-Host " → Get the latest tests built by the Maester team and community." -ForegroundColor Yellow
            return $true
        }
    } catch { Write-Verbose -Message $_ }
    return $false
}