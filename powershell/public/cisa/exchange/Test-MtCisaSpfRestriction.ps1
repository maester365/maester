function Test-MtCisaSpfRestriction {
    <#
    .SYNOPSIS
    Checks state of SPF records for all exo domains

    .DESCRIPTION
    A list of approved IP addresses for sending mail SHALL be maintained.

    .EXAMPLE
    Test-MtCisaSpfRestriction

    Returns true if SPF record exists and has a fail all modifier for all exo domains

    .LINK
    https://maester.dev/docs/commands/Test-MtCisaSpfRestriction
    #>
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    Add-MtTestResultDetail -SkippedBecause Custom -SkippedCustomReason "This test has been deprecated by CISA as of May 2024 (MS.EXO.2.1v1)."
    return $null
}
