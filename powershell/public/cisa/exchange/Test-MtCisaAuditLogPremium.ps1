<#
.SYNOPSIS
    Checks state of purview

.DESCRIPTION
    Microsoft Purview Audit (Premium) logging SHALL be enabled.

.EXAMPLE
    Test-MtCisaAuditLogPremium

    Returns true if audit log enabled

.LINK
    https://maester.dev/docs/commands/Test-MtCisaAuditLogPremium
#>
function Test-MtCisaAuditLogPremium {
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    Add-MtTestResultDetail -SkippedBecause Custom -SkippedCustomReason "This test has been deprecated by CISA on March 2025. MS.EXO.17.2v1 was originally included in order to enable auditing of additional user actions not captured under Purview Audit (Standard). In October 2023, Microsoft announced changes to its Purview Audit service that included making audit events in Purview Audit (Premium) available to Purview Audit (Standard) subscribers. Now that the rollout of changes has been completed, Purview (Standard) includes the necessary auditing which is addressed by MS.EXO.17.2v1 See [CISA Gov - GitHub](https://github.com/cisagov/ScubaGear/blob/7cefa12639b4bc36990f8f2849b57ad2fdafec4c/PowerShell/ScubaGear/baselines/removedpolicies.md?plain=1#L56)"
    return $null
}