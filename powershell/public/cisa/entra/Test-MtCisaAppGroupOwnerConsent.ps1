function Test-MtCisaAppGroupOwnerConsent {
    <#
    .SYNOPSIS
    Checks if group owners can consent to apps

    .DESCRIPTION
    Group owners SHALL NOT be allowed to consent to applications.

    .EXAMPLE
    Test-MtCisaAppGroupOwnerConsent

    Returns true if disabled

    .LINK
    https://maester.dev/docs/commands/Test-MtCisaAppGroupOwnerConsent
    #>
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    Add-MtTestResultDetail -SkippedBecause Custom -SkippedCustomReason "This test has been deprecated by CISA as of March 2025. Microsoft announced via MC712143 that it will no longer be possible for group owners to consent to applications. All references including the policy, implementation steps, and section have been removed as the setting is no longer present. See [CISA SCuBA Removed Policies](https://github.com/cisagov/ScubaGear/blob/main/PowerShell/ScubaGear/baselines/removedpolicies.md#msaad54v1)"
    return $null
}
