function Update-MaesterTests {
    <#
    .SYNOPSIS
    Removes copies of the built-in Maester tests from a folder.

    .DESCRIPTION
    From Maester 3.0 the tests that ship with Maester run from the module itself. Copies of them that
    Install-MaesterTests wrote in Maester 2.x are not run any more. Update-MaesterTests removes those
    copies: every *.Tests.ps1 file outside a Custom folder whose tests all have the ID of a current,
    previous or retired built-in test. Files with any other test, and everything under Custom/, are kept.

    A maester-config.json that is a copy of the file Maester 2.x shipped is reduced to the settings
    that differ from the built-in defaults.

    .PARAMETER Path
    The folder to clean up. Defaults to the current directory.

    .PARAMETER Force
    Does not ask for confirmation.

    .EXAMPLE
    Update-MaesterTests -Path ./maester-tests -WhatIf

    Lists the files that would be removed.

    .EXAMPLE
    Update-MaesterTests -Path ./maester-tests -Force

    Removes the copies without asking.

    .LINK
    https://maester.dev/docs/commands/Update-MaesterTests
    #>
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseSingularNouns', '', Justification = 'Kept for compatibility with Maester 2.x')]
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSShouldProcess', '', Justification = 'ShouldProcess is called by Update-MtMaesterTests, which inherits -WhatIf and -Confirm')]
    [CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'High')]
    param(
        # The folder to clean up. Defaults to the current directory.
        [Parameter(Mandatory = $false)]
        [string] $Path = '.',

        # Do not ask for confirmation.
        [Parameter(Mandatory = $false)]
        [switch] $Force
    )

    Write-Verbose 'Checking if newer version is available.'
    Get-IsNewMaesterVersionAvailable | Out-Null

    if ($Force -and -not $PSBoundParameters.ContainsKey('Confirm')) { $ConfirmPreference = 'None' }
    Update-MtMaesterTests -Path $Path
}
