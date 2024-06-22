<#
.SYNOPSIS
   Installs the latest ready-made Maester tests built by the Maester team.

.DESCRIPTION
    The Maester team maintains a repository of ready made tests that can be used to verify the configuration of your Microsoft 365 tenant.

    The tests can be viewed at https://github.com/maester365/maester/tree/main/tests

.PARAMETER Path
    The path to install the Maester tests to. Defaults to the current directory.

.Parameter Prerequisites
    Install prerequisite PowerShell modules if the minimum required versions are not already installed.

.EXAMPLE
    Install-MaesterTests

    Install the latest set of Maester tests in the current directory.

.EXAMPLE
    Install-MaesterTests -Path .\maester-tests

    Installs the latest Maester tests in the specified directory.

.EXAMPLE
    Install-MaesterTests -Prerequisites

    Installs the latest Maester tests in the current directory.
    Installs the required PowerShell modules if the minimum required versions are not already installed.
#>

Function Install-MaesterTests {
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSAvoidUsingWriteHost', '', Justification = 'Colors are beautiful')]
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseSingularNouns', '', Justification = 'This command updates multiple tests')]
    [CmdletBinding()]
    param(
        # The path to install the Maester tests to, defaults to the current directory.
        [Parameter(Mandatory = $false)]
        [string] $Path = ".\",

        # Switch to optionally install Pester pre-requisites
        [Parameter(Mandatory = $false)]
        [switch] $Prerequisites
    )
    Get-IsNewMaesterVersionAvailable | Out-Null

    Write-Verbose "Installing Maester tests to $Path"

    $targetFolderExists = (Test-Path -Path $Path)

    # Check if current folder is empty and prompt user to continue if it is not
    if ($targetFolderExists -and (Get-ChildItem -Path $Path).Count -gt 0) {
        $message = "`nThe folder $Path is not empty.`nWe recommend installing the tests in an empty folder.`nDo you want to continue with this folder? (y/n): "
        $continue = Get-MtConfirmation $message
        if (!$continue) {
            Write-Host "Maester tests not installed." -ForegroundColor Red
            return
        }
    }

    Update-MtMaesterTests -Path $Path -Install

    # Optionally install any missing required module versions.
    if ( $PSBoundParameters.ContainsKey('Prerequisites') ) {
        $RequiredModules = (Get-Module -Name 'Maester' -ListAvailable).RequiredModules
        foreach ($module in $RequiredModules) {
            $moduleMinVersion = $module.Version
            $moduleName = $module.Name

            if ( ((Get-Module $moduleName -ListAvailable).Version | Sort-Object -Descending | Select-Object -First 1) -lt $moduleMinVersion ) {
                Write-Verbose "Installing $moduleName."
                Install-Module -Name $moduleName -SkipPublisherCheck -Force -Scope CurrentUser
            } else {
                Write-Information -Message "The minimum required version of $moduleName is already installed." -InformationAction Continue
            }
        }
        Remove-Variable moduleName,moduleMinVersion,RequiredModules
    }

}
