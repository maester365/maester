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

    Add-MtTestResultDetail -SkippedBecause Custom -SkippedCustomReason "This test has been deprecated by CISA as of May 2024. MS.EXO.2.1v1 is not a security configuration that can be audited and acts as a step in the implementation of policy MS.EXO.2.2. Maintaining the list of approved IPs has been incorporated into the implementation guidance for MS.EXO.2.2 and removed as a standalone policy. See [CISA SCuBA Removed Policies](https://github.com/cisagov/ScubaGear/blob/main/PowerShell/ScubaGear/baselines/removedpolicies.md#msexo21v1)"
    return $null
}
