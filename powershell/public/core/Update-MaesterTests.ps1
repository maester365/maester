
<#
.SYNOPSIS
   Updates the specified folder with the latest ready-made Maester tests built by the Maester team.

.DESCRIPTION
    The Maester team maintains a repository of ready made tests that can be used to verify the configuration of your Microsoft 365 tenant.

    The tests can be viewed at https://github.com/maester365/maester/tree/main/tests

.PARAMETER Path
    The path to install or update the Maester tests in.

.EXAMPLE
    Update-MaesterTests -Path .\maester-tests

    Installs or updates the latest Maester tests in the specified directory.

.EXAMPLE
    Update-MaesterTests -Path .\

    Install the latest set of Maester tests in the current directory.

.LINK
    https://maester.dev/docs/commands/Update-MaesterTests
#>
function Update-MaesterTests {
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSAvoidUsingWriteHost', '', Justification = 'Colors are beautiful')]
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseSingularNouns', '', Justification = 'This command updates multiple tests')]
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseShouldProcessForStateChangingFunctions', '', Justification = 'TODO: Implement ShouldProcess')]
    [CmdletBinding()]
    param(
        # The path to install or update Maester tests in. Defaults to the current directory.
        [Parameter(Mandatory = $false)]
        [string] $Path = '.\',

        # Switch to control the toggling off of the "Are you sure?" prompt
        [Parameter(Mandatory = $false)]
        [switch] $Force
    )
    Write-Verbose 'Checking if newer version is available.'
    Get-IsNewMaesterVersionAvailable | Out-Null

    Write-Verbose "Updating Maester tests in '$Path'."
    Update-MtMaesterTests -Path $Path -Force:$Force
}
