<#
.SYNOPSIS
   Installs the latest ready-made Maester tests built by the Maester team and the required Pester module.

.DESCRIPTION
    The Maester team maintains a repository of ready made tests that can be used to verify the configuration of your Microsoft 365 tenant.

    The tests can be viewed at https://github.com/maester365/maester/tree/main/tests

.PARAMETER Path
    The path to install the Maester tests in. Defaults to the current directory.

.Parameter SkipPesterCheck
    Skips the automatic installation check for Pester.

.EXAMPLE
    Install-MaesterTests

    Install the latest set of Maester tests in the current directory and installs the Pester module if needed.

.EXAMPLE
    Install-MaesterTests -Path .\maester-tests

    Installs the latest Maester tests in the specified directory and installs the Pester module if needed.

.EXAMPLE
    Install-MaesterTests -SkipPesterCheck

    Installs the latest Maester tests in the current directory. Skips the check for the required version of Pester.

.LINK
    https://maester.dev/docs/commands/Install-MaesterTests
#>
function Install-MaesterTests {
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSAvoidUsingWriteHost', '', Justification = 'Colors are beautiful')]
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseSingularNouns', '', Justification = 'This command updates multiple tests')]
    [CmdletBinding()]
    param(
        # The path to install the Maester tests to, defaults to the current directory.
        [Parameter(Mandatory = $false)]
        [string] $Path = ".\",

        # Skip automatic installation of Pester
        [Parameter(Mandatory = $false)]
        [switch] $SkipPesterCheck
    )

    # Note: If testing this locally in dev, you will need to run ./build/Copy-MaesterTestsToPSModule.ps1 to copy the tests to the correct location.
    # This script is automatically run during the build process to embed the tests into the PowerShell module.

    [version]$MinPesterVersion = '5.5.0'
    # The default action installs the minimum required version of Pester if not present. Opt out with -SkipPesterCheck.
    if ( $PSBoundParameters.ContainsKey('SkipPesterCheck') ) {
        Write-Verbose "Skipping Pester version check."
    } else {
        if ( ((Get-Module -Name 'Pester' -ListAvailable).Version | Sort-Object -Descending | Select-Object -First 1) -lt $MinPesterVersion ) {
            Write-Host "The minimum required version of Pester is not installed." -ForegroundColor Yellow
            Write-Host "Installing Pester version $MinPesterVersion..." -ForegroundColor Yellow
            Install-Module -Name 'Pester' -MinimumVersion $MinPesterVersion -SkipPublisherCheck -Force -Scope CurrentUser
            Import-Module -Name 'Pester'
        } else {
            Write-Verbose "The minimum required version of Pester is already installed."
        }
    }

    Get-IsNewMaesterVersionAvailable | Out-Null

    Write-Verbose "Installing Maester tests to $Path"

    $targetFolderExists = (Test-Path -Path $Path -PathType Container)


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
}
